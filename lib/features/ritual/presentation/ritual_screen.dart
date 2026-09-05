import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/milestone_placeholder.dart';

/// Дневной ритуал: Восход → уровень → ночной вызов. Круг и забег приходят
/// с M1, сам ритуал — с M2, ночной вызов — с M5.
class RitualScreen extends StatelessWidget {
  const RitualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.gameTitle)),
      body: const MilestonePlaceholder(
        milestone: 'M1',
        what: 'круг, забег, озвучка, очки',
        icon: Icons.play_circle_outline,
      ),
    );
  }
}
