// Проверка отчёта независимой вычитки и выгрузка контента для неё.
//
// Вторая половина процесса, описанного в docs/CONTENT_REVIEW_PROMPT.md:
// промт объясняет, что проверять, а этот скрипт проверяет сам отчёт.
//
//   dart run tool/verify_audit.dart capture
//   dart run tool/verify_audit.dart stats
//   dart run tool/verify_audit.dart concepts a0 doctor food
//   dart run tool/verify_audit.dart phrases a0
//   dart run tool/verify_audit.dart verify-report docs/<отчёт>.yaml
//
// `verify-report` отвечает на вопрос, который иначе задать некому: описывает
// ли отчёт тот контент, который лежит здесь сейчас. Аудит идёт долго, за это
// время дерево уходит вперёд, и половина находок может быть уже исправлена —
// а по тексту отчёта этого не видно. Скрипт сверяет поле `current` каждой
// находки с исходником и падает на первом расхождении.
//
// ── О чём этот скрипт говорит после перехода на разговорник ───────────────
//
// Файлы он разбирает сам, YAML-ом, а не через `content_sources.dart`, поэтому
// переход на фразовую модель его не задел ни компиляцией, ни работой. Но
// режимы `forms`, `capture`, `stats` и `concepts` описывают словарный слой —
// концепты и немецкие лексемы. Пайплайн их больше не читает и в базу не
// отгружает (почему — в докстроке `ContentSources`), а на диске они остались
// материалом, по которому пишутся короткие фразы. Значит скрипт по-прежнему
// полезен, но говорит о материале; о том, что уезжает игроку, говорит режим
// `phrases`.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Снимок контента для выгрузки. Лежит в `.dart_tool/`: это промежуточный
/// файл, а не исходник.
final _snapshot = File('.dart_tool/content_review_snapshot.json');

/// Язык изучения, чьи фразы попадают в выгрузку.
const targetLang = 'de';

/// YAML-файлы каталога в стабильном порядке. Порядок значим: выгрузка
/// сравнивается между прогонами.
List<File> _yamlFiles(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

dynamic _plain(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _plain(v)));
  }
  if (value is List) return value.map(_plain).toList();
  return value;
}

dynamic _load(String path) => _plain(loadYaml(File(path).readAsStringSync()));

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('нужен режим: capture | stats | concepts | phrases | '
        'verify-report');
    exitCode = 1;
    return;
  }

  switch (args.first) {
    case 'forms':
      _forms(args.length > 1 ? args[1] : 'HEAD');
    case 'verify-report':
      _verifyReport(args[1]);
    case 'capture':
      _capture();
    case 'stats':
      _stats();
    default:
      _dump(args);
  }
}

/// Перечисляет изменившиеся `form` относительно git-ссылки.
///
/// Это самая дешёвая защита от самой дорогой ошибки при правке контента
/// скриптом. Дистракторов у концепта пять, а форма одна, и замена «первого
/// вхождения» слова попадает в неё чаще, чем кажется: у concepts
/// `complaints_noun` форма была `Beschwerden`, а замена дистрактора
/// `Beschwerde` превратила её в `Beschwerlichkeitn` — слово, которого нет.
///
/// Поймать это проверкой нельзя: чтобы отличить испорченное слово от
/// настоящего, нужен словарь немецкого с разбором составных слов. Зато
/// можно посмотреть глазами на короткий список: форм меняется единицы, и
/// каждая должна быть намеренной.
void _forms(String ref) {
  final head = Process.runSync(
    'git',
    ['show', '$ref:content/lang/de.yaml'],
    stdoutEncoding: utf8,
  );
  if (head.exitCode != 0) {
    stderr.writeln('не читается $ref: ${head.stderr}');
    exitCode = 1;
    return;
  }

  Map<String, String> formsOf(String yaml) {
    final lexemes = _plain(loadYaml(yaml))['lexemes'] as Map;
    return {
      for (final e in lexemes.entries) '${e.key}': '${e.value['form']}',
    };
  }

  final before = formsOf(head.stdout as String);
  final now = formsOf(File('content/lang/de.yaml').readAsStringSync());

  final changed = <String>[];
  for (final entry in now.entries) {
    final was = before[entry.key];
    if (was == null) {
      changed.add('+ ${entry.key}: ${entry.value}');
    } else if (was != entry.value) {
      changed.add('  ${entry.key}: $was → ${entry.value}');
    }
  }
  for (final key in before.keys) {
    if (!now.containsKey(key)) changed.add('- $key: ${before[key]}');
  }

  if (changed.isEmpty) {
    stdout.writeln('Формы не менялись относительно $ref.');
    return;
  }
  stdout.writeln('Изменённых форм относительно $ref: ${changed.length}');
  for (final line in changed..sort()) {
    stdout.writeln(line);
  }
}

/// Сверяет отчёт с исходниками. Падает на первом расхождении: отчёт, который
/// описывает не тот контент, лучше не применять вовсе, чем применять частями.
void _verifyReport(String path) {
  final report = _load(path);
  final docs = <String, dynamic>{};
  final counts = <String, int>{};
  final keys = <String>{};

  for (final finding in report['findings']) {
    final file = finding['file'] as String;
    final doc = docs.putIfAbsent(file, () => _load(file));
    final key =
        '${finding['concept']}/${finding['field']}/${finding['phrase'] ?? ''}';
    if (!keys.add(key)) throw StateError('Находка встречается дважды: $key');

    dynamic actual;
    if (finding['field'] == 'phrase') {
      // Фразы переехали: файл содержит tiers.<ярус> списком, без
      // промежуточного ключа `phrases`. Поддерживаются оба вида — отчёт
      // может быть снят до переезда, и падать на этом бессмысленно.
      final node = doc['tiers'][finding['tier']];
      final list = node is List ? node : (node['phrases'] as List);
      final phrase = list.singleWhere((p) => p['id'] == finding['phrase']);
      final answers = phrase['answers'] ?? phrase['answer'];
      actual = {'template': phrase['template'], 'answer': answers};

      final proposal = finding['proposed'];
      if (proposal != null) {
        // Раньше здесь требовался ровно один слот. Теперь пропусков может
        // быть несколько — но их число обязано совпадать с числом ответов,
        // иначе в собранном предложении останется пустое место.
        final slots =
            RegExp(r'\{[^}]+\}').allMatches(proposal['template']).length;
        final proposed = proposal['answers'] ?? proposal['answer'];
        final count = proposed is List ? proposed.length : 1;
        if (slots == 0) {
          throw StateError('В предложенном шаблоне нет слота: $key');
        }
        if (slots != count) {
          throw StateError(
            'В предложенном шаблоне $slots пропусков, а ответов $count: $key',
          );
        }
      }
    } else {
      final lex = doc['lexemes'][finding['concept']];
      actual = ['near', 'far'].contains(finding['field'])
          ? lex['distractors'][finding['field']]
          : lex[finding['field']];
    }

    if (jsonEncode(actual) != jsonEncode(finding['current'])) {
      throw StateError(
        'Отчёт описывает не текущий контент: $key\n'
        '  в отчёте:  ${jsonEncode(finding['current'])}\n'
        '  в файле:   ${jsonEncode(actual)}',
      );
    }
    if (finding['line'] is! int) throw StateError('Нет номера строки: $key');
    counts.update(finding['severity'], (n) => n + 1, ifAbsent: () => 1);
  }

  const totals = {'error': 'errors', 'doubt': 'doubts', 'style': 'styles'};
  for (final entry in totals.entries) {
    if (counts[entry.key] != report['summary'][entry.value]) {
      throw StateError('Итог по «${entry.key}» не сходится с находками');
    }
  }
  if (report['findings'].length != report['summary']['findings']) {
    throw StateError('Общее число находок не сходится с итогом');
  }

  stdout.writeln(
    'Проверено ${keys.length} находок: YAML, уникальность, текущие значения '
    'в исходниках, номера строк, шаблоны, итоги.',
  );
}

/// Собирает контент в один JSON, чтобы вычитку можно было вести по плоскому
/// списку, а не по девяти файлам созвездий и четырём файлам языков.
void _capture() {
  // Языки не перечисляются списком: их находят перебором каталога — ровно
  // так же, как это делает пайплайн. Список в коде разошёлся бы с
  // содержимым, и выгрузка молча потеряла бы язык.
  final languages = <String, dynamic>{};
  for (final file in _yamlFiles('content/lang')) {
    final data = _load(file.path);
    final code = '${data['lang']}';
    languages[code] = data['lexemes'] ?? <String, dynamic>{};
  }

  final rows = <dynamic>[];
  for (final file in _yamlFiles('content/concepts')) {
    final data = _load(file.path);
    for (final entry in (data['tiers'] as Map).entries) {
      for (final concept in entry.value['concepts'] ?? []) {
        rows.add({
          'topic': data['constellation'],
          'tier': entry.key,
          ...concept,
          for (final lang in languages.keys)
            lang: languages[lang][concept['id']],
        });
      }
    }
  }

  final phrases = <dynamic>[];
  for (final file in _yamlFiles('content/phrases/$targetLang')) {
    final data = _load(file.path);
    for (final entry in (data['tiers'] as Map).entries) {
      for (final phrase in entry.value ?? []) {
        phrases.add({
          'topic': data['constellation'],
          'tier': entry.key,
          ...phrase,
        });
      }
    }
  }

  _snapshot.parent.createSync(recursive: true);
  _snapshot.writeAsStringSync(jsonEncode({'rows': rows, 'phrases': phrases}));
  stdout.writeln(
    'Выгружено ${rows.length} концептов и ${phrases.length} фраз.',
  );
}

void _stats() {
  final data = jsonDecode(_snapshot.readAsStringSync());
  for (final tier in ['a0', 'a1', 'a2', 'b1', 'b2']) {
    final rows = (data['rows'] as List).where((r) => r['tier'] == tier);
    final pos = <String, int>{};
    for (final row in rows) {
      pos.update(row['pos'] ?? 'unset', (n) => n + 1, ifAbsent: () => 1);
    }
    stdout.writeln(jsonEncode({
      'tier': tier,
      'count': rows.length,
      'pos': pos,
      'phrases':
          (data['phrases'] as List).where((p) => p['tier'] == tier).length,
    }));
  }
}

void _dump(List<String> args) {
  final data = jsonDecode(_snapshot.readAsStringSync());
  final tier = args[1];
  final topics = args.skip(2).toSet();
  final phrases = args.first == 'phrases';

  for (final row in data[phrases ? 'phrases' : 'rows']) {
    if (row['tier'] != tier) continue;
    if (topics.isNotEmpty && !topics.contains(row['topic'])) continue;

    if (phrases) {
      stdout.writeln('${row['id']} | ${row['template']} => ${row['answer']} '
          '| ${row['register']} | ${row['concepts']}');
    } else {
      final de = row['de'];
      stdout.writeln(
        '${row['topic']}/${row['id']} | ${row['pos']} | ${row['en']['form']} '
        '| ${row['ru']['form']} | ${de['article'] ?? '-'} ${de['form']} '
        '(${de['gender'] ?? '-'}; pl=${de['plural'] ?? '-'}) '
        '| far=${de['distractors']?['far']} '
        '| near=${de['distractors']?['near']}',
      );
    }
  }
}
