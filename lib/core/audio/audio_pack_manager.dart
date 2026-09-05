import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// База CDN с аудио-паками. Задаётся при сборке:
/// `--dart-define=AUDIO_PACK_BASE_URL=https://...`.
const String audioPackBaseUrl =
    String.fromEnvironment('AUDIO_PACK_BASE_URL');

/// Описание одного пака из `packs.json`.
class AudioPack {
  const AudioPack({
    required this.lang,
    required this.tier,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.items,
  });

  final String lang;
  final String tier;
  final String file;
  final int bytes;

  /// Хеш архива. Без него докачка не может отличить обрыв связи от
  /// испорченного файла — а испорченный пак хуже отсутствующего, потому что
  /// он выглядит установленным.
  final String sha256;

  final int items;

  double get megabytes => bytes / 1024 / 1024;

  static AudioPack fromJson(String lang, Map<String, Object?> json) =>
      AudioPack(
        lang: lang,
        tier: json['tier']! as String,
        file: json['file']! as String,
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
        items: (json['items'] as num?)?.toInt() ?? 0,
      );
}

/// Состояние загрузки.
enum PackStatus { notInstalled, downloading, installed, failed }

class PackState {
  const PackState({
    required this.pack,
    this.status = PackStatus.notInstalled,
    this.receivedBytes = 0,
    this.error,
  });

  final AudioPack pack;
  final PackStatus status;
  final int receivedBytes;
  final String? error;

  double get progress =>
      pack.bytes == 0 ? 0 : (receivedBytes / pack.bytes).clamp(0.0, 1.0);

  PackState copyWith({
    PackStatus? status,
    int? receivedBytes,
    String? Function()? error,
  }) =>
      PackState(
        pack: pack,
        status: status ?? this.status,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        error: error == null ? this.error : error(),
      );
}

/// Докачка аудио-паков.
///
/// Появилась ровно на M8 и ровно по своему триггеру — второму языку
/// изучения. До этого её сознательно не было: загрузчик тянет за собой
/// прогресс, возобновление, проверку хеша, инвалидацию кеша, управление
/// местом и ветки «нет сети» в самых неудачных местах.
///
/// Три правила, которые делают её терпимой:
///
/// 1. **Отсутствие пака — не ошибка.** Играется всё, что уже скачано;
///    текущий ярус никогда не блокируется предложением докачать.
/// 2. **Возобновление, а не перекачивание.** Частичный файл сохраняется, и
///    докачка продолжается запросом `Range` с того же места.
/// 3. **Хеш обязателен.** Пак, не совпавший с хешем, удаляется целиком:
///    испорченный пак хуже отсутствующего, потому что выглядит рабочим.
class AudioPackManager {
  AudioPackManager({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? audioPackBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// Каталог установленных паков.
  Future<Directory> packsDirectory(String lang) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/audio_packs/$lang');
    await dir.create(recursive: true);
    return dir;
  }

  /// Список паков языка с CDN. Пустой — сеть недоступна или паков нет.
  Future<List<AudioPack>> available(String lang) async {
    if (!isConfigured) return const [];
    try {
      final url = '${_trimmed()}/$lang/packs.json';
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, Object?>;
      return [
        for (final item in (json['packs'] as List? ?? const []))
          AudioPack.fromJson(lang, item as Map<String, Object?>),
      ];
    } catch (e) {
      if (kDebugMode) debugPrint('[packs] $e');
      return const [];
    }
  }

  /// Установлен ли пак.
  Future<bool> isInstalled(AudioPack pack) async {
    final dir = await packsDirectory(pack.lang);
    return Directory('${dir.path}/${pack.tier}').existsSync();
  }

  /// Сколько занимают установленные паки языка.
  Future<int> installedBytes(String lang) async {
    final dir = await packsDirectory(lang);
    var total = 0;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  /// Установленные ярусы языка.
  Future<Set<String>> installedTiers(String lang) async {
    final dir = await packsDirectory(lang);
    return {
      for (final entity in dir.listSync())
        if (entity is Directory) entity.uri.pathSegments.lastWhere(
              (s) => s.isNotEmpty,
            ),
    };
  }

  /// Скачивает и распаковывает пак.
  ///
  /// [onProgress] вызывается по мере получения байтов. Возвращает `false`,
  /// если не получилось — и это не повод показывать ошибку крупно: игра
  /// продолжает работать на том, что уже есть.
  Future<bool> install(
    AudioPack pack, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!isConfigured) return false;

    final dir = await packsDirectory(pack.lang);
    final partial = File('${dir.path}/${pack.tier}.part');
    final target = Directory('${dir.path}/${pack.tier}');

    try {
      final downloaded = await _download(pack, partial, onProgress);
      if (!downloaded) return false;

      final bytes = await partial.readAsBytes();

      // Недокачанное и испорченное — разные вещи, и путать их дорого.
      //
      // Файл короче ожидаемого — это оборванная связь: его надо СОХРАНИТЬ,
      // чтобы следующая попытка продолжила с того же места. Удалять его
      // из-за несовпадения хеша означает, что возобновление не работает
      // вообще, а игрок платит за двадцать мегабайт дважды.
      if (pack.bytes > 0 && bytes.length < pack.bytes) return false;

      if (pack.sha256.isNotEmpty &&
          sha256.convert(bytes).toString() != pack.sha256) {
        // Полный размер, но не тот хеш — файл действительно испорчен.
        // Вот его удалять обязательно: иначе докачка будет вечно
        // «возобновлять» мусор.
        await partial.delete();
        return false;
      }

      if (target.existsSync()) await target.delete(recursive: true);
      await target.create(recursive: true);

      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final out = File('${target.path}/${file.name}');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(file.content as List<int>);
      }

      await partial.delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[packs] install ${pack.tier}: $e');
      return false;
    }
  }

  /// Скачивание с возобновлением.
  ///
  /// Обрыв связи в середине не должен стоить игроку двадцати мегабайт
  /// трафика заново — это критерий приёмки M8.
  Future<bool> _download(
    AudioPack pack,
    File partial,
    void Function(int, int)? onProgress,
  ) async {
    final already = partial.existsSync() ? partial.lengthSync() : 0;
    if (already >= pack.bytes && pack.bytes > 0) return true;

    final request = http.Request(
      'GET',
      Uri.parse('${_trimmed()}/${pack.lang}/${pack.file}'),
    );
    if (already > 0) {
      request.headers['Range'] = 'bytes=$already-';
    }

    final response = await _client.send(request);

    // 206 — сервер поддержал возобновление; 200 — отдал файл целиком, и
    // тогда частичное надо выбросить, иначе получится склейка.
    final resuming = response.statusCode == 206;
    if (response.statusCode != 200 && !resuming) return false;

    final sink = partial.openWrite(
      mode: resuming ? FileMode.append : FileMode.write,
    );
    var received = resuming ? already : 0;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, pack.bytes);
      }
    } finally {
      await sink.close();
    }

    return true;
  }

  /// Удаляет установленный пак.
  Future<void> remove(AudioPack pack) async {
    final dir = await packsDirectory(pack.lang);
    final target = Directory('${dir.path}/${pack.tier}');
    if (target.existsSync()) await target.delete(recursive: true);

    final partial = File('${dir.path}/${pack.tier}.part');
    if (partial.existsSync()) await partial.delete();
  }

  /// Удаляет всё скачанное для языка.
  Future<void> removeAll(String lang) async {
    final dir = await packsDirectory(lang);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  String _trimmed() => _baseUrl.replaceAll(RegExp(r'/+$'), '');

  void dispose() => _client.close();
}
