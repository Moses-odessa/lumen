import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player.dart';
import '../../domain/entities/tier.dart';

/// Язык изучения по умолчанию: до M8 в ассетах лежит озвучка ровно одного.
const String defaultTargetLang = 'de';

/// Язык подсказок по умолчанию. Настоящий выбирается в онбординге.
const String defaultNativeLang = 'ru';

/// Состояние игрока. `null` — игрок ещё не создан: роутер держит такого
/// в онбординге.
class PlayerController extends Notifier<Player?> {
  @override
  Player? build() => null;

  void replace(Player player) => state = player;

  void clear() => state = null;

  /// Создаёт игрока по выбору языков в онбординге — до калибровки.
  void createDraft({
    required String targetLang,
    required String nativeLang,
    String? uiLang,
  }) =>
      state = Player(
        targetLang: targetLang,
        nativeLang: nativeLang,
        uiLang: uiLang,
        tier: Tier.a0,
      );

  /// Фиксирует результат калибровки. Ярус — предложение, а не приговор:
  /// его можно сменить вручную в любой момент.
  void completeCalibration(Tier tier) =>
      state = state?.copyWith(tier: tier, calibrated: true);

  void setTier(Tier tier) => state = state?.copyWith(tier: tier);

  void setLanguages({String? targetLang, String? nativeLang}) =>
      state = state?.copyWith(targetLang: targetLang, nativeLang: nativeLang);

  void setUiLang(String? code) => state = state?.copyWith(uiLang: () => code);

  void setSoundEnabled(bool enabled) =>
      state = state?.copyWith(soundEnabled: enabled);

  void setFreePace(bool enabled) => state = state?.copyWith(freePace: enabled);
}

final playerControllerProvider =
    NotifierProvider<PlayerController, Player?>(PlayerController.new);
