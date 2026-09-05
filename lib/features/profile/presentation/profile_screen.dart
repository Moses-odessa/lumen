import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/milestone_placeholder.dart';
import '../../../data/repositories/player_repository.dart';

/// Профиль: орбита, искры, горящие слова. Главная цифра здесь — счётчик
/// горящих слов, а не XP (docs/CONCEPT.md «Очки»).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final player = ref.watch(playerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: Column(
        children: [
          if (player != null)
            ListTile(
              leading: const Icon(Icons.public),
              title: Text('${player.nativeLang} → ${player.targetLang}'),
              subtitle: Text('${player.tier.label} · орбита ${player.orbit}'),
            ),
          const Expanded(
            child: MilestonePlaceholder(
              milestone: 'M5',
              what: 'орбита, искры, статистика, свои слова',
              icon: Icons.person_outline,
            ),
          ),
        ],
      ),
    );
  }
}
