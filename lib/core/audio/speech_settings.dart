import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Путь к установке голоса — то, что можно предложить игроку, у которого
/// синтеза для языка нет.
///
/// Android умеет открыть нужную страницу сам, iOS — нет: к разделу
/// «Проговаривание» в настройках доступности нет схемы для перехода.
/// Поэтому [openVoiceSettings] возвращает `false`, и экран показывает путь
/// текстом. Врать кнопкой, которая никуда не ведёт, хуже, чем написать три
/// строки инструкции.
abstract final class SpeechSettings {
  static const MethodChannel _channel = MethodChannel('lumen/speech_settings');

  /// Открывает страницу, где ставится голос. `false` — открыть нечего.
  ///
  /// Сначала пробуется диалог загрузки языковых данных: он короче, сразу
  /// список языков. Если его нет — общая страница синтеза речи.
  static Future<bool> openVoiceSettings() async {
    if (!_supported) return false;
    for (final method in ['installVoiceData', 'openVoiceSettings']) {
      try {
        if (await _channel.invokeMethod<bool>(method) == true) return true;
      } on PlatformException catch (e) {
        if (kDebugMode) debugPrint('[speech] $method: $e');
      } on MissingPluginException {
        return false;
      }
    }
    return false;
  }

  /// Есть ли вообще куда вести. Проверяется до показа кнопки, чтобы кнопки
  /// не было там, где она бесполезна.
  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  static bool get canOpenVoiceSettings => _supported;

  /// Путь к настройкам голоса словами — для платформ без перехода.
  static String get manualPath => switch (defaultTargetPlatform) {
        TargetPlatform.iOS =>
          'Настройки → Универсальный доступ → Контент вслух → Голоса',
        TargetPlatform.android =>
          'Настройки → Система → Язык и ввод → Синтез речи',
        _ => 'Настройки системы → синтез речи',
      };
}
