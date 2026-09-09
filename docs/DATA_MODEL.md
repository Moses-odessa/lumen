# Модель данных

Две базы, никогда не пересекающиеся по таблицам.

- **`content.db`** — read-only, схема **v5**, собирается на машине разработчика
  через `tool/build_content.dart`, кладётся в `assets/content/<lang>.db`,
  копируется в support-директорию при первом запуске и открывается отдельным
  `NativeDatabase`. На устройстве **не мигрируется** — при обновлении
  заменяется целиком.

  Копия в support-директории сверяется с ассетом по длине **и первым ста
  байтам** — это заголовок SQLite, где лежит `user_version`. Одной длины не
  хватало: сборка с новой схемой, случайно совпавшая по размеру со старой
  копией, оставляла старый файл на месте, и первый же запрос падал с
  «пересоберите контент» на устройстве, где пересобрать нечего.
- **`user.db`** — Drift со схемой и миграциями, схема v6, только состояние
  игрока.

Причина разделения: контент большой, полностью детерминированный и общий для
всех; пользовательские данные маленькие, персональные и мигрируют. Смешивать их
в одной базе — значит гонять миграции по всему контенту при каждом обновлении
курса.

---

## content.db — фразы и их переводы

**Единица изучения — фраза, отдельного слова в игре нет вовсе.** Игра стала
разговорником: фраза сама себе словарная запись — у неё есть ярус, созвездие,
порядок внутри темы, текст и перевод. Пять таблиц, и ни одной лишней:

```sql
-- Языки базы: язык объявляет о себе сам, а не перечисляется в коде.
languages (
  code         TEXT PRIMARY KEY,   -- 'de', 'uk'
  role         TEXT NOT NULL,      -- 'native' | 'target' | 'both'
  status       TEXT NOT NULL,      -- 'draft' | 'launched'
  name         TEXT NOT NULL,      -- самоназвание: 'Українська'
  phrases      INTEGER NOT NULL    -- покрытие: считается при сборке
);

-- Фраза — единица изучения. `text` готов к показу: скрытых частей у фразы
-- нет, подстановку делать нечем и незачем.
phrases (
  id           TEXT PRIMARY KEY,   -- 'about_me_a0_01'
  lang         TEXT NOT NULL,      -- язык изучения, на котором она написана
  tier         TEXT NOT NULL,      -- 'a0' | 'a1' | 'a2' | 'b1' | 'b2'
  constellation TEXT NOT NULL,     -- 'about_me', 'cafe_food'
  idx          INTEGER NOT NULL,   -- порядок внутри созвездия и яруса
  text         TEXT NOT NULL,      -- 'Ich heiße ...'
  register     TEXT                -- 'formal' | 'casual', необязательно
);

-- Перевод фразы на родной язык. Приходит из файла родного языка, а не из
-- файла фразы: язык добавляется одним файлом и не правит файлы других.
phrase_translations (
  phrase_id    TEXT NOT NULL,
  lang         TEXT NOT NULL,
  text         TEXT NOT NULL,
  PRIMARY KEY (phrase_id, lang)
);

-- Набор для калибровки: отобранные фразы по ярусам.
calibration_items (
  id           TEXT PRIMARY KEY,
  tier         TEXT NOT NULL,
  phrase_id    TEXT NOT NULL,
  kind         TEXT NOT NULL       -- сегодня всегда 'phrase'
);

-- Метаданные сборки: из чего собран этот ассет.
content_meta (
  key          TEXT PRIMARY KEY,
  value        TEXT NOT NULL
);

CREATE INDEX phrases_constellation_tier ON phrases (constellation, tier);
CREATE INDEX phrase_translations_lang   ON phrase_translations (lang);
CREATE INDEX calibration_tier           ON calibration_items (tier);
```

**`phrases.idx` — порядок, как он написан в файле контента.** Прежнюю
последовательность знакомства задавала частотность слова
(`concepts.freq_rank`), а у фразы частотности нет и быть не может: «Zum
Frühstück esse ich Brot» не встречается в корпусе ни разу. Порядок решает
автор, и решает он его порядком строк в файле.

**`calibration_items.kind` сегодня всегда `phrase`.** Поле оставлено потому,
что видов вопроса о фразе больше одного — узнать перевод, узнать на слух, — и
различать их придётся. Прежнее значение `word` исчезло вместе со словом.

**В `content_meta` восемь ключей:** `lang`, `schema_version`, `phrases`,
`constellations`, `languages`, `launched_tiers`, `source_hash`,
`source_revision`. Первые пять отвечают на вопрос «что это за контент»,
`launched_tiers` — машинная граница правила «ярус не запускается без вычитки»
(её читает рантайм), последние два — «из каких исходников он собран».

**Почему `content_meta`, а не просто версия в `PRAGMA user_version`.**
`user_version` нужен Drift, чтобы не запускать миграции, и больше ни для чего
не годится. По собранному ассету надо уметь ответить на вопрос «что это за
контент и из каких исходников он собран» — и из приложения тоже, а не только
из сборочного лога. **Метки времени в метаданных нет намеренно:** она сделала
бы каждую пересборку новым файлом в git и сломала бы правило воспроизводимости
из [CONTENT_PIPELINE.md](CONTENT_PIPELINE.md). Вместо неё — `source_hash` (хеш
YAML-исходников) и `source_revision` (короткий git-хеш); при неизменных
исходниках и неизменной ревизии две сборки подряд дают байт-в-байт один файл.

**DDL живёт в `tool/content_schema.dart`.** Он один для сборщика и валидатора,
и обязан совпадать с тем, что генерирует Drift для `ContentDatabase`.
Расхождение имён колонок означает падение у игрока на первом запросе, поэтому
шов закрыт тестом `test/data/content_schema_test.dart`, который поднимает базу
из DDL инструмента и выполняет по ней настоящие запросы Drift.

Одна деталь Drift, которую видно только в коде: колонка `text` объявлена
геттером `sentence` с `named('text')`. `text()` в Drift — билдер колонки, и
`TextColumn get text => text()()` рекурсивно возвращает сам себя. Имя в SQL
при этом остаётся `text`.

### Почему неверных вариантов в базе нет вовсе

Качество круга целиком определяется вариантами вокруг, и раньше они лежали в
контенте: таблица `distractors`, у каждого слова не меньше двух тематических и
трёх созвучных, около 31 000 единиц ручной работы на полный курс. Довод был
верный — случайные слова превращают игру в угадайку, а созвучность живёт в
фонетике, и подобрать её рантаймом нельзя.

Сегодня варианты не хранятся и не пишутся: **вокруг фразы стоят другие фразы,
которые игрок уже знает.** Новое даётся методом исключения — пять знакомых и
одно новое, — и выдумать несуществующее слово при этом структурно невозможно.
Пул собирает загрузчик сессии, у которого есть память игрока; сборщик вопросов
берёт из начала пула и про яркость не знает ничего.

### Что ушло из схемы и что каждая таблица охраняла

Схема дошла до v5 через шесть удалённых таблиц из одиннадцати. Записи ниже
нужны затем, чтобы удалённое не выглядело потерянным:

- **`concepts`** — смысл, не привязанный к языку: ярус, созвездие, часть речи,
  частотность. Держал скелет курса и порядок знакомства. Фраза несёт ярус и
  созвездие сама, а частотности у неё нет.
- **`lexemes`** — как концепт выглядит в конкретном языке: форма, артикль,
  род, множественное число, пометка. Отсюда росли проверки «артикль не
  противоречит роду» и «пометка — код, а не свободный текст»: пара «die / n»
  учит игрока неверному роду и ничем себя не выдаёт.
- **`distractors`** — заранее подобранные неверные варианты, тематические и
  созвучные. См. раздел выше.
- **`phrase_slots`** — пропуски фразы по порядку слева направо. Фраза
  хранилась разобранной, потому что её собирала механика вставки слов.
- **`phrase_orders`** — сборки предложения, которые тоже принимаются верными:
  немецкий позволяет вынести в начало почти любой член предложения, и
  собранный из своих же слов законный другой порядок — не ошибка игрока.
  Таблица сама была починкой: до неё на том же месте стояли `phrase_options`
  (посторонние слова для пропуска), и шесть раундов вычитки ушло на то, чтобы
  выяснить, что посторонние слова встают в рамку предложения не хуже верного.
- **`phrase_concepts`** — какие слова закрывает фраза. Непривязанная фраза не
  зажигала ни одной звезды и не попадала ни в один уровень; звездой стала сама
  фраза, и связывать её больше не с чем.

Подробности — в шапке `tool/content_schema.dart` (история версий) и в
[CONTENT_PIPELINE.md](CONTENT_PIPELINE.md), раздел «История».

---

## user.db — состояние игрока (Drift)

```dart
/// Игрок — одна строка (id = 1).
class Players extends Table {
  IntColumn  get id            => integer().withDefault(const Constant(1))();
  TextColumn get targetLang    => text()();            // что учим
  TextColumn get nativeLang    => text()();            // язык подсказок
  TextColumn get uiLang        => text().nullable()(); // интерфейс, null = системный
  TextColumn get tier          => text()();            // текущий ярус
  BoolColumn get calibrated    => boolean().withDefault(const Constant(false))();
  IntColumn  get orbit         => integer().withDefault(const Constant(0))();
  IntColumn  get sparks        => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();
  IntColumn  get missedInRow   => integer().withDefault(const Constant(0))();
  BoolColumn get freePace      => boolean().withDefault(const Constant(false))();
  BoolColumn get soundEnabled  => boolean().withDefault(const Constant(true))();
  DateTimeColumn get eclipseUntil => dateTime().nullable()();  // пауза орбиты
  IntColumn  get preferredHour => integer().nullable()();      // когда играет
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false))();
}

/// Состояние одной единицы памяти. Сегодня это всегда фраза.
/// Источник правды по памяти — difficulty/stability/lastReview.
@TableIndex(name: 'word_states_due_lm', columns: {#due, #lmCached})
class WordStates extends Table {
  TextColumn     get itemId     => text()();          // id фразы в content.db
  TextColumn     get kind       => text().withDefault(const Constant('word'))();
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
  @override Set<Column> get primaryKey => {itemId};
}

/// Журнал ответов: нужен и для дообучения параметров FSRS, и для аналитики.
class Reviews extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  TextColumn     get itemId    => text()();
  DateTimeColumn get at        => dateTime()();
  IntColumn      get latencyMs => integer()();
  TextColumn     get mode      => text()();           // код механики
  BoolColumn     get correct   => boolean()();
  IntColumn      get grade     => integer()();        // 1..4, выведено из latency
}

/// Отложенное обслуживание: что миграция попросила сделать, но сделать в
/// момент миграции не могла. См. «Правила, которые легко нарушить».
class Maintenance extends Table {
  TextColumn get key   => text()();
  TextColumn get value => text()();
  @override Set<Column> get primaryKey => {key};
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

**Имена, которые лгут наполовину, оставлены сознательно.** `WordStates`,
`CustomConcepts` и `Sessions.newWords` говорят «слово», а хранят фразу.
Переименование таблицы в Drift — это миграция с переносом данных, то есть
риск потерять единственный экземпляр прогресса ради точности имени; резервной
копии у игрока нет. Цена названа здесь, чтобы имя не читалось как утверждение
о модели: единица памяти сегодня одна, и это фраза.

---

## Правила, которые легко нарушить

- **`lmCached` — производная.** Считается из `(difficulty, stability, lastReview)`
  на момент запроса и сохраняется только чтобы сортировать «самые тусклые»
  индексом, а не в памяти. При расхождении верна тройка FSRS.
- **`due` — тоже производная**, но её удобно материализовать: планировщик берёт
  пул одним запросом `WHERE due <= now ORDER BY lm_cached ASC LIMIT 40`, и под
  него стоит индекс `word_states_due_lm`.
- **`Reviews` растёт неограниченно.** Раз в месяц схлопывать записи старше
  полугода в агрегаты, иначе база у активного игрока за год перевалит за
  сотню тысяч строк.
- **`WordStates` не хранит текст.** Всё содержимое берётся из `content.db` по
  `itemId`. Это позволяет обновить контент, не трогая прогресс.
- При смене языка изучения `WordStates` не удаляются, а фильтруются по языку
  через `content.db` — если игрок вернётся к немецкому через полгода, прогресс
  будет на месте. Значит, `itemId` должен быть уникален глобально, а не в
  пределах языка; уникальность идентификаторов фраз проверяет валидатор
  контента.
- **`kind` в `WordStates` никто не пишет.** Колонка добавлена миграцией v4 под
  фразы, но `applyAnswer` её не задаёт, и все строки лежат со значением по
  умолчанию `word` — включая те, чей `itemId` на самом деле идентификатор
  фразы. Полагаться на `kind` нельзя. Чистка памяти определяет принадлежность
  членством в множестве идентификаторов фраз (`ContentDatabase.allPhraseIds`),
  а не типом; после перехода на разговорник это множество и есть весь контент.
- **Миграция `user.db` не видит `content.db`.** Базы отдельные, с отдельными
  исполнителями, и контентную открывают по языку изучения, скопировав из
  ассетов уже после старта. Поэтому чистка «убрать память о фразах, которых в
  контенте больше нет» не может жить в `MigrationStrategy`: миграция кладёт
  метку `pending_item_sweep` в `Maintenance`, а `bootstrapPersistence` делает
  работу, когда оба файла открыты, и метку снимает. Пустой список известных
  идентификаторов игнорируется: это значит, что контент не открылся, а не что
  он опустел, — снести весь прогресс из-за неудачного чтения ассета
  несоизмеримо с задачей.
- **Смена корпуса — это именно тот случай.** Разговорник заменил
  идентификаторы целиком: от 864 концептов и 432 фраз не осталось ни одного
  совпадающего id. Метка обслуживания и есть механизм, которым такая замена
  не оставляет игроку очередь повторений на пустоту.
- **Резервной копии нет, и это решение.** Переустановка лечится повторной
  калибровкой за пару минут. Значит, `user.db` — не кеш, а единственный
  экземпляр данных, и терять его нельзя ни при какой миграции.

### История миграций `user.db`

Схема v6. Каждый шаг оставлен в `MigrationStrategy` с причиной, потому что
установленная база у автора существует, даже если релиза не было:

- **v2** — затмения, час напоминания и сами напоминания (M5).
- **v3** — удалена таблица `daily_challenge_results`: ночной вызов убран
  вместе с хостингом, а таблица под фичу, которой нет, — это мусор, который
  однажды примут за рабочие данные.
- **v4** — `concept_id` переименован в `item_id` в `WordStates` и `Reviews`,
  добавлена колонка `kind`. Фразы стали такими же единицами памяти, как
  слова: своё состояние FSRS, своя яркость, своё место в очереди повторений.
  До этого фразы памяти не имели вовсе и показывались по одному разу — для
  разговорника это означало бы, что заучить фразу невозможно в принципе.
- **v5** — аркадные заходы: сессия помнит, в каком заходе и на каком его
  уровне сыграна. Старые записи остаются с `null`, и это не пробел в данных, а
  честное «тогда заходов не было».
- **v6** — метка чистки памяти о единицах, которых нет в контенте.

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
