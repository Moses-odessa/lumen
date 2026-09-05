import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';

/// Онбординг. На M0 работает только кнопка «я с нуля»: она ставит A0 и
/// закрывает redirect-гейт. Выбор трёх языков и калибровка — M3.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

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
                Text(l10n.onboardingTitle, style: theme.textTheme.headlineSmall),
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
                        .log(AnalyticsEvents.calibrationStarted);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${l10n.comingSoon} · M3')),
                    );
                  },
                  child: Text(l10n.onboardingStartCalibration),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _startFromScratch(ref),
                  child: Text(l10n.onboardingFromScratch),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// «Я с нуля» — A0 без теста (docs/CONCEPT.md «Онбординг»).
  void _startFromScratch(WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);
    controller.createDraft(
      targetLang: defaultTargetLang,
      nativeLang: defaultNativeLang,
    );
    controller.completeCalibration(Tier.a0);
    ref.read(analyticsProvider).log(AnalyticsEvents.calibrationSkipped);
  }
}
