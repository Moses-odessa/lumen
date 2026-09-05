import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Манифест озвучки, который пишет `tool/synthesize_audio.dart`.
///
/// Приложение не строит путь к файлу из `audioId` напрямую, потому что
/// расширение зависит от того, чем собирали: Opus в релизе, WAV на машине без
/// кодека. Манифест снимает этот вопрос и заодно даёт честный ответ, есть ли
/// озвучка вообще — до того, как плеер попытается открыть несуществующий
/// ассет.
class AudioManifest {
  const AudioManifest(this._files);

  const AudioManifest.empty() : _files = const {};

  /// `audioId` → имя файла внутри каталога языка.
  final Map<String, String> _files;

  bool get isEmpty => _files.isEmpty;

  int get length => _files.length;

  /// Полный путь к ассету или `null`, если такой озвучки нет.
  String? pathFor(String audioId) {
    final file = _files[audioId];
    if (file == null) return null;
    final lang = audioId.split('/').first;
    return 'assets/audio/$lang/$file';
  }

  bool has(String audioId) => _files.containsKey(audioId);

  /// Все известные идентификаторы. Порядок стабильный — манифест пишется
  /// отсортированным, чтобы диффы в git были читаемыми.
  Iterable<String> get audioIds => _files.keys;

  /// Читает манифест языка из ассетов.
  ///
  /// Отсутствие манифеста — не ошибка: озвучка синтезируется отдельным
  /// шагом, и до него игра должна запускаться, просто молча.
  static Future<AudioManifest> load(String lang) async {
    try {
      final raw = await rootBundle.loadString('assets/audio/$lang/manifest.json');
      final json = jsonDecode(raw) as Map<String, Object?>;
      final files = json['files'] as Map<String, Object?>? ?? const {};
      return AudioManifest({
        for (final entry in files.entries)
          entry.key: (entry.value! as Map<String, Object?>)['file']! as String,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[audio] нет манифеста для $lang: $e');
      }
      return const AudioManifest.empty();
    }
  }
}
