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
/// v2 убрала `audio_id`: озвучка перешла на синтез устройства и
/// произносит текст лексемы, а не заранее записанный файл.
///
/// v3 сделала две вещи. Во-первых, у фразы стало несколько пропусков:
/// `phrases.answer` уехал в `phrase_slots`, рядом встали `phrase_options`
/// (неверные слова по слоту) и `phrase_translations` (перевод фразы целиком).
/// Без этого механики «заполни пропуски» и «собери предложение» не собрать.
/// Во-вторых, появилась таблица `languages`: язык объявляет о себе сам, а не
/// перечисляется списком в коде.
const int contentSchemaVersion = 3;

/// DDL контентной базы. Индексы — под запросы рантайма: выборка концептов
/// созвездия по ярусу и подбор дистракторов для круга.
const List<String> contentSchemaDdl = [
  '''
  CREATE TABLE concepts (
    id TEXT NOT NULL PRIMARY KEY,
    tier TEXT NOT NULL,
    constellation TEXT NOT NULL,
    pos TEXT NOT NULL,
    freq_rank INTEGER NULL
  )
  ''',
  '''
  CREATE TABLE lexemes (
    concept_id TEXT NOT NULL,
    lang TEXT NOT NULL,
    form TEXT NOT NULL,
    article TEXT NULL,
    gender TEXT NULL,
    plural TEXT NULL,
    note TEXT NULL,
    PRIMARY KEY (concept_id, lang)
  )
  ''',
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
    concepts INTEGER NOT NULL,
    phrases INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE phrases (
    id TEXT NOT NULL PRIMARY KEY,
    lang TEXT NOT NULL,
    tier TEXT NOT NULL,
    constellation TEXT NOT NULL,
    template TEXT NOT NULL,
    register TEXT NULL
  )
  ''',
  // Пропуски фразы по порядку. `idx` — номер слота в шаблоне слева направо.
  '''
  CREATE TABLE phrase_slots (
    phrase_id TEXT NOT NULL,
    idx INTEGER NOT NULL,
    answer TEXT NOT NULL,
    PRIMARY KEY (phrase_id, idx)
  )
  ''',
  // Неверные слова для конкретного слота. Необязательны: когда их нет,
  // варианты добираются соседями по созвездию.
  '''
  CREATE TABLE phrase_options (
    phrase_id TEXT NOT NULL,
    idx INTEGER NOT NULL,
    form TEXT NOT NULL,
    PRIMARY KEY (phrase_id, idx, form)
  )
  ''',
  // Перевод фразы целиком на родной язык: он проявляется после того, как все
  // пропуски заполнены. Живёт в языковом файле, а не рядом с фразой.
  '''
  CREATE TABLE phrase_translations (
    phrase_id TEXT NOT NULL,
    lang TEXT NOT NULL,
    text TEXT NOT NULL,
    PRIMARY KEY (phrase_id, lang)
  )
  ''',
  '''
  CREATE TABLE phrase_concepts (
    phrase_id TEXT NOT NULL,
    concept_id TEXT NOT NULL,
    PRIMARY KEY (phrase_id, concept_id)
  )
  ''',
  '''
  CREATE TABLE distractors (
    concept_id TEXT NOT NULL,
    lang TEXT NOT NULL,
    kind TEXT NOT NULL,
    form TEXT NOT NULL,
    PRIMARY KEY (concept_id, lang, form)
  )
  ''',
  '''
  CREATE TABLE calibration_items (
    id TEXT NOT NULL PRIMARY KEY,
    tier TEXT NOT NULL,
    concept_id TEXT NULL,
    phrase_id TEXT NULL,
    kind TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE content_meta (
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  'CREATE INDEX concepts_constellation_tier ON concepts (constellation, tier)',
  'CREATE INDEX lexemes_lang ON lexemes (lang)',
  'CREATE INDEX phrases_constellation_tier ON phrases (constellation, tier)',
  'CREATE INDEX distractors_lookup ON distractors (concept_id, lang, kind)',
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
/// Раньше здесь стоял `starsPerTier` — фиксированные 12/24/48/72/96
/// накопительно, и валидатор требовал их точного совпадения. На словнике из
/// 6000 лемм это правило провалили бы десять тем из двадцати четырёх: у
/// «денег» и «общества» на A0 по одному слову, и подгонять их до двенадцати
/// значило бы придумывать A0-лексику там, где её нет.
///
/// Порог вместо равенства: тема просто ждёт того яруса, на котором ей есть
/// что показать. Прогрессия из этого получается сама — A0 отдаёт 15
/// созвездий, A1 добавляет семь, A2 остальные два.
const int minStarsForConstellation = 8;

/// Пометки под центром круга: часть речи, исчисляемость, регистр фразы.
///
/// Закрытый набор кодов, а не свободный текст. Пометка `note` у лексемы
/// писалась на языке своего файла: у немецкого — по-русски. Немецкий здесь
/// язык **изучения**, его файл читает автор контента, а не игрок, — значит
/// правильного языка у такой пометки нет вообще, и украинскому игроку
/// показывалось «неисчисляемое». `register: casual` уезжал на экран как есть:
/// под каждой из 432 фраз стояло английское служебное слово.
///
/// Строку к коду даёт локализация — на языке интерфейса. Свободный текст
/// остался только у лексем **родного** языка (`Karte` → «банковская»), где
/// язык файла и есть язык игрока.
///
/// Дублируется с `lib/domain/entities/prompt_tag.dart`, совпадение проверяет
/// тест.
const Set<String> promptTags = {
  'adverb',
  'adjective',
  'uncountable',
  'plural_only',
  'usually_plural',
  'casual',
  'formal',
};

/// Сколько своих неверных слов нужно фразе на каждый слот.
///
/// Число не круглое, оно посчитано: сборщик ограничивает пул величиной
/// `optionsMax + extraOptionsMax`, и в пул сперва кладутся все ответы. Значит
/// на один слот остаётся `6 + 2 - 1 = 7` неверных слов — и ровно при семи
/// добор `far`-дистракторами и соседями по теме **не начинается никогда**.
///
/// Запас нулевой, и это надо знать. Поднять `extraOptionsMax` до трёх, добавить
/// ступень сложности или отгрузить фразу с шестью словами вместо семи — и
/// добор включится, а вместе с ним вернутся находки первого раунда вычитки:
/// `far` у `right_adv` это `[links, geradeaus]`, то есть «Gehen Sie nach
/// links», а у `hunger_noun` — `[Durst, Appetit]`, то есть «Ich habe großen
/// Durst». Оба предложения правильные, и оба игра объявит неверными.
///
/// Совпадение с балансом закрыто тестом: `tool/` не тянет за собой `lib/`, и
/// расхождение здесь означало бы, что проверка разрешает пул шире того, что
/// она проверила.
const int phraseOptionsPerSlot = 7;

/// Сколько вариантов слота должны отсеиваться **не** грамматикой.
///
/// Считается от обрезки, а не выбирается. При обычной сложности игрок видит
/// `optionsMax - 1 = 5` из семи вариантов, и какие именно — решает случай:
/// база отдаёт их по алфавиту, поэтому сборщик перемешивает список перед
/// обрезкой. В худшем случае из показанных пяти на «нужный» класс приходится
/// `5 - (7 - s)` слов, где `s` — сколько их в списке. Чтобы этих слов
/// гарантированно оказалось не меньше двух, нужно `s >= 4`.
///
/// Двух хватает: род ответа перестаёт быть отличительным признаком, и слово
/// приходится знать. Требовать больше значило бы запретить блокировку по роду
/// вовсе — а она законный и полезный вид неверного варианта.
const int minSameClassOptions = 4;

/// Слова, которые перед пропуском задают род и падеж.
///
/// Нужны затем, чтобы отличить рамку с артиклем от безартиклевой: в первой
/// вариант отсеивается несовпадением рода, во второй — требованием артикля у
/// исчисляемого. Проверка «ответ не опознаётся грамматикой» в этих двух
/// случаях разная, и спутать их значит требовать от рамки того, чего в ней
/// нет.
///
/// Список закрытый и его придётся дописывать. Незнакомое слово считается
/// не задающим род — то есть проверка становится мягче, а не роняет сборку
/// зря.
const Set<String> genderMarkers = {
  'der', 'die', 'das', 'dem', 'den', 'des',
  'ein', 'eine', 'einen', 'einem', 'eines',
  'kein', 'keine', 'keinen', 'keinem', 'keines',
  'mein', 'meine', 'meinen', 'meinem',
  'dein', 'deine', 'deinen',
  'sein', 'seine', 'seinen',
  'ihr', 'ihre', 'ihren', 'ihrem',
  'unser', 'unsere', 'unseren',
  'dieser', 'diese', 'dieses', 'diesen', 'diesem',
  'jeder', 'jede', 'jedes',
  'nächste', 'nächsten', 'nächstes',
  // Предлог, слипшийся с артиклем: артикль в нём и есть.
  'im', 'ins', 'am', 'ans', 'zum', 'zur', 'vom', 'beim',
  // Прилагательное в сильном склонении задаёт род не хуже артикля.
  'guter', 'gute', 'gutes', 'guten',
  'großer', 'große', 'großes', 'großen',
  'neuer', 'neue', 'neues', 'neuen',
  'kleiner', 'kleine', 'kleines', 'kleinen',
};

/// Слово, стоящее перед каждым пропуском шаблона, в нижнем регистре.
///
/// Пустая строка там, где пропуск в начале предложения.
List<String> phraseSlotMarkers(String template) {
  final result = <String>[];
  for (final match in RegExp(r'\{[^}]*\}').allMatches(template)) {
    final before = template.substring(0, match.start).trim();
    final words = before.split(RegExp(r'[\s,.;:!?]+'));
    result.add(words.isEmpty ? '' : words.last.toLowerCase());
  }
  return result;
}

/// Минимум дистракторов каждого типа на концепт (docs/CONTENT_PIPELINE.md).
///
/// Требуются только от языка изучения. На родном языке варианты берутся из
/// соседей по созвездию: это слова, уже написанные и проверенные, поэтому
/// несуществующее слово в круге структурно невозможно, а 31 000 единиц
/// ручной работы не появляется.
const int minFarDistractors = 2;
const int minNearDistractors = 3;

/// Текст фразы для синтеза: шаблон с заполненными пропусками.
///
/// Слотов может быть несколько, и порядок [answers] — это порядок слотов в
/// шаблоне слева направо.
String phraseSpeech(String template, List<String> answers) {
  var i = 0;
  return template.replaceAllMapped(
    RegExp(r'\{[^}]*\}'),
    (_) => i < answers.length ? answers[i++] : '…',
  );
}

/// Шаблон с пропусками вместо слотов: `Ich kaufe {bread}.` → `Ich kaufe ___.`
String phraseWithGaps(String template) =>
    template.replaceAll(RegExp(r'\{[^}]*\}'), '_____');

/// Сколько слотов в шаблоне.
int phraseSlotCount(String template) =>
    RegExp(r'\{[^}]*\}').allMatches(template).length;
