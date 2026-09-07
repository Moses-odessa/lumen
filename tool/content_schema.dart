/// Схема `content.db` в одном месте: её читают и `build_content.dart`, и
/// `validate_content.dart`.
///
/// Имена таблиц и колонок обязаны совпадать с тем, что генерирует Drift для
/// `lib/data/content/content_database.dart` — иначе приложение откроет базу и
/// упадёт на первом запросе. Версия схемы пишется в `PRAGMA user_version` и
/// сверяется с `ContentDatabase.schemaVersion`.
library;

/// Версия схемы контента. Меняется вместе с `ContentDatabase.schemaVersion`.
// v2 убрала audio_id: озвучка перешла на синтез устройства и
// произносит текст лексемы, а не заранее записанный файл.
const int contentSchemaVersion = 2;

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
  '''
  CREATE TABLE phrases (
    id TEXT NOT NULL PRIMARY KEY,
    lang TEXT NOT NULL,
    tier TEXT NOT NULL,
    constellation TEXT NOT NULL,
    template TEXT NOT NULL,
    answer TEXT NOT NULL,
    register TEXT NULL
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

/// Языки проекта: язык изучения плюс языки подсказок.
const List<String> projectLangs = ['de', 'ru', 'uk', 'en'];

/// Язык изучения. До M8 в ассетах лежит озвучка ровно одного.
const String targetLang = 'de';

/// Размер созвездия по ярусу — накопительный (docs/CONCEPT.md).
/// Валидатор сверяет с ним фактические размеры.
const Map<String, int> starsPerTier = {
  'a0': 12,
  'a1': 24,
  'a2': 48,
  'b1': 72,
  'b2': 96,
};

/// Минимум дистракторов каждого типа на концепт (docs/CONTENT_PIPELINE.md).
const int minFarDistractors = 2;
const int minNearDistractors = 3;

/// Текст фразы для синтеза: шаблон со слотом, заполненным ответом.
String phraseSpeech(String template, String answer) =>
    template.replaceAll(RegExp(r'\{[^}]*\}'), answer);

