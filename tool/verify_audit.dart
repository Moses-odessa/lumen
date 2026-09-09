// Выгрузка контента для независимой вычитки и проверка её отчёта.
//
// Вторая половина процесса из docs/CONTENT_REVIEW_PROMPT.md: промт объясняет
// проверяющему, что искать, а этот скрипт готовит ему данные и проверяет то,
// что он вернул.
//
//   dart run tool/verify_audit.dart stats
//   dart run tool/verify_audit.dart phrases a0
//   dart run tool/verify_audit.dart phrases a0 about_me needs_help
//   dart run tool/verify_audit.dart capture
//   dart run tool/verify_audit.dart verify-report docs/<отчёт>.yaml
//
// `verify-report` отвечает на вопрос, который иначе задать некому: описывает
// ли отчёт тот контент, который лежит здесь сейчас. Вычитка идёт долго, за это
// время дерево уходит вперёд, и часть находок может быть уже исправлена — а по
// тексту отчёта этого не видно. Так и вышло с прежним аудитом: из 263 находок
// 74 описывали уже исправленное.
//
// ── Что здесь изменил разговорник ─────────────────────────────────────────
//
// Скрипт разбирает YAML сам, а не через `ContentSources`, поэтому смена
// единицы изучения не сломала его ни компиляцией, ни запуском — и именно
// поэтому поломку было не видно. Он читал `content/concepts` и `lexemes:` из
// `content/lang/de.yaml`: первого больше нет по этому пути, второго нет вовсе,
// и режимы возвращали пустоту вместо ошибки. Режим `phrases` был хуже
// пустоты: он печатал не исходники, а снимок в `.dart_tool/`, снятый до
// замены корпуса, — то есть выдавал на вычитку 432 фразы, которых в проекте
// уже нет.
//
// Отсюда два правила, которые теперь держит этот файл.
//
// **Печатается только то, что прочитано сейчас.** Снимок пишет режим
// `capture` — он существует затем, чтобы отдать проверяющему один файл вместо
// пятидесяти четырёх, — но ни один режим из него не читает. Снимок, который
// можно показать вместо исходника, однажды это и сделает.
//
// **Номера строк считает скрипт, а не проверяющий.** Прежний контракт требовал
// от отчёта поле `line` и падал без него. Модель проставляет номера строк
// неверно чаще, чем верно, и отчёт целиком отвергался из-за поля, которое
// скрипт умеет вычислить сам по идентификатору фразы.
//
// **Что удалено вместе со словарным слоем.** Режим `forms` перечислял
// изменившиеся немецкие формы относительно git-ссылки — самая дешёвая защита
// от самой дорогой ошибки правки контента скриптом: у концепта было пять
// дистракторов и одна форма, и замена «первого вхождения» слова попадала в
// форму чаще, чем кажется (`Beschwerden` → `Beschwerlichkeitn`, слово,
// которого нет). Форм больше нет: у фразы есть текст, и правка текста это и
// есть предмет вычитки, а не побочный эффект правки чего-то другого.
// Режимы `concepts` и словарная половина `capture`/`stats` печатали концепты
// с лексемами и дистракторами — того, что игрок никогда не увидит.
library;

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Снимок для проверяющего. Лежит в `.dart_tool/`: это выгрузка, а не
/// исходник, и никакой режим её не читает — см. шапку.
final _snapshot = File('.dart_tool/content_review_snapshot.json');

/// Язык изучения, чьи фразы вычитываются.
const targetLang = 'de';

/// Ярусы по порядку. Совпадает с `Tier` в `lib/` и с ярусами в исходниках;
/// список здесь потому, что `tool/` не тянет за собой `lib/`.
const tiers = ['a0', 'a1', 'a2', 'b1', 'b2'];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('нужен режим: stats | phrases <ярус> [темы…] | capture | '
        'verify-report <файл>');
    exitCode = 1;
    return;
  }

  switch (args.first) {
    case 'stats':
      _stats();
    case 'phrases':
      _phrases(args.skip(1).toList());
    case 'capture':
      _capture();
    case 'verify-report':
      if (args.length < 2) {
        stderr.writeln('нужен путь к отчёту');
        exitCode = 1;
        return;
      }
      _verifyReport(args[1]);
    default:
      stderr.writeln('неизвестный режим: ${args.first}');
      exitCode = 1;
  }
}

// ─── Чтение исходников ─────────────────────────────────────────────────────

/// Фраза изучаемого языка вместе с тем, где она лежит.
///
/// Файл и строка нужны обеим сторонам процесса: проверяющему — чтобы указать
/// на место, применяющему правку — чтобы её найти.
class Phrase {
  Phrase({
    required this.id,
    required this.constellation,
    required this.tier,
    required this.text,
    required this.register,
    required this.file,
    required this.line,
  });

  final String id;
  final String constellation;
  final String tier;
  final String text;
  final String? register;
  final String file;
  final int line;
}

/// Перевод фразы: значение и место в языковом файле.
class Translation {
  Translation({required this.text, required this.file, required this.line});

  final String text;
  final String file;
  final int line;
}

/// YAML-файлы каталога в стабильном порядке. Порядок значим: выгрузки
/// сравниваются между прогонами, а `listSync` порядка не обещает.
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

/// Путь через `/` независимо от платформы: он уезжает в отчёты и в вывод, и
/// обратные слэши Windows сделали бы отчёт непереносимым.
String _posix(String path) => path.replaceAll(r'\', '/');

/// Номер строки, на которой в файле стоит `образец`. Единица, а не ноль:
/// номер читает человек и открывает им редактор.
///
/// Ищется первое вхождение: идентификатор в файле уникален (это проверяет
/// валидатор), поэтому первое оно же и единственное. Ноль означает «не нашли»
/// и в вывод не попадает: у всякой прочитанной фразы строка есть по
/// построению.
int _lineOf(List<String> lines, String pattern) {
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(pattern)) return i + 1;
  }
  return 0;
}

/// Все фразы языка изучения, по идентификатору.
///
/// [root] существует ради тестов: проверка, у которой единственный выход это
/// `stdout`, непроверяема, и ровно так этот скрипт однажды сломался молча.
Map<String, Phrase> readPhrases({String root = 'content'}) {
  final result = <String, Phrase>{};

  for (final file in _yamlFiles('$root/phrases/$targetLang')) {
    final data = _load(file.path);
    final lines = file.readAsLinesSync();
    final constellation = '${data['constellation']}';
    final tiersNode = data['tiers'] as Map?;
    if (tiersNode == null) continue;

    for (final entry in tiersNode.entries) {
      for (final phrase in (entry.value as List? ?? const [])) {
        final id = '${phrase['id']}';
        result[id] = Phrase(
          id: id,
          constellation: constellation,
          tier: '${entry.key}',
          text: '${phrase['text']}',
          register: phrase['register'] as String?,
          file: _posix(file.path),
          line: _lineOf(lines, 'id: $id'),
        );
      }
    }
  }
  return result;
}

/// Переводы: код языка → идентификатор фразы → перевод.
///
/// Языки не перечисляются списком, а находятся перебором каталога — так же,
/// как это делает пайплайн. Список в коде разошёлся бы с содержимым, и
/// выгрузка молча потеряла бы язык.
Map<String, Map<String, Translation>> readTranslations({
  String root = 'content',
}) {
  final result = <String, Map<String, Translation>>{};

  for (final file in _yamlFiles('$root/lang')) {
    final data = _load(file.path);
    final code = '${data['lang']}';
    if (code == targetLang) continue;
    final phrases = data['phrases'] as Map?;
    if (phrases == null || phrases.isEmpty) continue;

    final lines = file.readAsLinesSync();
    result[code] = {
      for (final entry in phrases.entries)
        '${entry.key}': Translation(
          text: '${entry.value}',
          file: _posix(file.path),
          line: _lineOf(lines, '${entry.key}:'),
        ),
    };
  }
  return result;
}

// ─── Режимы выгрузки ───────────────────────────────────────────────────────

/// Что в контенте есть: по ярусам, с покрытием переводами.
///
/// Покрытие считается, а не объявляется. Неполный язык — это меньше кругов, а
/// не чужие фразы, и увидеть эту неполноту надо до вычитки: проверять перевод,
/// которого нет, проверяющий будет молча и впустую.
void _stats() {
  final phrases = readPhrases();
  final translations = readTranslations();

  for (final tier in tiers) {
    final ofTier = phrases.values.where((p) => p.tier == tier).toList();
    if (ofTier.isEmpty) continue;

    final registers = <String, int>{};
    for (final phrase in ofTier) {
      registers.update(phrase.register ?? 'unset', (n) => n + 1,
          ifAbsent: () => 1);
    }

    stdout.writeln(jsonEncode({
      'tier': tier,
      'phrases': ofTier.length,
      'constellations': ofTier.map((p) => p.constellation).toSet().length,
      'registers': registers,
      'translations': {
        for (final code in translations.keys.toList()..sort())
          code: ofTier.where((p) => translations[code]![p.id] != null).length,
      },
    }));
  }
}

/// Плоский список яруса: фраза и её переводы.
///
/// Так и подаётся на вычитку. Немецкая строка и переводы стоят рядом
/// намеренно: без них проверяющий не знает, что фраза должна была значить, и
/// не поймает главную ошибку — когда немецкое предложение верное, но не то.
void _phrases(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('нужен ярус: ${tiers.join(' | ')}');
    exitCode = 1;
    return;
  }

  final tier = args.first;
  final topics = args.skip(1).toSet();
  final phrases = readPhrases();
  final translations = readTranslations();

  final selected = phrases.values
      .where((p) => p.tier == tier)
      .where((p) => topics.isEmpty || topics.contains(p.constellation))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  if (selected.isEmpty) {
    stderr.writeln('на ярусе $tier нет фраз'
        '${topics.isEmpty ? '' : ' в темах ${topics.join(', ')}'}');
    exitCode = 1;
    return;
  }

  for (final phrase in selected) {
    stdout.writeln('${phrase.id} | ${phrase.text}'
        '${phrase.register == null ? '' : ' | ${phrase.register}'}');
    for (final code in translations.keys.toList()..sort()) {
      final translation = translations[code]![phrase.id];
      if (translation != null) stdout.writeln('  $code: ${translation.text}');
    }
  }
  stdout.writeln('# фраз: ${selected.length}');
}

/// Один файл вместо пятидесяти четырёх — чтобы вычитку можно было вести по
/// плоскому списку, а не по файлу на созвездие и файлу на язык.
void _capture() {
  final phrases = readPhrases();
  final translations = readTranslations();

  final rows = [
    for (final phrase in phrases.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id)))
      {
        'id': phrase.id,
        'constellation': phrase.constellation,
        'tier': phrase.tier,
        'text': phrase.text,
        if (phrase.register != null) 'register': phrase.register,
        'file': phrase.file,
        'line': phrase.line,
        for (final code in translations.keys)
          code: translations[code]![phrase.id]?.text,
      },
  ];

  _snapshot.parent.createSync(recursive: true);
  _snapshot.writeAsStringSync(jsonEncode({'phrases': rows}));
  stdout.writeln('Выгружено ${rows.length} фраз и '
      '${translations.keys.length} языков подсказок в ${_posix(_snapshot.path)}');
}

// ─── Проверка отчёта ───────────────────────────────────────────────────────

/// Закрытый набор пометок регистра. Дублирует `promptTags` в `lib/` и в
/// `tool/content_schema.dart` по той же причине: `tool/` не тянет `lib/`.
const _registers = {'casual', 'formal'};

/// Итог сверки отчёта с контентом.
///
/// Три списка, а не один, потому что это три разных исхода и решения по ним
/// разные. **Устаревшая** находка — правда о дереве: контент ушёл вперёд,
/// находку надо отложить, а не применять. **Испорченная** — правда об отчёте:
/// его нельзя применять вовсе. **Несошедшийся итог** не относится ни к одной
/// находке и означает, что проверяющий сам себя не сосчитал.
class AuditReview {
  AuditReview({
    required this.findings,
    required this.stale,
    required this.problems,
    required this.summaryProblems,
    required this.places,
    required this.counts,
    required this.summaryChecked,
  });

  /// Сколько находок было в отчёте.
  final int findings;

  /// Находки, описывающие не нынешний контент: ключ, место и оба значения.
  final List<String> stale;

  /// Ошибки в самом отчёте: дубли, пропавшие фразы, чужие поля.
  final List<String> problems;

  /// Итоги, не сошедшиеся с находками.
  final List<String> summaryProblems;

  /// `файл:строка | ключ` для находок, сошедшихся с контентом. Это и есть
  /// список того, что можно применять.
  final List<String> places;

  /// Сколько находок какой важности.
  final Map<String, int> counts;

  /// Были ли в отчёте итоги. Их отсутствие — не ошибка: отчёт без `summary`
  /// неполон, но его находки годны, и терять их из-за отсутствующего поля
  /// значило бы выбрасывать работу целиком из-за оформления.
  final bool summaryChecked;

  /// Сошлось с контентом.
  int get matched => places.length;

  /// Применять отчёт как есть можно только при пустых всех трёх списках.
  bool get clean =>
      stale.isEmpty && problems.isEmpty && summaryProblems.isEmpty;
}

/// Сверяет отчёт вычитки с исходниками.
///
/// Отвечает на один вопрос: описывает ли отчёт нынешний контент? Расхождения
/// собираются **все**, а не первое. Прежняя версия падала на первом, и это
/// противоречило тому, для чего проверка нужна: отчёт надо разделить на
/// открытые находки и уже исправленные, а для этого нужен полный список.
///
/// Возвращает [AuditReview], а не печатает: печать — дело `main`. Проверка,
/// у которой единственный выход это `stdout`, непроверяема тестом, и ровно
/// так этот скрипт полгода выдавал на вычитку удалённый корпус.
AuditReview reviewReport(String path, {String root = 'content'}) {
  final report = _load(path);
  final findings = report['findings'];
  if (findings is! List || findings.isEmpty) {
    return AuditReview(
      findings: 0,
      stale: const [],
      problems: const ['в отчёте нет списка findings'],
      summaryProblems: const [],
      places: const [],
      counts: const {},
      summaryChecked: false,
    );
  }

  final phrases = readPhrases(root: root);
  final translations = readTranslations(root: root);

  // Три разных исхода, и складывать их в один список нельзя: устаревшая
  // находка это правда о дереве, испорченная — о самом отчёте, а несошедшийся
  // итог не относится ни к одной находке.
  final problems = <String>[];
  final summaryProblems = <String>[];
  final stale = <String>[];
  final seen = <String>{};
  final counts = <String, int>{};
  final places = <String>[];

  for (final finding in findings) {
    final id = '${finding['id']}';
    final field = '${finding['field']}';
    final key = '$id/$field';

    if (!seen.add(key)) {
      problems.add('находка встречается дважды: $key');
      continue;
    }

    final phrase = phrases[id];
    if (phrase == null) {
      problems.add('нет фразы с таким id: $id — переименована или удалена');
      continue;
    }

    // Поле — либо своё у фразы, либо код языка подсказок. Третьего у фразы
    // нет: части речи, рода и числа ушли вместе со словарным слоем.
    String? actual;
    String where;
    if (field == 'text') {
      actual = phrase.text;
      where = '${phrase.file}:${phrase.line}';
    } else if (field == 'register') {
      actual = phrase.register;
      where = '${phrase.file}:${phrase.line}';
    } else if (translations.containsKey(field)) {
      final translation = translations[field]![id];
      actual = translation?.text;
      where = translation == null
          ? 'перевода нет'
          : '${translation.file}:${translation.line}';
    } else {
      problems.add('$key: поле не text, не register и не код языка подсказок '
          '(${translations.keys.join(', ')})');
      continue;
    }

    // Поле обязано быть, а значение в нём может быть пустым — и это не то же
    // самое. «У этой фразы регистра нет, а должен быть formal» — законная
    // находка, у которой `current: null` и есть нынешнее состояние. Пока
    // пустота читалась как «поля нет», сверка отвергала именно такие находки:
    // единственные, которые пометку добавляют, а не правят.
    if (!(finding as Map).containsKey('current')) {
      problems.add('$key: нет поля current — сверять нечего');
      continue;
    }
    final claimed = finding['current'];
    if ((claimed == null ? '' : '$claimed') != (actual ?? '')) {
      stale.add('$key ($where)\n'
          '  в отчёте: ${jsonEncode(claimed)}\n'
          '  в файле:  ${jsonEncode(actual)}');
      continue;
    }

    final proposed = finding['proposed'];
    if (proposed != null) {
      final value = '$proposed'.trim();
      if (value.isEmpty) {
        problems.add('$key: предложено пустое значение');
      } else if (value == actual) {
        problems.add('$key: предложено то же, что стоит сейчас');
      } else if (field == 'register' && !_registers.contains(value)) {
        problems.add('$key: регистр «$value» не код из набора '
            '${_registers.join('/')}');
      } else if (field != 'register' && value.contains('{')) {
        problems.add('$key: фигурная скобка в тексте — остаток шаблонного '
            'формата, читатель исходников на нём падает');
      }
    }

    final severity = '${finding['severity']}';
    if (!const {'error', 'doubt', 'style'}.contains(severity)) {
      problems.add('$key: severity «$severity» не error/doubt/style');
    }
    counts.update(severity, (n) => n + 1, ifAbsent: () => 1);
    places.add('$where | $key');
  }

  // Итоги сверяются, только если они заявлены: отчёт без summary — это
  // неполный отчёт, а не поломанный, и терять из-за него все находки нельзя.
  final summary = report['summary'];
  if (summary is Map) {
    const totals = {'error': 'errors', 'doubt': 'doubts', 'style': 'styles'};
    for (final entry in totals.entries) {
      final claimed = summary[entry.value];
      if (claimed != null && claimed != (counts[entry.key] ?? 0)) {
        summaryProblems.add('итог по «${entry.key}» заявлен $claimed, '
            'а находок ${counts[entry.key] ?? 0}');
      }
    }
    final claimed = summary['findings'];
    if (claimed != null && claimed != findings.length) {
      summaryProblems.add('всего находок заявлено $claimed, а в списке '
          '${findings.length}');
    }
  }

  return AuditReview(
    findings: findings.length,
    stale: stale,
    problems: problems,
    summaryProblems: summaryProblems,
    places: places,
    counts: counts,
    summaryChecked: summary is Map,
  );
}

/// Печать итога сверки. Отдельно от [reviewReport] ровно затем, чтобы сверку
/// можно было проверить тестом, а не глазами по выводу.
void _verifyReport(String path) {
  final review = reviewReport(path);
  final stale = review.stale;
  final problems = review.problems;
  final summaryProblems = review.summaryProblems;

  if (!review.summaryChecked) {
    stdout.writeln('· в отчёте нет summary — итоги не сверены');
  }
  if (stale.isNotEmpty) {
    stdout.writeln('── Описывают не нынешний контент: ${stale.length} ──');
    for (final line in stale) {
      stdout.writeln(line);
    }
  }
  if (problems.isNotEmpty) {
    stdout.writeln('── Ошибки в самом отчёте: ${problems.length} ──');
    for (final line in problems) {
      stdout.writeln('· $line');
    }
  }
  if (summaryProblems.isNotEmpty) {
    stdout.writeln('── Итоги не сходятся с находками ──');
    for (final line in summaryProblems) {
      stdout.writeln('· $line');
    }
  }

  stdout.writeln('Находок ${review.findings}: сходится с контентом '
      '${review.matched}, устарело ${stale.length}, испорчено '
      '${problems.length}.');
  if (review.counts.isNotEmpty) {
    stdout.writeln('По важности: ${jsonEncode(review.counts)}');
  }
  if (review.places.isNotEmpty) {
    stdout.writeln('── Куда править ──');
    for (final place in review.places) {
      stdout.writeln('· $place');
    }
  }

  // Ненулевой код возврата — чтобы CI и человек одинаково понимали результат.
  // Устаревшие находки это не ошибка отчёта, но применять его как есть
  // нельзя, поэтому код тоже ненулевой.
  if (!review.clean) exitCode = 1;
}
