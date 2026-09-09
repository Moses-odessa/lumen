@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_audit.dart';

/// Сверка отчёта вычитки — на подсаженных дефектах, а не на настоящем
/// контенте.
///
/// У этого скрипта тестов не было, и цена этого известна точно. Он читал
/// `content/concepts` и `lexemes:`, а после перехода на разговорник первого не
/// стало по этому пути, второго — вовсе; ни одна из четырёх функций не
/// перестала компилироваться, и запуск не падал. Режимы просто возвращали
/// пустоту, а выгрузка фраз печатала снимок в `.dart_tool/`, снятый до замены
/// корпуса, — то есть на вычитку 1000 новых фраз он выдал бы 432 удалённых.
/// Молча.
///
/// Отсюда два свойства, которые здесь и проверяются:
///
/// * сверка возвращает результат, а не печатает его — иначе её нельзя
///   спросить ни из теста, ни из другой программы;
/// * читаются исходники, а не снимок: [readPhrases] видит правку файла сразу.
void main() {
  late Directory root;

  /// Минимальный курс: одна тема, три фразы, один язык подсказок.
  void write({
    String phrases = '''
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brot."
      register: casual
    - id: food_a0_water
      text: "Ich trinke jeden Tag Wasser."
    - id: food_a0_hunger
      text: "Ich habe großen Hunger."
''',
    String translations = '''
  food_a0_bread: "На сніданок я їм хліб."
  food_a0_water: "Я п'ю воду щодня."
  food_a0_hunger: "Я дуже голодний."
''',
  }) {
    File('${root.path}/phrases/de/food.yaml').writeAsStringSync('''
lang: de
constellation: food
tiers:
  a0:
$phrases''');
    File('${root.path}/lang/de.yaml').writeAsStringSync('''
lang: de
role: target
status: launched
name: Deutsch
''');
    File('${root.path}/lang/uk.yaml').writeAsStringSync('''
lang: uk
role: native
status: launched
name: Українська
phrases:
$translations''');
  }

  /// Отчёт во временном файле: сверка читает его с диска, как и в жизни.
  String report(String body) {
    final file = File('${root.path}/report.yaml')..writeAsStringSync(body);
    return file.path;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumen_audit');
    for (final dir in ['lang', 'phrases/de']) {
      Directory('${root.path}/$dir').createSync(recursive: true);
    }
    write();
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('чтение исходников', () {
    test('фразы и переводы читаются вместе с местом в файле', () {
      final phrases = readPhrases(root: root.path);
      expect(phrases.keys, hasLength(3));

      final bread = phrases['food_a0_bread']!;
      expect(bread.text, 'Zum Frühstück esse ich Brot.');
      expect(bread.register, 'casual');
      expect(bread.constellation, 'food');
      expect(bread.tier, 'a0');
      // Строка нужна тому, кто будет править: по ней открывают редактор.
      expect(bread.file, endsWith('phrases/de/food.yaml'));
      expect(
        File(bread.file).readAsLinesSync()[bread.line - 1],
        contains('food_a0_bread'),
      );

      final uk = readTranslations(root: root.path)['uk']!;
      expect(uk['food_a0_water']!.text, "Я п'ю воду щодня.");
      expect(
        File(uk['food_a0_water']!.file).readAsLinesSync()[
            uk['food_a0_water']!.line - 1],
        contains('food_a0_water'),
      );
    });

    test('язык изучения в переводы не попадает', () {
      // У изучаемого языка нет «перевода», у него есть текст. Файл `de.yaml`
      // несёт только заголовок, и пустой раздел переводов не должен
      // превращаться в язык подсказок с нулевым покрытием.
      expect(readTranslations(root: root.path).keys, ['uk']);
    });

    test('правка файла видна сразу, без пересъёмки снимка', () {
      // То самое свойство, которого не было: режим печатал снимок, снятый
      // однажды, и пережил им замену всего корпуса.
      write(phrases: '''
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brötchen."
''');
      expect(readPhrases(root: root.path)['food_a0_bread']!.text,
          endsWith('Brötchen.'));
    });
  });

  group('сверка отчёта', () {
    test('отчёт про нынешний текст сходится', () {
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Brot."
    proposed: "Zum Frühstück esse ich ein Brötchen."
    severity: style
    why: "живее"
summary:
  findings: 1
  styles: 1
'''),
        root: root.path,
      );

      expect(review.clean, isTrue, reason: review.problems.join('; '));
      expect(review.matched, 1);
      expect(review.counts, {'style': 1});
      // Место находки указывает на строку с идентификатором — это и есть
      // ответ на «куда править».
      expect(review.places.single, contains('food_a0_bread/text'));
    });

    test('устаревшая находка — правда о дереве, а не ошибка отчёта', () {
      // Вычитка идёт долго, и часть находок к её концу уже исправлена. Так
      // было с прежним аудитом: из 263 находок 74 описывали исправленное.
      // Это не повод отвергнуть отчёт целиком — это повод разделить его.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Toast."
    severity: error
    why: "описывает уже исправленное"
  - id: food_a0_water
    field: uk
    current: "Я п'ю воду щодня."
    severity: style
    why: "сходится"
'''),
        root: root.path,
      );

      expect(review.stale, hasLength(1));
      expect(review.stale.single, contains('food_a0_bread/text'));
      expect(review.problems, isEmpty);
      expect(review.matched, 1, reason: 'вторая находка годна и должна остаться');
      expect(review.clean, isFalse);
    });

    test('пропавший идентификатор — ошибка отчёта', () {
      // Переименование фразы делает находку неприменимой: применить её
      // «примерно туда» нельзя, а промолчать — значит потерять правку.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_toast
    field: text
    current: "Ich esse Toast."
    severity: error
    why: "фразы нет"
'''),
        root: root.path,
      );

      expect(review.problems.single, contains('food_a0_toast'));
      expect(review.matched, 0);
    });

    test('поле из словарного слоя — ошибка отчёта', () {
      // У фразы есть текст, регистр и переводы. Части речи, рода и числа
      // ушли вместе со словарным слоем, и находка про них означает, что
      // проверяющему дали устаревший промт.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: plural
    current: "Brote"
    severity: error
    why: "поле из прежней модели"
'''),
        root: root.path,
      );

      expect(review.problems.single, contains('не text, не register'));
    });

    test('дубль находки не проходит', () {
      // Две находки об одном поле противоречили бы друг другу, и применение
      // зависело бы от порядка строк в отчёте.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Brot."
    severity: style
    why: "раз"
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Brot."
    severity: error
    why: "два"
'''),
        root: root.path,
      );

      expect(review.problems.single, contains('дважды'));
    });

    test('предложенное значение проверяется, а не берётся на слово', () {
      // Три способа испортить правку: предложить то же самое, предложить
      // пустоту и притащить фигурную скобку из шаблонного формата — на
      // последней падает чтение исходников, то есть сборка контента.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Brot."
    proposed: "Zum Frühstück esse ich Brot."
    severity: style
    why: "то же самое"
  - id: food_a0_water
    field: text
    current: "Ich trinke jeden Tag Wasser."
    proposed: "Ich trinke jeden Tag {water}."
    severity: error
    why: "скобка"
  - id: food_a0_hunger
    field: register
    current: null
    proposed: "höflich"
    severity: error
    why: "не код"
'''),
        root: root.path,
      );

      expect(review.problems.join('\n'), contains('то же, что стоит сейчас'));
      expect(review.problems.join('\n'), contains('фигурная скобка'));
      expect(review.problems.join('\n'), contains('не код из набора'));
    });

    test('несошедшийся итог — отдельный исход', () {
      // Итог не относится ни к одной находке: сами находки могут быть
      // безупречны, а сосчитал проверяющий себя неверно. Смешивать это с
      // испорченными находками значит терять годную работу.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Brot."
    severity: error
    why: "сходится"
summary:
  findings: 7
  errors: 4
'''),
        root: root.path,
      );

      expect(review.problems, isEmpty);
      expect(review.matched, 1);
      expect(review.summaryProblems, hasLength(2));
      expect(review.clean, isFalse);
    });

    test('отчёт без итогов годен, и это видно', () {
      // Отсутствие `summary` — неполнота оформления, а не поломка. Терять
      // из-за неё все находки значило бы выбрасывать работу целиком.
      final review = reviewReport(
        report('''
findings:
  - id: food_a0_bread
    field: text
    current: "Zum Frühstück esse ich Brot."
    severity: error
    why: "сходится"
'''),
        root: root.path,
      );

      expect(review.summaryChecked, isFalse);
      expect(review.clean, isTrue);
      expect(review.matched, 1);
    });

    test('отчёт без находок — ошибка, а не пустой успех', () {
      // Иначе пустой файл выглядел бы как «вычитка прошла, замечаний нет», а
      // это ровно то, чего проверка обязана не допускать.
      final review = reviewReport(
        report('summary:\n  findings: 0\n'),
        root: root.path,
      );

      expect(review.clean, isFalse);
      expect(review.problems.single, contains('нет списка findings'));
    });
  });
}
