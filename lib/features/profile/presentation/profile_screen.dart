import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/scoring/balance.dart';
import '../application/records_controller.dart';
import '../application/stats_controller.dart';
import 'records_wall.dart';

/// Профиль: орбита, искры, статистика.
///
/// Главная цифра здесь — горящие слова, а не XP. Любая валюта, которую можно
/// нафармить повтором лёгкого, будет фармиться, поэтому её тут нет.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(playerStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: l10n.customWordsTitle,
            onPressed: () => context.push(Routes.customWords),
          ),
        ],
      ),
      body: switch (stats) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playerStatsProvider);
              ref.invalidate(recordWallProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OrbitCard(l10n: l10n, stats: value),
                const SizedBox(height: 12),
                _KeyNumbers(l10n: l10n, stats: value),
                const SizedBox(height: 12),
                const RecordsWall(),
                const SizedBox(height: 20),
                Text(
                  l10n.profileBrightness,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final c in value.constellations)
                  _ConstellationRow(l10n: l10n, brightness: c),
                if (value.constellations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.profileEmpty),
                  ),
              ],
            ),
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Орбита: высота, недельная цель и честное предупреждение о сбросе.
class _OrbitCard extends StatelessWidget {
  const _OrbitCard({required this.l10n, required this.stats});

  final AppLocalizations l10n;
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = stats.orbit;
    final risky = Orbit.missesBeforeReset(orbit) <= 1 && orbit.level > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${orbit.level}',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(color: LumenPalette.starlight),
                ),
                const SizedBox(width: 8),
                Text(l10n.profileOrbit, style: theme.textTheme.bodyMedium),
                const Spacer(),
                if (orbit.eclipseUntil != null &&
                    orbit.eclipsedAt(DateTime.now()))
                  Chip(
                    label: Text(l10n.profileEclipse),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              // Пропуск опускает, а не обнуляет: это главное отличие от
              // стрика, и о нём стоит сказать прямо.
              l10n.profileOrbitExplain,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (risky) ...[
              const SizedBox(height: 10),
              Text(
                l10n.profileOrbitRisk,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(l10n.profileWeek, style: theme.textTheme.labelLarge),
                const SizedBox(width: 12),
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: i < stats.weeklyProgress
                          ? LumenPalette.starlight
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              stats.weeklyGoalMet
                  ? l10n.profileWeeklyGoalMet
                  : l10n.profileWeeklyGoal(RetentionBalance.weeklyGoalDays),
              style: theme.textTheme.bodySmall?.copyWith(
                color: stats.weeklyGoalMet
                    ? LumenPalette.correct
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyNumbers extends StatelessWidget {
  const _KeyNumbers({required this.l10n, required this.stats});

  final AppLocalizations l10n;
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final latency = stats.medianLatency;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Number(
              value: '${stats.burningWords}',
              label: l10n.profileBurning,
              highlight: true,
            ),
            _Number(
              value: '${stats.knownWords}',
              label: l10n.profileWordsInWork,
            ),
            _Number(
              value: latency == null
                  ? '—'
                  : l10n.unitSeconds(
                      (latency.inMilliseconds / 1000).toStringAsFixed(1),
                    ),
              label: l10n.profileLatency,
              // Целевая метрика из CONCEPT.md — медиана меньше 1.8 с.
              highlight: latency != null &&
                  latency <= const Duration(milliseconds: 1800),
            ),
            _Number(value: '${stats.sparks}', label: l10n.profileSparks),
          ],
        ),
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: highlight ? LumenPalette.starlight : null,
          ),
        ),
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

class _ConstellationRow extends StatelessWidget {
  const _ConstellationRow({required this.l10n, required this.brightness});

  final AppLocalizations l10n;
  final ConstellationBrightness brightness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = LumenBand.of(brightness.averageLumens.round());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(brightness.name,
                    style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${brightness.averageLumens.round()} lm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: brightness.averageLumens / 100,
              minHeight: 6,
              color: LumenPalette.star(band),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.profileBurningOf(brightness.burning, brightness.stars),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
