import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player.dart';
import '../../domain/entities/tier.dart';

/// Язык изучения по умолчанию: в ассетах лежит собранная база ровно одного.
///
/// Это значение только до онбординга и только для кнопки «я с нуля». Список
/// доступных языков в коде не хранится — он читается из контентной базы
/// (`targetLanguagesProvider`).
const String defaultTargetLang = 'de';

/// Язык подсказок по умолчанию. Настоящий выбирается в онбординге.
///
/// Был `ru`; стал `uk`. Проект несёт немецкий и украинский, русский остался
/// в репозитории со `status: draft` и потому в игре не предлагается. Если
/// значение по умолчанию окажется недоступным, экран языков берёт первый
/// доступный, а не записывает пустую пару.
const String defaultNativeLang = 'uk';

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
