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

/// Кодирование в Opus. Отдельно от синтеза, потому что TTS и кодек — разные
/// инструменты, и второго может не быть на машине.
class OpusEncoder {
  const OpusEncoder._(this.executable);

  const OpusEncoder.unavailable() : executable = null;

  final String? executable;

  bool get available => executable != null;

  static Future<OpusEncoder> detect() async {
    for (final candidate in ['ffmpeg']) {
      try {
        final result = await Process.run(candidate, ['-version']);
        if (result.exitCode == 0) return OpusEncoder._(candidate);
      } catch (_) {
        // Не найден — пробуем следующий.
      }
    }
    return const OpusEncoder.unavailable();
  }

  /// Opus 24 kbps mono: примерно 3 КБ на секунду звука. Именно из этой цифры
  /// считается бюджет «один язык ≈ 25 МБ» в README.
  Future<bool> encode(File wav, File opus) async {
    final exe = executable;
    if (exe == null) return false;
    try {
      final result = await Process.run(exe, [
        '-y',
        '-loglevel', 'error',
        '-i', wav.path,
        '-c:a', 'libopus',
        '-b:a', '24k',
        '-ac', '1',
        '-ar', '24000',
        // Речь, а не музыка: кодек экономит биты на том, чего в голосе нет.
        '-application', 'voip',
        opus.path,
      ]);
      return result.exitCode == 0 && opus.existsSync();
    } catch (_) {
      return false;
    }
  }
}
