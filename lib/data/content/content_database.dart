import 'package:drift/drift.dart';

import '../../domain/entities/tier.dart';
import 'content_executor.dart';

part 'content_database.g.dart';

/// Языки базы: код, роль, готовность, самоназвание и покрытие.
///
/// Язык объявляет о себе сам — списка языков в коде нет. Покрытие
/// **считается** при сборке, а не объявляется в файле: объявленное число
/// разошлось бы с содержимым при первой же правке.
@DataClassName('LanguageRow')
class Languages extends Table {
  TextColumn get code => text()();

  /// `native` — на нём подсказки, `target` — его учат, `both` — и то и то.
  TextColumn get role => text()();

  /// `draft` или `launched`. Черновой язык лежит в репозитории, но игроку
  /// не предлагается.
  TextColumn get status => text()();

  /// Самоназвание: «Українська», «Deutsch». На языке самого языка.
  TextColumn get name => text()();

  /// Сколько фраз язык покрывает.
  IntColumn get phrases => integer()();

  @override
  Set<Column> get primaryKey => {code};
}

/// Фраза — единица изучения.
///
/// Разговорник: игрок заучивает фразу целиком, а не слово. Поэтому у фразы
/// нет ни пропусков, ни разбора на слова — есть готовый к показу [text],
/// ярус, созвездие и перевод в [PhraseTranslations].
@DataClassName('PhraseRow')
class Phrases extends Table {
  TextColumn get id => text()();

  /// Язык изучения, на котором написана фраза.
  TextColumn get lang => text()();

  TextColumn get tier => text()();
  TextColumn get constellation => text()();

  /// Порядок внутри созвездия и яруса, как в файле контента.
  ///
  /// Прежнюю последовательность знакомства задавала частотность слова, а у
  /// фразы частотности нет: порядок решает автор, и он же решает, с чего
  /// начинается тема.
  IntColumn get idx => integer()();

  /// Готовая к показу фраза.
  ///
  /// Геттер называется не `text`, и это не вкус: `text()` — билдер колонки в
  /// Drift, и `TextColumn get text => text()()` рекурсивно возвращает сам
  /// себя. Имя колонки в SQL при этом остаётся `text`.
  TextColumn get sentence => text().named('text')();

  /// Вид фразы: `phrase`, `example` или `idiom`. Закрытый набор кодов, как у
  /// [register].
  ///
  /// Зачем он в схеме, если ни одна из трёх механик его не спрашивает.
  /// У идиомы перевод **смысловой**: «Ich habe gerade viel um die Ohren» —
  /// это «у мене зараз багато справ», ни одного общего слова. Проверка
  /// буквальности перевода — а вычитка просит именно её — обязана идиомы
  /// пропускать, и пометка единственный способ их узнать: по тексту идиома от
  /// фразы не отличается ничем. Пример — законченный образец речевой модели,
  /// занявший место прежнего шаблона с многоточием: «Ich heiße Alex.» вместо
  /// «Ich heiße ...».
  ///
  /// В отличие от соседнего [register] колонка не `nullable`, и разница не в
  /// аккуратности: регистр у фразы либо есть, либо нет — 1315 строк корпуса
  /// не несут пометки вовсе, и NULL там правдив, — а чем-то фраза является
  /// всегда. NULL
  /// пришлось бы читать «неизвестно чем», то есть третьим ответом на вопрос
  /// «это идиома?», которого в закрытом наборе нет. Умолчание при этом
  /// существует, но живёт на входе, а не в базе: `kind:` можно не писать в
  /// файле фразы (`defaultPhraseKind` в `tool/content_schema.dart`), а в базу
  /// уезжает явный код у каждой строки — поэтому `DEFAULT` у колонки нет.
  ///
  /// Коллизии имён, как у [sentence], здесь нет: билдера колонки `kind` в
  /// Drift не существует, а [CalibrationItems.kind] в этом же файле живёт с
  /// первых версий схемы. Проверено генерацией, а не рассуждением.
  TextColumn get kind => text()();

  /// Регистр: `casual` или `formal`. Код, а не текст — строку даёт
  /// локализация на языке интерфейса.
  TextColumn get register => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Перевод фразы на родной язык. Живёт в языковом файле, а не рядом с
/// фразой: язык добавляется одним файлом.
@DataClassName('PhraseTranslationRow')
class PhraseTranslations extends Table {
  TextColumn get phraseId => text()();
  TextColumn get lang => text()();

  /// Имя колонки в SQL — `text`; геттер другой, потому что `text()` в Drift
  /// это билдер колонки.
  TextColumn get sentence => text().named('text')();

  @override
  Set<Column> get primaryKey => {phraseId, lang};
}

/// Отобранные фразы для калибровки: по кругу через созвездия, по несколько
/// на ярус.
@DataClassName('CalibrationItemRow')
class CalibrationItems extends Table {
  TextColumn get id => text()();
  TextColumn get tier => text()();
  TextColumn get phraseId => text()();

  /// Вид шага теста — гребёнка, поиск, подтверждение.
  TextColumn get kind => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Имя созвездия на одном языке.
///
/// Имя темы — **контент**, а не строка интерфейса, и это решение, а не
/// удобство: тема приходит вместе с фразами и обязана добавляться тем же
/// одним файлом. В ARB ей вдобавок нет места технически — `gen-l10n` не умеет
/// достать строку по вычисляемому ключу, и пятьдесят тем превратились бы в
/// `switch` на пятьдесят ветвей, который забудут дополнить на пятьдесят
/// первой.
///
/// Один ряд — одно имя на одном языке; язык изучения (`de`) лежит здесь
/// наравне с языками подсказок. У изучаемого языка нет «перевода» имени, у
/// него есть текст — ровно так же, как с самой фразой.
@DataClassName('ConstellationNameRow')
class ConstellationNames extends Table {
  /// Slug созвездия — тот же, что в [Phrases.constellation]. Связь по слагу,
  /// а не по числовому id: созвездие не отдельная сущность контента, а поле
  /// в шапке файла фразы.
  TextColumn get constellation => text()();

  /// Код языка: `de` (язык изучения) либо язык подсказок — `uk`, `ru`, `en`,
  /// `it`. Языков интерфейса шесть, а имён пять: французского контента нет,
  /// и правило показа это учитывает.
  TextColumn get lang => text()();

  /// Имя темы, готовое к подписи на карте.
  ///
  /// Геттер назван `name`, и это проверено, а не понадеялось. Шрам
  /// [Phrases.sentence] выше — про то, что `text` в Drift это **билдер
  /// колонки**, поэтому `TextColumn get text => text()()` рекурсивно
  /// возвращает сам себя, а генерация на такой файл молча не даёт ничего.
  /// Билдера с именем `name` в Drift нет — переименование колонки делает
  /// `named()` у уже построенной колонки, а не одноимённый геттер таблицы, —
  /// и [Languages.name] тому свидетель: колонка `name` там существует с
  /// первого дня схемы. Переименовывать нечего.
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {constellation, lang};
}

/// Метаданные сборки: язык, версия схемы, отпечаток исходников, запущенные
/// ярусы. Метки времени здесь нет намеренно — сборка обязана быть
/// воспроизводимой байт-в-байт.
@DataClassName('ContentMetaRow')
class ContentMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Контентная база: **read-only**. Поставляется собранной в ассетах, на
/// устройстве никогда не мигрируется и при обновлении заменяется целиком.
///
/// Поэтому у класса нет ни одного метода записи, а [migration] намеренно
/// падает: если Drift решил, что нужна миграция, значит в ассеты попала база
/// не той версии — это ошибка сборки, а не ситуация, которую надо лечить в
/// рантайме.
@DriftDatabase(tables: [
  Languages,
  Phrases,
  PhraseTranslations,
  ConstellationNames,
  CalibrationItems,
  ContentMeta,
])
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.executor);

  /// Открывает `assets/content/<lang>.db`, скопировав его в
  /// support-директорию при первом запуске.
  ContentDatabase.forLanguage(String lang) : super(openContentExecutor(lang));

  /// Версия схемы контента. Меняется вместе с `tool/build_content.dart` и
  /// записывается в `PRAGMA user_version` при сборке.
  ///
  /// v2 убрала `audio_id`: озвучка перешла на синтез устройства.
  ///
  /// v3 сделала у фразы несколько пропусков и добавила таблицу языков.
  ///
  /// v4 сменила устройство фразовой механики: `phrase_options` уехала, на её
  /// место встала `phrase_orders`.
  ///
  /// **v5 — разговорник.** Единицей изучения стала фраза, и вместе с
  /// отдельным словом ушли шесть таблиц: `concepts`, `lexemes`,
  /// `distractors`, `phrase_slots`, `phrase_orders`, `phrase_concepts`.
  /// Осталось пять.
  ///
  /// **v6 добавила `constellation_names`.** До неё у созвездия было только
  /// имя-slug, и карта подписывала темы латиницей вроде `first_contact`.
  /// Имя — контент: оно приходит с темой одним файлом, а не строкой в шести
  /// ARB.
  ///
  /// **v7 добавила `phrases.kind`** — вид фразы: `phrase`, `example`,
  /// `idiom`. Корпус вырос до 1500 фраз и потерял многоточия («с ним не
  /// понятно как читать»), а взамен объявил вид каждой строки. Пометка нужна
  /// не игре, а проверке текста: у идиомы перевод смысловой, и проверять её
  /// на буквальность нельзя, а пример — образец речевой модели, занявший
  /// место шаблона с многоточием. Подробнее, вместе с решением не заводить
  /// вид в игровую логику, — у [Phrases.kind].
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) => throw StateError(
          'content.db read-only: пустая база означает, что ассет не собран — '
          'запустите dart run tool/build_content.dart',
        ),
        onUpgrade: (_, from, to) => throw StateError(
          'content.db read-only: ассет схемы v$from, приложение ждёт v$to — '
          'пересоберите контент',
        ),
      );

  /// Ярусы, вычитанные и разрешённые к игре.
  ///
  /// Правило «язык не запускается, пока его ярусы не вычитаны» действует и в
  /// рантайме: приложение не предлагает подняться туда, где контент ещё
  /// черновой. Пустое поле означает старую сборку — тогда разрешаем всё,
  /// иначе обновление ассета сломало бы игру.
  Future<Set<Tier>> launchedTiers() async {
    final raw = (await loadMeta())['launched_tiers'];
    if (raw == null || raw.isEmpty) return Tier.values.toSet();
    return raw.split(',').map(Tier.fromCode).toSet();
  }

  /// Значения из таблицы метаданных сборки.
  Future<Map<String, String>> loadMeta() async {
    final rows = await select(contentMeta).get();
    return {for (final r in rows) r.key: r.value};
  }

  /// Сколько фраз в базе — самый дешёвый способ убедиться, что ассет
  /// открылся и не пуст.
  Future<int> countPhrases() async {
    final count = phrases.id.count();
    final row = await (selectOnly(phrases)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  // ── Чтение фразы: четыре запроса, и все отдают строку целиком ────────────
  //
  // [phrasesFor], [phrasesUpTo], [phrasesOn] и [phrase] возвращают
  // [PhraseRow], а не отобранные колонки, — поэтому `kind` из v7 доехал до
  // вызывающего сам, без правки ни одного запроса. Так и задумано, и вот где
  // он останавливается.
  //
  // Отдельного запроса «дай мне идиомы» нет: читатель у вида один — проверка
  // текста, и она смотрит на выборку целиком, а не ищет тридцать строк.
  // Фильтр по виду означал бы, что кто-то собирается играть идиомами иначе,
  // чем фразами.
  //
  // Поля в игровых сущностях (`StudyItem`, вопрос круга) у вида тоже нет, и
  // это запрет, а не недоделка. Механик три, и все три показывают фразу как
  // есть: идиома играется тем же кругом, что и приветствие, — вид не меняет
  // ни центра, ни шести вариантов, ни оценки памяти. Поле, доехавшее до
  // игровой логики, стало бы приглашением ветвиться по нему.
  //
  // В базе вид при этом обязан быть, а не только в YAML: у прежней вычитки
  // ровно в этом было слепое пятно — она читала исходники, то есть текст,
  // которого игрок не видит (см. проверку «отгруженный ассет собран из
  // нынешних исходников» в `test/data/databases_test.dart`).

  List<String> _tiersUpTo(Tier upTo) => Tier.values
      .where((t) => t.index <= upTo.index)
      .map((t) => t.code)
      .toList();

  /// Фразы созвездия на ярусе и ниже: небо уплотняется, а не переписывается,
  /// поэтому старые фразы остаются в выборке.
  Future<List<PhraseRow>> phrasesFor(String constellation, Tier upTo) =>
      (select(phrases)
            ..where((p) => p.constellation.equals(constellation))
            ..where((p) => p.tier.isIn(_tiersUpTo(upTo)))
            ..orderBy([
              (p) => OrderingTerm(expression: p.tier),
              (p) => OrderingTerm(expression: p.idx),
            ]))
          .get();

  /// Все фразы яруса и ниже, в порядке яруса и авторской последовательности.
  ///
  /// Порядок задан явно, и это важно: по нему идёт знакомство. Прежний
  /// запрос по концептам сортировал по частотности слова — у фразы её нет.
  Future<List<PhraseRow>> phrasesUpTo(Tier upTo) => (select(phrases)
        ..where((p) => p.tier.isIn(_tiersUpTo(upTo)))
        ..orderBy([
          (p) => OrderingTerm(expression: p.tier),
          (p) => OrderingTerm(expression: p.constellation),
          (p) => OrderingTerm(expression: p.idx),
        ]))
      .get();

  /// Фразы **ровно** этого яруса, в авторском порядке.
  ///
  /// Нужны калибровке: она мерит ярус, а не всё, что ниже. Круг с фразой A0
  /// на пробе B1 ничего не измерил бы.
  Future<List<PhraseRow>> phrasesOn(Tier tier) => (select(phrases)
        ..where((p) => p.tier.equals(tier.code))
        ..orderBy([
          (p) => OrderingTerm(expression: p.constellation),
          (p) => OrderingTerm(expression: p.idx),
        ]))
      .get();

  Future<int> countPhrasesUpTo(Tier upTo) async {
    final count = phrases.id.count();
    final row = await (selectOnly(phrases)
          ..addColumns([count])
          ..where(phrases.tier.isIn(_tiersUpTo(upTo))))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Future<PhraseRow?> phrase(String id) =>
      (select(phrases)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Set<String>> allPhraseIds() async {
    final rows = await select(phrases).get();
    return rows.map((r) => r.id).toSet();
  }

  /// Созвездия в порядке появления: по ярусу первой фразы, потом по имени.
  Future<List<String>> constellations() async {
    final rows = await (select(phrases)
          ..orderBy([
            (p) => OrderingTerm(expression: p.tier),
            (p) => OrderingTerm(expression: p.constellation),
          ]))
        .get();
    final seen = <String>[];
    for (final row in rows) {
      if (!seen.contains(row.constellation)) seen.add(row.constellation);
    }
    return seen;
  }

  /// Имена созвездий на одном языке: `slug → имя`.
  ///
  /// Запрос дешёвый намеренно, потому что вызывается **дважды** на построение
  /// карты — на языке интерфейса и на языке подсказок (правило показа живёт в
  /// `ConstellationNaming`, файл рядом). Отсюда две вещи. Берутся две колонки:
  /// `lang` в ответе не нужен, он и есть аргумент, а возвращать его значило бы
  /// читать третью строку на каждый ряд. И запрос отдаёт готовую карту, а не
  /// список рядов: вызывающему нужен поиск по слагу, а не порядок — порядок
  /// созвездий на небе задаёт [constellations].
  ///
  /// Индекса по одному `lang` нет и не нужно: первичный ключ
  /// `(constellation, lang)` по второй колонке не помогает, но таблица — это
  /// пятьдесят тем на пять языков, то есть просмотр двухсот пятидесяти
  /// коротких рядов один раз за открытие карты.
  Future<Map<String, String>> constellationNamesFor(String lang) async {
    final slug = constellationNames.constellation;
    final name = constellationNames.name;
    final rows = await (selectOnly(constellationNames)
          ..addColumns([slug, name])
          ..where(constellationNames.lang.equals(lang)))
        .get();
    // Обе колонки `NOT NULL`, поэтому чтение без запаса на null: пустой ряд
    // здесь означал бы битый ассет, и молча превратить его в отсутствующее
    // имя — значит спрятать поломку сборки за латинским слагом на карте.
    return {for (final row in rows) row.read(slug)!: row.read(name)!};
  }

  /// Перевод одной фразы.
  Future<String?> translation(String phraseId, String lang) async {
    final row = await (select(phraseTranslations)
          ..where((t) => t.phraseId.equals(phraseId))
          ..where((t) => t.lang.equals(lang)))
        .getSingleOrNull();
    return row?.sentence;
  }

  /// Переводы пачкой: `id → текст`.
  ///
  /// Круг требует шесть текстов сразу, и спрашивать их по одному значило бы
  /// шесть запросов на каждый круг забега.
  Future<Map<String, String>> translationsFor(
    Iterable<String> phraseIds,
    String lang,
  ) async {
    final ids = phraseIds.toList();
    if (ids.isEmpty) return const {};
    final rows = await (select(phraseTranslations)
          ..where((t) => t.phraseId.isIn(ids))
          ..where((t) => t.lang.equals(lang)))
        .get();
    return {for (final r in rows) r.phraseId: r.sentence};
  }

  Future<List<CalibrationItemRow>> calibrationFor(Tier tier) =>
      (select(calibrationItems)..where((c) => c.tier.equals(tier.code))).get();

  Future<List<LanguageRow>> allLanguages() =>
      (select(languages)..orderBy([(l) => OrderingTerm(expression: l.code)]))
          .get();

  /// Языки, на которых можно подсказывать: роль позволяет и статус запущен.
  Future<List<LanguageRow>> nativeLanguages() async {
    final rows = await allLanguages();
    return rows
        .where((l) => l.role != 'target' && l.status == 'launched')
        .toList();
  }

  /// Языки, которые можно учить.
  Future<List<LanguageRow>> targetLanguages() async {
    final rows = await allLanguages();
    return rows
        .where((l) => l.role != 'native' && l.status == 'launched')
        .toList();
  }
}
