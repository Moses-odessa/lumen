import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../domain/scoring/records.dart';
import '../application/records_controller.dart';

/// Личная стена рекордов.
///
/// Облака нет, сравниваться не с кем — соперник это ты вчерашний. Поэтому у
/// каждого окна показаны две цифры: рекорд и то, что набрано в текущем окне.
/// Рекорд без второй цифры не говорит, далеко ли до него, и мотивирует не
/// больше, чем строчка в справке.
///
/// Окна разной длины нарочно: месячный рекорд к концу месяца недостижим, а
/// часовой можно побить сегодня же. Всегда должна быть цель, до которой
/// рукой подать.
class RecordsWall extends ConsumerWidget {
  const RecordsWall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wall = ref.watch(recordWallProvider);

    return wall.maybeWhen(
      data: (value) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.recordsTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              if (_isEmpty(value))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.recordsEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final window in RecordWindow.values)
                  _Row(entry: value[window]!, l10n: l10n),
            ],
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Ни одного рекорда и ничего в текущих окнах: показывать таблицу нулей
  /// бессмысленно, лучше сказать, откуда рекорды берутся.
  static bool _isEmpty(RecordWall wall) => wall.entries.values
      .every((e) => e.best == 0 && e.current == 0);
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.l10n});

  final RecordEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beaten = entry.isRecordNow;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(_label(l10n, entry.window),
                style: theme.textTheme.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _format(beaten ? entry.current : entry.best),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: beaten ? theme.colorScheme.primary : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                beaten
                    ? l10n.recordsBeaten
                    : entry.current > 0
                        ? l10n.recordsToBeat(_format(entry.remaining))
                        : l10n.recordsNow(_format(entry.current)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: beaten
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _label(AppLocalizations l10n, RecordWindow window) =>
      switch (window) {
        RecordWindow.climb => l10n.recordsClimb,
        RecordWindow.hour => l10n.recordsHour,
        RecordWindow.day => l10n.recordsDay,
        RecordWindow.week => l10n.recordsWeek,
        RecordWindow.month => l10n.recordsMonth,
      };

  /// Разряды разделены неразрывным пробелом: очки читаются глазами, а не
  /// парсером, и «4 200» понятнее, чем «4200».
  static String _format(int value) {
    final digits = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
