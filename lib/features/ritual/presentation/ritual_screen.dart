import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../game/application/run_controller.dart';
import '../../game/presentation/run_screen.dart';
import '../../sky/application/sky_controller.dart';
import '../application/ritual_controller.dart';

/// Дневной ритуал: Восход → уровень → ночной вызов.
///
/// Шесть-семь минут с началом и концом. Ритуал существует затем, чтобы из
/// игры можно было выйти с чувством, что дело сделано, — в отличие от ленты,
/// которая не кончается никогда.
class RitualScreen extends ConsumerWidget {
  const RitualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ritualControllerProvider);
    final controller = ref.read(ritualControllerProvider.notifier);

    // Забег сам не знает про ритуал: о его окончании сообщает экран.
    ref.listen(runControllerProvider, (previous, next) {
      if (next.isFinished && (previous?.isFinished ?? true) == false) {
        controller.onRunFinished();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l10n, state.phase)),
        leading: state.phase == RitualPhase.idle
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.reset();
                  // Небо пересобирается: после сессии яркость изменилась.
                  ref.invalidate(skySnapshotProvider);
                },
              ),
      ),
      body: switch (state.phase) {
        RitualPhase.idle => _RitualHome(
            error: state.error,
            onStart: controller.startRitual,
            onLevelOnly: controller.startLevelOnly,
          ),
        RitualPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        RitualPhase.sunrise || RitualPhase.level => const RunScreen(),
        RitualPhase.sunriseResult => _SunriseResult(
            lumens: state.lumensReturned,
            onNext: controller.next,
          ),
        RitualPhase.levelResult => _LevelResult(
            state: state,
            onNext: controller.next,
          ),
        RitualPhase.challenge => _ChallengePlaceholder(onNext: controller.next),
        RitualPhase.done => _RitualDone(
            state: state,
            onFinish: () {
              controller.reset();
              ref.invalidate(skySnapshotProvider);
            },
          ),
      },
    );
  }

  String _title(AppLocalizations l10n, RitualPhase phase) => switch (phase) {
        RitualPhase.sunrise || RitualPhase.sunriseResult => 'Восход',
        RitualPhase.level || RitualPhase.levelResult => 'Уровень',
        RitualPhase.challenge => 'Ночной вызов',
        _ => l10n.gameTitle,
      };
}

class _RitualHome extends StatelessWidget {
  const _RitualHome({
    required this.onStart,
    required this.onLevelOnly,
    this.error,
  });

  final VoidCallback onStart;
  final VoidCallback onLevelOnly;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Дневной ритуал', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Восход — уровень — ночной вызов. Шесть минут с началом и '
                  'концом.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStart,
                    child: const Text('Начать'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Только уровень'),
          subtitle: const Text('Пропустить Восход и сразу взять новое'),
          onTap: onLevelOnly,
        ),
        if (error != null) ...[
          const SizedBox(height: 24),
          Text(
            error!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// Итог Восхода — только люмены, вернувшиеся небу.
///
/// Никаких очков: Восход не про очки, а про то, что часть неба снова горит.
class _SunriseResult extends StatelessWidget {
  const _SunriseResult({required this.lumens, required this.onNext});

  final int lumens;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wb_twilight,
                size: 48, color: LumenPalette.starlight),
            const SizedBox(height: 20),
            Text(
              '+$lumens lm',
              style: theme.textTheme.displaySmall
                  ?.copyWith(color: LumenPalette.starlight),
            ),
            const SizedBox(height: 8),
            Text(
              lumens > 0
                  ? 'вернулось небу'
                  : 'небо и так горело — повторять было нечего',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 36),
            FilledButton(
              onPressed: onNext,
              child: const Text('К новому уровню'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelResult extends StatelessWidget {
  const _LevelResult({required this.state, required this.onNext});

  final RitualState state;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${state.score}',
              style: theme.textTheme.displayMedium
                  ?.copyWith(color: LumenPalette.starlight),
            ),
            const SizedBox(height: 4),
            Text('очков за ритуал', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(value: '${state.newWords}', label: 'новых слов'),
                _Stat(value: '+${state.lumensReturned}', label: 'люменов'),
              ],
            ),
            const SizedBox(height: 36),
            FilledButton(onPressed: onNext, child: const Text('Дальше')),
          ],
        ),
      ),
    );
  }
}

class _ChallengePlaceholder extends StatelessWidget {
  const _ChallengePlaceholder({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nightlight_round, size: 44),
            const SizedBox(height: 16),
            Text('Ночной вызов', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'M5 — общий для всех набор из 20 пар, 60 секунд, один заход.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onNext, child: const Text('Завершить')),
          ],
        ),
      ),
    );
  }
}

class _RitualDone extends StatelessWidget {
  const _RitualDone({required this.state, required this.onFinish});

  final RitualState state;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, size: 48, color: LumenPalette.correct),
            const SizedBox(height: 16),
            Text('Ритуал пройден', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Небу вернулось ${state.lumensReturned} lm, выучено '
              '${state.newWords} новых слов.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onFinish, child: const Text('К небу')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

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
