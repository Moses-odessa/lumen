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
/// Что эти два прогона печатают сегодня (семена 7 и 11, 1000 и 400 забегов):
///
/// * ошибка не больше яруса — 992 забега из 1000. Шесть из восьми выпавших
///   приходятся на A2 и уходят **вверх** на два яруса: угадать три
///   подтверждения подряд это (1/6)³, и на тысяче забегов такое случается.
/// * кругов на забег — от 9,2 на B2 до 17,1 на A1, худший наблюдённый 26.
///   Удалённая фаза фраз стоила каждому забегу ровно четыре круга сверху:
///   она спрашивала четыре предложения и считала каждое. Низкое среднее на
///   B2 не из-за неё — при шуме 8 % гребёнку берут с ходу примерно две трети
///   забегов (0,92⁵), и такой забег кончается на пятом круге.
/// * подтверждения границы не видят 44 % забегов игрока, который знает всё и
///   ошибается в 15 % кругов. Докстрока `CalibrationPhase.confirm` обещает
///   «примерно 42 %» — обещание в силе.
/// * на подтверждение уходит 16,6 % всех кругов: фаза короткая, и удлинять
///   её нельзя — она стоит в самом конце теста, когда терпение кончается.
///
/// Жёстких проверок здесь ровно столько, сколько нужно, чтобы измерение не
/// оказалось измерением пустоты: каждый забег обязан закончиться, и каждая
/// ветвь, доля которой печатается, обязана встретиться хотя бы раз.
void main() {
  test('распределение ошибки по ярусам', () {
    final random = Random(7);
    final matrix = <Tier, Map<int, int>>{};
    final steps = <Tier, List<int>>{};

    for (final tier in Tier.values) {
      matrix[tier] = {};
      steps[tier] = [];

      for (var i = 0; i < 200; i++) {
        var state = CalibrationState.start();
        var guard = 0;
        while (!state.isDone && guard++ < 200) {
          final step = state.step;
          // Штрафа за трудность круга больше нет, и это не упрощение модели,
          // а следствие: механика в тесте одна на все фазы, а вида
          // дистракторов не существует — вокруг фразы стоят другие фразы.
          // Пока штраф был, модель игрока и калибровка расходились в оценке
          // одного и того же круга.
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
        steps[tier]!.add(state.asked);
      }
    }

    final buffer = StringBuffer('\nОшибка калибровки (сдвиг ярусов):\n');
    for (final tier in Tier.values) {
      final row = matrix[tier]!;
      final keys = row.keys.toList()..sort();
      final within = keys
          .where((k) => k.abs() <= 1)
          .fold<int>(0, (sum, k) => sum + row[k]!);
      final avgSteps =
          steps[tier]!.reduce((a, b) => a + b) / steps[tier]!.length;
      final worstSteps = steps[tier]!.reduce(max);
      buffer.writeln(
        '  ${tier.label}: '
        '${[for (final k in keys) '${k >= 0 ? '+' : ''}$k×${row[k]}'].join(' ')}'
        '  → в пределах яруса ${(within / 2).toStringAsFixed(0)} %, '
        'кругов ${avgSteps.toStringAsFixed(1)} (худший $worstSteps)',
      );
    }
    // ignore: avoid_print
    print(buffer);
  });

  test('подтверждение границы — фаза не обязательная', () {
    // Мера того, чего прежний набор фаз измерить не давал.
    //
    // Здесь стояло измерение созвучных кругов: доля тесных кругов и то,
    // доходят ли они до фазы подтверждения. Рукописных дистракторов в игре
    // нет — вокруг фразы стоят другие фразы яруса, — «тесного круга» как вида
    // круга не существует, и измерять нечего.
    //
    // Осталось измерить то, что докстрока `CalibrationPhase.confirm` обещает
    // словами: подтверждение — фаза **не обязательная**. Забег, взявший все
    // пять ярусов гребёнкой с ходу, кончается прямо там и границу не
    // подтверждает ни разу. Число рядом с этим обещанием и считается здесь:
    // если оно уедет к нулю, «не обязательная» станет неправдой, а если к
    // сотне — неправдой станет само подтверждение.
    const runs = 400;
    final random = Random(11);
    var circles = 0;
    var confirmCircles = 0;
    var throughConfirm = 0;
    var straightFromComb = 0;
    var asked = 0;

    for (var i = 0; i < runs; i++) {
      var state = CalibrationState.start();
      var guard = 0;
      var sawConfirm = false;

      while (!state.isDone && guard++ < 200) {
        final step = state.step;
        circles++;
        if (step.phase == CalibrationPhase.confirm) {
          confirmCircles++;
          sawConfirm = true;
        }
        state = Calibration.answer(
          state,
          // Игрок, который знает всё и ошибается примерно каждый седьмой
          // круг: это ровно тот «уровень B2 со шумом», про который говорит
          // докстрока фазы. Здесь важен не итог, а чтобы забеги разошлись по
          // обеим ветвям — и через подтверждение границы, и сразу в конец,
          // когда верхний ярус взят с ходу.
          correct: random.nextDouble() > 0.15,
          latency: Duration(milliseconds: 1100 + random.nextInt(900)),
        );
      }

      // Незавершённый забег исказил бы измерение молча.
      expect(
        state.isDone,
        isTrue,
        reason: 'калибровка не сошлась за 200 кругов',
      );

      asked += state.asked;
      if (sawConfirm) {
        throughConfirm++;
      } else {
        straightFromComb++;
        // Единственный способ закончить тест, не подтверждая границу, — взять
        // всю гребёнку подряд. Если появится второй, доля ниже перестанет
        // означать то, что написано у неё в названии.
        expect(state.result, Tier.b2, reason: 'забег $i');
        expect(state.asked, Tier.values.length, reason: 'забег $i');
      }
    }

    // Обе ветви обязаны встречаться: измерение, в котором одна из них не
    // появилась ни разу, печатает ноль или сотню и не проверяет ничего.
    expect(throughConfirm, greaterThan(0),
        reason: 'ни один забег не дошёл до подтверждения границы');
    expect(straightFromComb, greaterThan(0),
        reason: 'гребёнку не взял с ходу никто — мерить нечего');

    // ignore: avoid_print
    print(
      '\nПодтверждение границы (игрок знает всё, ошибается в 15 % кругов):\n'
      '  забегов через подтверждение '
      '${(throughConfirm * 100 / runs).toStringAsFixed(0)} %\n'
      '  забегов, взявших гребёнку с ходу '
      '${(straightFromComb * 100 / runs).toStringAsFixed(0)} %\n'
      '  кругов на подтверждение '
      '${(confirmCircles * 100 / circles).toStringAsFixed(1)}'
      ' % ($confirmCircles из $circles)\n'
      '  кругов на забег ${(asked / runs).toStringAsFixed(1)}\n',
    );
  });
}
