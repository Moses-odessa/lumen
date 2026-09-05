import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Манифест озвучки: `audioId` → путь к ассету.
///
/// Приложение не строит путь из `audioId` напрямую: расширение зависит от
/// того, чем собирали — Opus там, где при сборке был `ffmpeg`, WAV там, где
/// его не было. Знать об этом должен один объект, а не каждый вызов
/// проигрывания.
///
/// Вся озвучка лежит в ассетах, все ярусы сразу. Докачка паков была и
/// удалена: она требовала хостинга, а полный курс одного языка это 17 МБ —
/// цена, которую проще заплатить установкой один раз, чем поддерживать
/// загрузчик с возобновлением, проверкой хешей и управлением местом.
class AudioManifest {
  const AudioManifest(this._files);

  const AudioManifest.empty() : _files = const {};

  final Map<String, String> _files;

  bool get isEmpty => _files.isEmpty;

  int get length => _files.length;

  /// Все известные идентификаторы. Порядок стабильный — манифест пишется
  /// отсортированным, чтобы диффы в git были читаемыми.
  Iterable<String> get audioIds => _files.keys;

  bool has(String audioId) => _files.containsKey(audioId);

  /// Путь к ассету или `null`, если позиции нет в манифесте.
  String? locate(String audioId) => _files[audioId];

  /// Манифест языка из ассетов. Отсутствие манифеста — не ошибка: язык
  /// может быть ещё не озвучен, и игра тогда молча идёт без звука.
  static Future<AudioManifest> load(String lang) async {
    try {
      final raw =
          await rootBundle.loadString('assets/audio/$lang/manifest.json');
      final json = jsonDecode(raw) as Map<String, Object?>;
      final files = json['files'] as Map<String, Object?>? ?? const {};
      return AudioManifest({
        for (final entry in files.entries)
          entry.key: 'assets/audio/$lang/'
              '${(entry.value! as Map<String, Object?>)['file']! as String}',
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] нет манифеста $lang: $e');
      return const AudioManifest.empty();
    }
  }
}
