import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../game/application/run_controller.dart';
import '../../game/application/session_loader.dart';
import '../../game/presentation/run_screen.dart';

/// Что сейчас показывает вкладка «Игра».
enum _RitualStage { idle, loading, playing, empty }

/// Дневной ритуал: Восход → уровень → ночной вызов.
///
/// На M1 здесь два входа — Восход и уровень — и сам забег. Сборка ритуала в
/// единую последовательность с подсчётом возвращённых люменов приходит на M2,
/// ночной вызов — на M5.
class RitualScreen extends ConsumerStatefulWidget {
  const RitualScreen({super.key});

  @override
  ConsumerState<RitualScreen> createState() => _RitualScreenState();
}

class _RitualScreenState extends ConsumerState<RitualScreen> {
  _RitualStage _stage = _RitualStage.idle;
  String? _error;

  Future<void> _start({required bool sunrise}) async {
    setState(() {
      _stage = _RitualStage.loading;
      _error = null;
    });

    try {
      final loader = ref.read(sessionLoaderProvider);
      final now = DateTime.now();
      final session =
          sunrise ? await loader.sunrise(now) : await loader.level(now);

      if (!mounted) return;
      if (session.isEmpty) {
        setState(() => _stage = _RitualStage.empty);
        return;
      }

      ref.read(runControllerProvider.notifier).start(session.questions);
      setState(() => _stage = _RitualStage.playing);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _RitualStage.idle;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: _stage == _RitualStage.playing
          ? AppBar(
              title: Text(l10n.gameTitle),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _stage = _RitualStage.idle),
              ),
            )
          : AppBar(title: Text(l10n.gameTitle)),
      body: switch (_stage) {
        _RitualStage.loading =>
          const Center(child: CircularProgressIndicator()),
        _RitualStage.playing => RunScreen(
            onFinished: () => setState(() => _stage = _RitualStage.idle),
          ),
        _RitualStage.empty => _EmptySession(
            onBack: () => setState(() => _stage = _RitualStage.idle),
          ),
        _RitualStage.idle => _RitualHome(
            error: _error,
            onSunrise: () => _start(sunrise: true),
            onLevel: () => _start(sunrise: false),
          ),
      },
    );
  }
}

class _RitualHome extends StatelessWidget {
  const _RitualHome({
    required this.onSunrise,
    required this.onLevel,
    this.error,
  });

  final VoidCallback onSunrise;
  final VoidCallback onLevel;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _RitualCard(
          icon: Icons.wb_twilight,
          title: 'Восход',
          subtitle: 'Только повторение. Первыми — самые тусклые звёзды.',
          onTap: onSunrise,
        ),
        const SizedBox(height: 12),
        _RitualCard(
          icon: Icons.auto_awesome,
          title: 'Новый уровень',
          subtitle: 'Шесть новых слов, двенадцать повторов и босс-фраза.',
          onTap: onLevel,
        ),
        const SizedBox(height: 12),
        const _RitualCard(
          icon: Icons.nightlight_round,
          title: 'Ночной вызов',
          subtitle: 'M5 — общий набор из 20 пар на всех, 60 секунд.',
          onTap: null,
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

class _RitualCard extends StatelessWidget {
  const _RitualCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(
          icon,
          color: enabled
              ? LumenPalette.starlight
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
      ),
    );
  }
}

/// Повторять нечего и новое кончилось — состояние, которое обязано выглядеть
/// как достижение, а не как ошибка.
class _EmptySession extends StatelessWidget {
  const _EmptySession({required this.onBack});

  final VoidCallback onBack;

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
            Text('Небо в порядке', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Повторять сейчас нечего. Звёзды потускнеют — и вернутся сюда '
              'сами.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: onBack, child: const Text('Назад')),
          ],
        ),
      ),
    );
  }
}
