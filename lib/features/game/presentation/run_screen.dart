import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/palette.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/game_mode.dart';
import '../application/run_controller.dart';
import 'circle_arena.dart';
import 'run_summary_view.dart';
import 'typing_arena.dart';

/// Экран забега: 10–14 кругов подряд без пауз.
///
/// Верхняя полоса намеренно тихая. Счёт и комбо — это обратная связь, а не
/// содержание: как только они начинают перетягивать внимание с центра круга,
/// игра превращается в кликер.
class RunScreen extends ConsumerWidget {
  const RunScreen({super.key, this.onFinished});

  /// Что делать после забега. `null` — просто показать итог.
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runControllerProvider);
    final controller = ref.read(runControllerProvider.notifier);

    if (state.isFinished) {
      return RunSummaryView(
        summary: state.summary,
        onContinue: onFinished,
      );
    }

    final question = state.current;
    if (question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _RunHeader(state: state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _Arena(
              question: question,
              enabled: state.phase == RunPhase.asking,
              onOption: controller.answerOption,
              onInput: controller.answerInput,
              onReplay: controller.replayPrompt,
            ),
          ),
        ),
      ],
    );
  }
}

/// Выбор арены по режиму. Геометрия одна на все режимы, кроме «Набора»,
/// где вместо круга поле ввода.
class _Arena extends StatelessWidget {
  const _Arena({
    required this.question,
    required this.enabled,
    required this.onOption,
    required this.onInput,
    required this.onReplay,
  });

  final CircleQuestion question;
  final bool enabled;
  final void Function(int, Duration) onOption;
  final void Function(String, Duration) onInput;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    if (question.isTyped) {
      return TypingArena(
        question: question,
        onAnswer: onInput,
        enabled: enabled,
      );
    }

    if (question.mode == GameMode.audio) {
      return Stack(
        children: [
          CircleArena(
            question: question,
            onAnswer: onOption,
            enabled: enabled,
          ),
          Align(
            alignment: Alignment.center,
            child: IconButton.filledTonal(
              iconSize: 40,
              onPressed: enabled ? onReplay : null,
              icon: const Icon(Icons.volume_up),
              tooltip: 'Прослушать ещё раз',
            ),
          ),
        ],
      );
    }

    return CircleArena(
      question: question,
      onAnswer: onOption,
      enabled: enabled,
    );
  }
}

/// Прогресс, комбо и счёт.
class _RunHeader extends StatelessWidget {
  const _RunHeader({required this.state});

  final RunState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final combo = state.combo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 4,
              backgroundColor:
                  LumenPalette.constellationLine.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Множитель показывается только когда он есть: «×1.0» на
              // экране — это шум, который приучает не смотреть сюда вообще.
              AnimatedOpacity(
                opacity: combo.streak > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '×${combo.multiplier.toStringAsFixed(1)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: combo.isLocked
                        ? theme.colorScheme.onSurfaceVariant
                        : LumenPalette.starlight,
                  ),
                ),
              ),
              Text(
                '${state.score}',
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
