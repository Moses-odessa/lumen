@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
///
/// ── Что ушло вместе со словарным слоем ────────────────────────────────────
///
/// Пайплайн больше не читает ни `content/concepts/*.yaml`, ни секции
/// `lexemes:` языковых файлов: единицей изучения стала фраза. Вместе с этим
/// ушли пять проверок — три из них удалены совсем, у двух остался смысл, и он
/// перенесён на нынешнее правило:
///
/// * «покрытие считается, а не берётся из файла» — `coverageOf` считал
///   лексемы языка. Покрытие теперь это число переводов фраз, и вместо
///   прежней проверки здесь стоит «язык без переводов читается»: у проекта
///   ровно такие языки есть (`en`, `ru` — только заголовок), и требование
///   секции `phrases:` уронило бы сборку на них.
/// * «принимаемые порядки слов разбираются списком» — охраняла `orders:` и
///   `acceptedOrders`: список законных сборок фразы из её же слов. Механики
///   вставки слов в предложение больше нет, значит нет ни сборок, ни того,
///   что можно было бы принять сверх шаблона.
/// * «фразы рядом с концептами больше не принимаются» — охраняла запрет
///   держать немецкое предложение в язык-нейтральном файле. Файлы концептов
///   не читаются вовсе, поэтому запрещать в них нечего; смысл проверки —
///   «фраза принадлежит языку» — перенесён на каталог фраз, см. «фраза лежит
///   в каталоге своего языка».
/// * «служебные слова» — две проверки: совпадение `functionWordPos` с набором
///   приложения и `ConceptSource.isFunctionWord`. Обе решали, годится ли слово
///   для круга с вариантами. У фразы части речи нет, а варианты вокруг неё —
///   другие фразы, которые игрок уже знает. В пайплайне от этого не осталось
///   ничего: ни набора, ни `ConceptSource`.
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
      expect(before.languages.keys, unorderedEquals(['de', 'uk']));

      // Ровно то, что должен сделать человек, добавляющий язык: положить
      // один файл. Ни строки Dart, ни правки списков. Всё, что язык приносит
      // с собой, — заголовок и переводы фраз.
      File('${root.path}/lang/fr.yaml').writeAsStringSync('''
lang: fr
role: native
status: draft
name: Français
phrases:
  food_a0_bread: "Au petit déjeuner, je mange du pain."
  food_a0_water: "Je bois de l'eau chaque jour."
''');

      final after = ContentSources.load(root, lang: 'de');
      expect(after.languages.keys, containsAll(['de', 'fr', 'uk']));
      expect(after.languages['fr']!.phraseTranslations.length, 2);
      expect(after.languages['fr']!.name, 'Français');
      expect(after.languages['fr']!.isNative, isTrue);
      expect(after.languages['fr']!.isLaunched, isFalse);

      // И это меняет хеш исходников: собранный ассет обязан отличаться.
      expect(after.hash, isNot(before.hash));
    });

    test('язык может быть каталогом файлов по темам', () {
      // Вид остался от словарного слоя: шесть тысяч лексем в одном YAML — это
      // сорок тысяч строк, которые нельзя ни читать, ни править по частям.
      // Переводы фраз столько места не занимают, но каталоги на диске лежат
      // (`content/lang/de/` — двадцать пять файлов), и читать их надо.
      // Заголовок при этом объявляется один раз, в любом из файлов.
      Directory('${root.path}/lang/it').createSync();
      File('${root.path}/lang/it/_language.yaml').writeAsStringSync('''
lang: it
role: native
status: draft
name: Italiano
''');
      File('${root.path}/lang/it/food.yaml').writeAsStringSync('''
lang: it
phrases:
  food_a0_bread: "A colazione mangio il pane."
  food_a0_water: "Bevo acqua ogni giorno."
''');

      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.languages['it']!.phraseTranslations.length, 2);
      expect(sources.languages['it']!.name, 'Italiano');
    });

    test('язык без объявленной роли не проходит молча', () {
      File('${root.path}/lang/fr.yaml').writeAsStringSync('''
lang: fr
status: draft
name: Français
phrases:
  food_a0_bread: "Au petit déjeuner, je mange du pain."
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
phrases:
  food_a0_bread: "A colazione mangio il pane."
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>()),
      );
    });

    test('покрытие — это число прочитанных переводов, а язык без них законен',
        () {
      // Покрытие языка не объявляется в файле, а считается по тому, что в нём
      // лежит: объявленное число разошлось бы с содержимым при первой же
      // правке — этот проект уже ловил такое на строке о вычитке в launch.yaml.
      //
      // Ноль — законный результат, и это не мелочь: у языка изучения переводов
      // нет по определению (переводить фразу на её же язык незачем), а `en` и
      // `ru` лежат в репозитории одним заголовком. Потребуй чтение секции
      // `phrases:` — и сборка немецкого упала бы на трёх языках из четырёх.
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.languages['uk']!.phraseTranslations.length,
          sources.phrases.length,
          reason: 'украинский переводит весь минимальный курс');
      expect(sources.languages['de']!.phraseTranslations, isEmpty);
    });
  });

  // Удалён тест «и answer, и answers одновременно — ошибка». Он охранял две
  // формы записи ответа к пропуску: скаляр и список по слотам, — и требовал
  // ровно одну из них. Пропусков в фразе больше нет, ответа тоже, и после
  // правки тест продолжал зеленеть по неверной причине: исключение бросалось
  // за отсутствие `text`, а не за двойной ответ. Тест, который нельзя
  // сломать тем, о чём он написан, — это отсутствующий тест.
  group('фразы', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('lumen_content');
      _writeMinimalCourse(root);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('фраза в файле — готовая строка', () {
      // Раньше фраза лежала разобранной: `template` с пропуском `{bread}` и
      // `answer` к нему, — потому что её собирала механика вставки слов.
      // Механики нет, и разбирать нечего: у фразы есть текст. Проверка нужна
      // не ради поля, а ради того, что в базу не уедет ни `{bread}`, ни «…» на
      // месте пропуска: игрок увидел бы это на экране и услышал в синтезе.
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      text: "Ich kaufe Brot."
      register: casual
    - id: food_a0_two
      text: "Ich möchte das Brot."
      register: formal
''');
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.phrases.length, 2);
      expect(sources.phrases.first.text, 'Ich kaufe Brot.');
      expect(sources.phrases.last.text, 'Ich möchte das Brot.');
      expect(sources.phrases.first.register, 'casual');

      // Порядок знакомства — это порядок строк в файле, и он считается при
      // чтении, а не пишется полем: поле пришлось бы править у всех фраз ниже
      // при каждой вставке в середину. Частотности, которая раньше задавала
      // последовательность, у фразы нет и быть не может.
      expect(sources.phrases.map((p) => p.idx), [0, 1]);
    });

    test('пропуск в тексте фразы — ошибка чтения', () {
      // `{…}` в тексте означает, что фраза написана по старой форме, для
      // механики вставки слов. Прочитать её как готовую строку значит отдать
      // игроку фигурные скобки на экране; прочитать как шаблон нечем —
      // подстановки больше нет вовсе.
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      text: "Ich kaufe {bread}."
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('пропусков в фразе больше не бывает'),
        )),
      );
    });

    test('фраза лежит в каталоге своего языка', () {
      // Фраза принадлежит языку изучения, а не теме: немецкое предложение
      // нельзя положить в язык-нейтральный файл, и раньше оно там лежало —
      // рядом с концептами. Работало это ровно потому, что язык изучения был
      // один. Каталог `phrases/<код>/` делает принадлежность видимой, а
      // проверка ниже — обязательной: файл, объявивший другой язык, попал бы
      // в сборку немецкого французскими фразами.
      File('${root.path}/phrases/de/city.yaml').writeAsStringSync('''
lang: fr
constellation: city
tiers:
  a0:
    - id: city_a0_map
      template: "Je cherche la {map}."
      answer: carte
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('phrases/de/'),
        )),
      );
    });

    test('без файла фраз сборка не начинается', () {
      // Пустой каталог фраз — это не «курс без фраз», а не тот язык или не тот
      // путь. Собрать из него можно только базу без единой звезды, и узнать об
      // этом пришлось бы уже в игре: небо открылось бы пустым.
      Directory('${root.path}/phrases/de').deleteSync(recursive: true);
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('единица изучения'),
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
      // раньше на её месте стоял свободный текст на языке файла, а после
      // словарного слоя осталась одна пометка, которая у фразы есть, —
      // регистр.
      expect(promptTags, domain.promptTags);
    });
  });
}

/// Минимальный курс: три немецкие фразы, украинские переводы к ним и ни одной
/// лексемы. Фраза — единица изучения, и без файла фраз чтение исходников не
/// начинается вовсе.
void _writeMinimalCourse(Directory root) {
  Directory('${root.path}/phrases/de').createSync(recursive: true);
  Directory('${root.path}/lang').createSync(recursive: true);

  File('${root.path}/phrases/de/food.yaml').writeAsStringSync('''
lang: de
constellation: food
tiers:
  a0:
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brot."
      register: casual
    - id: food_a0_water
      text: "Ich trinke jeden Tag Wasser."
      register: casual
    - id: food_a0_hunger
      text: "Ich habe großen Hunger."
      register: casual
''');

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
  food_a0_bread: "На сніданок я їм хліб."
  food_a0_water: "Я п'ю воду щодня."
  food_a0_hunger: "Я дуже голодний."
''');
}

/// Заменяет файл фраз минимального курса своим набором ярусов.
void _writePhrases(Directory root, String tiers) {
  File('${root.path}/phrases/de/food.yaml').writeAsStringSync('''
lang: de
constellation: food
tiers:
$tiers''');
}
