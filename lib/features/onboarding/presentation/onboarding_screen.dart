import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
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

/// Экран результата: **почему** небо начинается здесь, а не просто где.
///
/// Экран был написан, локализован на шесть языков — и недостижим. Калибровка
/// в конце теста объявляла игрока откалиброванным, гейт роутера немедленно
/// открывался, и роутер уводил с `/onboarding` на карту, не дав показать
/// следующий шаг онбординга. Игрок узнавал свой ярус из бейджа в углу карты,
/// без единого слова о том, откуда он взялся.
///
/// Поэтому здесь теперь не одна цифра, а разбор: сколько кругов было, сколько
/// слов игрок узнал, что показал тест — и, если выданный ярус ниже
/// измеренного, почему. «Я ответил почти всё, а получил A0» — это вопрос, на
/// который экран обязан отвечать сам, а не оставлять игрока догадываться, что
/// тест его не понял.
///
/// Число слов курса важнее ярусной буквы: «B1» ничего не говорит человеку,
/// который не сдавал экзаменов.
class _Result extends ConsumerWidget {
  const _Result();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(calibrationControllerProvider);

    // Ярус приходит из состояния калибровки уже урезанным: решение принято
    // по прочитанным метаданным, а не по заглушке провайдера. Пока оно не
    // принято — а между концом теста и записью лежит одно ожидание —
    // экран ничего не утверждает.
    final granted = state.granted;
    if (granted == null) {
      return const _ResultShell(child: Center(
        child: CircularProgressIndicator(),
      ));
    }

    final measured = state.calibration.result;
    final capped = measured != null && measured.index > granted.index;

    // Число приходит из базы, а не из константы: курс растёт файлами
    // контента. Пока запрос не ответил, слово о количестве не говорится
    // вовсе — обещать примерное число, а потом заменить его другим хуже, чем
    // подождать.
    final vocabulary = ref.watch(vocabularyUpToProvider(granted)).value;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return _ResultShell(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  granted.label,
                  style: theme.textTheme.displayMedium
                      ?.copyWith(color: LumenPalette.starlight),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.calibrationResultTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                // Разбор теста: три строчки, по которым видно, откуда взялся
                // ярус. «Тест показал» появляется только когда показал
                // другое — иначе это строка, повторяющая заголовок.
                _ResultRow(
                  label: l10n.calibrationResultCircles,
                  // Показанные круги, а не зачётные: игрок считает экраны, и
                  // переспрос за подозрительно быстрый ответ был для него
                  // таким же кругом, как остальные.
                  value: '${state.calibration.circles}',
                ),
                _ResultRow(
                  // Узнанное — на любом ярусе, включая те, что выше
                  // выданного: гребёнка нарочно спрашивает выше, и игрок
                  // действительно их узнал.
                  label: l10n.calibrationResultRecognised,
                  value: '${state.recognised}',
                ),
                if (capped)
                  _ResultRow(
                    label: l10n.calibrationResultMeasured,
                    value: measured.label,
                    highlight: true,
                  ),
                const SizedBox(height: 16),
                if (capped)
                  Text(
                    l10n.calibrationResultCapped(granted.label),
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                if (capped) const SizedBox(height: 16),
                if (vocabulary != null)
                  Text(
                    l10n.calibrationResultVocabulary(vocabulary),
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                // «Уже светят на вашем небе» — и это теперь правда.
                //
                // Строка брала то же число, что строка «фраз вы узнали»,
                // то есть всё узнанное на всех ярусах: игрок читал «5 слів із
                // тесту вже світять», а четыре из пяти лежали на закрытых
                // ярусах и не светили нигде. Здесь только засеянное —
                // выданный ярус и ниже.
                if (state.seeded > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.calibrationResultSeeded(state.seeded),
                    textAlign: TextAlign.center,
                    style: muted?.copyWith(color: LumenPalette.starlight),
                  ),
                ],
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
                  // Гейт роутера открывает эта кнопка, и только она: пока
                  // калибровка объявляла игрока откалиброванным сама, этот
                  // экран не показывался вовсе.
                  onPressed: () => ref
                      .read(playerControllerProvider.notifier)
                      .completeCalibration(granted),
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

/// Небо за экраном результата — общий фон для готового результата и ожидания.
class _ResultShell extends StatelessWidget {
  const _ResultShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LumenPalette.skyZenith, LumenPalette.skyHorizon],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: child,
        ),
      );
}

/// Строка разбора: подпись слева, число справа.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: highlight ? LumenPalette.starlight : null,
            ),
          ),
        ],
      ),
    );
  }
}
