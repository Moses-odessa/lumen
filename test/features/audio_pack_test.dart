import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lumen/core/audio/audio_manifest.dart';
import 'package:lumen/core/audio/audio_pack_manager.dart';

/// Докачка проверяется на настоящем архиве и настоящем хеше: её ошибки
/// стоят игроку трафика и выглядят как «звук пропал», а не как исключение.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;

  /// Собирает настоящий zip-пак с манифестом внутри.
  ({List<int> bytes, String digest}) buildPack() {
    final archive = Archive();
    final audio = utf8.encode('RIFF-fake-wav-data-for-tests');
    archive.addFile(ArchiveFile('arzt.wav', audio.length, audio));

    final manifest = utf8.encode(jsonEncode({
      'version': 1,
      'files': {
        'de/arzt': {'file': 'arzt.wav', 'bytes': audio.length, 'signature': 'x'},
      },
    }));
    archive.addFile(
      ArchiveFile('manifest.json', manifest.length, manifest),
    );

    final bytes = ZipEncoder().encode(archive);
    return (bytes: bytes, digest: sha256.convert(bytes).toString());
  }

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_packs');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? support.path
          : null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    support.deleteSync(recursive: true);
  });

  group('без настроенного CDN', () {
    test('докачки просто нет, и это не ошибка', () async {
      final manager = AudioPackManager(baseUrl: '');
      expect(manager.isConfigured, isFalse);
      expect(await manager.available('de'), isEmpty);
    });
  });

  group('установка пака', () {
    test('скачивает, проверяет хеш и распаковывает', () async {
      final pack = buildPack();
      final manager = AudioPackManager(
        baseUrl: 'https://cdn.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('packs.json')) {
            return http.Response(
              jsonEncode({
                'version': 1,
                'lang': 'de',
                'packs': [
                  {
                    'tier': 'a1',
                    'file': 'a1.zip',
                    'bytes': pack.bytes.length,
                    'sha256': pack.digest,
                    'items': 1,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response.bytes(pack.bytes, 200);
        }),
      );

      final packs = await manager.available('de');
      expect(packs, hasLength(1));
      expect(packs.single.tier, 'a1');

      final progress = <int>[];
      final ok = await manager.install(
        packs.single,
        onProgress: (received, _) => progress.add(received),
      );

      expect(ok, isTrue);
      expect(progress, isNotEmpty, reason: 'прогресс должен сообщаться');
      expect(await manager.isInstalled(packs.single), isTrue);
      expect(await manager.installedTiers('de'), contains('a1'));
      expect(await manager.installedBytes('de'), greaterThan(0));

      final dir = await manager.packsDirectory('de');
      expect(File('${dir.path}/a1/arzt.wav').existsSync(), isTrue);
      expect(File('${dir.path}/a1/manifest.json').existsSync(), isTrue);
      // Частичный файл после успеха не остаётся.
      expect(File('${dir.path}/a1.part').existsSync(), isFalse);
    });

    test('испорченный пак полного размера удаляется целиком', () async {
      // Важно именно полного размера: короткий ответ неотличим от обрыва
      // связи, и его надо сохранять для возобновления, а не выбрасывать.
      final pack = buildPack();
      final corrupted = List<int>.from(pack.bytes)
        ..setRange(0, 8, List.filled(8, 0));

      final manager = AudioPackManager(
        baseUrl: 'https://cdn.test',
        client: MockClient(
          (request) async => http.Response.bytes(corrupted, 200),
        ),
      );

      final ok = await manager.install(
        AudioPack(
          lang: 'de',
          tier: 'a1',
          file: 'a1.zip',
          bytes: pack.bytes.length,
          // Хеш от настоящего пака — присланное ему не соответствует.
          sha256: pack.digest,
          items: 1,
        ),
      );

      expect(ok, isFalse);
      final dir = await manager.packsDirectory('de');
      expect(Directory('${dir.path}/a1').existsSync(), isFalse);
      expect(File('${dir.path}/a1.part').existsSync(), isFalse,
          reason: 'иначе докачка вечно «возобновляла» бы мусор');
    });

    test('обрыв связи не стоит трафика заново', () async {
      // Критерий приёмки M8: обрыв в середине загрузки восстанавливается
      // без потери скачанного.
      final pack = buildPack();
      final half = pack.bytes.length ~/ 2;
      var attempt = 0;
      final ranges = <String?>[];

      final manager = AudioPackManager(
        baseUrl: 'https://cdn.test',
        client: MockClient((request) async {
          ranges.add(request.headers['Range']);
          attempt++;
          if (attempt == 1) {
            // Первая попытка обрывается на половине.
            return http.Response.bytes(pack.bytes.sublist(0, half), 200);
          }
          final from = _rangeStart(request.headers['Range']);
          return http.Response.bytes(pack.bytes.sublist(from), 206);
        }),
      );

      final descriptor = AudioPack(
        lang: 'de',
        tier: 'a1',
        file: 'a1.zip',
        bytes: pack.bytes.length,
        sha256: pack.digest,
        items: 1,
      );

      // Первая попытка обрывается на половине.
      final first = await manager.install(descriptor);
      expect(first, isFalse);

      // Скачанная половина СОХРАНЕНА: удалить её значит заставить игрока
      // платить за те же мегабайты второй раз.
      final dir = await manager.packsDirectory('de');
      final partial = File('${dir.path}/a1.part');
      expect(partial.existsSync(), isTrue);
      expect(partial.lengthSync(), half);

      // Вторая попытка продолжает с того же места, а не начинает заново.
      final second = await manager.install(descriptor);
      expect(second, isTrue);
      expect(await manager.isInstalled(descriptor), isTrue);

      expect(ranges.first, isNull, reason: 'первый запрос — с начала');
      expect(ranges.last, 'bytes=$half-',
          reason: 'второй запрос обязан быть Range с точки обрыва');
    });

    test('удаление освобождает место', () async {
      final pack = buildPack();
      final manager = AudioPackManager(
        baseUrl: 'https://cdn.test',
        client: MockClient((_) async => http.Response.bytes(pack.bytes, 200)),
      );

      final descriptor = AudioPack(
        lang: 'de',
        tier: 'a1',
        file: 'a1.zip',
        bytes: pack.bytes.length,
        sha256: pack.digest,
        items: 1,
      );

      await manager.install(descriptor);
      expect(await manager.installedBytes('de'), greaterThan(0));

      await manager.remove(descriptor);
      expect(await manager.isInstalled(descriptor), isFalse);
      expect(await manager.installedBytes('de'), 0);
    });
  });

  group('манифест', () {
    test('скачанный пак перекрывает ассеты', () async {
      final manager = AudioPackManager(
        baseUrl: 'https://cdn.test',
        client: MockClient((_) async => http.Response('', 404)),
      );
      final dir = await manager.packsDirectory('de');

      // Кладём пак руками, как будто он уже установлен.
      final tier = Directory('${dir.path}/a1')..createSync(recursive: true);
      File('${tier.path}/arzt.wav').writeAsStringSync('audio');
      File('${tier.path}/manifest.json').writeAsStringSync(jsonEncode({
        'version': 1,
        'files': {
          'de/arzt': {'file': 'arzt.wav'},
        },
      }));

      final manifest = await AudioManifest.load('de', packsDirectory: dir);

      final location = manifest.locate('de/arzt');
      expect(location, isNotNull);
      expect(location!.source, AudioSource.pack,
          reason: 'докачанное должно побеждать ассет');
      expect(location.isAsset, isFalse);
      expect(manifest.fromPacks, 1);
    });

    test('ассеты остаются доступны без единого пака', () async {
      // Свежая установка играбельна сразу — критерий приёмки M8.
      final manifest = await AudioManifest.load('de');
      expect(manifest.isEmpty, isFalse);
      expect(manifest.locate('de/arzt')?.source, AudioSource.asset);
      expect(manifest.fromPacks, 0);
    });

    test('битый манифест пака не ломает остальное', () async {
      final manager = AudioPackManager(baseUrl: '');
      final dir = await manager.packsDirectory('de');
      final tier = Directory('${dir.path}/a1')..createSync(recursive: true);
      File('${tier.path}/manifest.json').writeAsStringSync('{ не json');

      final manifest = await AudioManifest.load('de', packsDirectory: dir);
      // Ассеты на месте, битый пак просто проигнорирован.
      expect(manifest.locate('de/arzt')?.source, AudioSource.asset);
    });
  });
}

int _rangeStart(String? header) {
  if (header == null) return 0;
  final match = RegExp(r'bytes=(\d+)-').firstMatch(header);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Минимальный тестовый клиент: `package:http` предоставляет свой в
/// `http/testing.dart`, но он тянет лишнюю зависимость на MockClient из
/// другого пакета — здесь достаточно нескольких строк.
class MockClient extends http.BaseClient {
  MockClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
    );
  }
}
