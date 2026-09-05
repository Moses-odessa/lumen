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
          final penalty = step.mode == GameMode.phrase
              ? 0.15
              : step.mode == GameMode.tight
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
}
