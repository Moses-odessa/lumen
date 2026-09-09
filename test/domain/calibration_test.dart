import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Синтетический игрок с заданным истинным уровнем.
///
/// Он знает всё на своём ярусе и ниже, а выше — угадывает с вероятностью
/// 1/6: калибровка спрашивает полным кругом, а шесть — потолок вариантов
/// на экране. Плюс немного шума: живой человек ошибается и на знакомом.
class _Player {
  _Player({
    required this.trueTier,
    required this.random,
    this.slip = 0.08,
    this.guessRate = 1 / 6,
  });

  final Tier trueTier;
  final Random random;

  /// Ошибка на знакомом материале — усталость, промах пальцем.
  final double slip;

  /// Вероятность угадать на незнакомом ярусе.
  final double guessRate;

  bool answer(CalibrationStep step) {
    // Фразы даются тяжелее отдельных слов: собрать предложение сложнее,
    // чем узнать слово.
    final penalty = step.mode.isPhrase ? 0.15 : 0.0;
    // Созвучные дистракторы тоже сложнее. Раньше это читалось по режиму
    // (`GameMode.tight`), теперь — по виду дистракторов: механика у тесного
    // круга та же самая, и отличить его можно только так.
    final tight = step.isTight ? 0.08 : 0.0;

    if (step.tier.index <= trueTier.index) {
      return random.nextDouble() > slip + penalty + tight;
    }
    return random.nextDouble() < guessRate;
  }

  /// Время отклика: на знакомом быстро, на незнакомом дольше.
  Duration latency(CalibrationStep step) {
    final known = step.tier.index <= trueTier.index;
    final base = known ? 1100 : 2600;
    return Duration(milliseconds: base + random.nextInt(900));
  }
}

/// Прогоняет калибровку целиком.
CalibrationState _run(_Player player, {int maxSteps = 200}) {
  var state = CalibrationState.start();
  var steps = 0;
  while (!state.isDone && steps < maxSteps) {
    final step = state.step;
    state = Calibration.answer(
      state,
      correct: player.answer(step),
      latency: player.latency(step),
    );
    steps++;
  }
  return state;
}

/// Доводит тест до фазы подтверждения на игроке, знающем до A2.
CalibrationState _toConfirm() {
  var state = CalibrationState.start();
  var guard = 0;
  while (state.phase != CalibrationPhase.confirm && guard++ < 100) {
    state = Calibration.answer(
      state,
      correct: state.step.tier.index <= Tier.a2.index,
      latency: const Duration(seconds: 2),
    );
  }
  return state;
}

void main() {
  group('шаг', () {
    test('теснота живёт в дистракторах и не зависит от механики', () {
      // Поле обязано быть на шаге, а не выводиться из режима. Иначе правило
      // «границу проверяем созвучными» становится невыразимым: механика у
      // обычного и тесного круга теперь одна.
      const loose = CalibrationStep(
        tier: Tier.a1,
        mode: GameMode.pickTarget,
        phase: CalibrationPhase.search,
      );
      const tight = CalibrationStep(
        tier: Tier.a1,
        mode: GameMode.pickTarget,
        phase: CalibrationPhase.confirm,
        distractorKind: DistractorKind.near,
      );

      expect(loose.mode, tight.mode);
      expect(loose.isTight, isFalse, reason: 'по умолчанию круг тематический');
      expect(tight.isTight, isTrue);
    });
  });

  group('гребёнка', () {
    test('начинается с самого нижнего яруса обычным кругом', () {
      final state = CalibrationState.start();
      expect(state.phase, CalibrationPhase.comb);
      expect(state.step.tier, Tier.a0);
      expect(state.step.mode, GameMode.pickTarget);
      // «Обычный» — это про дистракторы, а не про механику: первый круг
      // игры не должен требовать различать созвучные формы.
      expect(state.step.distractorKind, DistractorKind.far);
      expect(state.step.isTight, isFalse);
    });

    test('верный ответ поднимает на ярус выше', () {
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));

      expect(state.phase, CalibrationPhase.comb);
      expect(state.step.tier, Tier.a1);
      expect(state.confirmed, contains(Tier.a0));
    });

    test('первый промах переводит в поиск', () {
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));

      expect(state.phase, CalibrationPhase.search);
      expect(state.highest, Tier.a1);
    });

    test('пройденная целиком гребёнка ведёт сразу к фразам', () {
      var state = CalibrationState.start();
      for (var i = 0; i < Tier.values.length; i++) {
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
      }

      expect(state.phase, CalibrationPhase.phrases);
      expect(state.probe, Tier.b2);
    });
  });

  group('защита от угадывания', () {
    test('подозрительно быстрый верный ответ переспрашивается', () {
      var state = CalibrationState.start();
      // Поднимаемся выше подтверждённого, чтобы ярус стал незнакомым.
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));

      final before = state.asked;
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 300));

      // Круг не засчитан, вместо него будет переспрос.
      expect(state.asked, before);
      expect(state.step.isRepeat, isTrue);
      expect(state.repeats, 1);
    });

    test('переспрос засчитывается как обычный круг', () {
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 300));

      final before = state.asked;
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));

      expect(state.asked, before + 1);
      expect(state.step.isRepeat, isFalse);
    });

    test('переспросы не бесконечны', () {
      var state = CalibrationState.start();
      var repeats = 0;
      for (var i = 0; i < 60 && !state.isDone; i++) {
        if (state.step.isRepeat) repeats++;
        state = Calibration.answer(state,
            correct: true, latency: const Duration(milliseconds: 200));
      }
      expect(repeats, lessThanOrEqualTo(CalibrationBalance.maxRepeats));
    });

    test('медленный верный ответ не переспрашивается', () {
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 3));
      expect(state.step.isRepeat, isFalse);
    });

    test('на подтверждённом ярусе быстрый ответ подозрений не вызывает', () {
      // Быстро отвечать на том, что знаешь, — норма, а не признак угадывания.
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));
      expect(state.step.isRepeat, isFalse);
    });
  });

  group('подтверждение границы', () {
    test('верный ответ обнуляет счётчик промахов', () {
      // Правило рядом с константой сказано так: «ярус роняет только вторая
      // осечка ПОДРЯД». Счётчик копился накопительно, и «промах → верно →
      // промах» ронял ярус, хотя по описанию не должен был. Расхождение
      // между комментарием и кодом здесь дорого: игрок получал ярус ниже
      // заслуженного и не мог понять, за что.
      var state = _toConfirm();
      final probe = state.probe;

      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 2));
      expect(state.probe, probe, reason: 'первый промах прощается');
      expect(state.confirmFailures, 1);

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      expect(state.confirmFailures, 0, reason: 'верный ответ не обнулил счёт');

      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 2));
      expect(state.probe, probe,
          reason: 'ярус упал от промахов, которые не шли подряд');
    });

    test('итог остаётся пустым, пока тест не закончен', () {
      // Контракт поля: «итог; null, пока тест не закончен». Ветка «две
      // осечки на A0» его нарушала: состояние читалось как
      // phase: phrases, isDone: false, result: a0 — все четыре оставшихся
      // круга. Гейт в приложении стоит на isDone, поэтому не стреляло; любой,
      // кто проверил бы result != null, закончил бы тест на четыре круга
      // раньше и выдал незаработанный A0.
      var state = CalibrationState.start();
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        expect(state.result, isNull,
            reason: 'итог появился в фазе ${state.phase}');
        state = Calibration.answer(state,
            correct: false, latency: const Duration(seconds: 3));
      }
      expect(state.isDone, isTrue);
      expect(state.result, isNotNull);
    });

    test('граница проверяется тесным кругом', () {
      var state = CalibrationState.start();
      // Гоним поиск до подтверждения.
      var guard = 0;
      while (state.phase != CalibrationPhase.confirm && guard++ < 100) {
        state = Calibration.answer(
          state,
          correct: state.step.tier.index <= Tier.a1.index,
          latency: const Duration(seconds: 2),
        );
      }

      expect(state.phase, CalibrationPhase.confirm);
      // Первый круг подтверждения — обязательно тесный. Тесноту теперь
      // видно только по дистракторам: механика осталась той же, что в
      // гребёнке, и проверка по режиму молча перестала бы что-либо значить.
      expect(state.step.distractorKind, DistractorKind.near);
      expect(state.step.isTight, isTrue);
      expect(state.step.mode, GameMode.pickTarget);
    });

    test('тесный круг — вид дистракторов, а не отдельная механика', () {
      // Граница проверяется тем же жестом и той же механикой, что и всё
      // остальное: игрок не должен на последнем шаге теста учить новое
      // задание. Меняется только то, из чего он выбирает.
      var state = CalibrationState.start();
      final combMode = state.step.mode;

      var guard = 0;
      while (state.phase != CalibrationPhase.confirm && guard++ < 100) {
        state = Calibration.answer(
          state,
          correct: state.step.tier.index <= Tier.a1.index,
          latency: const Duration(seconds: 2),
        );
      }

      expect(state.step.mode, combMode);
      expect(state.step.isTight, isTrue);
    });

    test('после тесного подтверждения круг снова обычный', () {
      // Требование — «хотя бы раз созвучными», а не «всегда». Три тесных
      // круга подряд превратили бы подтверждение в наказание за то, что
      // игрок дошёл до своей границы.
      var state = _toConfirm();
      expect(state.step.isTight, isTrue);

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));

      expect(state.tightConfirmed, isTrue);
      expect(state.step.distractorKind, DistractorKind.far);
    });

    test('ни одна граница не подтверждается без созвучного круга', () {
      // Инвариант, который прежде читался как `mode == GameMode.tight`.
      // После слияния круга и тесного круга такая проверка не упала бы — она
      // просто никогда больше не срабатывала бы, и каждая граница
      // подтверждалась бы шестью тематическими вариантами, то есть с шансом
      // угадать один к шести. Поэтому проверяется не шаг, а весь прогон.
      final random = Random(13);
      var confirmRuns = 0;

      for (final tier in Tier.values) {
        for (var i = 0; i < 20; i++) {
          final player = _Player(trueTier: tier, random: random);
          var state = CalibrationState.start();
          var sawConfirm = false;
          var sawNear = false;
          var guard = 0;

          while (!state.isDone && guard++ < 200) {
            final step = state.step;
            if (step.phase == CalibrationPhase.confirm) sawConfirm = true;
            if (step.distractorKind == DistractorKind.near) sawNear = true;
            state = Calibration.answer(
              state,
              correct: player.answer(step),
              latency: player.latency(step),
            );
          }

          // Равенство, а не импликация: созвучные уместны только на границе,
          // и появиться где-то ещё они тоже не должны.
          expect(sawNear, sawConfirm, reason: 'ярус $tier, прогон $i');
          if (sawConfirm) confirmRuns++;
        }
      }

      // Иначе проверка выше сводится к `false == false` на каждом прогоне и
      // зеленеет, даже если фазу подтверждения выкинуть целиком.
      expect(confirmRuns, greaterThan(50),
          reason: 'прогоны не доходят до подтверждения — проверять нечего');
    });

    test('одного верного круга для подтверждения мало', () {
      var state = CalibrationState.start();
      var guard = 0;
      while (state.phase != CalibrationPhase.confirm && guard++ < 100) {
        state = Calibration.answer(
          state,
          correct: state.step.tier.index <= Tier.a1.index,
          latency: const Duration(seconds: 2),
        );
      }

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      expect(state.phase, CalibrationPhase.confirm,
          reason: 'ярус не может подтверждаться одним кругом');
      expect(state.confirmations, 1);
    });

    test('одна осечка при подтверждении прощается', () {
      // Тройная проверка стоит против угадывания вверх, а не против промаха
      // пальцем. Ронять целый ярус из-за одной осечки — ошибка дороже.
      var state = _toConfirm();
      final probe = state.probe;

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));

      expect(state.probe, probe);
      expect(state.confirmFailures, 1);
      expect(state.confirmations, 1, reason: 'уже набранное не сгорает');
    });

    test('вторая осечка опускает ярус и сбрасывает счёт', () {
      var state = _toConfirm();
      final probe = state.probe;

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));

      expect(state.confirmations, 0);
      expect(state.confirmFailures, 0);
      expect(state.probe.index, lessThan(probe.index));
    });

    test('верный ответ снимает потолок, поставленный случайной осечкой', () {
      // Игрок B2, промахнувшийся на A1 в гребёнке, обязан суметь подняться:
      // без этого одна осечка навсегда ограничивала бы результат.
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));
      expect(state.highest, Tier.a0);

      // Дальше отвечает верно на всём подряд.
      var guard = 0;
      while (!state.isDone && guard++ < 60) {
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
      }

      expect(state.result!.index, greaterThan(Tier.a0.index));
    });
  });

  group('финальные фразы', () {
    CalibrationState toPhrases() {
      var state = CalibrationState.start();
      var guard = 0;
      while (state.phase != CalibrationPhase.phrases && guard++ < 200) {
        state = Calibration.answer(
          state,
          correct: state.step.tier.index <= Tier.a2.index,
          latency: const Duration(seconds: 2),
        );
      }
      return state;
    }

    test('спрашивается ровно четыре фразы', () {
      var state = toPhrases();
      final tier = state.probe;

      for (var i = 0; i < CalibrationBalance.finalPhraseChecks; i++) {
        expect(state.isDone, isFalse, reason: 'фраза ${i + 1}');
        expect(state.step.mode, GameMode.fillGaps);
        // Механика может однажды стать другой фразовой, но проверка обязана
        // остаться фразовой: словами ярус уже проверен выше.
        expect(state.step.mode.isPhrase, isTrue);
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
      }

      expect(state.isDone, isTrue);
      expect(state.result, tier);
    });

    test('провал фраз опускает результат на ярус', () {
      var state = toPhrases();
      final tier = state.probe;

      for (var i = 0; i < CalibrationBalance.finalPhraseChecks; i++) {
        state = Calibration.answer(state,
            correct: false, latency: const Duration(seconds: 4));
      }

      expect(state.isDone, isTrue);
      expect(state.result!.index, lessThan(tier.index));
    });

    test('половина верных фраз ярус сохраняет', () {
      var state = toPhrases();
      final tier = state.probe;

      for (var i = 0; i < CalibrationBalance.finalPhraseChecks; i++) {
        state = Calibration.answer(state,
            correct: i.isEven, latency: const Duration(seconds: 2));
      }

      expect(state.result, tier);
    });
  });

  group('«я с нуля»', () {
    test('ставит A0 без единого круга', () {
      final state = Calibration.fromScratch();
      expect(state.isDone, isTrue);
      expect(state.result, Tier.a0);
      expect(state.asked, 0);
    });
  });

  group('сходимость на синтетических игроках', () {
    test('тест всегда заканчивается и не зацикливается', () {
      final random = Random(2026);
      for (final tier in Tier.values) {
        for (var i = 0; i < 50; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          expect(state.isDone, isTrue, reason: 'ярус $tier, прогон $i');
          expect(state.result, isNotNull);
        }
      }
    });

    test('ошибка не больше одного яруса в 90 % случаев', () {
      // Критерий приёмки M3. Прогон на 1000 «игроков» — по 200 на ярус.
      final random = Random(7);
      var within = 0;
      var total = 0;

      for (final tier in Tier.values) {
        for (var i = 0; i < 200; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          final error = (state.result!.index - tier.index).abs();
          if (error <= 1) within++;
          total++;
        }
      }

      final share = within / total;
      expect(share, greaterThanOrEqualTo(0.9),
          reason: 'ошибка больше яруса в ${((1 - share) * 100).round()} % '
              'случаев');
    });

    test('система систематически не завышает ярус', () {
      // Завышенный ярус отпугивает сильнее, чем заниженный утомляет,
      // поэтому смещение допустимо только вниз.
      final random = Random(11);
      var sum = 0;
      var total = 0;

      for (final tier in Tier.values) {
        for (var i = 0; i < 200; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          sum += state.result!.index - tier.index;
          total++;
        }
      }

      expect(sum / total, lessThanOrEqualTo(0.2));
    });

    test('чистый угадыватель не получает высокий ярус', () {
      // Игрок, который не знает ничего и тычет наугад, должен оказаться
      // внизу — иначе тройная проверка границы не работает.
      final random = Random(3);
      var high = 0;

      for (var i = 0; i < 200; i++) {
        final state = _run(_Player(
          trueTier: Tier.a0,
          random: random,
          slip: 0.5,
          guessRate: 1 / 6,
        ));
        if (state.result!.index >= Tier.a2.index) high++;
      }

      expect(high / 200, lessThan(0.1));
    });

    test('тест укладывается в разумное число кругов', () {
      // Онбординг должен проходиться примерно за три минуты.
      final random = Random(5);
      var worst = 0;

      for (final tier in Tier.values) {
        for (var i = 0; i < 100; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          if (state.asked > worst) worst = state.asked;
        }
      }

      expect(worst, lessThanOrEqualTo(30));
    });

    test('повторный прогон на том же профиле даёт тот же ярус', () {
      // Критерий приёмки M3: воспроизводимость на безошибочном игроке.
      for (final tier in Tier.values) {
        final first = _run(
          _Player(trueTier: tier, random: Random(1), slip: 0, guessRate: 0),
        );
        final second = _run(
          _Player(trueTier: tier, random: Random(1), slip: 0, guessRate: 0),
        );
        expect(first.result, second.result, reason: '$tier');
      }
    });

    test('идеальный игрок получает свой ярус точно', () {
      for (final tier in Tier.values) {
        final state = _run(
          _Player(trueTier: tier, random: Random(9), slip: 0, guessRate: 0),
        );
        expect(state.result, tier, reason: 'ожидался $tier');
      }
    });
  });

  group('засев памяти', () {
    test('подтверждённые ярусы копятся по ходу теста', () {
      final state = _run(
        _Player(trueTier: Tier.a2, random: Random(4), slip: 0, guessRate: 0),
      );
      expect(state.confirmed, contains(Tier.a0));
      expect(state.confirmed, contains(Tier.a1));
    });

    // Тест «оценка словаря растёт вместе с ярусом» удалён вместе с
    // `Calibration.estimatedVocabulary`. Он утверждал, что на B2 игрок знает
    // 2880 слов, — при том, что в базе их 864, а множитель «30 созвездий»
    // был взят из планов, а не из содержимого. Тест защищал ложное число.
    //
    // Число теперь приходит из базы (`countConceptsUpTo`), и проверять его
    // на выдуманных данных бессмысленно: проверяет его тот же ассет, что
    // играет.
  });

  group('прогресс', () {
    test('растёт от начала к концу и не выходит за границы', () {
      var state = CalibrationState.start();
      var previous = state.progress;
      expect(previous, inInclusiveRange(0, 1));

      final player = _Player(trueTier: Tier.a2, random: Random(6));
      var guard = 0;
      while (!state.isDone && guard++ < 100) {
        state = Calibration.answer(
          state,
          correct: player.answer(state.step),
          latency: player.latency(state.step),
        );
        expect(state.progress, inInclusiveRange(0, 1));
      }
      expect(state.progress, 1);
    });
  });
}
