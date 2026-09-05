/// Абстракция синтезатора речи.
///
/// Провайдер меняется по мере роста проекта: системный TTS на старте,
/// облачный при выходе за пределы поддерживаемых языков, записи носителей
/// в конце. Игра об этом не знает — она получает готовые файлы из ассетов.
library;

import 'dart:io';

/// Одна позиция для озвучки.
class SpeechItem {
  const SpeechItem({required this.audioId, required this.text});

  /// Идентификатор из `content.db`, например `de/arzt`.
  final String audioId;

  /// Что произносить.
  final String text;
}

abstract class TtsProvider {
  /// Имя голоса — входит в подпись кеша: смена голоса обязана пересинтезировать
  /// всё, иначе в озвучке окажется два разных диктора.
  String get voiceName;

  /// Синтезирует [text] в [output] (WAV). `false` — не получилось.
  Future<bool> speakToFile(String text, File output);
}

/// Кодирование в AAC-LC (`.m4a`). Отдельно от синтеза, потому что TTS и
/// кодек — разные инструменты, и второго может не быть на машине.
///
/// Почему не Opus, который эффективнее в полтора раза: его не умеет iOS.
/// AVFoundation декодирует Ogg Opus только в контейнере CAF, а `just_audio`
/// на iOS — это AVFoundation. Формат, который не играет на половине целевых
/// платформ, не экономит ничего.
class SpeechEncoder {
  const SpeechEncoder._(this.executable);

  const SpeechEncoder.unavailable() : executable = null;

  final String? executable;

  bool get available => executable != null;

  static Future<SpeechEncoder> detect() async {
    for (final candidate in ['ffmpeg']) {
      try {
        final result = await Process.run(candidate, ['-version']);
        if (result.exitCode == 0) return SpeechEncoder._(candidate);
      } catch (_) {
        // Не найден — пробуем следующий.
      }
    }
    return const SpeechEncoder.unavailable();
  }

  /// AAC-LC 24 kbps mono при 16 кГц — измеренные 6 КБ на позицию.
  ///
  /// 16 кГц, а не исходные 22: это стандартная широкополосная речь, выше
  /// 8 кГц у синтезатора почти пусто, и биты, потраченные на пустой диапазон,
  /// отняты у разборчивости. 32 kbps звучали бы лучше, но пять языков тогда
  /// упираются в лимит Google Play (198 МБ из 200) — запас нужнее.
  Future<bool> encode(File wav, File m4a) async {
    final exe = executable;
    if (exe == null) return false;
    try {
      final result = await Process.run(exe, [
        '-y',
        '-loglevel', 'error',
        '-i', wav.path,
        '-c:a', 'aac',
        '-profile:a', 'aac_low',
        '-b:a', '24k',
        '-ac', '1',
        '-ar', '16000',
        m4a.path,
      ]);
      return result.exitCode == 0 && m4a.existsSync();
    } catch (_) {
      return false;
    }
  }
}
