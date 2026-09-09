@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/content_sources.dart';
import '../../tool/validate_content.dart';

/// Отпечаток яруса того контента, что лежит во временном каталоге: запись о
/// вычитке обязана ссылаться именно на него.
String tierHashOf(Directory root) =>
    ContentSources.load(root, lang: 'de').tierHash('a0');

/// Проверки валидатора — на подсаженных дефектах, а не на настоящем контенте.
///
/// До M13 у валидатора не было ни одного теста, и это не пробел в покрытии, а
/// пробел в самой проверке: единственным его выходом был `stdout`, поэтому
/// проверить его было нечем. Проверка, о которой известно только то, что она
/// «вроде работает», ничем не отличается от отсутствующей — и ровно так уехал
/// в репозиторий `en.db` с немецкими фразами.
///
/// Критерий приёмки M13 сформулирован именно так: подсадить в контент
/// несуществующее слово и убедиться, что валидатор его находит.
void main() {
  late Directory root;

  /// Минимальный, но полный контент: одно созвездие, один концепт, один язык
  /// изучения, один родной. Запущенных ярусов нет — иначе валидатор законно
  /// потребует полноты, и подсаженный дефект утонет в требованиях.
  void write({
    String deLexemes = '''
  bread_food:
    form: Brot
    article: das
    gender: n
    plural: Brote
    distractors:
      far: [Butter, Käse]
      near: [Boot, Bord, Brust]
''',
    String phrases = '',
    String launch = 'de:\n  launched: []\n  drafted: [a0]\n',
  }) {
    File('${root.path}/concepts/food.yaml').writeAsStringSync('''
constellation: food
tiers:
  a0:
    concepts:
      - { id: bread_food, pos: noun, freq_rank: 1870 }
''');
    File('${root.path}/lang/de.yaml').writeAsStringSync('''
lang: de
role: target
status: launched
name: Deutsch
lexemes:
$deLexemes''');
    File('${root.path}/lang/uk.yaml').writeAsStringSync('''
lang: uk
role: native
status: launched
name: Українська
lexemes:
  bread_food: { form: хліб, gender: m, plural: хліби }
''');
    File('${root.path}/phrases/de/food.yaml').writeAsStringSync('''
lang: de
constellation: food
tiers:
  a0:
$phrases''');
    File('${root.path}/launch.yaml').writeAsStringSync(launch);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumen_validate');
    for (final dir in ['concepts', 'lang', 'phrases/de']) {
      Directory('${root.path}/$dir').createSync(recursive: true);
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('чистый контент проходит', () {
    write();
    final findings = validateContent(root, 'de');
    expect(findings.errors, isEmpty, reason: findings.errors.join('; '));
  });

  test('подсаженное несуществующее слово находится', () {
    // Отрицательный список — единственная часть проверки существования,
    // работающая без словаря языка. Доказать существование он не может, но
    // делает невозможным возврат: найденная однажды выдумка не вернётся.
    Directory('${root.path}/dictionaries').createSync();
    File('${root.path}/dictionaries/de-nonwords.txt')
        .writeAsStringSync('Brotmesserhalter  выдумка модельной генерации\n');
    write(deLexemes: '''
  bread_food:
    form: Brot
    article: das
    gender: n
    plural: Brote
    distractors:
      far: [Butter, Brotmesserhalter]
      near: [Boot, Bord, Brust]
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('Brotmesserhalter'));
  });

  test('пометка языка изучения свободным текстом — ошибка', () {
    // У пометки на лексеме языка изучения нет правильного языка: немецкий
    // файл читает автор контента, а не игрок.
    write(deLexemes: '''
  bread_food:
    form: Brot
    article: das
    gender: n
    plural: Brote
    note: неисчисляемое
    distractors:
      far: [Butter, Käse]
      near: [Boot, Bord, Brust]
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('не код'));
  });




  test('вычитка требуется от нынешнего текста, а не от всей истории', () {
    // Раньше любой устаревший проход был ошибкой, и это делало честную
    // историю невозможной: вычитка A0 прошла шесть раундов, каждый нашёл
    // настоящее, каждая правка меняла текст. Одиннадцать «устаревших» ошибок
    // за сохранённую историю — это требование её стереть.
    //
    // Спрашивать надо одно: этот текст прочитан двумя разными моделями?
    write(
      launch: """de:
  launched: [a0]
  drafted: []
  reviewers:
    a0:
      by: 'тест'
      constellations: [food]
      passes:
        - model: 'model-a'
          at: '2026-09-09'
          content_hash: 'deadbeefcafe'
          scope: full
        - model: 'model-b'
          at: '2026-09-09'
          content_hash: 'deadbeefcafe'
          scope: full
""",
    );

    final stale = validateContent(root, 'de');
    expect(stale.errors.join('\n'), contains('прочитан целиком 0 разными'),
        reason: 'устаревшие проходы не должны считаться прочтением');

    // Тот же ярус, но проходы описывают нынешний текст: ошибки нет.
    final hash = tierHashOf(root);
    write(
      launch: """de:
  launched: [a0]
  drafted: []
  reviewers:
    a0:
      by: 'тест'
      constellations: [food]
      passes:
        - model: 'model-a'
          at: '2026-09-09'
          content_hash: '$hash'
          scope: full
        - model: 'model-b'
          at: '2026-09-09'
          content_hash: '$hash'
          scope: full
        - model: 'model-a'
          at: '2026-09-01'
          content_hash: 'deadbeefcafe'
          scope: full
""",
    );

    // Не `errors, isEmpty`: в этом крошечном контенте одно созвездие с одной
    // звездой, и порог появления законно ругается. Проверяется отсутствие
    // именно той ошибки, о которой тест.
    final fresh = validateContent(root, 'de');
    expect(fresh.errors.join('\n'), isNot(contains('прочитан целиком')),
        reason: 'проходы описывают нынешний текст, а ошибка всё равно есть');
    expect(fresh.notes.join('\n'), contains('более ранние версии'),
        reason: 'история должна быть видна, но не быть ошибкой');
  });

  test('заявленный порядок обязан быть перестановкой предложения', () {
    // «Этот порядок тоже верен» — заявление про **те же** слова. Заявленная
    // сборка, отличающаяся хоть одним словом, объявила бы верным то, чего
    // игрок собрать не может: слова ему выдаются из предложения.
    write(
      phrases: """    - id: food_a0_bread
      template: "Heute kaufe ich {bread}."
      answer: Brot
      orders:
        - "Ich kaufe heute Kuchen."
      concepts: [bread_food]
""",
    );

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('собран не из тех слов'));
  });

  test('два предложения в одной фразе — ошибка', () {
    // Они меняются местами без потери смысла, и сборка из своих же слов
    // начнёт отвергать верный порядок.
    write(
      phrases: """    - id: food_a0_bread
      template: "Ich kaufe {bread}. Ich habe Hunger."
      answer: Brot
      concepts: [bread_food]
""",
    );

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('два предложения'));
  });
}
