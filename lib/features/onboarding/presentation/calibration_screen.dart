import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    ref.listen(calibrationControllerProvider, (previous, next) {
      if (next.isDone && !(previous?.isDone ?? false)) widget.onDone();
    });

    final theme = Theme.of(context);

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
                      _hint(state.calibration.phase),
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
                  child: const Text('Я с нуля'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _hint(CalibrationPhase phase) => switch (phase) {
        CalibrationPhase.comb => 'Просто соединяйте то, что знаете',
        CalibrationPhase.search => 'Подбираем, с чего начать',
        CalibrationPhase.confirm => 'Проверяем ещё раз',
        CalibrationPhase.phrases => 'Теперь целые фразы',
        CalibrationPhase.done => 'Готово',
      };
}
