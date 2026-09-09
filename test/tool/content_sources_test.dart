@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/part_of_speech.dart' as domain;
import 'package:lumen/domain/entities/prompt_tag.dart' as domain;

import '../../tool/content_schema.dart';
import '../../tool/content_sources.dart';

/// Тесты на контракт каталога `content/`.
///
/// До этого файла весь пайплайн был непокрыт: `content_sources.dart` в
/// одиночку определяет, что считается контентом, а проверить это было нечем.
/// Изменение раскладки не ломало ни одного теста — оно ломало сборку, и
/// узнавали об этом из CI.
///
/// Главное, что здесь проверяется, — обещание «язык добавляется одним
/// файлом». Обещание, не закрытое тестом, живёт до первой правки.
void main() {
  group('язык — это файл', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('lumen_content');
      _writeMinimalCourse(root);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('добавление одного файла добавляет язык', () {
      final before = ContentSources.load(root, lang: 'de');
      expect(before.languages.keys, ['de']);

      // Ровно то, что должен сделать человек, добавляющий язык: положить
      // один файл. Ни строки Dart, ни правки списков.
      File('${root.path}/lang/fr.yaml').writeAsStringSync('''
lang: fr
role: native
status: draft
name: Français
lexemes:
  bread_food: { form: pain, gender: m }
  water_drink: { form: eau, gender: f }
  milk_drink: { form: lait, gender: m }
''');

      final after = ContentSources.load(root, lang: 'de');
      expect(after.languages.keys, containsAll(['de', 'fr']));
      expect(after.coverageOf('fr'), 3);
      expect(after.languages['fr']!.name, 'Français');
      expect(after.languages['fr']!.isNative, isTrue);
      expect(after.languages['fr']!.isLaunched, isFalse);

      // И это меняет хеш исходников: собранный ассет обязан отличаться.
      expect(after.hash, isNot(before.hash));
    });

    test('язык может быть каталогом файлов по темам', () {
      // 6299 концептов в одном YAML — сорок тысяч строк, которые нельзя ни
      // читать, ни править по частям.
      Directory('${root.path}/lang/it').createSync();
      File('${root.path}/lang/it/food.yaml').writeAsStringSync('''
lang: it
role: native
status: draft
name: Italiano
lexemes:
  bread_food: { form: pane, gender: m }
''');
      File('${root.path}/lang/it/drink.yaml').writeAsStringSync('''
lang: it
lexemes:
  water_drink: { form: acqua, gender: f }
''');

      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.coverageOf('it'), 2);
      expect(sources.languages['it']!.name, 'Italiano');
    });

    test('язык без объявленной роли не проходит молча', () {
      File('${root.path}/lang/fr.yaml').writeAsStringSync('''
lang: fr
status: draft
name: Français
lexemes:
  bread_food: { form: pain }
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('role'),
        )),
      );
    });

    test('несовпадение имени файла и объявленного языка — ошибка', () {
      File('${root.path}/lang/fr.yaml').writeAsStringSync('''
lang: it
role: native
status: draft
name: Italiano
lexemes:
  bread_food: { form: pane }
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>()),
      );
    });

    test('покрытие считается, а не берётся из файла', () {
      final sources = ContentSources.load(root, lang: 'de');
      // В файле немецкого три лексемы, концептов тоже три.
      expect(sources.coverageOf('de'), sources.concepts.length);
      // Языка, которого нет, покрытие нулевое, а не бросок.
      expect(sources.coverageOf('ja'), 0);
    });
  });

  group('фразы', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('lumen_content');
      _writeMinimalCourse(root);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('один пропуск пишется скаляром, несколько — списком', () {
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      template: "Ich kaufe {bread}."
      answer: Brot
      concepts: [bread_food]
    - id: food_a0_two
      template: "Ich {want} das {bread}."
      answers: [möchte, Brot]
      concepts: [bread_food]
''');
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.phrases.length, 2);
      expect(sources.phrases.first.answers, ['Brot']);
      expect(sources.phrases.first.slotCount, 1);
      expect(sources.phrases.last.answers, ['möchte', 'Brot']);
      expect(sources.phrases.last.slotCount, 2);
    });

    test('число ответов обязано совпадать с числом пропусков', () {
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      template: "Ich {verb} das {bread}."
      answer: Brot
      concepts: [bread_food]
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('пропусков'),
        )),
      );
    });

    test('и answer, и answers одновременно — ошибка', () {
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      template: "Ich kaufe {bread}."
      answer: Brot
      answers: [Brot]
      concepts: [bread_food]
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>()),
      );
    });

    test('варианты по слоту разбираются в порядке слотов', () {
      _writePhrases(root, '''
  a0:
    - id: food_a0_two
      template: "Ich {want} das {bread}."
      answers: [möchte, Brot]
      options:
        - [kaufe, esse]
        - [Wasser, Milch]
      concepts: [bread_food]
''');
      final phrase = ContentSources.load(root, lang: 'de').phrases.single;
      expect(phrase.optionsFor(0), ['kaufe', 'esse']);
      expect(phrase.optionsFor(1), ['Wasser', 'Milch']);
      expect(phrase.optionsFor(2), isEmpty);
    });

    test('плоский список вариантов при нескольких пропусках — ошибка', () {
      _writePhrases(root, '''
  a0:
    - id: food_a0_two
      template: "Ich {want} das {bread}."
      answers: [möchte, Brot]
      options: [kaufe, esse]
      concepts: [bread_food]
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('на слот'),
        )),
      );
    });

    test('фразы рядом с концептами больше не принимаются', () {
      // Раньше немецкое предложение лежало в язык-нейтральном файле, и это
      // работало ровно потому, что язык изучения был один.
      File('${root.path}/concepts/food.yaml').writeAsStringSync('''
constellation: food
tiers:
  a0:
    concepts:
      - { id: bread_food, pos: noun }
    phrases:
      - id: food_a0_bread
        template: "Ich kaufe {bread}."
        answer: Brot
        concepts: [bread_food]
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('phrases'),
        )),
      );
    });
  });

  group('порог появления созвездия', () {
    test('число в пайплайне и в приложении — одно и то же', () {
      // Дубль намеренный: tool/ не тянет за собой lib/. Проверка живёт в
      // test/domain/balance_test.dart; здесь фиксируется само значение,
      // чтобы правка в одну сторону была видна сразу.
      expect(minStarsForConstellation, 8);
    });
  });

  group('пометки под центром', () {
    test('набор кодов одинаков в пайплайне и в приложении', () {
      // Дубль намеренный: tool/ не тянет за собой lib/. Расхождение здесь
      // означало бы, что валидатор пропустил код, к которому у приложения нет
      // перевода, — и пометка просто не показалась бы. Именно это и лечится:
      // раньше на её месте стоял свободный текст на языке файла.
      expect(promptTags, domain.promptTags);
    });
  });

  group('служебные слова', () {
    test('набор частей речи одинаков в пайплайне и в приложении', () {
      // Дубль намеренный: tool/ не тянет за собой lib/. Расхождение здесь
      // означало бы, что валидатор не требует дистракторов от слова, круг из
      // которого игра всё-таки попытается собрать.
      expect(functionWordPos, domain.functionWordPos);
    });

    test('часть речи решает, годится ли слово для круга', () {
      final noun = ConceptSource(
        id: 'bread_food',
        tier: 'a0',
        constellation: 'food',
        pos: 'noun',
      );
      final particle = ConceptSource(
        id: 'nicht_particle',
        tier: 'a0',
        constellation: 'dialog',
        pos: 'particle',
      );
      expect(noun.isFunctionWord, isFalse);
      expect(particle.isFunctionWord, isTrue);
    });
  });
}

/// Минимальный курс: три концепта, немецкий, ни одной фразы.
void _writeMinimalCourse(Directory root) {
  Directory('${root.path}/concepts').createSync(recursive: true);
  Directory('${root.path}/lang').createSync(recursive: true);

  File('${root.path}/concepts/food.yaml').writeAsStringSync('''
constellation: food
tiers:
  a0:
    concepts:
      - { id: bread_food, pos: noun, freq_rank: 1870 }
      - { id: water_drink, pos: noun, freq_rank: 610 }
      - { id: milk_drink, pos: noun, freq_rank: 2450 }
''');

  File('${root.path}/lang/de.yaml').writeAsStringSync('''
lang: de
role: target
status: launched
name: Deutsch
lexemes:
  bread_food:
    form: Brot
    article: das
    gender: n
    plural: Brote
    distractors:
      far: [Wasser, Milch]
      near: [Brut, Boot, Brett]
  water_drink: { form: Wasser, article: das, gender: n }
  milk_drink: { form: Milch, article: die, gender: f }
''');
}

void _writePhrases(Directory root, String tiers) {
  Directory('${root.path}/phrases/de').createSync(recursive: true);
  File('${root.path}/phrases/de/food.yaml').writeAsStringSync('''
lang: de
constellation: food
tiers:
$tiers''');
}
