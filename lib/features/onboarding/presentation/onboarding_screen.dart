import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/calibration/calibration.dart';
import '../../../domain/entities/tier.dart';
import '../application/calibration_controller.dart';
import 'calibration_screen.dart';
import 'language_screen.dart';

/// Шаги онбординга.
enum _Step { welcome, languages, calibration, result }

/// Онбординг: приветствие → языки → калибровка → результат.
///
/// Ни на одном шаге игрока не спрашивают, какой у него уровень: люди
/// систематически ошибаются в обе стороны. Вместо вопроса он сразу играет.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.welcome;

  @override
  Widget build(BuildContext context) => switch (_step) {
        _Step.welcome => _Welcome(
            onCalibrate: () => setState(() => _step = _Step.languages),
            onFromScratch: _fromScratch,
          ),
        _Step.languages => LanguageScreen(
            onDone: () => setState(() => _step = _Step.calibration),
          ),
        _Step.calibration => CalibrationScreen(
            onDone: () => setState(() => _step = _Step.result),
          ),
        _Step.result => const _Result(),
      };

  /// «Я с нуля» — A0 без теста. Работает и до выбора языков: у них есть
  /// разумные значения по умолчанию, и поменять их можно в настройках.
  void _fromScratch() {
    final controller = ref.read(playerControllerProvider.notifier);
    controller.createDraft(
      targetLang: defaultTargetLang,
      nativeLang: defaultNativeLang,
    );
    controller.completeCalibration(Tier.a0);
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationSkipped);
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onCalibrate, required this.onFromScratch});

  final VoidCallback onCalibrate;
  final VoidCallback onFromScratch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: LumenPalette.starlight.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.onboardingTitle,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.onboardingSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(analyticsProvider)
                        .log(AnalyticsEvents.onboardingOpened);
                    onCalibrate();
                  },
                  child: Text(l10n.onboardingStartCalibration),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onFromScratch,
                  child: Text(l10n.onboardingFromScratch),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран результата: где начинается небо и сколько слов игрок уже знает.
///
/// Число слов здесь важнее яруса: «B1» ничего не говорит человеку, который
/// не сдавал экзаменов, а «вы уже знаете примерно 1 850 слов» говорит.
class _Result extends ConsumerWidget {
  const _Result();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(calibrationControllerProvider);
    // Показываем ровно тот ярус, на котором игрок будет играть: обещать
    // B1 и выдать A0 хуже, чем сразу назвать доступное.
    final measured = state.calibration.result ??
        ref.watch(playerControllerProvider)?.tier ??
        Tier.a0;
    final tier = measured.atMost(ref.watch(maxTierProvider));
    final vocabulary = Calibration.estimatedVocabulary(tier);

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
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tier.label,
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: LumenPalette.starlight),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.calibrationResultTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.calibrationResultVocabulary(vocabulary),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.calibrationResultTierChangeable,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  // Гейт роутера уже открыт: игрок откалиброван, и его
                  // достаточно вернуть на карту.
                  onPressed: () => ref
                      .read(playerControllerProvider.notifier)
                      .completeCalibration(tier),
                  child: Text(l10n.calibrationResultOpen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
