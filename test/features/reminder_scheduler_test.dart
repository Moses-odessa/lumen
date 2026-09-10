import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/core/l10n/interface_lang.dart';
import 'package:lumen/data/content/constellation_naming.dart';
import 'package:lumen/data/content/content_provider.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/data/repositories/player_repository.dart';
import 'package:lumen/data/repositories/word_state_repository.dart';
import 'package:lumen/domain/entities/player.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/settings/application/reminder_scheduler.dart';

/// Что уезжает в текст пуш-напоминания: имя темы, её slug — и на каком языке
/// сказано всё остальное.
///
/// Формулировки проверяет `reminder_text_test.dart` — там `ReminderText`
/// вызывается напрямую с готовой строкой, и на слаг `doctor` в подставленном
/// аргументе он согласится с той же охотой, что на «Врач». Ровно поэтому
/// игрок и получал на телефон «В созвездии «place_time_price»»: чистая
/// функция была права, а собирал ей аргумент планировщик. Здесь проверяется
/// он — на настоящем ассете `de.db` и настоящей схеме `user.db`, потому что
/// путь от базы до текста весь состоит из их стыка.
///
/// Язык проверяется здесь же и по той же причине: имя темы собирается по
/// языку интерфейса, а фраза вокруг него собиралась русскими литералами в
/// коде — то есть игрок с украинским интерфейсом получал правильно
/// переведённое имя в русской обёртке. Один экран не покажет этого никогда:
/// обе половины текста видны только вместе, и только здесь они сходятся.
/// Ожидания записаны ключами `AppLocalizations`, а не строками: прежний
/// `expect(text.title, 'Небо в порядке')` был зелёным ровно тогда, когда
/// напоминание врало, — литерал в тесте цементирует язык.
///
/// Уведомление не ставится: `NotificationService` — синглтон с приватным
/// конструктором, подменить его нечем, а в тестовой среде плагин не
/// инициализируется, и `scheduleDaily` молча ничего не делает. Наблюдаемый
/// результат планировщика один — текст, и он спрашивается напрямую.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase db;

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_reminder');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? support.path
          : null,
    );
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Игрок учит немецкий с украинскими подсказками; язык интерфейса — аргумент.
  ///
  /// `naming` подменяет собранное именование: единственный способ показать,
  /// чего стоит отказ базы имён, — таблицы имён нет в ассете предыдущей
  /// сборки, а такой ассет в тест не положить.
  ProviderContainer containerFor({
    required String? uiLang,
    ConstellationNaming? naming,
  }) {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (naming != null)
        constellationNamingProvider.overrideWith((ref) async => naming),
    ]);
    addTearDown(container.dispose);
    container.read(playerControllerProvider.notifier).replace(
          Player(
            targetLang: 'de',
            nativeLang: 'uk',
            uiLang: uiLang,
            tier: Tier.a0,
            calibrated: true,
            notificationsEnabled: true,
          ),
        );
    return container;
  }

  /// Тускнеющие звёзды одной темы: сколько их и в каком созвездии.
  ///
  /// Тема выбирается из ассета, а не вписывается: состав ярусов меняется
  /// файлами контента, и константа здесь устарела бы молча. Засев уводится
  /// на два месяца назад, потому что тускнеет только то, чего давно не
  /// касались: свежие 55 lm — это полоса «узнаёте», и напоминание про них
  /// говорить не станет.
  Future<({String slug, int stars})> seedDimming(
    ProviderContainer container,
  ) async {
    final phrases = await container
        .read(currentContentDatabaseProvider)
        .phrasesUpTo(Tier.a0);
    final slug = phrases.first.constellation;
    final ids = [
      for (final p in phrases)
        if (p.constellation == slug) p.id,
    ];
    expect(ids, isNotEmpty);

    // Засеяна ровно одна тема: тогда «где тускнеет больше всего» — это она,
    // и тест проверяет перевод идентичности в имя, а не выбор максимума.
    await WordStateRepository(db).seed(
      confirmed: {for (final id in ids) id: Tier.a0},
      lumens: 55,
      now: DateTime.now().subtract(const Duration(days: 60)),
    );
    return (slug: slug, stars: ids.length);
  }

  /// Строки локали — тем же способом, которым их берёт планировщик:
  /// `load` принимает локаль аргументом и дерева виджетов не требует.
  Future<AppLocalizations> l10nFor(String lang) =>
      AppLocalizations.delegate.load(Locale(lang));

  /// Имя темы на одном языке — из ассета: имена правятся файлами контента.
  Future<String> nameOf(
    ProviderContainer container,
    String lang,
    String slug,
  ) async {
    final names = await container
        .read(currentContentDatabaseProvider)
        .constellationNamesFor(lang);
    expect(names[slug], isNotNull, reason: 'у темы $slug нет имени на $lang');
    return names[slug]!;
  }

  test('в напоминание уезжает имя темы, а не slug', () async {
    final container = containerFor(uiLang: 'de');
    final dimming = await seedDimming(container);
    final german = await nameOf(container, 'de', dimming.slug);

    final text =
        await container.read(reminderSchedulerProvider).composeText(Tier.a0);

    final l10n = await l10nFor('de');
    expect(text.title, l10n.reminderDimmingTitle(dimming.stars),
        reason: 'ветка тускнеющих звёзд не сработала — проверять нечего');
    // Целиком, а не `contains(german)`: имя стоит внутри немецкой фразы, и
    // проверять только имя значило бы разрешить русскую обёртку вокруг него.
    expect(text.body, l10n.reminderDimmingIn(german));
    expect(text.body.contains(dimming.slug), isFalse,
        reason: 'slug — идентичность темы, а не то, что читает игрок');
  });

  test('интерфейс без имён откатывается на язык подсказок', () async {
    // Так живёт француз: интерфейсов шесть, а имён пять языков —
    // французского контента нет вовсе. Полное правило (интерфейс → подсказки
    // → slug) планировщику доступно целиком, с первого звена: язык интерфейса
    // решает провайдер, а не `Localizations.localeOf`, и дерево виджетов ему
    // не нужно. Если бы откат здесь начинался со второго звена, эта проверка
    // прошла бы и на сломанном первом — поэтому ниже проверяется ещё и
    // немецкий случай, а язык изучения исключён явно.
    final container = containerFor(uiLang: 'fr');
    final dimming = await seedDimming(container);
    final ukrainian = await nameOf(container, 'uk', dimming.slug);
    final german = await nameOf(container, 'de', dimming.slug);

    final text =
        await container.read(reminderSchedulerProvider).composeText(Tier.a0);

    // Обёртка французская, имя украинское — и это не поломка, а ровно то,
    // чем игра устроена: интерфейсов шесть, а контента пять языков. Проверка
    // записана целой строкой, чтобы разъехаться эти две половины больше не
    // могли молча: раньше обёртка была русской при любом интерфейсе.
    expect(text.body, (await l10nFor('fr')).reminderDimmingIn(ukrainian));
    expect(text.body.contains(german), isFalse,
        reason: 'язык изучения — не язык подсказок и не язык интерфейса');

    final naming = await container.read(constellationNamingProvider.future);
    expect(naming.interfaceNames, isEmpty,
        reason: 'французских имён в базе нет — иначе тест проверяет не откат');
  });

  test('отказ базы имён не отменяет напоминание', () async {
    // Ассет предыдущей сборки, в котором таблицы имён нет: провайдер отдаёт
    // пустое именование, и третье звено отката — slug — снова оказывается в
    // тексте. Это и есть цена отказа: прежняя некрасивая строка, а не
    // пропавшее уведомление, ради которого игрок включал напоминания.
    final container = containerFor(
      uiLang: 'de',
      naming: const ConstellationNaming.slugsOnly(),
    );
    final dimming = await seedDimming(container);

    final text =
        await container.read(reminderSchedulerProvider).composeText(Tier.a0);

    expect(text.title,
        (await l10nFor('de')).reminderDimmingTitle(dimming.stars));
    expect(text.body, contains(dimming.slug));
  });

  test('без тускнеющих звёзд имена не спрашиваются вовсе', () async {
    // Небо в порядке: называть нечего, и про созвездие текст не говорит.
    // Именование в этой ветке не запрашивается — здесь оно подменено future,
    // который не завершается никогда: спроси планировщик имена до того, как
    // узнал, есть ли что называть, тест повис бы, а не покраснел.
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      constellationNamingProvider
          .overrideWith((ref) => Completer<ConstellationNaming>().future),
    ]);
    addTearDown(container.dispose);
    container.read(playerControllerProvider.notifier).replace(
          const Player(
            targetLang: 'de',
            nativeLang: 'uk',
            uiLang: 'de',
            tier: Tier.a0,
            calibrated: true,
            notificationsEnabled: true,
          ),
        );

    final text =
        await container.read(reminderSchedulerProvider).composeText(Tier.a0);

    expect(text.title, (await l10nFor('de')).reminderCalmTitle,
        reason: 'ветка спокойного неба — и на языке интерфейса игрока');
  });
}
