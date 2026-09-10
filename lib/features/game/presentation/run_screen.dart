import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/scheduler/level_stage.dart';
import '../application/run_controller.dart';
import 'circle_arena.dart';
import 'run_summary_view.dart';

/// Экран забега: 10–14 кругов, темп которых задаёт озвучка.
///
/// Верхняя полоса намеренно тихая. Счёт и комбо — это обратная связь, а не
/// содержание: как только они начинают перетягивать внимание с центра круга,
/// игра превращается в кликер.
///
/// **Под ареной ничего нет, и это отмена прошлого захода.** Там стояла кнопка
/// «Дальше», и охраняла она вот что: круг кончался тогда, когда игрок сам
/// решил, — единственное, что тогда давало верному ответу дозвучать, потому
/// что пауза до неё была числом (420/1100 мс) и озвучка в него не
/// укладывалась. Правило живо, исполнитель другой: паузу отмеряет теперь сама
/// озвучка ([RunController.skipReveal] — про то, как и почему). Цена кнопки —
/// касание на каждом из десяти-четырнадцати кругов — снята.
///
/// Ушла вместе с ней и причина, по которой кнопка стояла на экране **всегда**,
/// даже выключенной: появись она только в паузе, арена меняла бы высоту на
/// каждом ответе и круг пересчитывал бы раскладку под новый размер — то есть
/// шесть капсул переезжали бы ровно в тот момент, когда игрок смотрит на
/// верный вариант. Теперь под ареной не появляется и не исчезает ничего, и
/// переезжать нечему по построению.
///
/// Ключ локализации `runNext` («Дальше») после этого не читает никто.
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
            // Рамка реакции: зелёная на верном ответе, красная на неверном.
            //
            // Раньше цветом отзывались только сами варианты, и на фразовых
            // механиках отзываться было нечему: там не выбирают вариант, а
            // заполняют слоты. Рамка одна на все механики — реакция не
            // должна зависеть от того, во что играют.
            // Нажатие по арене в паузе закрывает её досрочно: ждать не обязан
            // тот, кто уже всё прочёл и услышал. Палец после ответа и так на
            // арене, так что движение это ничего не стоит — в отличие от
            // кнопки, которая требовала его от каждого круга.
            child: GestureDetector(
              onTap: state.phase == RunPhase.revealing
                  ? controller.skipReveal
                  : null,
              child: _Feedback(
                outcome: state.lastCorrect,
                child: _Arena(
                  question: question,
                  enabled: state.phase == RunPhase.asking,
                  window: state.window,
                  onOption: controller.answerOption,
                  onReplay: controller.replayPrompt,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Арена круга. Одна на все три механики.
///
/// Отличаются они тем, что в центре — текст или динамик, — и на каком языке
/// варианты; второе арену не касается вовсе, она получает готовый список.
/// Второй арены больше нет: она заполняла пропуски фразы, а вставки слов в
/// предложение в игре не осталось.
class _Arena extends StatelessWidget {
  const _Arena({
    required this.question,
    required this.enabled,
    required this.window,
    required this.onOption,
    required this.onReplay,
  });

  final CircleQuestion question;
  final bool enabled;

  /// Окно, открытое забегом прямо сейчас; `null` — окна нет.
  final Duration? window;

  final void Function(int, Duration) onOption;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return CircleArena(
      question: question,
      onAnswer: onOption,
      enabled: enabled,
      // Динамик в центре вместо текста: нажатие проигрывает заново.
      onReplay: question.mode.needsAudio ? onReplay : null,
      // Полоса окна берёт длину у забега, а не у вопроса, и это и есть «одни
      // часы».
      //
      // Спросить длину у вопроса ([CircleQuestion.answerWindow]) было бы
      // вторым источником одного числа: полоса шла бы столько же, сколько
      // таймер, но **сама по себе** — и уже не совпадала бы с ним по началу.
      // Окно круга на слух открывается не в кадре появления круга, а когда
      // фраза дозвучала; окно после переслушивания заводится заново. Полоса,
      // спросившая вопрос, обещала бы отсчёт, который в этот миг не идёт, а
      // это то же самое, чем она обманывала в онбординге: там таймера нет
      // вовсе, а полоса краснела по `!isNew`.
      //
      // `RunState.window` — то самое значение, которым заведён таймер: нет
      // отсчёта — нет и полосы.
      answerWindow: window,
    );
  }
}

/// Рамка вокруг арены: зелёная на верном, красная на неверном.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.outcome, required this.child});

  /// `null` — ответа ещё нет.
  final bool? outcome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = switch (outcome) {
      true => LumenPalette.correct,
      false => LumenPalette.wrong,
      null => Colors.transparent,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
        boxShadow: outcome == null
            ? const []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Прогресс, этап, комбо и счёт.
class _RunHeader extends StatelessWidget {
  const _RunHeader({required this.state});

  final RunState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final combo = state.combo;
    final goal = state.goal;

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
          const SizedBox(height: 8),
          // Этап называется словом, а не угадывается по числу вариантов.
          //
          // Без подписи игрок видит, что сложность то растёт, то падает, и
          // не может понять, по какому правилу; а правило есть, и оно
          // простое. Спринт вместо названия показывает планку: там важна не
          // фаза, а сколько осталось.
          if (state.stage != null)
            Text(
              goal == null
                  ? _stageName(l10n, state.stage!)
                  : l10n.sprintGoal(
                      state.correct,
                      goal.connections,
                      goal.duration.inSeconds,
                    ),
              style: theme.textTheme.labelMedium?.copyWith(
                color: goal == null
                    ? theme.colorScheme.onSurfaceVariant
                    : LumenPalette.starlight,
              ),
            ),
          const SizedBox(height: 6),
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

/// Название этапа. Живёт здесь, а не в домене: домен не знает про локали.
String _stageName(AppLocalizations l10n, LevelStage stage) => switch (stage) {
      LevelStage.introduction => l10n.stageIntroduction,
      LevelStage.consolidation => l10n.stageConsolidation,
      LevelStage.check => l10n.stageCheck,
      LevelStage.reminder => l10n.stageReminder,
      LevelStage.sprint => l10n.stageSprint,
    };
