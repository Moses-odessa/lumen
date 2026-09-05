import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';

/// Ключ карточки результата: по нему её снимают в картинку.
final challengeShareKey = GlobalKey();

/// Карточка результата вызова — то, что уходит в шаринг.
///
/// Она сделана красивой не ради красоты: картинкой делятся, а скриншотом
/// интерфейса — нет. Поэтому у карточки свой фон, свои поля и никаких
/// элементов управления внутри.
class ChallengeShareCard extends StatelessWidget {
  const ChallengeShareCard({
    super.key,
    required this.correct,
    required this.total,
    required this.elapsed,
  });

  final int correct;
  final int total;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      key: challengeShareKey,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LumenPalette.skyZenith, LumenPalette.skyHorizon],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.challengeTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              '$correct / $total',
              style: theme.textTheme.displaySmall?.copyWith(
                color: LumenPalette.starlight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.challengeCardSeconds(
                (elapsed.inMilliseconds / 1000).toStringAsFixed(1),
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            // Звёздная строка: наглядно и без цифр.
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: i < correct
                        ? LumenPalette.starlight
                        : Colors.white24,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Lumen',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка «поделиться»: снимает карточку в PNG и отдаёт системе.
class ShareChallengeButton extends ConsumerWidget {
  const ShareChallengeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () => _share(ref),
      icon: const Icon(Icons.ios_share),
      label: Text(AppLocalizations.of(context).challengeShare),
    );
  }

  Future<void> _share(WidgetRef ref) async {
    try {
      final bytes = await _capture();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lumen_challenge.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
      ref.read(analyticsProvider).log(AnalyticsEvents.resultShared);
    } catch (_) {
      // Шаринг — приятное дополнение. Его отказ не должен выглядеть как
      // поломка игры.
    }
  }

  /// Снимок карточки в PNG.
  ///
  /// Множитель 3 — чтобы картинка не выглядела мыльной в мессенджере,
  /// который её ещё раз пережмёт.
  Future<Uint8List?> _capture() async {
    final boundary = challengeShareKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;

    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}
