@Tags(['diagnostic'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';

/// Не проверка, а измерение: печатает, где именно калибровка ошибается.
///
/// Держится в репозитории намеренно. Когда пороги в `balance.dart` поедут,
/// этот вывод покажет, что именно сломалось, за одну команду:
/// `flutter test test/domain/calibration_diagnostic_test.dart`.
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
          // Штраф к вероятности верного ответа: фраза труднее слова, а
          // созвучные варианты труднее тематических. Второе спрашивается у
          // круга, а не у механики: «тесный круг» перестал быть режимом и
          // стал видом дистракторов, и `mode == ...` здесь не упало бы —
          // оно просто перестало бы срабатывать, и модель игрока тихо стала
          // бы оптимистичнее самой калибровки.
          final penalty = step.mode == GameMode.fillGaps
              ? 0.15
              : step.isTight
              ? 0.08
              : 0.0;
          final known = step.tier.index <= tier.index;
          final correct = known
              ? random.nextDouble() > 0.08 + penalty
              : random.nextDouble() < 1 / 6;
          state = Calibration.answer(
            state,
            correct: correct,
            latency: Duration(
              milliseconds: (known ? 1100 : 2600) + random.nextInt(900),
            ),
          );
        }

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
      buffer.writeln(
        '  ${tier.label}: '
        '${[for (final k in keys) '${k >= 0 ? '+' : ''}$k×${row[k]}'].join(' ')}'
        '  → в пределах яруса ${(within / 2).toStringAsFixed(0)} %, '
        'кругов ${avgSteps.toStringAsFixed(1)}',
      );
    }
    // ignore: avoid_print
    print(buffer);
  });

  test('созвучные варианты доходят до границы', () {
    // Мера того, чего прежний набор режимов измерить не давал.
    //
    // Правило «границу нужно подтвердить хотя бы раз созвучными» раньше
    // читалось как `mode == GameMode.tight`. Круг и тесный круг слились в
    // одну механику, и такая проверка не упала бы — она перестала бы
    // срабатывать никогда, а каждая граница подтверждалась бы шестью
    // тематическими, то есть с шансом угадать один к шести трижды подряд.
    //
    // Поэтому спрашивается не механика, а `distractorKind`, который теперь
    // едет на самом круге: доля созвучных кругов и то, добираются ли они до
    // фазы подтверждения в каждом забеге, который до этой фазы дошёл.
    const runs = 400;
    final random = Random(11);
    var circles = 0;
    var tightCircles = 0;
    var throughConfirm = 0;
    var confirmWithoutTight = 0;

    for (var i = 0; i < runs; i++) {
      var state = CalibrationState.start();
      var guard = 0;
      var sawConfirm = false;
      var sawTight = false;

      while (!state.isDone && guard++ < 200) {
        final step = state.step;
        circles++;
        if (step.phase == CalibrationPhase.confirm) sawConfirm = true;
        if (step.isTight) {
          tightCircles++;
          sawTight = true;
        }
        state = Calibration.answer(
          state,
          // Игрок средней руки: ошибается примерно каждый седьмой круг вне
          // зависимости от яруса. Здесь важен не точный итог, а чтобы забеги
          // разошлись по обеим ветвям — и через подтверждение границы, и
          // сразу во фразы, когда верхний ярус взят с ходу.
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

      if (sawConfirm) {
        throughConfirm++;
        if (!sawTight) confirmWithoutTight++;
      }
    }

    // Единственная жёсткая проверка в этом файле: ни один забег не имеет
    // права подтвердить границу одними тематическими вариантами.
    expect(
      confirmWithoutTight,
      0,
      reason: 'граница подтверждена без созвучных вариантов',
    );
    // И сама ветвь подтверждения обязана встречаться: измерение, в котором
    // её нет, не проверяет ничего.
    expect(throughConfirm, greaterThan(0));

    // ignore: avoid_print
    print(
      '\nСозвучные круги в калибровке:\n'
      '  забегов через подтверждение границы '
      '${(throughConfirm * 100 / runs).toStringAsFixed(0)} %\n'
      '  созвучных кругов ${(tightCircles * 100 / circles).toStringAsFixed(1)}'
      ' % ($tightCircles из $circles)\n',
    );
  });
}
