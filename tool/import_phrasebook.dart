/// Импорт разговорника: 1500 фраз на пяти языках → исходники контента.
///
/// Запуск:
///   dart run tool/import_phrasebook.dart
///
/// Источник — `content/_import/phrasebook_1500/<уровень>.json`, по файлу на
/// ярус, плюс `source.json` с провенансом: имя листа, его sha256, число строк
/// и `deviations` — построчный список того, чем выгрузка от листа отличается.
/// Внутри уровня — массив блоков; блок это тема, у него есть заголовок и
/// `rows` — строки с явными ключами:
///
/// ```json
/// {"uk": "...", "de": "...", "en": "...", "ru": "...", "it": "...",
///  "type": "Фраза", "register": "нейтр."}
/// ```
///
/// **Ключи явные, а не позиционные, и это разница с прежним источником.** Тот
/// был массивом из пяти строк (`[uk, de, en, ru, it]`) и необязательной
/// шестой пометки, порядок языков приходилось объяснять комментарием, а
/// перепутанные местами `de` и `en` дали бы не ошибку, а немецкие фразы,
/// уехавшие в английский языковой файл. Такое в этом проекте уже случалось —
/// см. шапку `tool/validate_content.dart` про `en.db` с немецкими фразами.
///
/// Что делает импорт:
///
/// * `content/phrases/de/<тема>.yaml` — немецкие фразы, по файлу на тему, и
///   немецкое имя темы полем `name:` в шапке;
/// * `content/lang/<код>.yaml` — заголовок языка, имена тем на этом языке
///   (раздел `constellations:`) и переводы всех 1500 фраз для uk, ru, en, it.
///
/// Немецкий здесь язык **изучения**, поэтому его строки лежат в `phrases/`, а
/// не в языковом файле: у изучаемого языка нет «перевода», у него есть текст.
///
/// **Тема становится созвездием.** Их пятьдесят, и каждая приносит ровно
/// тридцать фраз — много больше порога появления
/// (`minStarsForConstellation`), поэтому на карте тема видна сразу, как только
/// ярус открыт.
///
/// По ярусам темы распределены неровно: 5 на A0, 9 на A1, 11 на A2, 12 на B1,
/// 13 на B2. Это свойство источника, а не решение импорта: чем выше уровень,
/// тем больше в нём областей речи. Число тем на ярусе читается из контента —
/// нигде в коде оно не зафиксировано.
///
/// **Slug темы — латиница и написан руками.** Заголовки в источнике только
/// по-русски, и slug остаётся именем темы в базе и в памяти игрока.
/// Транслитерация дала бы `pervyy_kontakt` и превратила бы правку заголовка в
/// переименование созвездия, то есть в потерю прогресса.
///
/// **Игроку при этом slug больше не показывается.** Схема v6 завела таблицу
/// имён созвездий, и имя приезжает из `tool/constellation_names.dart`: на
/// языке изучения — полем `name:` в шапке файла фраз, на языках подсказок —
/// разделом `constellations:` языкового файла. Раньше на карте стояло
/// `first_contact` латиницей посреди немецких фраз.
///
/// Имена едут **из кода**, а не остаются в исходниках, и это то же решение,
/// что и со слагами: [_writePhrases] удаляет `content/phrases/de/` целиком,
/// поэтому дописанное руками имя следующий импорт снёс бы молча.
///
/// **Порядок строк — это программа курса.** Порядок внутри темы сохраняется в
/// `idx`, и по нему идёт знакомство. Авторского расписания повторений импорт
/// не читает и раньше не читал: у планировщика своё, построенное на FSRS, и
/// второе ему противоречило бы.
///
/// ── Чего расширение корпуса стоило памяти игрока ──────────────────────────
///
/// Идентификатор фразы — `<slug>_<ярус>_<nn>`, где `nn` — её позиция в теме
/// (теперь до 30, было до 20). То есть идентификатор говорит **где** фраза
/// лежит, а не **что** в ней написано, и держится он на обещании: позиция
/// принадлежит одной и той же фразе.
///
/// При переходе с тысячи на 1500 обещание сдержано наполовину:
///
/// * **761 фраза** сохранила и текст, и позицию в теме — значит сохранила и
///   идентификатор, и всю привязанную к нему память;
/// * **239 идентификаторов несут другой текст.** 235 из них — хвост темы,
///   позиции `nn` 13–20: расширяя тему с 20 фраз до 30, автор не дописал
///   десять, а заменил хвост и дописал. Ещё четыре — в теме `about_me`
///   (`nn` 01, 03, 05, 07), где шаблон с многоточием стал законченным
///   образцом: «Ich heiße ...» → «Ich heiße Alex.».
///
/// Память игрока привязана к идентификатору (`word_states.item_id`,
/// `reviews.item_id` в `user.db`), поэтому на устройстве с прогрессом эти 239
/// записей стали записями **о другой фразе**: интервал, стабильность и
/// история ответов остались от строки, которой в игре больше нет.
///
/// Чистка это не ловит и ловить не может. `needsItemSweep` +
/// `sweepUnknownItems` сравнивают память с `allPhraseIds()` и убирают
/// идентификаторы, которых в контенте нет; здесь все 239 на месте — изменился
/// текст под ними, а текст чистка не видит.
///
/// Названо это прямо, потому что цена невидима, а не потому, что что-то
/// сломано. Дешёвого способа не платить её нет: идентификатор, привязанный к
/// тексту (хеш фразы), сделал бы правку опечатки потерей прогресса, а
/// идентификатор, привязанный к позиции, платит вот этим — и платит только тот
/// игрок, который начал играть до расширения корпуса. Их сегодня столько,
/// сколько устройств у автора.
library;

import 'dart:convert';
import 'dart:io';

import 'constellation_names.dart';
import 'content_schema.dart';

/// Тема → slug созвездия. Пятьдесят тем, по порядку файлов источника.
///
/// Пишется руками осознанно: это единственное место, где решается, как
/// созвездие называется в базе и в памяти игрока. Автоматическая
/// транслитерация превратила бы правку заголовка в переименование созвездия,
/// то есть в потерю прогресса.
///
/// Карта пережила смену корпуса без единой правки: все пятьдесят заголовков
/// листа 1500 совпали с прежними посимвольно. Это проверено, а не принято на
/// веру, — и проверено дважды: ведущим при выгрузке и импортом при каждом
/// запуске, потому что заголовок без слага останавливает импорт (см. ниже).
///
/// Как тема **подписывается** игроку — решение другое и живёт в другом файле,
/// `tool/constellation_names.dart`. Слаг это личность темы, имя — её подпись:
/// первое менять нельзя, второе можно в любой момент.
const Map<String, String> constellationSlugs = {
  // A0
  'Первый контакт': 'first_contact',
  'О себе': 'about_me',
  'Понимание и переспрос': 'understanding',
  'Потребности и помощь': 'needs_help',
  'Место, время и цена': 'place_time_price',
  // A1
  'Люди и семья': 'people_family',
  'Обычный день': 'daily_routine',
  'Кафе и еда': 'cafe_food',
  'Покупка и оплата': 'shopping_payment',
  'Дорога и транспорт': 'transport',
  'Поездка и гостиница': 'travel_hotel',
  'Самочувствие и врач': 'health_doctor',
  'Планы и приглашения': 'plans_invitations',
  'Учёба и связь': 'study_contact',
  // A2
  'Рассказ о прошлом': 'past_stories',
  'Договорённости и сроки': 'arrangements',
  'Жильё и неполадки': 'housing_repairs',
  'Возврат и доставка': 'returns_delivery',
  'Проблемы в поездке': 'travel_trouble',
  'Симптомы и лечение': 'symptoms_treatment',
  'Работа и поиск места': 'work_search',
  'Как учиться': 'learning_how',
  'Чувства и поддержка': 'feelings_support',
  'Аккаунты и цифровой быт': 'digital_life',
  'Сравнение и условия': 'comparison_conditions',
  // B1
  'Мнение и причины': 'opinion_reasons',
  'Согласие и возражение': 'agree_object',
  'Советы и решения': 'advice_decisions',
  'Работа в команде': 'teamwork',
  'Письма и обращения': 'letters_requests',
  'Отношения и границы': 'relations_boundaries',
  'Здоровье и образ жизни': 'health_lifestyle',
  'Деньги и договоры': 'money_contracts',
  'Культура и впечатления': 'culture_impressions',
  'Экология и передвижение': 'ecology_mobility',
  'История и последствия': 'history_consequences',
  'Уточнение и посредничество': 'clarify_mediate',
  // B2
  'Построение аргумента': 'argument_building',
  'Источники и доказательства': 'sources_evidence',
  'Неуверенность и оговорки': 'hedging',
  'Переговоры и компромисс': 'negotiation',
  'Совещания и решения': 'meetings_decisions',
  'Презентации и данные': 'presentations_data',
  'ИИ и цифровая информация': 'ai_information',
  'Общество и права': 'society_rights',
  'Экологические решения': 'ecology_decisions',
  'Работа, обучение и перемены': 'work_change',
  'Убедительное обращение': 'persuasion',
  'Разговорные устойчивые выражения': 'idioms_speech',
  'Итог и переосмысление': 'summary_rethink',
};

/// Колонка «Тип» источника → код `phraseKinds`.
///
/// Три вида, и различие между ними стоит колонки в базе: у идиомы перевод
/// смысловой, а не буквальный, и всякая будущая проверка перевода обязана её
/// пропускать. Подробнее — [phraseKinds] в `content_schema.dart`.
///
/// «Пример» — законченный образец речевой модели, и в корпусе 1500 он стоит
/// ровно там, где в прежней тысяче был шаблон с многоточием: «Ich heiße Alex.»
/// вместо «Ich heiße ...». Автор убрал многоточия («с ним не понятно как
/// читать»), и пометка — единственное, что от них осталось.
const Map<String, String> kinds = {
  'Фраза': 'phrase',
  'Пример': 'example',
  'Идиома': 'idiom',
};

/// Пометка обращения из источника → код `promptTags`.
///
/// «нейтр.» (1313 строк) и «группа» (2) кодом не становятся: закрытый набор
/// пометок это `casual`/`formal`, и добавлять в него код ради двух строк
/// значило бы заводить в игре различие, которого игрок не увидит.
const Map<String, String> registers = {'ты': 'casual', 'Вы': 'formal'};

/// Языки строки в источнике. Порядок теперь ни на что не влияет — ключи в
/// строке явные, — но список остаётся: по нему собираются языковые файлы и
/// проверяется полнота имён созвездий.
const List<String> rowLangs = ['uk', 'de', 'en', 'ru', 'it'];

const Map<String, String> languageNames = {
  'uk': 'Українська',
  'ru': 'Русский',
  'en': 'English',
  'it': 'Italiano',
};

/// Готовность родного языка. Все четыре пришли одним источником и одним
/// качеством — объявлять один из них черновым, а другой запущенным, было бы
/// неправдой.
const Map<String, String> languageStatus = {
  'uk': 'launched',
  'ru': 'launched',
  'en': 'launched',
  'it': 'launched',
};

/// Каталог источника. Число в имени — часть провенанса, а не украшение:
/// рядом с ним в `source.json` лежит sha256 листа, из которого выгружено.
const String sourceDir = 'content/_import/phrasebook_1500';

void main(List<String> args) {
  final root = Directory.current;
  final source = Directory('${root.path}/$sourceDir');
  if (!source.existsSync()) {
    stderr.writeln('нет ${source.path}');
    exitCode = 2;
    return;
  }

  final phrasesByConstellation = <String, List<_Phrase>>{};
  final translations = {for (final lang in rowLangs) lang: <String, String>{}};
  final kindCounts = <String, int>{};
  final registerCounts = <String, int>{};
  var seen = 0;
  var unmarked = 0;

  for (final level in const ['A0', 'A1', 'A2', 'B1', 'B2']) {
    final tier = level.toLowerCase();
    final blocks = _readBlocks(File('${source.path}/$level.json'));

    for (final block in blocks) {
      final title = block['title'] as String;
      final slug = constellationSlugs[title];
      if (slug == null) {
        stderr.writeln('нет slug для темы «$title» — допиши в '
            'constellationSlugs, иначе тема потеряется молча');
        exitCode = 2;
        return;
      }

      final rows = (block['rows'] as List).cast<Map<String, Object?>>();
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final id = '${slug}_${tier}_${(i + 1).toString().padLeft(2, '0')}';

        // Вид и обращение читаются словарями, а не как есть, и незнакомая
        // пометка останавливает импорт. Молчаливое `null` увезло бы в контент
        // фразу без вида — то есть обычную реплику на месте идиомы, чей
        // перевод нарочно не буквален.
        final type = '${row['type']}';
        final kind = kinds[type];
        if (kind == null) {
          stderr.writeln('фраза $id: тип «$type» неизвестен — допиши в kinds '
              'или поправь лист; известны ${kinds.keys.join(", ")}');
          exitCode = 2;
          return;
        }
        kindCounts[kind] = (kindCounts[kind] ?? 0) + 1;

        final mark = '${row['register']}';
        final register = registers[mark];
        if (register == null) {
          // «нейтр.» и «группа» — законное отсутствие пометки, а не ошибка
          // разбора, поэтому считаются отдельно от кодов и печатаются
          // отдельной строкой.
          if (mark != 'нейтр.' && mark != 'группа') {
            stderr.writeln('фраза $id: обращение «$mark» неизвестно — допиши '
                'в registers или поправь лист');
            exitCode = 2;
            return;
          }
          unmarked++;
        } else {
          registerCounts[register] = (registerCounts[register] ?? 0) + 1;
        }

        phrasesByConstellation.putIfAbsent(slug, () => []).add(_Phrase(
              id: id,
              tier: tier,
              idx: i,
              text: '${row['de']}',
              kind: kind,
              register: register,
            ));

        for (final lang in rowLangs) {
          if (lang == 'de') continue;
          translations[lang]![id] = '${row[lang]}';
        }
        seen++;
      }
    }
  }

  // Имена проверяются до первой записи, и это не придирчивость к порядку
  // вызовов: `_writePhrases` начинает с удаления content/phrases/de/ целиком.
  // Отказ на середине оставил бы репозиторий без половины контента — а отказ
  // здесь не трогает ни одного файла.
  final slugs = phrasesByConstellation.keys.toList()..sort();
  final missing = _missingNames(slugs);
  if (missing.isNotEmpty) {
    stderr.writeln(
      'нет имён у ${missing.length} пар «тема/язык»: '
      '${missing.take(8).join(', ')}${missing.length > 8 ? ', …' : ''}\n'
      'Допиши их в tool/constellation_names.dart — по имени темы на каждый из '
      'языков ${rowLangs.join(", ")}. Ни один файл не тронут: без имён карта '
      'подписала бы темы латинскими слагами, а дописать имя в '
      'сгенерированный файл нельзя — следующий импорт снесёт его молча.',
    );
    exitCode = 2;
    return;
  }

  _writePhrases(root, phrasesByConstellation);
  _writeLanguages(root, translations, slugs);

  stdout.writeln('Импорт разговорника');
  stdout.writeln('  фраз: $seen');
  stdout.writeln('  созвездий: ${phrasesByConstellation.length}');
  // Виды и обращения печатаются потому, что теряются молча: колонка,
  // прочитанная не тем ключом, дала бы 1500 обычных фраз без единой идиомы —
  // и контент выглядел бы собранным.
  stdout.writeln('  видов: ${_counts(kindCounts, phraseKinds)}');
  stdout.writeln('  обращений: ${_counts(registerCounts, promptTags)}, '
      'без пометки $unmarked');
  for (final lang in rowLangs.where((l) => l != 'de')) {
    stdout.writeln('  $lang: переводов ${translations[lang]!.length}, '
        'имён созвездий ${slugs.length}');
  }
}

/// Счётчики в порядке закрытого набора, а не в порядке встречи: иначе строка
/// вывода менялась бы от того, какая фраза попалась первой.
String _counts(Map<String, int> counts, Set<String> order) => order
    .map((code) => '$code ${counts[code] ?? 0}')
    .join(', ');

/// Пары «тема/язык», для которых имени не написано.
///
/// Пустая строка считается отсутствием имени, а не именем: пустое `name:`
/// уехало бы в исходники, прошло бы разбор YAML и осталось бы на карте слагом
/// — то есть выглядело бы сделанной работой. Валидатор контента говорит о
/// таком отдельно, но до валидатора дело доходить не должно.
List<String> _missingNames(List<String> slugs) {
  final missing = <String>[];
  for (final slug in slugs) {
    for (final lang in rowLangs) {
      final name = constellationNames[slug]?[lang];
      if (name == null || name.trim().isEmpty) missing.add('$slug/$lang');
    }
  }
  return missing;
}

/// Блоки одного яруса. Файл — обычный JSON целиком, и это тоже упрощение по
/// сравнению с прежним источником: тот был модулем JavaScript с `export
/// default`, и чтение начиналось с поиска первой `[` и отрезания `;` в конце.
List<Map<String, Object?>> _readBlocks(File file) {
  final json = jsonDecode(file.readAsStringSync()) as List;
  return json.cast<Map<String, Object?>>();
}

class _Phrase {
  _Phrase({
    required this.id,
    required this.tier,
    required this.idx,
    required this.text,
    required this.kind,
    this.register,
  });

  final String id;
  final String tier;
  final int idx;
  final String text;
  final String kind;
  final String? register;
}

void _writePhrases(Directory root, Map<String, List<_Phrase>> byName) {
  final dir = Directory('${root.path}/content/phrases/de');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  for (final entry in byName.entries) {
    final byTier = <String, List<_Phrase>>{};
    for (final phrase in entry.value) {
      byTier.putIfAbsent(phrase.tier, () => []).add(phrase);
    }

    final out = StringBuffer()
      ..writeln('# Сгенерировано: dart run tool/import_phrasebook.dart')
      ..writeln('# Источник: $sourceDir')
      ..writeln('#')
      ..writeln('# Правки руками не запрещены, но следующий импорт их снесёт:')
      ..writeln('# правь источник, а не этот файл.')
      ..writeln('lang: de')
      ..writeln('constellation: ${entry.key}')
      // Имя темы на языке изучения стоит рядом с самим языком изучения: у
      // немецкого нет «перевода» имени, у него есть текст — ровно так же, как
      // с фразой ниже. Имена языков подсказок лежат в их языковых файлах.
      ..writeln('$constellationNameField: '
          '${_yaml(constellationNames[entry.key]!['de']!)}')
      ..writeln('tiers:');

    for (final tier in tiers) {
      final phrases = byTier[tier];
      if (phrases == null) continue;
      out.writeln('  $tier:');
      for (final phrase in phrases..sort((a, b) => a.idx.compareTo(b.idx))) {
        out.writeln('    - id: ${phrase.id}');
        out.writeln('      text: ${_yaml(phrase.text)}');
        // `kind: phrase` не пишется, хотя таковы четыре фразы из пяти:
        // обычная реплика — умолчание чтения (`defaultPhraseKind`), и
        // 1231 строка «этот случай обычный» спрятала бы 269 строк, ради
        // которых поле и заведено. В `idioms_speech.yaml` пометка стоит у всех
        // тридцати фраз, и это видно с первого взгляда на файл.
        if (phrase.kind != defaultPhraseKind) {
          out.writeln('      kind: ${phrase.kind}');
        }
        if (phrase.register != null) {
          out.writeln('      register: ${phrase.register}');
        }
      }
    }

    File('${dir.path}/${entry.key}.yaml').writeAsStringSync(out.toString());
  }
}

void _writeLanguages(
  Directory root,
  Map<String, Map<String, String>> byLang,
  List<String> slugs,
) {
  for (final lang in byLang.keys) {
    if (lang == 'de') continue;
    final out = StringBuffer()
      ..writeln('# Сгенерировано: dart run tool/import_phrasebook.dart')
      ..writeln('# Источник: $sourceDir')
      ..writeln('#')
      ..writeln('# Язык подсказок: заголовок, имена тем и переводы фраз.')
      ..writeln('# Лексем здесь больше нет — единицей изучения стала фраза.')
      ..writeln('lang: $lang')
      ..writeln('role: native')
      ..writeln('status: ${languageStatus[lang]}')
      // `name:` заголовка — самоназвание языка, а не имя темы: два поля с
      // одним написанием в двух видах файлов, см. `content_schema.dart`.
      ..writeln('name: ${languageNames[lang]}')
      // Имена тем идут выше переводов: их пятьдесят против полутора тысяч, и
      // файл должен читаться сверху вниз — сначала то, чем язык объявляет
      // себя, потом карта, потом фразы.
      ..writeln('$constellationNamesSection:');

    for (final slug in slugs) {
      out.writeln('  $slug: ${_yaml(constellationNames[slug]![lang]!)}');
    }

    out.writeln('phrases:');

    final ids = byLang[lang]!.keys.toList()..sort();
    for (final id in ids) {
      out.writeln('  $id: ${_yaml(byLang[lang]![id]!)}');
    }

    File('${root.path}/content/lang/$lang.yaml')
        .writeAsStringSync(out.toString());
  }
}

/// Строка в двойных кавычках с экранированием.
///
/// Кавычки не «на всякий случай»: во фразах есть двоеточия, вопросительные
/// знаки и кавычки, а немецкое `null` YAML читает пустотой — это уже стоило
/// проекту одной поломки сборки в другом файле и с другим сообщением.
String _yaml(String value) {
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
