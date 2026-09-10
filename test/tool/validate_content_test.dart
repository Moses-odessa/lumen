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
/// **Что удалено вместе со словарным слоем.** Игра стала разговорником:
/// единицей изучения стала фраза, и двадцать одна проверка валидатора
/// исчезла вместе с тем, что охраняла. Здесь были тесты на три из них:
///
/// * «подсаженное несуществующее слово находится» — охранял проверку
///   существования форм. Она держалась на двух списках: отрицательный
///   (`content/dictionaries/<код>-nonwords.txt`) запрещал возврат однажды
///   найденной выдумки, положительный сверял форму со словарём. Форм в
///   контенте больше нет — есть фразы, и проверять их существование по
///   словарю нечем: предложение в словаре не лежит. Списки остались в
///   `content/_material/dictionaries/` материалом.
/// * «пометка языка изучения свободным текстом — ошибка» — охранял то, что у
///   лексемы изучаемого языка пометка это код, а не текст: немецкий файл
///   читает автор контента, и написанное в нём «неисчисляемое» показывалось
///   украинцу как есть. Лексем нет; у фразы осталась одна пометка — регистр,
///   и её проверка на месте (см. ниже).
/// * «заявленный порядок обязан быть перестановкой предложения» плюс три
///   теста вокруг него (регистр, место знака, перестановка хвоста) — охраняли
///   `orders:` у фразы, список верных сборок для механики вставки слов.
///   Механики нет, сборок нет.
void main() {
  late Directory root;

  /// Минимальный, но полный курс: одна тема, три фразы, язык изучения и один
  /// родной. Запущенных ярусов нет — иначе валидатор законно потребует
  /// полноты, и подсаженный дефект утонет в требованиях.
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
    String launch = 'de:\n  launched: []\n  drafted: [a0]\n',
    String name = 'name: "Essen"\n',
    String names = 'constellations:\n  food: "Їжа"\n',
  }) {
    File('${root.path}/phrases/de/food.yaml').writeAsStringSync('''
lang: de
constellation: food
${name}tiers:
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
${names}phrases:
$translations''');
    File('${root.path}/launch.yaml').writeAsStringSync(launch);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumen_validate');
    for (final dir in ['lang', 'phrases/de']) {
      Directory('${root.path}/$dir').createSync(recursive: true);
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('чистый контент проходит', () {
    write();
    final findings = validateContent(root, 'de');
    expect(findings.errors, isEmpty, reason: findings.errors.join('; '));
  });

  test('фраза без перевода — не ошибка, а меньше кругов', () {
    // Неполный язык обязан давать меньше фраз, а не чужие. Ошибкой это
    // становится только на запущенном ярусе, где обещана полнота.
    write(translations: '  food_a0_bread: "На сніданок я їм хліб."\n');
    final findings = validateContent(root, 'de');
    expect(findings.errors, isEmpty, reason: findings.errors.join('; '));
  });

  test('два предложения в одной фразе — ошибка', () {
    // Две единицы изучения под одной звездой и с одним переводом: их нельзя
    // ни показать, ни спросить по отдельности.
    write(phrases: '''
    - id: food_a0_bread
      text: "Ich kaufe Brot. Ich habe Hunger."
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('два предложения'));
  });

  test('многоточие концом предложения не считается', () {
    // **Тест про историю, а не про нынешний корпус: в корпусе 1500
    // многоточий ноль.** Автор их убрал и заменил шаблоны законченными
    // образцами — «Ich heiße Alex.» вместо «Ich heiße ...», с пометкой
    // `kind: example`.
    //
    // Тест всё равно остаётся, потому что охраняет он не корпус, а форму
    // записи. В прежней тысяче 239 фраз были написаны с местом для своего
    // слова: «Ich heiße ...», «Ich bin ... Jahre alt.». Пока проверка читала
    // последнюю точку многоточия концом предложения, она давала 84 ложных
    // отказа на 1000 фраз — то есть отвергала ровно тот корпус, для которого
    // игра и делается. Вернуть такую строку автор может одной правкой листа;
    // сняв тест как «проверяющий то, чего в контенте нет», мы вернули бы
    // вместе с ней и все 84 отказа.
    write(phrases: '''
    - id: food_a0_bread
      text: "Ich heiße ..."
    - id: food_a0_water
      text: "Ich bin ... Jahre alt."
    - id: food_a0_hunger
      text: "Statt nur ... zu bewerten, sollte man ... prüfen."
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), isNot(contains('два предложения')));
  });

  test('обращение на Sie с пометкой casual — ошибка', () {
    // Игрок учит вежливое обращение с ярлыком «так говорят с друзьями».
    //
    // Обратной проверки — «formal обязана содержать Sie» — здесь больше нет:
    // вежливость в немецком бывает лексической, без единого местоимения
    // («Entschuldigung.»), и требование Sie отвергало именно такие фразы.
    write(
      phrases: '''
    - id: food_a0_bread
      text: "Möchten Sie noch Brot?"
      register: casual
''',
      translations: '  food_a0_bread: "Бажаєте ще хліба?"\n',
      launch: 'de:\n  launched: [a0]\n  drafted: []\n',
    );

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('помечена casual'));
  });

  test('вид фразы вне закрытого набора — ошибка', () {
    // По этой пометке решается, буквальный у фразы перевод или смысловой: у
    // идиомы он смысловой, и первая же проверка перевода на буквальность
    // обязана идиомы пропускать. Код вне набора не значит ничего — такую
    // фразу проверка идиомой не признает и объявит дефектом единственно
    // верный перевод.
    write(phrases: '''
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brot."
      kind: idiome
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('не код из набора'));
    expect(findings.errors.join('\n'), contains('idiome'));
  });

  test('вид фразы не написан — не ошибка, а обычная реплика', () {
    // Умолчание держится осознанно: четыре фразы из пяти обычны, и требуй
    // поле от каждой — добавление одной строки руками стало бы правкой из
    // двух полей, второе из которых почти всегда одно и то же.
    //
    // Обратная сторона названа вслух в `content_schema.dart`: **забытая**
    // пометка у идиомы не ловится ничем, кроме вычитки. Опечатка ловится
    // (тест выше), отсутствие — нет.
    write();

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), isNot(contains('не код из набора')));
    expect(findings.notes.join('\n'), contains('виды фраз: phrase 3'));
  });

  test('регистр вне закрытого набора — ошибка', () {
    // Свободный текст в пометке показался бы игроку на языке файла, а не на
    // его собственном: `register: casual` уже уезжал на экран как есть.
    write(phrases: '''
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brot."
      register: höflich
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('не код из набора'));
  });

  test('тема без имени на языке изучения — ошибка', () {
    // Без имени карта подписывает тему латинским слагом посреди немецких
    // фраз. Это не падение и не пустая подпись, поэтому найти такое можно
    // только проверкой: в игре оно выглядит как решение автора.
    write(name: '');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'),
        contains('нет имени на языке изучения de'));
    expect(findings.errors.join('\n'), contains('name:'),
        reason: 'сообщение должно говорить, куда писать имя');
  });

  test('launched-язык без имени темы — ошибка, draft — отложенное', () {
    // Полноты требуем от `launched` и не требуем от `draft`: это и есть
    // механизм добавления языка — файл ложится в каталог, валидатор говорит,
    // сколько он покрывает, и ничего не блокирует.
    write(names: '');
    expect(validateContent(root, 'de').errors.join('\n'),
        contains('нет имён у 1 созвездий'));

    File('${root.path}/lang/uk.yaml').writeAsStringSync('''
lang: uk
role: native
status: draft
name: Українська
phrases:
  food_a0_bread: "На сніданок я їм хліб."
''');
    final draft = validateContent(root, 'de');
    expect(draft.errors.join('\n'), isNot(contains('нет имён')));
    expect(draft.pendings.join('\n'), contains('нет имён у 1 созвездий'));
  });

  test('пустое имя — ошибка отдельно от отсутствующего', () {
    // Игрок увидит одно и то же, а правки разные: одну строку надо написать,
    // другую — дописать. Пустая вдобавок выглядит сделанной работой, и
    // рантайм откатится на слаг молча.
    write(names: 'constellations:\n  food: "  "\n');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('имя пустое'));
  });

  test('фигурная скобка в имени — ошибка', () {
    // Тот же запрет, что у текста фразы с v5: подстановки в подписи никто не
    // делает, и `{…}` уехало бы на карту скобками.
    write(name: 'name: "Essen {tier}"\n');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('фигурная скобка'));
  });

  test('имя темы, которой в курсе нет, не остаётся висеть', () {
    // Обычно это опечатка в слаге или тема, переименованная в файле фраз:
    // имя остаётся в языковом файле, а тема — без подписи.
    write(names: 'constellations:\n  food: "Їжа"\n  fodo: "Їжа"\n');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'), contains('которого в курсе нет'));
  });

  test('раздел constellations: у языка изучения — ошибка', () {
    // Сборка его не читает: у языка изучения имя живёт в шапке файла фраз.
    // Два источника одного имени разошлись бы, и победил бы невидимо один —
    // а правка выглядела бы сделанной.
    write();
    File('${root.path}/lang/de.yaml').writeAsStringSync('''
lang: de
role: target
status: launched
name: Deutsch
constellations:
  food: "Essen"
''');

    final findings = validateContent(root, 'de');
    expect(findings.errors.join('\n'),
        contains('у языка изучения имя живёт в шапке файла фраз'));
  });

  test('вычитка требуется от нынешнего текста, а не от всей истории', () {
    // Раньше любой устаревший проход был ошибкой, и это делало честную
    // историю невозможной: вычитка A0 прошла восемь раундов, каждый нашёл
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

    // Не `errors, isEmpty`: в этом крошечном курсе одна тема с тремя фразами,
    // и порог появления созвездия законно ругается. Проверяется отсутствие
    // именно той ошибки, о которой тест.
    final fresh = validateContent(root, 'de');
    expect(fresh.errors.join('\n'), isNot(contains('прочитан целиком')),
        reason: 'проходы описывают нынешний текст, а ошибка всё равно есть');
    expect(fresh.notes.join('\n'), contains('более ранние версии'),
        reason: 'история должна быть видна, но не быть ошибкой');
  });

  test('отпечаток яруса меняется вместе с текстом фразы', () {
    // Отпечаток — это машинная форма правила «вычитка описывает прочитанный
    // текст». Считается он по тому, что видит вычитывающий: тексты фраз яруса
    // и их переводы. Не по хешу файлов: файл несёт все ярусы, и правка B2
    // объявляла бы устаревшей вычитку A0.
    write();
    final before = tierHashOf(root);

    write(phrases: '''
    - id: food_a0_bread
      text: "Zum Frühstück esse ich Brötchen."
      register: casual
    - id: food_a0_water
      text: "Ich trinke jeden Tag Wasser."
    - id: food_a0_hunger
      text: "Ich habe großen Hunger."
''');

    expect(tierHashOf(root), isNot(before));
  });
}
