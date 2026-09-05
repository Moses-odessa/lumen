/// Системный синтезатор речи Windows (SAPI) через PowerShell.
///
/// Зачем он вообще: озвучка — часть ядра игры, без неё нельзя проверить ни
/// один круг. Облачный TTS требует ключей и денег, а системный бесплатен,
/// работает офлайн и на большинстве машин уже умеет нужные языки. Для
/// разработки и для первого языка этого достаточно; качество носителей —
/// отдельная задача (M8).
library;

import 'dart:convert';
import 'dart:io';

import 'tts_provider.dart';

/// Подбирает провайдера под платформу и язык. `null` — озвучить нечем.
Future<TtsProvider?> resolveProvider(String lang) async {
  if (Platform.isWindows) {
    final voice = await SapiProvider.findVoice(lang);
    return voice == null ? null : SapiProvider(voice);
  }
  // TODO(data): для macOS есть `say`, для Linux — piper/espeak. Появятся,
  // когда сборка озвучки понадобится не только на машине разработчика.
  return null;
}

class SapiProvider implements TtsProvider {
  SapiProvider(this.voiceName);

  @override
  final String voiceName;

  /// Первый установленный голос нужной культуры.
  static Future<String?> findVoice(String lang) async {
    final script = '''
Add-Type -AssemblyName System.Speech
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$s.GetInstalledVoices() |
  Where-Object { \$_.VoiceInfo.Culture.TwoLetterISOLanguageName -eq '$lang' } |
  ForEach-Object { \$_.VoiceInfo.Name }
''';
    final result = await _runPowerShell(script);
    if (result == null) return null;
    final voices = result
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return voices.isEmpty ? null : voices.first;
  }

  @override
  Future<bool> speakToFile(String text, File output) async {
    // Текст передаётся base64: в словах есть кавычки, апострофы и умляуты,
    // а экранирование их в PowerShell — источник тихих ошибок.
    final encoded = base64.encode(utf8.encode(text));
    final script = '''
Add-Type -AssemblyName System.Speech
\$bytes = [System.Convert]::FromBase64String('$encoded')
\$text = [System.Text.Encoding]::UTF8.GetString(\$bytes)
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$s.SelectVoice('$voiceName')
\$s.Rate = -1
\$s.SetOutputToWaveFile('${output.path.replaceAll(r'\', r'\\')}')
\$s.Speak(\$text)
\$s.Dispose()
''';
    final result = await _runPowerShell(script);
    return result != null && output.existsSync() && output.lengthSync() > 0;
  }
}

/// Запуск PowerShell со скриптом в base64 — единственный способ передать
/// многострочный текст без войны с экранированием.
Future<String?> _runPowerShell(String script) async {
  try {
    final encoded = base64.encode(
      // PowerShell ждёт UTF-16LE для -EncodedCommand.
      Uint16Encoding.encode(script),
    );
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
      stdoutEncoding: const SystemEncoding(),
    );
    if (result.exitCode != 0) {
      stderr.writeln(result.stderr);
      return null;
    }
    return result.stdout as String;
  } catch (e) {
    stderr.writeln('powershell: $e');
    return null;
  }
}

/// UTF-16LE без BOM — формат, который требует `-EncodedCommand`.
abstract final class Uint16Encoding {
  static List<int> encode(String value) {
    final bytes = <int>[];
    for (final unit in value.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return bytes;
  }
}
