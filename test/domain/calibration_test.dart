import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Синтетический игрок с заданным истинным уровнем.
///
/// Он знает всё на своём ярусе и ниже, а выше — угадывает с вероятностью
/// 1/[ScoreBalance.optionsPerCircle]: круг всегда полный, и наугад попадают в
/// один из шести. Плюс немного шума: живой человек ошибается и на знакомом.
///
/// Штрафы за трудность круга отсюда ушли вместе с тем, что их порождало.
/// Раньше их было два: фразовая механика (собрать предложение труднее, чем
/// узнать слово) и созвучные дистракторы. Механика в тесте теперь одна на все
/// фазы, а «неверный вариант» никто не пишет руками — вокруг фразы стоят
/// другие фразы. Модель, в которой один и тот же круг то труднее, то легче,
/// врала бы калибровке в её же пользу.
class _Player {
  _Player({
    required this.trueTier,
    required this.random,
    this.slip = 0.08,
    this.guessRate = 1 / ScoreBalance.optionsPerCircle,
  });

  final Tier trueTier;
  final Random random;

  /// Ошибка на знакомом материале — усталость, промах пальцем.
  final double slip;

  /// Вероятность угадать на незнакомом ярусе.
  final double guessRate;

  bool answer(CalibrationStep step) {
    if (step.tier.index <= trueTier.index) {
      return random.nextDouble() > slip;
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
  // Иначе тест, который начинается этой строкой, проверял бы неизвестно что:
  // не дошедший до подтверждения прогон отдаёт состояние любой другой фазы.
  expect(state.phase, CalibrationPhase.confirm,
      reason: 'до подтверждения границы не дошли за 100 кругов');
  return state;
}

/// Доводит до подтверждения на самом нижнем ярусе: игрок не берёт ничего.
CalibrationState _toConfirmAtA0() {
  var state = CalibrationState.start();
  var guard = 0;
  while (state.phase != CalibrationPhase.confirm && guard++ < 100) {
    state = Calibration.answer(
      state,
      correct: false,
      latency: const Duration(seconds: 3),
    );
  }
  expect(state.phase, CalibrationPhase.confirm,
      reason: 'до подтверждения границы не дошли за 100 кругов');
  return state;
}

/// Что отсюда удалено вместе с правилами, которых больше нет.
///
/// * Группа «финальные фразы», три теста: «спрашивается ровно четыре фразы»,
///   «провал фраз опускает результат на ярус», «половина верных фраз ярус
///   сохраняет». Они охраняли фазу `CalibrationPhase.phrases`: найдя ярус,
///   тест спрашивал четыре целых предложения механикой `fillGaps` и ронял
///   ярус, если игрок собрал меньше половины, — «знает слова, но не собирает
///   предложения». Единицей изучения стала фраза: гребёнка, поиск и
///   подтверждение спрашивают ровно то, что спрашивала эта фаза, и отдельная
///   проверка стала повтором самой себя. Фазы нет, `finalPhraseChecks` нет,
///   правила «не собрал предложения — ярус вниз» нет.
/// * Пять тестов про созвучные варианты: «теснота живёт в дистракторах и не
///   зависит от механики», «граница проверяется тесным кругом», «тесный круг
///   — вид дистракторов, а не отдельная механика», «после тесного
///   подтверждения круг снова обычный», «ни одна граница не подтверждается
///   без созвучного круга». Все они охраняли `CalibrationStep.distractorKind`
///   и требование «хотя бы одно подтверждение созвучными вариантами»: шесть
///   тематических дают 17 % случайного попадания, и без созвучных граница
///   подтверждалась бы угадыванием. Рукописных дистракторов в игре больше
///   нет — вокруг фразы стоят другие фразы яруса, «неверный вариант» никто не
///   придумывает. Вида дистракторов не существует, `tightConfirmed` тоже, и
///   охранять нечего. То, что от них осталось охранять — «механика в тесте
///   одна», — проверяется в группе «шаг».
void main() {
  group('шаг', () {
    test('весь тест мерит одной механикой, и она продуктивная', () {
      // Ярус нельзя мерить узнаванием: выбрать перевод из шести проще, чем
      // назвать фразу на изучаемом, и игрок, который «всё понимает», получил
      // бы ярус, на котором не может сказать ничего. Отсюда единственная
      // механика на все фазы — самая требовательная из трёх.
      //
      // Это же место занимала проверка вида дистракторов: механик в тесте
      // было две, обычный круг и тесный, и различить их можно было только по
      // ним. Различать больше нечего, и осталось правило про механику.
      final modes = <GameMode>{};
      final phases = <CalibrationPhase>{};

      var state = CalibrationState.start();
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        modes.add(state.step.mode);
        phases.add(state.step.phase);
        state = Calibration.answer(
          state,
          correct: state.step.tier.index <= Tier.a2.index,
          latency: const Duration(seconds: 2),
        );
      }

      expect(modes, {GameMode.pickTarget});
      expect(modes.single.isProductive, isTrue,
          reason: 'ярус измерен узнаванием, а не производством');
      // Иначе множество режимов набралось бы из одной фазы, и проверка выше
      // говорила бы только про гребёнку.
      expect(phases, {
        CalibrationPhase.comb,
        CalibrationPhase.search,
        CalibrationPhase.confirm,
      });
    });
  });

  group('гребёнка', () {
    test('начинается с самого нижнего яруса', () {
      final state = CalibrationState.start();
      expect(state.phase, CalibrationPhase.comb);
      expect(state.step.tier, Tier.a0);
      expect(state.step.mode, GameMode.pickTarget);
      expect(state.step.isRepeat, isFalse);
      expect(state.result, isNull);
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

    test('взятая с ходу гребёнка заканчивает тест верхним ярусом', () {
      // Раньше отсюда шли к проверке фразами: она была единственным, что
      // отделяло «прошёл всю гребёнку» от «получил B2», и ярус выставляла
      // она. Проверки нет — значит гребёнка обязана быть полноценной
      // концовкой: и закончить тест, и объявить итог. Угадать её целиком это
      // (1/6)⁵, один шанс из семи с половиной тысяч.
      var state = CalibrationState.start();
      final phases = <CalibrationPhase>[];
      for (var i = 0; i < Tier.values.length; i++) {
        phases.add(state.phase);
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
      }

      expect(phases, everyElement(CalibrationPhase.comb),
          reason: 'гребёнка сходила куда-то ещё по дороге вверх');
      expect(state.phase, CalibrationPhase.done);
      expect(state.result, Tier.b2);
      expect(state.asked, Tier.values.length,
          reason: 'верхний ярус стоил лишних кругов');
      // Засев памяти идёт из подтверждённых ярусов, и верхний в них тоже
      // должен попасть: игрок его взял.
      expect(state.confirmed, containsAll(Tier.values));
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
      expect(repeats, greaterThan(0),
          reason: 'ни один быстрый ответ не переспросили — мерить нечего');
    });

    test('медленный верный ответ не переспрашивается', () {
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 3));
      expect(state.step.isRepeat, isFalse);
    });

    test('на подтверждённом ярусе быстрый ответ подозрений не вызывает', () {
      // Быстро отвечать на том, что знаешь, — норма, а не признак
      // угадывания. Правило держится на `_isAboveKnown`, и без него игрок,
      // который просто быстро играет, тратил бы переспросы на своих же
      // подтверждённых ярусах.
      //
      // Раньше в этом тесте стоял один медленный **неверный** ответ: он
      // проверял, что промах не переспрашивается, то есть не то, что обещано
      // в названии. Переспрос требует верного ответа, так что тот вариант был
      // истинным по построению.
      var state = CalibrationState.start();
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      expect(state.step.tier, Tier.a0);
      expect(state.lowest, Tier.a0, reason: 'ярус не стал подтверждённым');

      final before = state.asked;
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 200));

      expect(state.step.isRepeat, isFalse);
      expect(state.asked, before + 1, reason: 'круг ушёл в переспрос');
      expect(state.repeats, 0);
    });
  });

  group('подтверждение границы', () {
    test('три подтверждения заканчивают тест и объявляют ярус', () {
      // Прежде подтверждение было не концом, а поворотом: найденный ярус оно
      // передавало фазе фраз, и итог выставляла она. Фазы нет — значит
      // подтверждение обязано делать и то, и другое.
      //
      // Цена пропуска не абстрактная: `CalibrationController._finish` читает
      // `result ?? Tier.a0`, и тест, дошедший до `done` без итога, молча
      // выдал бы A0 игроку, ответившему на B1.
      var state = _toConfirm();
      final probe = state.probe;
      final before = state.asked;

      for (var i = 1; i < CalibrationBalance.borderConfirmations; i++) {
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
        expect(state.isDone, isFalse,
            reason: 'тест закончился на подтверждении $i из '
                '${CalibrationBalance.borderConfirmations}');
      }
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));

      expect(state.phase, CalibrationPhase.done);
      expect(state.result, probe);
      expect(state.asked, before + CalibrationBalance.borderConfirmations,
          reason: 'после подтверждения спросили что-то ещё');
    });

    test('одного верного круга для подтверждения мало', () {
      var state = _toConfirm();

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      expect(state.phase, CalibrationPhase.confirm,
          reason: 'ярус не может подтверждаться одним кругом');
      expect(state.confirmations, 1);
    });

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
      expect(state.isDone, isFalse, reason: 'ниже есть куда спускаться');
    });

    test('ниже A0 некуда: вторая осечка там заканчивает тест', () {
      // Единственная ветка, где ярус ронять нельзя, а закончить тест раньше
      // было нечем: она уводила в фазу фраз и не выставляла `result`, чтобы
      // не нарушить контракт поля. Получалось состояние
      // `phase: phrases, isDone: false, result: a0` на все четыре оставшихся
      // круга. Фазы нет, ветка стала концовкой, и итог выставляется вместе с
      // фазой — как во всех остальных концовках.
      var state = _toConfirmAtA0();
      expect(state.probe, Tier.a0, reason: 'подтверждать начали не с нуля');
      final before = state.asked;

      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));
      expect(state.isDone, isFalse, reason: 'и на нуле осечка прощается');
      expect(state.result, isNull);

      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));

      expect(state.phase, CalibrationPhase.done);
      expect(state.probe, Tier.a0);
      expect(state.result, Tier.a0);
      expect(state.asked, before + 2,
          reason: 'после второй осечки на нуле спросили что-то ещё');
    });

    test('итог остаётся пустым, пока тест не закончен', () {
      // Контракт поля: «итог; null, пока тест не закончен». Гейт в приложении
      // стоит на `isDone`, а `_finish` читает `result ?? Tier.a0`, поэтому
      // любое расхождение этих двух признаков стоит игроку яруса — в одну
      // сторону тест кончается раньше времени, в другую выдаёт A0 вместо
      // измеренного.
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
          guessRate: 1 / ScoreBalance.optionsPerCircle,
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
    // 2880 слов, — при том, что в базе их было 864, а множитель «30
    // созвездий» был взят из планов, а не из содержимого. Тест защищал ложное
    // число.
    //
    // Отдельных слов в игре не осталось вовсе: считать теперь нечего, кроме
    // фраз, и число приходит из базы (`ContentDatabase.phrasesUpTo`).
    // Проверять его на выдуманных данных бессмысленно — проверяет его тот же
    // ассет, что играет.
  });

  group('прогресс', () {
    test('полоса идёт от нуля к единице и не выходит за границы', () {
      // Монотонности здесь нет, и это не оплошность: сорвавшееся
      // подтверждение сбрасывает `confirmations` вместе с ярусом, и полоса
      // делает шаг назад. Обещать «осталось чуть-чуть» и потом отобрать
      // обещание хуже, чем шагнуть назад честно.
      var state = CalibrationState.start();
      expect(state.progress, 0);

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
