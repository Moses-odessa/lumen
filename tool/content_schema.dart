/// Схема `content.db` в одном месте: её читают и `build_content.dart`, и
/// `validate_content.dart`.
///
/// Имена таблиц и колонок обязаны совпадать с тем, что генерирует Drift для
/// `lib/data/content/content_database.dart` — иначе приложение откроет базу и
/// упадёт на первом запросе. Версия схемы пишется в `PRAGMA user_version` и
/// сверяется с `ContentDatabase.schemaVersion`.
library;

/// Версия схемы контента. Меняется вместе с `ContentDatabase.schemaVersion`.
///
/// v2 убрала `audio_id`: озвучка перешла на синтез устройства и произносит
/// текст, а не заранее записанный файл.
///
/// v3 сделала две вещи. Во-первых, у фразы стало несколько пропусков:
/// `phrases.answer` уехал в `phrase_slots`, рядом встали `phrase_options`
/// (неверные слова по слоту) и `phrase_translations` (перевод фразы целиком).
/// Во-вторых, появилась таблица `languages`: язык объявляет о себе сам, а не
/// перечисляется списком в коде.
///
/// v4 сменила устройство фразовой механики. Пропусков стало от двух до всех
/// слов, а вокруг — ровно вынутые слова, без посторонних. `phrase_options`
/// уехала целиком, а вместо неё встала `phrase_orders` — сборки, которые
/// принимаются верными.
///
/// **v5 — разговорник.** Единицей изучения стала фраза, а отдельного слова в
/// игре больше нет. Вместе со словом ушли пять таблиц:
///
/// * `concepts` и `lexemes` — единицей была словарная запись; теперь фраза
///   сама себе запись: у неё есть ярус, созвездие и перевод;
/// * `distractors` — неверные варианты больше не пишутся руками. Вокруг
///   фразы лежат **другие фразы, которые игрок уже знает**: новое даётся
///   методом исключения, а знакомое проверяется тем же кругом;
/// * `phrase_slots` и `phrase_orders` — вставки слов в предложение больше
///   нет, значит нет ни пропусков, ни списка верных сборок;
/// * `phrase_concepts` — связывать фразу со словом больше незачем.
///
/// `phrases.template` стал `phrases.text`: шаблон с пропуском нужен был
/// механике вставки. Сборка подставляет ответ в шаблон и пишет готовое
/// предложение — в игре у фразы нет ни пропусков, ни скрытых частей.
///
/// `phrases.idx` — порядок внутри созвездия и яруса, как он написан в файле.
/// Прежнюю последовательность знакомства задавала частотность слова
/// (`concepts.freq_rank`), а у фразы частотности нет: порядок решает автор.
const int contentSchemaVersion = 5;

/// DDL контентной базы. Индексы — под запросы рантайма: выборка фраз
/// созвездия по ярусу и набор калибровки.
const List<String> contentSchemaDdl = [
  // Языки базы: код, роль, готовность, самоназвание и покрытие.
  //
  // Покрытие считается при сборке, а не объявляется в файле: объявленное
  // число разошлось бы с содержимым при первой же правке — этот проект уже
  // ловил такое на строке о вычитке в launch.yaml.
  '''
  CREATE TABLE languages (
    code TEXT NOT NULL PRIMARY KEY,
    role TEXT NOT NULL,
    status TEXT NOT NULL,
    name TEXT NOT NULL,
    phrases INTEGER NOT NULL
  )
  ''',
  // Фраза — единица изучения. `text` готов к показу: подстановка сделана
  // сборкой, скрытых частей у фразы нет.
  '''
  CREATE TABLE phrases (
    id TEXT NOT NULL PRIMARY KEY,
    lang TEXT NOT NULL,
    tier TEXT NOT NULL,
    constellation TEXT NOT NULL,
    idx INTEGER NOT NULL,
    text TEXT NOT NULL,
    register TEXT NULL
  )
  ''',
  // Перевод фразы на родной язык. Живёт в языковом файле, а не рядом с
  // фразой: язык добавляется одним файлом.
  '''
  CREATE TABLE phrase_translations (
    phrase_id TEXT NOT NULL,
    lang TEXT NOT NULL,
    text TEXT NOT NULL,
    PRIMARY KEY (phrase_id, lang)
  )
  ''',
  '''
  CREATE TABLE calibration_items (
    id TEXT NOT NULL PRIMARY KEY,
    tier TEXT NOT NULL,
    phrase_id TEXT NOT NULL,
    kind TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE content_meta (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  'CREATE INDEX phrases_constellation_tier ON phrases (constellation, tier)',
  'CREATE INDEX phrase_translations_lang ON phrase_translations (lang)',
  'CREATE INDEX calibration_tier ON calibration_items (tier)',
];

/// Ярусы в порядке возрастания. Дублируется с `domain/entities/tier.dart`
/// намеренно: `tool/` — отдельная программа и не тянет за собой `lib/`.
const List<String> tiers = ['a0', 'a1', 'a2', 'b1', 'b2'];

/// Язык изучения по умолчанию — только значение флага `--lang`.
///
/// Раньше рядом стоял `projectLangs`: список языков в коде. Его больше нет.
/// Языки находятся перебором `content/lang/`, и это не косметика — это
/// разница между «добавить язык значит создать файл» и «добавить язык значит
/// править Dart, пересобирать и не забыть четыре места».
const String defaultTargetLang = 'de';

/// Роли языка. `both` оставлено на случай языка, который и учат, и понимают
/// (немецкий для швейцарца), но сегодня такого нет.
const List<String> languageRoles = ['native', 'target', 'both'];

/// Готовность языка. `launched` требует полноты, `draft` — нет.
const List<String> languageStatuses = ['draft', 'launched'];

/// Сколько звёзд должно быть у созвездия на ярусе, чтобы оно вообще
/// появилось на карте.
///
/// Считается по фразам: звезда — это фраза. Раньше здесь стоял `starsPerTier`
/// — фиксированные 12/24/48/72/96 накопительно, и валидатор требовал их
/// точного совпадения. Порог вместо равенства: тема просто ждёт того яруса,
/// на котором ей есть что показать.
const int minStarsForConstellation = 8;

/// Пометки под центром круга. Сегодня это регистр фразы.
///
/// Закрытый набор кодов, а не свободный текст: `register: casual` уезжал на
/// экран как есть, и под каждой из 432 фраз стояло английское служебное
/// слово. Строку к коду даёт локализация — на языке интерфейса.
///
/// Словарные пометки (часть речи, исчисляемость, число) ушли вместе со
/// словарным слоем: у фразы части речи нет.
///
/// Дублируется с `lib/domain/entities/prompt_tag.dart`, совпадение проверяет
/// тест.
const Set<String> promptTags = {'casual', 'formal'};
