import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/audio/audio_manifest.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/domain/entities/tier.dart';

/// Озвучка на запущенных ярусах — против настоящих ассетов.
///
/// Этот файл появился после живого бага: игра выдавала слова ярусов выше
/// запущенного, у которых нет файлов озвучки, и для игрока это выглядело
/// как «сработал только первый звук, дальше тишина». Валидатор контента
/// такое не ловит: с его точки зрения всё в порядке — невычитанные ярусы
/// озвучивать и не положено. Ловится это только сверкой того, что игра
/// показывает, с тем, что она умеет проиграть.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_audio_cov');
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

  for (final lang in ['de', 'en']) {
    group('озвучка $lang', () {
      test('каждое слово запущенных ярусов имеет файл', () async {
        final content = ContentDatabase.forLanguage(lang);
        addTearDown(content.close);

        final launched = await content.launchedTiers();
        expect(launched, isNotEmpty, reason: 'без запущенных ярусов играть не во что');

        final ceiling =
            launched.reduce((a, b) => a.index >= b.index ? a : b);
        final manifest = await AudioManifest.load(lang);
        expect(manifest.isEmpty, isFalse, reason: 'манифест озвучки не прочитался');

        final silent = <String>[];
        for (final concept in await content.conceptsUpTo(ceiling)) {
          final lexeme = await content.lexeme(concept.id, lang);
          final audioId = lexeme?.audioId;
          if (audioId == null || audioId.isEmpty) {
            silent.add('${concept.id} (нет лексемы)');
          } else if (!manifest.has(audioId)) {
            silent.add(audioId);
          }
        }

        expect(
          silent,
          isEmpty,
          reason: 'на ярусах до ${ceiling.label} нет озвучки для: '
              '${silent.take(10).join(', ')}',
        );
      });

      test('выше потолка озвучки нет — потому и нельзя туда пускать', () async {
        // Обратная сторона того же факта, зафиксированная намеренно: если
        // однажды озвучат все ярусы, этот тест упадёт и напомнит пересмотреть
        // ограничение, а не оставит его навсегда.
        final content = ContentDatabase.forLanguage(lang);
        addTearDown(content.close);

        final launched = await content.launchedTiers();
        final ceiling =
            launched.reduce((a, b) => a.index >= b.index ? a : b);
        final above = ceiling.up;
        if (above == null) return;

        final manifest = await AudioManifest.load(lang);
        final onlyAbove = (await content.conceptsUpTo(above))
            .where((c) => c.tier == above.code);
        expect(onlyAbove, isNotEmpty, reason: 'ярус $above пуст, проверять нечего');

        var voiced = 0;
        for (final concept in onlyAbove) {
          final audioId = (await content.lexeme(concept.id, lang))?.audioId;
          if (audioId != null && manifest.has(audioId)) voiced++;
        }
        expect(voiced, 0,
            reason: 'ярус ${above.label} озвучен — пора поднимать потолок '
                'в content/launch.yaml');
      });
    });
  }

  group('потолок яруса', () {
    test('ярус выше потолка урезается', () {
      expect(Tier.b2.atMost(Tier.a0), Tier.a0);
      expect(Tier.b1.atMost(Tier.a1), Tier.a1);
    });

    test('ярус не выше потолка остаётся собой', () {
      expect(Tier.a0.atMost(Tier.b2), Tier.a0);
      expect(Tier.a1.atMost(Tier.a1), Tier.a1);
    });
  });
}
