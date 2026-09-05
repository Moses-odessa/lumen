import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/scoring/score.dart';

/// Итог забега.
///
/// Показываем то, что относится к обучению — точность и комбо, — а не только
/// очки. Очки здесь крупные, потому что они награда, но не единственная
/// цифра: иначе игрок начнёт оптимизировать их, а не память.
class RunSummaryView extends StatelessWidget {
  const RunSummaryView({super.key, required this.summary, this.onContinue});

  final RunSummary? summary;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final result = summary;

    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${result.total}',
              style: theme.textTheme.displayMedium?.copyWith(
                color: LumenPalette.starlight,
              ),
            ),
            if (result.isPerfect) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.runPerfect} · ×${result.accuracyBonus}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: LumenPalette.correct,
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(
                  label: l10n.runAccuracy,
                  value: '${(result.accuracy * 100).round()}%',
                ),
                _Stat(label: l10n.runCircles, value: '${result.circles}'),
                _Stat(label: l10n.runCombo, value: '×${result.maxCombo}'),
              ],
            ),
            const SizedBox(height: 36),
            if (onContinue != null)
              FilledButton(
                onPressed: onContinue,
                child: Text(l10n.runContinue),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
