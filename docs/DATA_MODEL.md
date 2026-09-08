# Модель данных

Две базы, никогда не пересекающиеся по таблицам.

- **`content.db`** — read-only, собирается на машине разработчика через
  `tool/build_content.dart`, кладётся в `assets/content/<lang>.db`, копируется в
  support-директорию при первом запуске и открывается отдельным
  `NativeDatabase`. На устройстве **не мигрируется** — при обновлении заменяется
  целиком.
- **`user.db`** — Drift со схемой и миграциями, только состояние игрока.

Причина разделения: контент большой, полностью детерминированный и общий для
всех; пользовательские данные маленькие, персональные и мигрируют. Смешивать их
в одной базе — значит гонять миграции по 100 тысячам строк контента при каждом
обновлении словаря.

---

## content.db — граф концептов

```sql
-- Концепт: смысл, не привязанный ни к одному языку.
concepts (
  id           TEXT PRIMARY KEY,   -- 'bill_restaurant'
  tier         TEXT NOT NULL,      -- 'a0' | 'a1' | 'a2' | 'b1' | 'b2'
  constellation TEXT NOT NULL,     -- 'doctor', 'rent', 'interview'
  pos          TEXT NOT NULL,      -- часть речи
  freq_rank    INTEGER             -- ранг по частотному списку
);

-- Лексема: как этот концепт выглядит в конкретном языке.
lexemes (
  concept_id   TEXT NOT NULL REFERENCES concepts(id),
  lang         TEXT NOT NULL,      -- 'de', 'ru', 'uk', 'en'
  form         TEXT NOT NULL,      -- 'Rechnung'
  article      TEXT,               -- 'die'
  gender       TEXT,               -- 'f'
  plural       TEXT,
  audio_id     TEXT,               -- имя файла в аудио-паке
  note         TEXT,
  PRIMARY KEY (concept_id, lang)
);

-- Фраза: шаблон со слотами, связывает несколько концептов.
phrases (
  id           TEXT PRIMARY KEY,
  lang         TEXT NOT NULL,
  tier         TEXT NOT NULL,
  constellation TEXT NOT NULL,
  template     TEXT NOT NULL,      -- 'Die {bill}, bitte.'
  answer       TEXT NOT NULL,
  register     TEXT,               -- 'formal' | 'casual'
  audio_id     TEXT
);

phrase_concepts (phrase_id TEXT, concept_id TEXT);

-- Дистракторы: заранее подобранные варианты для круга.
distractors (
  concept_id   TEXT NOT NULL,
  lang         TEXT NOT NULL,
  kind         TEXT NOT NULL,      -- 'far' (тема) | 'near' (созвучный/однокоренной)
  form         TEXT NOT NULL,
  PRIMARY KEY (concept_id, lang, form)
);

-- Набор для калибровки: откалиброванные круги по ярусам.
calibration_items (
  id           TEXT PRIMARY KEY,
  tier         TEXT NOT NULL,
  concept_id   TEXT,
  phrase_id    TEXT,
  kind         TEXT NOT NULL       -- 'word' | 'phrase'
);

-- Метаданные сборки: из чего собран этот ассет.
content_meta (
  key          TEXT PRIMARY KEY,   -- 'lang', 'schema_version', 'concepts',
  value        TEXT NOT NULL       -- 'source_hash', 'source_revision'
);
```

**Почему `content_meta`, а не просто версия в `PRAGMA user_version`.**
`user_version` нужен Drift, чтобы не запускать миграции, и больше ни для чего
не годится. По собранному ассету надо уметь ответить на вопрос «что это за
контент и из каких исходников он собран» — и из приложения тоже, а не только
из сборочного лога. Метки времени в метаданных нет намеренно: она сделала бы
каждую пересборку новым файлом в git и сломала бы правило воспроизводимости
из [CONTENT_PIPELINE.md](CONTENT_PIPELINE.md). Вместо неё — `source_hash`
(хеш YAML-исходников) и `source_revision` (короткий git-хеш).

**DDL живёт в `tool/content_schema.dart`.** Он один для сборщика и валидатора,
и обязан совпадать с тем, что генерирует Drift для `ContentDatabase`.
Расхождение имён колонок означает падение у игрока на первом запросе, поэтому
шов закрыт тестом `test/data/content_schema_test.dart`.

**Почему дистракторы лежат в контенте, а не считаются на лету.** Качество круга
целиком определяется вариантами вокруг: случайные слова превращают игру в
угадайку, а «созвучные» надо подбирать по фонетике, а не по расстоянию
Левенштейна. Это работа для пайплайна с человеческой вычиткой, а не для рантайма.

---

## user.db — состояние игрока (Drift)

```dart
/// Игрок — одна строка (id = 1).
class Players extends Table {
  IntColumn  get id            => integer().withDefault(const Constant(1))();
  TextColumn get targetLang    => text()();          // что учим
  TextColumn get nativeLang    => text()();          // язык подсказок
  TextColumn get uiLang        => text().nullable()(); // язык интерфейса, null = системный
  TextColumn get tier          => text()();          // текущий ярус
  BoolColumn get calibrated    => boolean().withDefault(const Constant(false))();
  IntColumn  get orbit         => integer().withDefault(const Constant(0))();
  IntColumn  get sparks        => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn  get missedInRow   => integer().withDefault(const Constant(0))();
  BoolColumn get freePace      => boolean().withDefault(const Constant(false))();
  BoolColumn get soundEnabled  => boolean().withDefault(const Constant(true))();
}

/// Состояние одного слова. Источник правды по памяти — difficulty/stability/lastReview.
class WordStates extends Table {
  TextColumn     get conceptId  => text()();
  TextColumn     get tier       => text()();
  RealColumn     get difficulty => real()();          // FSRS D
  RealColumn     get stability  => real()();          // FSRS S, в днях
  DateTimeColumn get lastReview => dateTime().nullable()();
  DateTimeColumn get due        => dateTime().nullable()();
  IntColumn      get lmCached   => integer().withDefault(const Constant(0))();  // производная, кеш для сортировки
  IntColumn      get fastStreak => integer().withDefault(const Constant(0))();  // подряд быстрых верных
  BoolColumn     get burning    => boolean().withDefault(const Constant(false))();
  IntColumn      get reps       => integer().withDefault(const Constant(0))();
  IntColumn      get lapses     => integer().withDefault(const Constant(0))();
  @override Set<Column> get primaryKey => {conceptId};
}

/// Журнал ответов: нужен и для дообучения параметров FSRS, и для аналитики.
class Reviews extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  TextColumn     get conceptId => text()();
  DateTimeColumn get at        => dateTime()();
  IntColumn      get latencyMs => integer()();
  TextColumn     get mode      => text()();           // 'recognition' | 'circle' | 'tight' | 'audio' | 'typing' | 'phrase'
  BoolColumn     get correct   => boolean()();
  IntColumn      get grade     => integer()();        // 1..4, выведено из latency
}

/// Прогресс по созвездию на конкретном ярусе.
class ConstellationProgress extends Table {
  TextColumn get constellation => text()();
  TextColumn get tier          => text()();
  BoolColumn get unlocked      => boolean().withDefault(const Constant(false))();
  BoolColumn get lit           => boolean().withDefault(const Constant(false))();
  IntColumn  get levelsDone    => integer().withDefault(const Constant(0))();
  @override Set<Column> get primaryKey => {constellation, tier};
}

/// Сессии — для ритуала, орбиты и метрик.
class Sessions extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn      get durationMs=> integer()();
  IntColumn      get lmGained  => integer()();        // прирост яркости — основа рейтинга лиг
  IntColumn      get score     => integer()();
  IntColumn      get newWords  => integer()();
  TextColumn     get climbId   => text().nullable()();     // аркадный заход
  IntColumn      get climbLevel=> integer().nullable()();  // его уровень
}

/// Свои слова: личное созвездие произвольного размера.
class CustomConcepts extends Table {
  TextColumn get id     => text()();
  TextColumn get target => text()();
  TextColumn get native => text()();
  TextColumn get deck   => text()();
  @override Set<Column> get primaryKey => {id};
}
```

---

## Правила, которые легко нарушить

- **`lmCached` — производная.** Считается из `(difficulty, stability, lastReview)`
  на момент запроса и сохраняется только чтобы сортировать «самые тусклые»
  индексом, а не в памяти. При расхождении верна тройка FSRS.
- **`due` — тоже производная**, но её удобно материализовать: планировщик берёт
  пул одним запросом `WHERE due <= now ORDER BY lmCached ASC LIMIT 40`.
- **`Reviews` растёт неограниченно.** Раз в месяц схлопывать записи старше
  полугода в агрегаты, иначе база у активного игрока за год перевалит за
  сотню тысяч строк.
- **`WordStates` не хранит перевод.** Всё содержимое берётся из `content.db` по
  `conceptId`. Это позволяет обновить контент, не трогая прогресс.
- При смене языка изучения `WordStates` не удаляются, а фильтруются по языку
  через `content.db` — если игрок вернётся к немецкому через полгода, прогресс
  будет на месте. Значит, `conceptId` должен быть уникален глобально, а не в
  пределах языка.

---

## Облачный снимок (M6)

Один JSONB на пользователя, как в `athlete_index`:

```jsonc
{
  "version": 1,
  "player": { /* Players */ },
  "wordStates": [ /* WordStates */ ],
  "constellations": [ /* ConstellationProgress */ ],
  "sessions": [ /* агрегаты, не все строки */ ],
  "customConcepts": [ /* CustomConcepts */ ]
}
```

Этот снимок **сейчас никуда не уходит**: облако удалено вместе с экспортом
(см. PLAN_M0_M8.md, «Отказ от сети»). Формат описан здесь потому, что вернётся он
именно в таком виде — и `Reviews` в него по-прежнему не попадут: журнал нужен
для локального дообучения, он большой и на другом устройстве бесполезен.
