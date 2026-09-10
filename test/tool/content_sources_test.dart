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

    test('вид фразы читается полем, а без поля это обычная реплика', () {
      // Колонка `kind` пришла в v7 из листа-источника: готовая реплика,
      // образец речевой модели, идиома. Проверяется здесь именно умолчание:
      // 1231 фраза корпуса из 1500 обычна, поле у них не написано, и если
      // чтение вернёт для них пустоту, сборка упадёт на `NOT NULL` — но уже
      // в самом конце пайплайна и с сообщением про SQL.
      //
      // Закрытости набора чтение не требует, и это не пробел: `kind:
      // idiome` читается как есть и становится ошибкой валидатора. Так же
      // устроен `register` — чтение падает на том, чего не понимает
      // (`{` в тексте), полноты и качества требует валидатор.
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      text: "Ich kaufe Brot."
    - id: food_a0_name
      text: "Ich heiße Alex."
      kind: example
    - id: food_a0_faden
      text: "Ich habe den Faden verloren."
      kind: idiom
''');
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.phrases.map((p) => p.kind),
          [defaultPhraseKind, 'example', 'idiom']);
      expect(defaultPhraseKind, 'phrase');
    });

    test('вид фразы входит в отпечаток яруса', () {
      // Отпечаток отвечает на вопрос «тот ли текст прочитан», и вид фразы —
      // часть условия задачи вычитки, а не украшение: у идиомы перевод
      // смысловой, и «Ich habe den Faden verloren.» → «Я потерял нить.»
      // правильно ровно потому, что строка помечена `idiom`. Снять пометку —
      // значит устареть вычитку, не тронув ни одной буквы.
      final before = ContentSources.load(root, lang: 'de').tierHash('a0');

      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brot."
      kind: example
      register: casual
    - id: food_a0_water
      text: "Ich trinke jeden Tag Wasser."
      register: casual
    - id: food_a0_hunger
      text: "Ich habe großen Hunger."
      register: casual
''');

      expect(ContentSources.load(root, lang: 'de').tierHash('a0'),
          isNot(before));
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

  group('имя созвездия', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('lumen_content');
      _writeMinimalCourse(root);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('имя приходит из двух мест, и это разные вещи', () {
      // Деление то же, что у самой фразы: у языка изучения есть **текст**
      // имени (шапка файла фраз, рядом с немецкими предложениями), у языка
      // подсказок — его перевод (раздел `constellations:` в своём файле).
      // Одна общая карта «slug → имя» слепила бы их и потребовала бы, чтобы
      // немецкий переводил имя на самого себя.
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.constellationNames, {'food': 'Essen'});
      expect(sources.languages['uk']!.constellationNames, {'food': 'Їжа'});
      expect(sources.languages['de']!.constellationNames, isEmpty,
          reason: 'у языка изучения имя лежит в файле фраз, а не в языковом');
    });

    test('язык добавляет имена тем тем же одним файлом', () {
      // Это и есть причина, по которой имя — контент, а не строка ARB: язык
      // приходит одним файлом и приносит с собой всё, включая подписи на
      // карте. В ARB имя вдобавок не положить технически — gen-l10n не умеет
      // достать строку по вычисляемому ключу.
      File('${root.path}/lang/fr.yaml').writeAsStringSync('''
lang: fr
role: native
status: draft
name: Français
constellations:
  food: "Nourriture"
phrases:
  food_a0_bread: "Au petit déjeuner, je mange du pain."
''');
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.languages['fr']!.constellationNames['food'],
          'Nourriture');
    });

    test('тема без имени читается: полноты требует валидатор', () {
      // Чтение падает на том, чего не понимает, а полноты требует тот, кто
      // знает про `launched`. Иначе первый же черновой файл темы уронил бы
      // сборку — и добавление темы перестало бы быть «положить один файл».
      _writePhrases(root, '''
  a0:
    - id: food_a0_bread
      text: "Ich kaufe Brot."
''');
      final sources = ContentSources.load(root, lang: 'de');
      expect(sources.constellations, ['food']);
      expect(sources.constellationNames, isEmpty);
    });

    test('два файла одной темы с разными именами — ошибка чтения', () {
      // Один slug в двух файлах законен: тему можно разложить по файлам. Два
      // разных имени у неё — нет: подпись на карте зависела бы от порядка
      // листинга каталога, то есть от имени файла.
      File('${root.path}/phrases/de/food_b2.yaml').writeAsStringSync('''
lang: de
constellation: food
name: "Essen und Trinken"
tiers:
  b2:
    - id: food_b2_menu
      text: "Die Speisekarte ist saisonal abgestimmt."
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('в другом файле той же темы'),
        )),
      );
    });

    test('имя, съеденное разбором YAML, — ошибка про кавычки', () {
      // Ловушка, на которой этот проект уже стоял: `Null` — настоящее
      // немецкое слово (die Null), а разбор читает его отсутствием, как и `~`
      // и пустое значение. Интерполяция сделала бы из такого подпись «null»
      // — на карте и молча. Имён пятьдесят, поправить кавычками легко,
      // поэтому чтение требует, а не угадывает.
      File('${root.path}/lang/uk.yaml').writeAsStringSync('''
lang: uk
role: native
status: launched
name: Українська
constellations:
  food: Null
''');
      expect(
        () => ContentSources.load(root, lang: 'de'),
        throwsA(isA<ContentSourceException>().having(
          (e) => e.message,
          'message',
          contains('кавычки'),
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
name: "Essen"
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
constellations:
  food: "Їжа"
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
