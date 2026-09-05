import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../application/challenge_controller.dart';
import 'challenge_share.dart';

/// Ночной вызов: 20 пар, 60 секунд, один заход.
///
/// Здесь нет ни комбо, ни множителей, ни FSRS: вызов ничего не учит и
/// намеренно ничего не меняет в памяти. Он существует ради одного — общего
/// на всех события, о котором можно рассказать.
class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(challengeControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(challengeControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.challengeTitle),
        leading: widget.onClose == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
      ),
      body: switch (state.stage) {
        ChallengeStage.loading =>
          const Center(child: CircularProgressIndicator()),
        ChallengeStage.unavailable => const _Unavailable(),
        ChallengeStage.alreadyPlayed => _AlreadyPlayed(state: state),
        ChallengeStage.running => _Running(state: state),
        ChallengeStage.finished => _Finished(state: state),
      },
    );
  }
}

class _Running extends ConsumerWidget {
  const _Running({required this.state});

  final ChallengeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final question = state.current;
    if (question == null) return const SizedBox.shrink();

    final seconds = state.remaining.inSeconds;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                l10n.challengeSeconds(seconds),
                style: theme.textTheme.titleLarge?.copyWith(
                  // Последние десять секунд — единственное место в игре,
                  // где время давит намеренно.
                  color: seconds <= 10
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text('${state.answered} / ${state.total}',
                  style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(question.prompt, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: question.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () => ref
                    .read(challengeControllerProvider.notifier)
                    .answer(index),
                child: Text(question.options[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.state});

  final ChallengeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChallengeShareCard(
              correct: state.correct,
              total: state.total,
              elapsed: state.elapsed,
            ),
            const SizedBox(height: 20),
            if (state.sparksEarned > 0)
              Text(
                l10n.challengeSparks(state.sparksEarned),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: LumenPalette.starlight),
              ),
            const SizedBox(height: 24),
            const ShareChallengeButton(),
          ],
        ),
      ),
    );
  }
}

class _AlreadyPlayed extends StatelessWidget {
  const _AlreadyPlayed({required this.state});

  final ChallengeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final previous = state.previous;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nightlight_round,
                size: 44, color: LumenPalette.starlight),
            const SizedBox(height: 16),
            Text(l10n.challengeAlreadyTitle,
                style: theme.textTheme.titleMedium),
            if (previous != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.challengeAlreadyResult(
                  previous.correct,
                  previous.total,
                  (previous.timeMs / 1000).round(),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.challengeAlreadyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Вызова нет — и это нормальное состояние, а не поломка.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

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
            const Icon(Icons.cloud_off, size: 44),
            const SizedBox(height: 16),
            Text(l10n.challengeUnavailableTitle,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              challengeBaseUrl.isEmpty
                  ? l10n.challengeUnavailableNotConfigured
                  : l10n.challengeUnavailableOffline,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
