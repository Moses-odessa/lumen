import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/calibration/calibration.dart';
import '../../game/presentation/circle_arena.dart';
import '../application/calibration_controller.dart';

/// Экран калибровки: та же механика круга, только слова со всех ярусов.
///
/// Игроку не сообщают, какой ярус проверяется, — иначе тест превращается в
/// экзамен, а он должен ощущаться как первая игра. Отсюда и подписи фаз:
/// они объясняют, что происходит, не называя уровень.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calibrationControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calibrationControllerProvider);
    final controller = ref.read(calibrationControllerProvider.notifier);

    // Дальше — когда результат **готов**, а не когда кончились круги.
    //
    // Условие было `next.isDone`, то есть последний ответ уводил экран сразу:
    // паузу после последней фразы никто не видел, а экран результата
    // открывался раньше, чем калибровка успевала урезать ярус и засеять
    // память, — и показывал пустоту вместо разбора.
    ref.listen(calibrationControllerProvider, (previous, next) {
      if (next.granted != null && previous?.granted == null) widget.onDone();
    });

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _hint(l10n, state.calibration),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (state) {
                  CalibrationUiState(error: final String error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error),
                      ),
                    ),
                  CalibrationUiState(question: final question?) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircleArena(
                        question: question,
                        enabled: !state.loading,
                        onAnswer: controller.answer,
                        onReplay: question.mode.needsAudio
                            ? controller.replayPrompt
                            : null,
                      ),
                    ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: () {
                    controller.skip();
                    widget.onDone();
                  },
                  child: Text(l10n.onboardingFromScratch),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Подпись под полосой: одна на весь тест.
  ///
  /// Фаз у калибровки больше нет — все двадцать кругов устроены одинаково, —
  /// и вместе с ними ушёл `switch` по фазам, который выбирал одну подпись из
  /// пяти. Он охранял вещь, которую стоит назвать: перечисление фаз руками
  /// заставляло автора новой фазы придумать ей слова, иначе экран не
  /// собирался. Различать нечего, и охранять нечего.
  ///
  /// Взята подпись «просто соединяйте то, что знаете»: для теста, который
  /// спрашивает фразы всех пяти ярусов подряд и ничего не сообщает игроку об
  /// уровне, она верна буквально. Ключ по-прежнему называется
  /// `calibrationHintComb`, хотя гребёнки нет; переименование ключа и текст
  /// нового — работа переводчика, а не рефакторинга. Ключи
  /// `calibrationHintSearch` и `calibrationHintConfirm` не читает больше
  /// никто: поиска и подтверждения границы в тесте не осталось.
  String _hint(AppLocalizations l10n, CalibrationState state) =>
      state.isDone ? l10n.calibrationHintDone : l10n.calibrationHintComb;
}
