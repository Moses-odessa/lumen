/// Импорт разговорника: 1000 фраз на пяти языках → исходники контента.
///
/// Запуск:
///   dart run tool/import_phrasebook.dart
///
/// Источник — `content/_import/phrasebook_1000/<уровень>.mjs`, по файлу на
/// ярус. Внутри `export default` и массив блоков; блок это тема, у него есть
/// заголовок, цель и `rows` — строки по пять языков:
/// `[uk, de, en, ru, it]` и необязательная шестая пометка регистра.
///
/// Что делает импорт:
///
/// * `content/phrases/de/<тема>.yaml` — немецкие фразы, по файлу на тему;
/// * `content/lang/<код>.yaml` — заголовок языка и переводы всех 1000 фраз
///   для uk, ru, en, it.
///
/// Немецкий здесь язык **изучения**, поэтому его строки лежат в `phrases/`, а
/// не в языковом файле: у изучаемого языка нет «перевода», у него есть текст.
///
/// **Тема становится созвездием.** Их пятьдесят, по десять на ярус, и
/// каждая приносит двадцать фраз — больше порога появления
/// (`minStarsForConstellation`), поэтому на карте тема видна сразу, как
/// только ярус открыт.
///
/// **Slug темы — латиница и написан руками.** Заголовки в источнике только
/// по-русски, а созвездие показывается игроку как есть (так же, как раньше
/// показывались `city` и `food`). Транслитерация дала бы `pervyy_kontakt`;
/// осмысленный английский slug читается лучше и совпадает по стилю с тем, что
/// было. Правильный ответ — переводить имя темы на язык игрока, как
/// переводится фраза, но для этого нужна таблица имён созвездий, которой ещё
/// нет: записано в PLAN.md.
///
/// **Порядок строк — это программа курса.** У блока есть `review` — номера
/// прежних блоков, к которым он возвращается. Импорт этого не читает: у
/// планировщика своё расписание повторений, построенное на FSRS, и второе,
/// авторское, ему противоречило бы. Но порядок внутри блока сохраняется в
/// `idx`, и по нему идёт знакомство.
library;

import 'dart:convert';
import 'dart:io';

/// Тема → slug созвездия. Пятьдесят тем, по порядку файлов источника.
///
/// Пишется руками осознанно: это единственное место, где решается, как
/// созвездие называется в базе и в памяти игрока. Автоматическая
/// транслитерация превратила бы правку заголовка в переименование созвездия,
/// то есть в потерю прогресса.
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

/// Пометка регистра из источника → код `promptTags`.
///
/// «группа» и «нейтр.» кодом не становятся: закрытый набор пометок это
/// `casual`/`formal`, и добавлять в него код ради двух строк значило бы
/// заводить в игре различие, которого игрок не увидит.
const Map<String, String> registers = {'ты': 'casual', 'Вы': 'formal'};

/// Языки строки в источнике, по порядку.
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

void main(List<String> args) {
  final root = Directory.current;
  final source = Directory('${root.path}/content/_import/phrasebook_1000');
  if (!source.existsSync()) {
    stderr.writeln('нет ${source.path}');
    exitCode = 2;
    return;
  }

  final phrasesByConstellation = <String, List<_Phrase>>{};
  final translations = {for (final lang in rowLangs) lang: <String, String>{}};
  var seen = 0;

  for (final level in const ['A0', 'A1', 'A2', 'B1', 'B2']) {
    final tier = level.toLowerCase();
    final blocks = _readBlocks(File('${source.path}/$level.mjs'));

    for (final block in blocks) {
      final title = block['title'] as String;
      final slug = constellationSlugs[title];
      if (slug == null) {
        stderr.writeln('нет slug для темы «$title» — допиши в '
            'constellationSlugs, иначе тема потеряется молча');
        exitCode = 2;
        return;
      }

      final rows = (block['rows'] as List).cast<List<Object?>>();
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i].map((v) => '$v').toList();
        final id = '${slug}_${tier}_${(i + 1).toString().padLeft(2, '0')}';
        final register = row.length > 5 ? registers[row[5]] : null;

        phrasesByConstellation.putIfAbsent(slug, () => []).add(_Phrase(
              id: id,
              tier: tier,
              idx: i,
              text: row[rowLangs.indexOf('de')],
              register: register,
            ));

        for (final lang in rowLangs) {
          if (lang == 'de') continue;
          translations[lang]![id] = row[rowLangs.indexOf(lang)];
        }
        seen++;
      }
    }
  }

  _writePhrases(root, phrasesByConstellation);
  _writeLanguages(root, translations);

  stdout.writeln('Импорт разговорника');
  stdout.writeln('  фраз: $seen');
  stdout.writeln('  созвездий: ${phrasesByConstellation.length}');
  for (final lang in rowLangs.where((l) => l != 'de')) {
    stdout.writeln('  $lang: переводов ${translations[lang]!.length}');
  }
}

List<Map<String, Object?>> _readBlocks(File file) {
  final text = file.readAsStringSync();
  final start = text.indexOf('[');
  final body = text.substring(start).trimRight();
  final json = jsonDecode(body.endsWith(';')
      ? body.substring(0, body.length - 1)
      : body) as List;
  return json.cast<Map<String, Object?>>();
}

class _Phrase {
  _Phrase({
    required this.id,
    required this.tier,
    required this.idx,
    required this.text,
    this.register,
  });

  final String id;
  final String tier;
  final int idx;
  final String text;
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
      ..writeln('# Источник: content/_import/phrasebook_1000')
      ..writeln('#')
      ..writeln('# Правки руками не запрещены, но следующий импорт их снесёт:')
      ..writeln('# правь источник, а не этот файл.')
      ..writeln('lang: de')
      ..writeln('constellation: ${entry.key}')
      ..writeln('tiers:');

    for (final tier in const ['a0', 'a1', 'a2', 'b1', 'b2']) {
      final phrases = byTier[tier];
      if (phrases == null) continue;
      out.writeln('  $tier:');
      for (final phrase in phrases..sort((a, b) => a.idx.compareTo(b.idx))) {
        out.writeln('    - id: ${phrase.id}');
        out.writeln('      text: ${_yaml(phrase.text)}');
        if (phrase.register != null) {
          out.writeln('      register: ${phrase.register}');
        }
      }
    }

    File('${dir.path}/${entry.key}.yaml').writeAsStringSync(out.toString());
  }
}

void _writeLanguages(Directory root, Map<String, Map<String, String>> byLang) {
  for (final lang in byLang.keys) {
    if (lang == 'de') continue;
    final out = StringBuffer()
      ..writeln('# Сгенерировано: dart run tool/import_phrasebook.dart')
      ..writeln('# Источник: content/_import/phrasebook_1000')
      ..writeln('#')
      ..writeln('# Язык подсказок: заголовок плюс переводы фраз. Лексем здесь')
      ..writeln('# больше нет — единицей изучения стала фраза.')
      ..writeln('lang: $lang')
      ..writeln('role: native')
      ..writeln('status: ${languageStatus[lang]}')
      ..writeln('name: ${languageNames[lang]}')
      ..writeln('phrases:');

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
