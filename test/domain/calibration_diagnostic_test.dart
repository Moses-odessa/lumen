@Tags(['diagnostic'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Не проверка, а измерение: печатает, где именно калибровка ошибается.
///
/// Держится в репозитории намеренно. Когда пороги в `balance.dart` поедут,
/// этот вывод покажет, что именно сломалось, за одну команду:
/// `flutter test test/domain/calibration_diagnostic_test.dart`.
///
/// Числа в комментариях ниже — измеренные этими же прогонами на этих же
/// семенах, а не взятые из планов. Меняется алгоритм — меняются и они, и
/// подгонять текст под старое значение нельзя: тогда комментарий начнёт
/// врать первым.
///
/// **Что показал переход от адаптивного поиска к квоте 6/5/4/3/2.** Семя 7,
/// по 200 синтетических игроков на ярус, ошибка на знакомом 8 %, угадывание
/// 1/6 — и то же семя, та же модель игрока на прежней тридцатикруговой схеме
/// с гребёнкой, поиском и тройным подтверждением границы:
///
/// * ошибка не больше яруса — 990 забегов из 1000 против 991. Критерий
///   приёмки M3 (не меньше 900) держится с тем же запасом, и это главное:
///   двадцать кругов с квотой определяют ярус не хуже прежнего адаптивного
///   поиска, который тратил на замер до 23 кругов.
/// * точное попадание — 920 из 1000 против 944, и это не общее ухудшение, а
///   перераспределение. По ярусам, новое против прежнего: A0 196/195,
///   A1 192/192, A2 169/190, B1 190/170, B2 173/197. B1 выиграл двадцать
///   забегов — прежняя схема завышала его на ярус в 13 % случаев, угадав три
///   подтверждения границы подряд, — а A2 и B2 проиграли двадцать с лишним
///   каждый, и оба проигрыша объясняются маленькой квотой сверху: знающий B2
///   игрок с одной осечкой из двух проб (15 % таких) получает B1, а игрок A2
///   в 7 % забегов угадывает две фразы B1 из трёх. Обе ошибки — на один
///   ярус, и обе преимущественно вниз.
/// * кругов на забег — 20,0 вместо тридцати. Переспросы идут сверх квоты и на
///   длину почти не влияют, пока игрок отвечает как человек: при отклике
///   1,1–3,5 с их ноль. Прогон «переспросы и длина забега» ниже показывает
///   другой край — игрока, который половину кругов отвечает быстрее 600 мс.
/// * засев — главное число этой правки, и печатает его второй прогон.
void main() {
  test('распределение ошибки по ярусам', () {
    final random = Random(7);
    final matrix = <Tier, Map<int, int>>{};
    final circles = <Tier, List<int>>{};
    final repeats = <Tier, List<int>>{};

    for (final tier in Tier.values) {
      matrix[tier] = {};
      circles[tier] = [];
      repeats[tier] = [];

      for (var i = 0; i < 200; i++) {
        var state = CalibrationState.start(ceiling: Tier.b2);
        var guard = 0;
        while (!state.isDone && guard++ < 200) {
          final step = state.step;
          // Штрафа за трудность круга нет, и это не упрощение модели, а
          // следствие: механика в тесте одна, а вида дистракторов не
          // существует — вокруг фразы стоят другие фразы. Пока штраф был,
          // модель игрока и калибровка расходились в оценке одного круга.
          final known = step.tier.index <= tier.index;
          final correct = known
              ? random.nextDouble() > 0.08
              : random.nextDouble() < 1 / ScoreBalance.optionsPerCircle;
          state = Calibration.answer(
            state,
            correct: correct,
            latency: Duration(
              milliseconds: (known ? 1100 : 2600) + random.nextInt(900),
            ),
          );
        }

        // Незавершённый забег исказил бы измерение молча, а `result!` упал бы
        // с сообщением про null вместо причины.
        expect(state.isDone, isTrue,
            reason: 'калибровка не сошлась за 200 кругов: ярус $tier');

        final error = state.result!.index - tier.index;
        matrix[tier]![error] = (matrix[tier]![error] ?? 0) + 1;
        circles[tier]!.add(state.circles);
        repeats[tier]!.add(state.repeats);
      }
    }

    final buffer = StringBuffer('\nОшибка калибровки (сдвиг ярусов):\n');
    for (final tier in Tier.values) {
      final row = matrix[tier]!;
      final keys = row.keys.toList()..sort();
      final within = keys
          .where((k) => k.abs() <= 1)
          .fold<int>(0, (sum, k) => sum + row[k]!);
      final avgCircles =
          circles[tier]!.reduce((a, b) => a + b) / circles[tier]!.length;
      final avgRepeats =
          repeats[tier]!.reduce((a, b) => a + b) / repeats[tier]!.length;
      buffer.writeln(
        '  ${tier.label}: '
        '${[for (final k in keys) '${k >= 0 ? '+' : ''}$k×${row[k]}'].join(' ')}'
        '  → в пределах яруса ${(within / 2).toStringAsFixed(0)} %, '
        'кругов ${avgCircles.toStringAsFixed(1)} '
        '(переспросов ${avgRepeats.toStringAsFixed(2)}), '
        'квота ${[for (final t in Tier.values) CalibrationBalance.quotaFor(t)].join('/')}',
      );
    }
    // ignore: avoid_print
    print(buffer);
  });

  test('сколько фраз засевается при квоте 6/5/4/3/2', () {
    // **Главное измерение этой правки.** Засев — лекарство от холодного
    // старта: знакомство устроено исключением, вокруг новой фразы стоят пять
    // уже известных, а у нового игрока известного нет ничего
    // (`session_loader.dart`, `_optionPool`). Знакомству нужно пять, и вопрос
    // ровно один: достаётся ли новичку пять.
    //
    // Считается то же, что засеет контроллер: верные ответы на выданном ярусе
    // и ниже. Одна фраза дважды за тест не выпадает (`_asked` в контроллере),
    // поэтому верных ответов и засеянных фраз ровно столько же.
    //
    // Два потолка, потому что они дают разные ответы. `content/launch.yaml`
    // держит запущенным один A0 — это сегодняшняя игра; B2 — та же игра,
    // когда вычитаны все ярусы.
    const need = ScoreBalance.optionsPerCircle - 1;
    final buffer = StringBuffer(
      '\nЗасев при квоте '
      '${[for (final t in Tier.values) CalibrationBalance.quotaFor(t)].join('/')}'
      ' (нужно $need на знакомство исключением):\n',
    );

    for (final ceiling in [Tier.a0, Tier.b2]) {
      buffer.writeln('  потолок ${ceiling.label}:');
      for (final tier in Tier.values) {
        final random = Random(23);
        final seeded = <int>[];

        for (var i = 0; i < 400; i++) {
          var state = CalibrationState.start(ceiling: ceiling);
          var guard = 0;
          final correctOn = <Tier, int>{};
          while (!state.isDone && guard++ < 200) {
            final step = state.step;
            final known = step.tier.index <= tier.index;
            final correct = known
                ? random.nextDouble() > 0.08
                : random.nextDouble() < 1 / ScoreBalance.optionsPerCircle;
            state = Calibration.answer(
              state,
              correct: correct,
              latency: Duration(
                milliseconds: (known ? 1100 : 2600) + random.nextInt(900),
              ),
            );
            // Считается **каждый** верный ответ, включая тот, который домен
            // отверг как подозрительно быстрый: контроллер пишет фразу в
            // `_confirmed` до того, как домен решит, зачитывать ли круг, и
            // фраза при переспросе берётся другая. Круг в зачёт не идёт, а
            // узнанная фраза остаётся узнанной — модель повторяет это, иначе
            // измерение назвало бы засев меньше настоящего.
            if (correct) {
              correctOn[step.tier] = (correctOn[step.tier] ?? 0) + 1;
            }
          }

          final granted = state.granted!;
          seeded.add(correctOn.entries
              .where((e) => e.key.index <= granted.index)
              .fold<int>(0, (sum, e) => sum + e.value));
        }

        final avg = seeded.reduce((a, b) => a + b) / seeded.length;
        final short = seeded.where((s) => s < need).length;
        buffer.writeln(
          '    игрок ${tier.label}: '
          'засеяно ${avg.toStringAsFixed(1)} '
          '(от ${seeded.reduce(min)} до ${seeded.reduce(max)}), '
          'меньше $need в ${(short * 100 / seeded.length).toStringAsFixed(0)} % '
          'забегов',
        );
      }
    }

    // ignore: avoid_print
    print(buffer);
  });

  test('переспросы и длина забега', () {
    // Переспрос за подозрительно быстрый ответ идёт **сверх** квоты, и это
    // решение стоит измерить с двух сторон: сколько кругов видит игрок и
    // сколько проб получает каждый ярус. Второе — то, ради чего переспросы
    // вынесены за длину: проба, съеденная переспросом, оставила бы B2 с одной
    // пробой вместо двух, а квота — это и есть весь замер.
    const runs = 400;
    final random = Random(11);
    var circles = 0;
    var repeats = 0;
    var withRepeat = 0;

    for (var i = 0; i < runs; i++) {
      var state = CalibrationState.start(ceiling: Tier.b2);
      final perTier = <Tier, int>{};
      var guard = 0;

      while (!state.isDone && guard++ < 200) {
        final step = state.step;
        if (!step.isRepeat) {
          perTier[step.tier] = (perTier[step.tier] ?? 0) + 1;
        }
        state = Calibration.answer(
          state,
          // Игрок, который знает всё, ошибается примерно каждый седьмой круг
          // и отвечает быстро: половина ответов быстрее порога подозрения.
          correct: random.nextDouble() > 0.15,
          latency: Duration(
            milliseconds: random.nextBool()
                ? 300 + random.nextInt(200)
                : 1100 + random.nextInt(900),
          ),
        );
      }

      expect(state.isDone, isTrue,
          reason: 'калибровка не сошлась за 200 кругов');
      // Квота обязана достаться каждому ярусу целиком, сколько бы переспросов
      // ни случилось: это и есть смысл выноса переспросов за длину.
      for (final tier in Tier.values) {
        expect(perTier[tier], CalibrationBalance.quotaFor(tier),
            reason: 'ярус ${tier.label} получил не свою квоту, забег $i');
      }
      expect(state.asked, CalibrationBalance.testCircles);

      circles += state.circles;
      repeats += state.repeats;
      if (state.repeats > 0) withRepeat++;
    }

    // Обе ветви обязаны встречаться: измерение, в котором переспросов не
    // случилось ни разу, печатает ноль и не проверяет ничего.
    expect(repeats, greaterThan(0),
        reason: 'ни один быстрый ответ не переспросили — мерить нечего');

    // ignore: avoid_print
    print(
      '\nПереспросы (игрок знает всё, ошибается в 15 % кругов, половина '
      'ответов быстрее ${CalibrationBalance.suspiciousLatency.inMilliseconds} мс):\n'
      '  кругов на забег ${(circles / runs).toStringAsFixed(1)} '
      'при ${CalibrationBalance.testCircles} зачётных\n'
      '  переспросов на забег ${(repeats / runs).toStringAsFixed(2)} '
      '(предел ${CalibrationBalance.maxRepeats})\n'
      '  забегов хотя бы с одним переспросом '
      '${(withRepeat * 100 / runs).toStringAsFixed(0)} %\n',
    );
  });
}
