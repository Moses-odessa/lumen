import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/theme/palette.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/sky/progression.dart';
import '../application/sky_controller.dart';
import 'sky_map.dart';

/// Карта созвездий — главный экран приложения.
///
/// Здесь не нужно объяснять интервальное повторение: игрок открывает карту и
/// видит, что часть неба потускнела. Это и есть весь интерфейс прогресса.
class SkyScreen extends ConsumerWidget {
  const SkyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(skySnapshotProvider);
    final selected = ref.watch(selectedConstellationProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LumenPalette.skyZenith, LumenPalette.skyHorizon],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.skyTitle),
          actions: [
            switch (snapshot) {
              AsyncData(:final value) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    value.tier.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
        body: switch (snapshot) {
          AsyncData(:final value) when value.isEmpty => const _EmptySky(),
          AsyncData(:final value) => Stack(
            children: [
              Positioned.fill(
                child: SkyMap(
                  constellations: value.placements,
                  states: value.states,
                  selected: selected,
                  onSelect: (name) => ref
                      .read(selectedConstellationProvider.notifier)
                      .toggle(name),
                ),
              ),
              if (selected == null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _TierSuggestionBanner(snapshot: value),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: selected == null
                    ? _SkySummary(snapshot: value)
                    : _ConstellationCard(
                        state: value.states[selected],
                        onClose: () => ref
                            .read(selectedConstellationProvider.notifier)
                            .clear(),
                      ),
              ),
            ],
          ),
          AsyncError(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$error'),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Предложение сменить ярус.
///
/// Именно предложение: запертого уровня в игре нет, и система не имеет права
/// двигать игрока сама. Баннер можно проигнорировать, и он не будет
/// возвращаться на каждый кадр — он исчезнет, как только условие перестанет
/// выполняться.
class _TierSuggestionBanner extends ConsumerWidget {
  const _TierSuggestionBanner({required this.snapshot});

  final SkySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suggestion = Progression.suggest(
      constellations: snapshot.states.values.toList(),
      current: snapshot.tier,
    );
    if (suggestion == TierSuggestion.stay) return const SizedBox.shrink();

    final target = suggestion == TierSuggestion.up
        ? snapshot.tier.up
        : snapshot.tier.down;
    if (target == null) return const SizedBox.shrink();

    // Подниматься некуда, если верхний ярус ещё не вычитан.
    if (suggestion == TierSuggestion.up &&
        target.index > ref.watch(maxTierProvider).index) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: LumenPalette.starlight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion == TierSuggestion.up
                      ? l10n.tierSuggestUp(target.label)
                      : l10n.tierSuggestDown(
                          snapshot.tier.label,
                          target.label,
                        ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  ref.read(analyticsProvider).log(
                    AnalyticsEvents.tierChanged,
                    {'from': snapshot.tier.code, 'to': target.code},
                  );
                  ref.read(playerControllerProvider.notifier).setTier(target);
                  ref.invalidate(skySnapshotProvider);
                },
                child: Text(target.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Сводка по небу: сколько звёзд, сколько горит, сколько созвездий зажжено.
class _SkySummary extends StatelessWidget {
  const _SkySummary({required this.snapshot});

  final SkySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Сводка лежит поверх ночного неба, поэтому всегда светлая, независимо
    // от темы интерфейса.
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LumenPalette.skyHorizon.withValues(alpha: 0),
              LumenPalette.skyHorizon,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Metric(value: '${snapshot.totalStars}', label: l10n.skyStars),
            // Светящие звёзды, а не XP — главная цифра.
            _Metric(
              value: '${snapshot.litStars}',
              label: l10n.skyBurning,
              highlight: true,
            ),
            _Metric(
              value:
                  '${snapshot.litConstellations}'
                  '/${snapshot.unlockedConstellations}',
              label: l10n.skyConstellations,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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
          style: theme.textTheme.headlineSmall?.copyWith(
            color: highlight ? LumenPalette.starlight : Colors.white,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

/// Карточка выбранного созвездия.
class _ConstellationCard extends StatelessWidget {
  const _ConstellationCard({required this.state, required this.onClose});

  final ConstellationState? state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final constellation = state;
    if (constellation == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    constellation.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (constellation.isLit)
                  const Icon(
                    Icons.auto_awesome,
                    color: LumenPalette.starlight,
                    size: 20,
                  ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              constellation.unlocked
                  ? l10n.constellationLitOf(
                      constellation.litStars,
                      constellation.starCount,
                    )
                  : l10n.constellationLocked,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: constellation.litProgress,
                minHeight: 6,
              ),
            ),
            if (constellation.unlocked && !constellation.isLit) ...[
              const SizedBox(height: 10),
              Text(
                constellation.starsToLight == 0
                    ? l10n.constellationAboutToLight
                    : l10n.constellationToLight(constellation.starsToLight),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Небо пустое: контент ещё не собран.
class _EmptySky extends StatelessWidget {
  const _EmptySky();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: Colors.white38),
            const SizedBox(height: 16),
            Text(l10n.skyEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.skyEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
