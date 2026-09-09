// Импорт редакторского словника в контент проекта.
//
//   dart run tool/import_lexicon.dart --dry-run   # только посчитать
//   dart run tool/import_lexicon.dart             # записать файлы
//
// Источник — docs/GERMAN_LEXICON_6000_A0_B2.yaml: 6000 немецких лемм с
// уровнем, темой, частью речи, артиклем и родом. Чего в нём нет: переводов,
// множественных чисел, форм глаголов, дистракторов и фраз. То есть импорт
// даёт **скелет курса**, а не играбельный контент, и всё импортированное
// помечается черновым.
//
// ── Три решения, которые импорт принимает ────────────────────────────────
//
// 1. **Девять существующих созвездий отображаются на темы словника один в
//    один.** doctor→health, shop→shopping, family→people, остальные шесть
//    совпадают по имени. Это не переименование ради красоты: без него
//    матчнутый концепт принадлежал бы двум созвездиям сразу, и «тема» в
//    проекте означала бы две разные вещи.
//
//    Прогресс от переименования не страдает: память привязана к id концепта,
//    а не к созвездию, и `ConstellationProgress` в базе никогда не пишется.
//
// 2. **Совпавшие по форме леммы сохраняют существующие id.** 565 из 6000 уже
//    есть в контенте под осмысленными слугами (`bread_food`) — вместе с
//    прогрессом игрока, переводами на четыре языка, дистракторами и
//    вычиткой. Выбросить это ради единообразия идентификаторов значит
//    заплатить всем содержимым за косметику.
//
// 3. **Новым лемам даются `lx####`, и нумерация append-only.** Редакторские
//    `deNNNN` не годятся идентификаторами: в словнике номер кодирует уровень
//    (id строго возрастает по A0→B2), и дописать слово на A0 без
//    перенумерации нельзя. А перенумерация идентификаторов — это потеря
//    прогресса у всех, кто уже играл.
//
//    Карта «лемма → id» лежит в content/lexicon_ids.yaml и только растёт.
//    Тест сверяет её со снимком: id, однажды выданный, не меняется.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'content_schema.dart';
import 'content_sources.dart';

/// Переименования созвездий, сделанные под темы словника.
///
/// Шесть тем совпали по имени и здесь не перечислены. Карта осталась в коде
/// не как справка, а как проверка: пока старый файл на месте, импорт создаст
/// вторую тему рядом с первой, и слово окажется в двух созвездиях.
const Map<String, String> constellationRenames = {
  'doctor': 'health',
  'shop': 'shopping',
  'family': 'people',
};

/// Русские названия тем — для комментария в шапке файла.
const Map<String, String> topicNames = {
  'dialog': 'Общение и язык',
  'people': 'Люди, семья и отношения',
  'feelings': 'Чувства и характер',
  'time': 'Время, числа и количество',
  'actions': 'Движение и базовые действия',
  'home': 'Дом и повседневный быт',
  'food': 'Еда и приготовление',
  'shopping': 'Покупки, одежда и вещи',
  'health': 'Тело, здоровье и помощь',
  'city': 'Город, жильё и услуги',
  'travel': 'Путешествия и гостеприимство',
  'transport': 'Транспорт и мобильность',
  'work': 'Работа и сотрудничество',
  'learning': 'Учёба и развитие',
  'digital': 'Цифровая жизнь и технологии',
  'leisure': 'Досуг, спорт и увлечения',
  'culture': 'Культура, медиа и творчество',
  'nature': 'Природа, погода и живой мир',
  'environment': 'Экология, энергия и ресурсы',
  'money': 'Деньги, экономика и потребление',
  'society': 'Общество, права и участие',
  'thinking': 'Мышление, решения и аргументация',
  'qualities': 'Свойства, оценка и сравнение',
  'processes': 'Процессы, изменения и методы',
};

/// Запись словника.
class LexiconEntry {
  LexiconEntry({
    required this.editorialId,
    required this.level,
    required this.topic,
    required this.lemma,
    required this.pos,
    this.article,
    this.gender,
    this.number,
    this.note,
    this.usage,
  });

  final String editorialId;
  final String level;
  final String topic;
  final String lemma;
  final String pos;
  final String? article;
  final String? gender;
  final String? number;

  /// Редакторская пометка: как слово вводить, с чем не путать.
  final String? note;

  /// Управление: «sich entschuldigen; jemanden entschuldigen».
  final String? usage;

  String get tier => level.toLowerCase();
}

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final root = Directory.current.path;

  for (final e in constellationRenames.entries) {
    for (final dir in ['concepts', 'lang/$defaultTargetLang', 'phrases/de']) {
      if (File('$root/content/$dir/${e.key}.yaml').existsSync()) {
        stderr.writeln(
          '✗ content/$dir/${e.key}.yaml на месте, а тема словника называется '
          '"${e.value}". Импорт создал бы вторую тему рядом с первой, и слово '
          'оказалось бы в двух созвездиях сразу. Переименуйте файл '
          '(git mv), поправьте в нём constellation и списки в '
          'content/launch.yaml.',
        );
        exitCode = 1;
        return;
      }
    }
  }

  final entries = _readLexicon(File('$root/docs/GERMAN_LEXICON_6000_A0_B2.yaml'));
  stdout.writeln('словник: ${entries.length} лемм');

  final ContentSources existing;
  try {
    existing = ContentSources.load(Directory('$root/content'));
  } on ContentSourceException catch (e) {
    stderr.writeln('✗ исходники: ${e.message}');
    exitCode = 1;
    return;
  }

  final german = existing.languages[defaultTargetLang]?.lexemes ?? const {};
  // Форма → id существующего концепта. Форма, а не смысл: смысл сопоставить
  // нечем, а совпадение написания в немецком почти всегда означает то же
  // слово.
  final byForm = <String, String>{};
  for (final lex in german.values) {
    byForm.putIfAbsent(lex.form, () => lex.conceptId);
  }

  final ids = _IdMap.read(File('$root/content/lexicon_ids.yaml'));

  var matched = 0;
  final assigned = <String, String>{};
  final fresh = <LexiconEntry>[];

  for (final entry in entries) {
    final existingId = byForm[entry.lemma];
    if (existingId != null) {
      assigned[entry.lemma] = existingId;
      matched++;
      continue;
    }
    assigned[entry.lemma] = ids.idFor(entry.lemma);
    fresh.add(entry);
  }

  // Слова контента, которых в словнике нет. Они остаются: часть законно
  // (узкая терминология, которую словник не брал), но среди них и бытовые —
  // Glas, Ecke, Wecker, Kindergarten, Nudeln, Fähre, Studium.
  final lexiconForms = {for (final e in entries) e.lemma};
  final outside = german.values
      .where((lex) => !lexiconForms.contains(lex.form))
      .map((lex) => lex.conceptId)
      .toSet();

  stdout.writeln('  совпало по форме: $matched');
  stdout.writeln('  новых: ${fresh.length}');
  stdout.writeln('  своих, вне словника: ${outside.length}');
  stdout.writeln('  всего концептов станет: ${entries.length + outside.length}');

  final functionWords =
      entries.where((e) => functionWordPos.contains(e.pos)).length;
  stdout.writeln('  из них служебных слов: $functionWords '
      '(звёздами не становятся)');

  if (dryRun) {
    stdout.writeln('\n--dry-run: файлы не тронуты');
    return;
  }

  ids.write(File('$root/content/lexicon_ids.yaml'));
  stdout.writeln('\n→ content/lexicon_ids.yaml (${ids.size} записей)');

  _writeConcepts(root, entries, fresh, assigned, existing);
  _writeGermanLexemes(root, fresh, assigned);
}

/// Файлы концептов: по одному на тему словника.
///
/// Существующие концепты переписываются как были — со своим ярусом, частью
/// речи и частотным рангом. Ярус берётся существующий, а не из словника, и
/// это то же решение, что и с идентификаторами: ярус запущенного A0 вычитан,
/// и переезд слова на A1 по редакторскому мнению отобрал бы у игрока
/// прочитанное.
void _writeConcepts(
  String root,
  List<LexiconEntry> all,
  List<LexiconEntry> fresh,
  Map<String, String> assigned,
  ContentSources existing,
) {
  // Тема → ярус → новые леммы. Порядок словника сохраняется: он же задаёт
  // порядок выдачи идентификаторов.
  final byTopic = <String, Map<String, List<LexiconEntry>>>{};
  for (final e in fresh) {
    (byTopic[e.topic] ??= {}).putIfAbsent(e.tier, () => []).add(e);
  }

  final topics = <String>{
    ...existing.concepts.values.map((c) => c.constellation),
    ...all.map((e) => e.topic),
  }.toList()
    ..sort();

  for (final topic in topics) {
    final file = File('$root/content/concepts/$topic.yaml');
    final out = StringBuffer()
      ..write(_conceptHeader(file, topic))
      ..writeln('constellation: $topic')
      ..writeln('tiers:');

    for (final tier in tiers) {
      final kept = existing.concepts.values
          .where((c) => c.constellation == topic && c.tier == tier);
      final added = byTopic[topic]?[tier] ?? const [];
      if (kept.isEmpty && added.isEmpty) continue;

      out
        ..writeln('  $tier:')
        ..writeln('    concepts:');
      for (final c in kept) {
        out.writeln('      ${_conceptLine(
          id: c.id,
          pos: c.pos,
          freqRank: c.freqRank,
          draft: c.draft,
        )}');
      }
      if (added.isNotEmpty && kept.isNotEmpty) {
        out.writeln('      # ── импортировано из словника, не вычитано ──');
      }
      for (final e in added) {
        out.writeln('      ${_conceptLine(
          id: assigned[e.lemma]!,
          pos: e.pos,
          freqRank: null,
          draft: true,
        )}  # ${e.lemma}');
      }
    }

    file.writeAsStringSync(out.toString());
  }
  stdout.writeln('→ content/concepts/: ${topics.length} тем');
}

String _conceptLine({
  required String id,
  required String pos,
  required int? freqRank,
  required bool draft,
}) {
  final parts = ['id: $id', 'pos: $pos'];
  if (freqRank != null) parts.add('freq_rank: $freqRank');
  if (draft) parts.add('draft: true');
  return '- { ${parts.join(', ')} }';
}

/// Шапка файла темы: у существующих сохраняется дословно, у новых пишется.
///
/// Дословно — потому что в шапках стоят источники и пометки `TODO(data)`,
/// написанные руками. Импорт, стирающий их, обменивал бы знание о том, откуда
/// взяты слова, на единообразие формата.
String _conceptHeader(File file, String topic) {
  if (file.existsSync()) {
    final head = <String>[];
    for (final line in file.readAsLinesSync()) {
      if (!line.startsWith('#')) break;
      head.add(line);
    }
    if (head.isNotEmpty) return '${head.join('\n')}\n';
  }

  final name = topicNames[topic] ?? topic;
  return '''
# Созвездие «$name».
#
# Тема целиком пришла из словника: все слова помечены `draft: true` и в игру
# не идут. Пометка снимается вычиткой — двумя проходами разных моделей с
# записью в content/launch.yaml, — а не правкой ради зелёного валидатора.
#
# Чего у импортированных слов нет и почему:
#   freq_rank — словник частотности не несёт, а выдумать её значило бы
#     записать вымысел в поле, которое читается как измерение;
#   plural и формы глаголов — нужен внешний источник (веха M15);
#   дистракторы — их не пишут руками, их выводят из проверенных форм.
#
# Источник: docs/GERMAN_LEXICON_6000_A0_B2.yaml.
''';
}

/// Немецкие лексемы импортированных слов.
///
/// Дописываются в конец файла темы, а не вписываются между вычитанными: у
/// импортированного слова есть только форма, артикль и род, и мешать его с
/// прочитанным значило бы прятать разницу.
void _writeGermanLexemes(
  String root,
  List<LexiconEntry> fresh,
  Map<String, String> assigned,
) {
  final byTopic = <String, List<LexiconEntry>>{};
  for (final e in fresh) {
    (byTopic[e.topic] ??= []).add(e);
  }
  if (byTopic.isEmpty) {
    stdout.writeln('→ content/lang/de/: новых лексем нет');
    return;
  }

  final dir = Directory('$root/content/lang/$defaultTargetLang');
  dir.createSync(recursive: true);

  for (final entry in byTopic.entries) {
    final topic = entry.key;
    final file = File('${dir.path}/$topic.yaml');
    final out = StringBuffer();

    if (file.existsSync()) {
      out.write(file.readAsStringSync().trimRight());
      out.writeln();
    } else {
      final name = topicNames[topic] ?? topic;
      out
        ..writeln('# Немецкие лексемы созвездия «$name».')
        ..writeln('#')
        ..writeln('# Тема целиком импортирована из словника. У слова есть'
            ' форма, артикль и род —')
        ..writeln('# и всё: множественного числа, форм глагола и дистракторов'
            ' словник не несёт,')
        ..writeln('# а выдумывать их нельзя (docs/CONTENT_PIPELINE.md,'
            ' content/dictionaries/README.md).')
        ..writeln('#')
        ..writeln('# Язык объявлен один раз, в'
            ' content/lang/de/_language.yaml.')
        ..writeln('lang: de')
        ..writeln('lexemes:');
    }

    out.writeln('  # ── импортировано из словника, не вычитано ───────────'
        '──────────────────');
    for (final e in entry.value) {
      // Редакторские пометки идут комментарием, а не полем `note`: `note`
      // уезжает в базу на устройство, а это указания автору контента —
      // как слово вводить и с чем не путать.
      if (e.note != null) out.writeln('  # ${e.note}');
      if (e.usage != null) out.writeln('  # Употребление: ${e.usage}');
      out.writeln('  ${assigned[e.lemma]}:');
      out.writeln('    form: ${_yamlScalar(e.lemma)}');
      if (e.article != null) out.writeln('    article: ${e.article}');
      if (e.gender != null) out.writeln('    gender: ${e.gender}');
      // `number: plural` словника — это pluralia tantum: у слова нет
      // единственного числа. В нашей схеме это не `plural`, а пометка.
      if (e.number == 'plural') out.writeln('    note: только множественное');
    }

    file.writeAsStringSync(out.toString());
  }
  stdout.writeln('→ content/lang/de/: ${byTopic.length} тем, '
      '${fresh.length} лексем');
}

/// Слова, которые YAML прочитает не как слова.
///
/// Немецкий `null` — это ноль, и без кавычек он приезжает в парсер пустотой:
/// `form: null` означает «формы нет». Сборка на этом падает — но падает она
/// в другом файле и с другим сообщением, потому что ошибка не синтаксическая.
/// Остальные — из YAML 1.1: наш парсер их так не читает, но чужой может.
const Set<String> _yamlReserved = {
  'null', 'true', 'false', 'yes', 'no', 'on', 'off', 'y', 'n',
};

/// Кавычки только там, где YAML без них прочитает не то.
String _yamlScalar(String value) {
  if (_yamlReserved.contains(value.toLowerCase())) {
    return "'$value'";
  }
  if (RegExp(r'^[A-Za-zÄÖÜäöüß][A-Za-zÄÖÜäöüß\-]*$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", "''")}'";
}

/// Читает словник. Записи лежат по одной на строку в JSON-подобном виде —
/// разбор построчный, чтобы не держать в памяти дерево YAML на 8000 строк.
List<LexiconEntry> _readLexicon(File file) {
  if (!file.existsSync()) {
    throw ContentSourceException('нет словника: ${file.path}');
  }

  final result = <LexiconEntry>[];
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('- {"id":"')) continue;
    final map = jsonDecode(trimmed.substring(2)) as Map<String, dynamic>;
    result.add(LexiconEntry(
      editorialId: '${map['id']}',
      level: '${map['level']}',
      topic: '${map['topic']}',
      lemma: '${map['lemma']}',
      pos: '${map['pos']}',
      article: map['article'] as String?,
      gender: map['gender'] as String?,
      number: map['number'] as String?,
      note: map['note'] as String?,
      usage: map['usage'] as String?,
    ));
  }
  return result;
}

/// Карта «лемма → id», которая только растёт.
///
/// Append-only не из аккуратности: id — это ключ, по которому у игрока лежит
/// память о слове. Перенумеровать их значит стереть прогресс всем, кто уже
/// играл, и сделать это молча.
class _IdMap {
  _IdMap(this._byLemma, this._next);

  final Map<String, String> _byLemma;
  int _next;

  int get size => _byLemma.length;

  static _IdMap read(File file) {
    if (!file.existsSync()) return _IdMap({}, 1);
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) return _IdMap({}, 1);

    final map = <String, String>{};
    var max = 0;
    final node = doc['ids'];
    if (node is YamlMap) {
      for (final entry in node.entries) {
        final id = '${entry.value}';
        map['${entry.key}'] = id;
        final n = int.tryParse(id.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
        if (n > max) max = n;
      }
    }
    return _IdMap(map, max + 1);
  }

  String idFor(String lemma) => _byLemma.putIfAbsent(
        lemma,
        () => 'lx${(_next++).toString().padLeft(4, '0')}',
      );

  void write(File file) {
    final keys = _byLemma.keys.toList()..sort();
    final out = StringBuffer()
      ..writeln('# Идентификаторы лемм словника. Карта только растёт.')
      ..writeln('#')
      ..writeln('# Генерируется: dart run tool/import_lexicon.dart')
      ..writeln('# Руками не правится, и особенно не перенумеровывается: id —')
      ..writeln('# это ключ, по которому у игрока лежит память о слове.')
      ..writeln('# Перенумеровать их значит стереть прогресс всем, кто уже')
      ..writeln('# играл, и сделать это молча.')
      ..writeln('#')
      ..writeln('# Редакторские deNNNN из словника здесь не используются: там')
      ..writeln('# номер кодирует уровень (id строго возрастает по A0→B2), и')
      ..writeln('# дописать слово на A0 без перенумерации нельзя.')
      ..writeln('ids:');
    for (final lemma in keys) {
      out.writeln('  ${_yamlScalar(lemma)}: ${_byLemma[lemma]}');
    }
    file.writeAsStringSync(out.toString());
  }
}
