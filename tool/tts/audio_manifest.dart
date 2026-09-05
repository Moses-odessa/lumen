/// Манифест озвучки: какой файл соответствует какому `audioId`, сколько
/// весит и из чего синтезирован.
///
/// Нужен по трём причинам: приложение по нему находит файл, не завися от
/// расширения (WAV на машине без кодека, AAC в релизе); синтезатор по нему
/// понимает, что пересинтезировать не надо; а суммарный вес видно сразу, без
/// обхода каталога — это тот самый бюджет из README.
library;

import 'dart:convert';
import 'dart:io';

class AudioEntry {
  const AudioEntry({
    required this.file,
    required this.bytes,
    required this.signature,
  });

  /// Имя файла внутри каталога языка.
  final String file;

  final int bytes;

  /// Хеш «голос + текст». Изменился — надо синтезировать заново.
  final String signature;

  Map<String, Object?> toJson() => {
        'file': file,
        'bytes': bytes,
        'signature': signature,
      };

  static AudioEntry fromJson(Map<String, Object?> json) => AudioEntry(
        file: json['file']! as String,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        signature: json['signature'] as String? ?? '',
      );
}

class AudioManifest {
  AudioManifest(this.entries);

  AudioManifest.empty() : entries = {};

  static const String fileName = 'manifest.json';

  /// `audioId` → файл.
  final Map<String, AudioEntry> entries;

  static Future<AudioManifest?> load(Directory dir) async {
    final file = File('${dir.path}/$fileName');
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final files = json['files'] as Map<String, Object?>? ?? {};
      return AudioManifest({
        for (final entry in files.entries)
          entry.key:
              AudioEntry.fromJson(entry.value! as Map<String, Object?>),
      });
    } catch (_) {
      // Битый манифест — не повод падать: пересинтезируем всё.
      return null;
    }
  }

  Future<void> save(Directory dir) async {
    // Ключи сортируются: манифест лежит в git, и его диффы должны быть
    // читаемыми, а не перемешанными от запуска к запуску.
    final keys = entries.keys.toList()..sort();
    final json = {
      'version': 1,
      'totalBytes': entries.values.fold<int>(0, (s, e) => s + e.bytes),
      'files': {
        for (final key in keys) key: entries[key]!.toJson(),
      },
    };
    await File('${dir.path}/$fileName')
        .writeAsString('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  }
}
