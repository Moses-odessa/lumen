import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Заглушка экрана, который появится в следующей вехе. Честно называет веху,
/// чтобы по приложению было видно, что уже сделано, а что нет.
class MilestonePlaceholder extends StatelessWidget {
  const MilestonePlaceholder({
    super.key,
    required this.milestone,
    required this.what,
    this.icon = Icons.auto_awesome_outlined,
  });

  /// Веха из PLAN.md: `M1`, `M2`, …
  final String milestone;

  /// Что именно здесь появится — одной строкой, на языке разработки.
  final String what;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              l10n.comingSoon,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$milestone · $what',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
