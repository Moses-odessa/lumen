import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Критерий приёмки M0: обе базы открываются. Проверяется на настоящем
/// ассете `assets/content/de.db` и на настоящей Drift-схеме `user.db`, а не
/// на моках — иначе проверка ничего не значит.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('user.db', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('схема создаётся и игрок переживает запись-чтение', () async {
      // Версия растёт вместе с миграциями: v2 добавила затмения и
      // напоминания (M5), v3 убрала таблицу ночного вызова вместе с самой
      // фичей.
      expect(db.schemaVersion, 3);
      expect(await db.loadPlayer(), isNull);

      await db.savePlayer(Player(
        targetLang: 'de',
        nativeLang: 'uk',
        uiLang: 'en',
        tier: Tier.b1,
        calibrated: true,
        orbit: 4,
        sparks: 120,
        soundEnabled: false,
        notificationsEnabled: true,
        preferredHour: 21,
        eclipseUntil: DateTime.utc(2026, 6, 1),
      ));

      final loaded = await db.loadPlayer();
      expect(loaded, isNotNull);
      expect(loaded!.targetLang, 'de');
      expect(loaded.nativeLang, 'uk');
      // Язык интерфейса — отдельная настройка от родного языка.
      expect(loaded.uiLang, 'en');
      expect(loaded.tier, Tier.b1);
      expect(loaded.calibrated, isTrue);
      expect(loaded.orbit, 4);
      expect(loaded.sparks, 120);
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.notificationsEnabled, isTrue);
      expect(loaded.preferredHour, 21);
      // Drift хранит дату как unix-секунды и отдаёт её в локальной зоне:
      // момент тот же, флаг UTC — нет. Сравнивать надо моменты.
      expect(
        loaded.eclipseUntil!.isAtSameMomentAs(DateTime.utc(2026, 6, 1)),
        isTrue,
      );
    });

    test('игрок — всегда одна строка', () async {
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'ru', tier: Tier.a0),
      );
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'en', tier: Tier.a2),
      );

      final rows = await db.select(db.players).get();
      expect(rows.length, 1);
      expect(rows.single.nativeLang, 'en');
    });

    test('wipe удаляет данные полностью', () async {
      await db.savePlayer(
        const Player(targetLang: 'de', nativeLang: 'ru', tier: Tier.a0),
      );
      await db.wipe();
      expect(await db.loadPlayer(), isNull);
    });
  });

  group('content.db', () {
    late Directory support;

    setUp(() {
      support = Directory.systemTemp.createTempSync('lumen_support');
      // path_provider — плагин, в тестах его канал надо подменить.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async =>
            call.method == 'getApplicationSupportDirectory'
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

    test('ассет копируется в support-директорию и открывается', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final meta = await db.loadMeta();
      expect(meta['lang'], 'de');
      expect(meta['schema_version'], '${db.schemaVersion}');
      // Метки времени в метаданных нет намеренно: сборка воспроизводима.
      expect(meta.containsKey('built_at'), isFalse);
      expect(meta['source_hash'], isNotEmpty);
      // Запущен только вычитанный ярус: играть по черновому контенту нельзя.
      expect(await db.launchedTiers(), {Tier.a0});

      // Созвездие «У врача» написано целиком на всех пяти ярусах: размеры
      // накопительные, 12 / 24 / 48 / 72 / 96 (docs/CONCEPT.md).
      expect(await db.countConcepts(),
          ProgressionBalance.starsPerConstellation(Tier.b2));
      for (final tier in Tier.values) {
        expect(
          (await db.conceptsFor('doctor', tier)).length,
          ProgressionBalance.starsPerConstellation(tier),
          reason: 'ярус ${tier.label}',
        );
      }

      // Файл действительно лёг в support-директорию.
      expect(File('${support.path}/content/de.db').existsSync(), isTrue);
    });

    test('лексемы и дистракторы читаются на всех языках проекта', () async {
      final db = ContentDatabase.forLanguage('de');
      addTearDown(db.close);

      final de = await db.lexeme('doctor_person', 'de');
      expect(de?.form, 'Arzt');
      expect(de?.article, 'der');
      // Озвучка нужна только языку изучения.
      expect(de?.audioId, 'de/arzt');

      for (final lang in ['ru', 'uk', 'en']) {
        final lexeme = await db.lexeme('doctor_person', lang);
        expect(lexeme, isNotNull, reason: 'нет лексемы на $lang');
        expect(lexeme!.audioId, isNull, reason: 'подсказки не озвучиваются');
      }

      // Круг собирается из дистракторов контента, а не случайных слов.
      final far = await db.distractorsFor('doctor_person', 'de', 'far');
      final near = await db.distractorsFor('doctor_person', 'de', 'near');
      expect(far.length, greaterThanOrEqualTo(2));
      expect(near.length, greaterThanOrEqualTo(3));
    });

    test('повторное открытие не перезаписывает файл', () async {
      final first = ContentDatabase.forLanguage('de');
      await first.countConcepts();
      await first.close();

      final file = File('${support.path}/content/de.db');
      final stamp = file.lastModifiedSync();

      final second = ContentDatabase.forLanguage('de');
      addTearDown(second.close);
      expect(await second.countConcepts(), greaterThan(0));
      expect(file.lastModifiedSync(), stamp);
    });
  });
}
