import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../core/widgets/milestone_placeholder.dart';
import '../../../data/repositories/player_repository.dart';

/// Карта созвездий. На M0 — только фон неба и текущий ярус; сама карта на
/// `CustomPainter` приходит с M2.
class SkyScreen extends ConsumerWidget {
  const SkyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tier = ref.watch(playerControllerProvider)?.tier;

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
        appBar: AppBar(
          title: Text(l10n.skyTitle),
          actions: [
            if (tier != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    tier.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
          ],
        ),
        body: const MilestonePlaceholder(
          milestone: 'M2',
          what: 'карта созвездий, ярусы, прогресс',
          icon: Icons.blur_on_outlined,
        ),
      ),
    );
  }
}
