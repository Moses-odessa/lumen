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
    final script = 'Add-Type -AssemblyName System.Speech; '
        '(New-Object System.Speech.Synthesis.SpeechSynthesizer)'
        '.GetInstalledVoices() | '
        'Where-Object { \$_.VoiceInfo.Culture.TwoLetterISOLanguageName '
        "-eq '${_quote(lang)}' } | "
        'ForEach-Object { \$_.VoiceInfo.Name }';
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
    // Текст едет через временный файл в UTF-8, а не внутри команды: в словах
    // есть кавычки, апострофы и умляуты, и экранировать их в командной строке
    // — источник тихих ошибок. Файл заодно оставляет команду читаемой.
    final carrier = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'lumen_tts_${output.uri.pathSegments.last}.txt',
    );
    await carrier.writeAsString(text, encoding: utf8);

    final script = 'Add-Type -AssemblyName System.Speech; '
        "\$t = [System.IO.File]::ReadAllText('${_quote(carrier.path)}', "
        '[System.Text.Encoding]::UTF8); '
        '\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
        "\$s.SelectVoice('${_quote(voiceName)}'); "
        '\$s.Rate = -1; '
        "\$s.SetOutputToWaveFile('${_quote(output.path)}'); "
        '\$s.Speak(\$t); '
        '\$s.Dispose()';

    try {
      final result = await _runPowerShell(script);
      return result != null && output.existsSync() && output.lengthSync() > 0;
    } finally {
      if (carrier.existsSync()) carrier.deleteSync();
    }
  }
}

/// Экранирование для одинарных кавычек PowerShell: внутри них специальных
/// символов нет, достаточно удвоить сам апостроф.
String _quote(String value) => value.replaceAll("'", "''");

/// Запуск PowerShell с открытым текстом команды.
///
/// Сознательно НЕ используется `-EncodedCommand`: base64-скрипт в командной
/// строке PowerShell — самый ходовой способ доставки вредоносного кода, и
/// поведенческие эвристики антивирусов (Avast `IDP.HELU.PSE*` и родня)
/// блокируют такой запуск не разбирая содержимого. Инструмент сборки не
/// должен выглядеть как малварь: команда идёт читаемой, а единственное, что
/// требовало кодирования — текст для озвучки — передаётся файлом.
///
/// Файл-скрипт (`-File`) тоже не годится: политика выполнения по умолчанию
/// `Restricted`, и `.ps1` просто не запустится. На `-Command` она не влияет.
Future<String?> _runPowerShell(String script) async {
  try {
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
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
