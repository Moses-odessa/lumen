import 'package:flutter/material.dart';

import '../../settings/presentation/voice_notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/scoring/climb.dart';
import '../../game/application/run_controller.dart';
import '../../game/presentation/run_screen.dart';
import '../../sky/application/sky_controller.dart';
import '../application/ritual_controller.dart';

/// Дневной ритуал: Восход → уровень.
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
            l10n: l10n,
            error: state.error,
            onStart: controller.startRitual,
            onLevelOnly: controller.startLevelOnly,
          ),
        RitualPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        RitualPhase.sunrise ||
        RitualPhase.level ||
        RitualPhase.sprint =>
          const RunScreen(),
        RitualPhase.sunriseResult => _SunriseResult(
            l10n: l10n,
            lumens: state.lumensReturned,
            onNext: controller.next,
          ),
        RitualPhase.levelResult => _LevelResult(
            l10n: l10n,
            state: state,
            onNext: controller.next,
            // Спринт предлагается только там, где ему есть на чём идти:
            // тема пройдена, и ярких слов достаточно. Кнопки нет, если
            // предлагать нечего, — предложение, которое не срабатывает,
            // раздражает сильнее отсутствующего.
            onSprint: controller.canSprint ? controller.startSprint : null,
          ),
        RitualPhase.sprintResult => _SprintResult(
            l10n: l10n,
            state: state,
            onNext: controller.next,
          ),
        RitualPhase.done => _RitualDone(
            l10n: l10n,
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
        RitualPhase.sunrise ||
        RitualPhase.sunriseResult =>
          l10n.ritualSunrise,
        RitualPhase.level || RitualPhase.levelResult => l10n.ritualLevel,
        RitualPhase.sprint || RitualPhase.sprintResult => l10n.stageSprint,
        _ => l10n.gameTitle,
      };
}

class _RitualHome extends StatelessWidget {
  const _RitualHome({
    required this.l10n,
    required this.onStart,
    required this.onLevelOnly,
    this.error,
  });

  final AppLocalizations l10n;
  final VoidCallback onStart;
  final VoidCallback onLevelOnly;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Про отсутствие голоса игрок узнаёт до начала, а не по тишине
        // в первом же круге.
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: VoiceNotice(compact: true),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ritualHeading, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  l10n.ritualSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onStart,
                    child: Text(l10n.ritualStart),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: Text(l10n.ritualLevelOnly),
          subtitle: Text(l10n.ritualLevelOnlySubtitle),
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
  const _SunriseResult({
    required this.l10n,
    required this.lumens,
    required this.onNext,
  });

  final AppLocalizations l10n;
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
              lumens > 0 ? l10n.sunriseReturned : l10n.sunriseNothing,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 36),
            FilledButton(
              onPressed: onNext,
              child: Text(l10n.sunriseNext),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelResult extends StatelessWidget {
  const _LevelResult({
    required this.l10n,
    required this.state,
    required this.onNext,
    this.onSprint,
  });

  final AppLocalizations l10n;
  final RitualState state;
  final VoidCallback onNext;

  /// Спринт по пройденной теме. `null` — предлагать нечего.
  final VoidCallback? onSprint;

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
            Text(l10n.ritualScore, style: theme.textTheme.bodyMedium),
            if (state.playedLevel > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.recordsClimbLevel(
                  state.playedLevel,
                  ClimbRules.multiplierFor(state.playedLevel)
                      .toStringAsFixed(2),
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(value: '${state.newWords}', label: l10n.ritualNewWords),
                _Stat(
                  value: '+${state.lumensReturned}',
                  label: l10n.ritualLumens,
                ),
              ],
            ),
            const SizedBox(height: 36),
            if (onSprint != null) ...[
              FilledButton.icon(
                onPressed: onSprint,
                icon: const Icon(Icons.bolt, size: 18),
                label: Text(l10n.stageSprint),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onNext, child: Text(l10n.commonNext)),
            ] else
              FilledButton(onPressed: onNext, child: Text(l10n.commonNext)),
          ],
        ),
      ),
    );
  }
}

/// Итог попытки спринта: взята планка или нет.
class _SprintResult extends StatelessWidget {
  const _SprintResult({
    required this.l10n,
    required this.state,
    required this.onNext,
  });

  final AppLocalizations l10n;
  final RitualState state;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = state.sprintGoal;
    final reached = state.sprintReached;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reached ? Icons.bolt : Icons.timer_off_outlined,
              size: 44,
              color: reached
                  ? LumenPalette.correct
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              reached
                  ? l10n.sprintReached
                  : l10n.sprintMissed(
                      state.sprintDone,
                      goal?.connections ?? 0,
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sprintAttempt(
                state.sprintAttempt + 1,
                StageBalance.sprintAttempts,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 36),
            // Не взятая планка не запирает ничего: следующая попытка есть
            // только у взятой, потому что расти можно только вверх. Провал
            // просто заканчивает спринт, не отнимая ни очков, ни доступа.
            FilledButton(
              onPressed: onNext,
              child: Text(
                state.hasNextSprint ? l10n.commonNext : l10n.commonDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RitualDone extends StatelessWidget {
  const _RitualDone({
    required this.l10n,
    required this.state,
    required this.onFinish,
  });

  final AppLocalizations l10n;
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
            Text(l10n.ritualDoneTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.ritualDoneBody(state.lumensReturned, state.newWords),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onFinish, child: Text(l10n.ritualToSky)),
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
