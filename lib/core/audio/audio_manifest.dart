import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Где лежит файл озвучки.
enum AudioSource {
  /// В ассетах приложения: базовый ярус, который едет вместе с установкой.
  asset,

  /// В скачанном паке, в support-директории.
  pack,
}

/// Одна позиция манифеста.
class AudioLocation {
  const AudioLocation({required this.path, required this.source});

  /// Путь к ассету или абсолютный путь к файлу пака.
  final String path;
  final AudioSource source;

  bool get isAsset => source == AudioSource.asset;
}

/// Манифест озвучки: `audioId` → файл.
///
/// Приложение не строит путь из `audioId` напрямую по двум причинам.
/// Первая: расширение зависит от того, чем собирали, — Opus в релизе, WAV
/// на машине без кодека. Вторая, с M8: файл может лежать не в ассетах, а в
/// скачанном паке, и знать об этом должен один объект, а не каждый вызов
/// проигрывания.
class AudioManifest {
  const AudioManifest(this._files);

  const AudioManifest.empty() : _files = const {};

  final Map<String, AudioLocation> _files;

  bool get isEmpty => _files.isEmpty;

  int get length => _files.length;

  /// Все известные идентификаторы. Порядок стабильный — манифест пишется
  /// отсортированным, чтобы диффы в git были читаемыми.
  Iterable<String> get audioIds => _files.keys;

  bool has(String audioId) => _files.containsKey(audioId);

  AudioLocation? locate(String audioId) => _files[audioId];

  /// Сколько позиций пришло из скачанных паков.
  int get fromPacks =>
      _files.values.where((l) => l.source == AudioSource.pack).length;

  /// Манифест языка: ассеты плюс всё, что уже скачано.
  ///
  /// Паки перекрывают ассеты, а не наоборот: если ярус докачан, играть надо
  /// докачанным. Отсутствие паков — не ошибка, просто их пока нет.
  static Future<AudioManifest> load(
    String lang, {
    Directory? packsDirectory,
  }) async {
    final files = <String, AudioLocation>{};

    for (final entry in await _loadAssetManifest(lang)) {
      files[entry.key] = AudioLocation(
        path: 'assets/audio/$lang/${entry.value}',
        source: AudioSource.asset,
      );
    }

    if (packsDirectory != null && packsDirectory.existsSync()) {
      for (final tier in packsDirectory.listSync().whereType<Directory>()) {
        for (final entry in _loadPackManifest(tier)) {
          files[entry.key] = AudioLocation(
            path: '${tier.path}/${entry.value}',
            source: AudioSource.pack,
          );
        }
      }
    }

    return AudioManifest(files);
  }

  static Future<List<MapEntry<String, String>>> _loadAssetManifest(
    String lang,
  ) async {
    try {
      final raw =
          await rootBundle.loadString('assets/audio/$lang/manifest.json');
      return _parse(raw);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] нет манифеста ассетов $lang: $e');
      return const [];
    }
  }

  static List<MapEntry<String, String>> _loadPackManifest(Directory tier) {
    try {
      final file = File('${tier.path}/manifest.json');
      if (!file.existsSync()) return const [];
      return _parse(file.readAsStringSync());
    } catch (e) {
      if (kDebugMode) debugPrint('[audio] битый манифест пака ${tier.path}');
      return const [];
    }
  }

  static List<MapEntry<String, String>> _parse(String raw) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final files = json['files'] as Map<String, Object?>? ?? const {};
    return [
      for (final entry in files.entries)
        MapEntry(
          entry.key,
          (entry.value! as Map<String, Object?>)['file']! as String,
        ),
    ];
  }
}
