import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/core/theme/palette.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';

import 'corpus_extremes.dart';

/// Круг проверяется по поведению и по раскладке: главный жест игры должен
/// работать, промах по варианту не должен считаться ответом, повторный ответ
/// на закрытый круг — не проходить, полоса окна — идти ровно там, где игрока
/// торопят, а ни одна фраза не должна ни обрезаться, ни налезать на соседнюю.
///
/// Арена одна на все три механики, и знает она о них ровно три вещи: стоит ли
/// в центре текст или динамик, есть ли под центром пометка и торопят ли на
/// этом круге. Ни язык вариантов, ни то, какие фразы вокруг, сюда не доходят —
/// язык арена получает готовым списком, а подбор фраз остался в сборщике.
///
/// ── Что здесь было и почему больше нет ──────────────────────────────────
///
/// 1. Тесты «подсказка под центром показывается, когда она есть» и
///    «подсказка и пометка стоят рядом, а не вместо друг друга» удалены
///    вместе с `promptHint`. Свободная подсказка была у лексемы **родного**
///    языка («карта» → «банковская»): там язык файла и есть язык игрока. У
///    фразы такого поля нет и взяться ему негде, так что под центром осталась
///    одна строка — пометка-код, сегодня это регистр. Ставить рядом нечего.
///
/// 2. Тесты «круг из одного варианта отвечает тапом» и «единственный вариант
///    соединяется линией от центра» удалены: одновариантных кругов больше не
///    бывает. Вариантов всегда шесть (`ScoreBalance.optionsPerCircle`), а
///    знакомство из показа стало исключением — вокруг новой фразы стоят пять
///    уже известных. Что круг работает при полном наборе, проверяет тест
///    «линия соединяет тот вариант, к которому её тянут»: он обходит все
///    шесть, чего одновариантные тесты как раз и не умели.
///
/// 3. Копия геометрии арены (радиус варианта, орбита, угол по индексу) из
///    этого файла удалена. Она держалась на том, что вариант — точка на
///    окружности известного радиуса; теперь вариант — капсула, размер которой
///    считается от фразы, и повторить этот расчёт в тесте значило бы
///    проверять свою же арифметику. Тянем и мерим по тому, что отрисовалось:
///    `find.text` для жестов, `CircleArena.optionKey` для прямоугольников.
///    Заодно ушло условие «тест обязан знать, как арена считает» — раскладку
///    теперь можно переделать, не переписывая тесты поведения.
void main() {
  // Худший случай раскладки читается из ассета, а не вписывается сюда:
  // корпус уже менялся дважды, и вписанные строки устарели бы молча.
  // Грузится он в `setUpAll`, потому что внутри `testWidgets` живут
  // поддельные часы и настоящее чтение файла под ними не завершается.
  late CorpusExtremes corpus;
  setUpAll(() async => corpus = await CorpusExtremes.load());

  // ── Размер арены в тесте ─────────────────────────────────────────────────
  //
  // 648×546 — телефонная арена, пересчитанная в тестовый шрифт.
  //
  // Настоящая арена на экране 360×640 — 324×546: столько остаётся от экрана
  // под шапкой забега, отступами и рамкой реакции. Это замер, а не оценка, и
  // делает его `run_screen_test.dart` — там тот же худший случай идёт на
  // настоящем `RunScreen`, на наборе экранов, и арену тест меряет сам, а не
  // объявляет. Здесь число вписано, потому что арена поднята без хозяина, и
  // ровно поэтому его нельзя брать наугад.
  //
  // В окружении flutter_test каждый знак шириной ровно с кегль (проверено:
  // десять знаков кегля 16 занимают 160 точек), в жизни средний знак примерно
  // вдвое уже. Значит одна и та же фраза занимает вдвое больше **ширины** —
  // а число строк и высота совпадают, потому что высота строки задана кеглем
  // и там, и здесь. Поэтому удвоена ширина (324 → 648), а высота взята
  // настоящей.
  //
  // Мерить раскладку на 324 тестовых точках было бы не строгостью, а
  // подлогом: это телефон шириной 162dp, которого не существует. Здесь стояла
  // высота 480 — тоже не подлог, но и не телефон: на ней худший случай нового
  // корпуса уже не влезает и картинка уменьшается, то есть эти тесты
  // проверяли бы не тот круг, который игрок видит в руках. Уменьшенный круг
  // проверяется отдельно и на настоящих экранах.
  const width = 648.0;
  const height = 546.0;

  // Шесть строк-фикстура: верная первая, остальные пять — те, которые игрок
  // уже знает (круг устроен так, а не «ответ плюс дистракторы»).
  //
  // Были фразами A0 из созвездий «Город» и «Тело, здоровье и помощь»; корпус
  // с тех пор сменился, и пяти из шести в нём больше нет. Для поведения это
  // безразлично — арена получает готовый список и про корпус не знает
  // ничего, — а вот худший случай раскладки ниже читается из ассета именно
  // потому, что там разница есть: длиннейшая фраза выросла с 90 знаков до
  // 118, и вписанные строки проверяли бы прошлый корпус.
  const options = [
    'Gehen Sie nach rechts.',
    'Ich bringe den Brief zur Post.',
    'Ich habe einen Termin beim Arzt.',
    'Auf dem Stadtplan finde ich jede Straße.',
    'Ich muss zum Arzt, mein Kopf tut weh.',
    'Ich habe seit gestern Schmerzen im Rücken.',
  ];
  const answer = 'Gehen Sie nach rechts.';
  const miss = 'Ich habe einen Termin beim Arzt.';
  const untouched = 'Auf dem Stadtplan finde ich jede Straße.';

  // Прежний «круг» — это pickTarget: в центре фраза на родном, вокруг фразы
  // на изучаемом.
  final question = CircleQuestion(
    itemId: 'city_a0_right',
    tier: Tier.a0,
    mode: GameMode.pickTarget,
    prompt: 'Ідіть праворуч.',
    options: options,
    answerIndex: 0,
    lumens: 45,
  );

  Widget arenaApp(
    CircleQuestion q,
    void Function(int, Duration) onAnswer, {
    bool enabled = true,
    VoidCallback? onReplay,
    Locale? locale,
    double textScale = 1,
    // ── Кто заводит окно ответа ──────────────────────────────────────────
    //
    // Полоса окна — картинка **чужого** отсчёта, и завести его должен хозяин
    // круга. Здесь окно заводится ровно так, как это делает забег: длину
    // берёт у вопроса, то есть у того же правила, по которому забег ставит
    // таймер. `counted: false` — хозяин без таймера; так устроена
    // калибровка, и именно там полоса шла впустую. `window` — хозяин с
    // другим сроком.
    bool counted = true,
    Duration? window,
    // Арена другого размера — там, где проверяется уменьшенная картинка.
    // Умолчание одно на весь файл: телефон, который игрок держит в руках.
    Size? arena,
  }) =>
      MaterialApp(
        // Динамик в центре несёт подпись из локализации: без делегатов
        // механики на слух не собрались бы вовсе.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Локаль задаётся явно там, где проверяется именно перевод: на
        // английском код пометки и её строка совпадают по написанию, и тест
        // не отличил бы перевод от выведенного кода.
        locale: locale,
        home: MediaQuery(
          // Системное увеличение шрифта — не экзотика, а настройка телефона, и
          // раскладка обязана считать по тому кеглю, который увидит глаз.
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: arena?.width ?? width,
                height: arena?.height ?? height,
                child: CircleArena(
                  question: q,
                  enabled: enabled,
                  onReplay: onReplay,
                  onAnswer: onAnswer,
                  answerWindow:
                      counted ? (window ?? q.answerWindow) : null,
                ),
              ),
            ),
          ),
        ),
      );

  /// Разворот круга — 260 мс, и после него арена готова к ответу.
  ///
  /// Именно `pump`, а не `pumpAndSettle`: окно ответа — тоже анимация, и
  /// «дождаться, пока всё успокоится» значит прокрутить все пять секунд
  /// окна. Полосу после этого проверять было бы нечем, а каждый тест начинал
  /// бы с просроченного круга.
  const shown = Duration(milliseconds: 300);

  Future<List<(int, Duration)>> pumpArena(
    WidgetTester tester, {
    bool enabled = true,
    CircleQuestion? q,
    VoidCallback? onReplay,
    Locale? locale,
    double textScale = 1,
    bool counted = true,
    Duration? window,
    Size? arena,
  }) async {
    final answers = <(int, Duration)>[];
    await tester.pumpWidget(
      arenaApp(
        q ?? question,
        (index, latency) => answers.add((index, latency)),
        enabled: enabled,
        onReplay: onReplay,
        locale: locale,
        textScale: textScale,
        counted: counted,
        window: window,
        arena: arena,
      ),
    );
    await tester.pump(shown);
    return answers;
  }

  /// Нажимает по центру каждой из шести капсул — по кругу на вариант — и
  /// возвращает то, что дошло до ответа.
  ///
  /// Нажатие, а не потяг, и это не придирка. Потяг, начавшийся внутри арены,
  /// доставляет свои точки той же арене и **за её границами**: жест уже
  /// захвачен, а `hitTest` раскладки отвечает по своим прямоугольникам, где
  /// бы они ни лежали. Поэтому тест на потяге не видит главного дефекта —
  /// капсулы, уехавшей за низ арены: он видит только то, что раскладка сама о
  /// себе думает. Нажатие идёт через настоящий hit-test дерева, а `Stack`
  /// клипует: капсула за краем не отвечает вовсе, и круг, у которого верный
  /// ответ достался нижней полосе, непроходим. Именно так дефект и нашли —
  /// нажатием, а не потягом.
  Future<List<int>> tapEveryOption(
    WidgetTester tester,
    CircleQuestion q,
  ) async {
    final landed = <int>[];
    var round = q;
    for (var i = 0; i < q.options.length; i++) {
      // Каждый круг принимает один ответ, поэтому на каждый вариант — свой
      // круг: тот же вопрос, но другим объектом.
      await tester.pumpWidget(
        arenaApp(round, (index, latency) => landed.add(index)),
      );
      await tester.pump(shown);
      await tester.tapAt(
        tester.getRect(find.byKey(CircleArena.optionKey(i))).center,
      );
      await tester.pump();
      round = round.again();
    }
    return landed;
  }

  /// Сколько времени осталось по полосе окна: 1 — только открылся, 0 — вышло.
  double timeLeft(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value!;

  /// Цвет надписи варианта. Рамку капсулы красит то же правило из
  /// `_buildOption`, что и надпись, — читаем надпись, она доступна.
  Color? optionColor(WidgetTester tester, String option) =>
      tester.widget<Text>(find.text(option)).style?.color;

  /// Кегль, которым отрисован вариант: раскладка вправе его уменьшить, если
  /// иначе фразы не влезают.
  double? optionFont(WidgetTester tester, String option) =>
      tester.widget<Text>(find.text(option)).style?.fontSize;

  /// Капсула варианта: то, что нарисовано и что должно не налезать.
  ///
  /// Прямоугольник берётся в координатах экрана, то есть **после** возможного
  /// уменьшения картинки: именно его видит и по нему нажимает игрок.
  Rect capsule(WidgetTester tester, int index) =>
      tester.getRect(find.byKey(CircleArena.optionKey(index)));

  /// Во сколько раз круг уменьшен при отрисовке. 1 — в натуральную величину.
  ///
  /// Считается по тому, что видно снаружи: арена, которую круг себе посчитал,
  /// против арены, которая ему досталась. `getSize` отдаёт размер до
  /// преобразования, `getRect` — после, и их отношение и есть масштаб. Своего
  /// поля с масштабом арена не выставляет нарочно: тест не должен уметь
  /// спросить у раскладки, что она сама о себе думает, — весь дефект был
  /// ровно в этом расхождении.
  double pictureScale(WidgetTester tester) =>
      tester.getRect(find.byType(CircleArena)).width /
      tester
          .getSize(find.descendant(
            of: find.byType(FittedBox),
            matching: find.byType(SizedBox),
          ))
          .width;

  /// Тянем от центра к варианту — по тому месту, где он отрисовался.
  Future<void> dragTo(WidgetTester tester, String option) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    await gesture.moveTo(tester.getCenter(find.text(option)));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('центр и все шесть вариантов видны', (tester) async {
    await pumpArena(tester);

    expect(find.text('Ідіть праворуч.'), findsOneWidget);
    // Число вариантов задаёт вопрос, а не арена: она рисует то, что пришло в
    // `options`. Сверка с балансом здесь затем, чтобы фикстура осталась
    // настоящим кругом — изменись `optionsPerCircle`, и раскладка ниже
    // (четыре полосы, между ними центр) складывалась бы уже про другой круг, а
    // тесты продолжали бы зеленеть.
    expect(options, hasLength(ScoreBalance.optionsPerCircle));
    for (final option in options) {
      expect(find.text(option), findsOneWidget, reason: option);
    }
  });

  testWidgets('линия соединяет тот вариант, к которому её тянут',
      (tester) async {
    // Главный жест игры: тянем от центра к нужной капсуле. Обход всех шести —
    // это проверка того, что нарисованное и нажимаемое совпадают: зона
    // попадания шире отрисованной капсулы, а капсулы стоят по две в полосе.
    // Разъедься геометрия отрисовки с `hitTest`, и игрок получал бы ответ
    // соседа — с полной уверенностью, что тянул к своему. Тянем в середину
    // надписи, то есть ровно туда, куда смотрит игрок.
    final answers = <(int, Duration)>[];
    var q = question;
    for (var i = 0; i < options.length; i++) {
      // Каждый круг принимает один ответ, поэтому на каждый вариант — свой
      // круг: тот же вопрос, но другим объектом.
      await tester.pumpWidget(arenaApp(q, (i, l) => answers.add((i, l))));
      await tester.pump(shown);
      await dragTo(tester, options[i]);
      q = q.again();
    }

    expect(answers.map((a) => a.$1).toList(), [0, 1, 2, 3, 4, 5]);
  });

  testWidgets('вариант под пальцем светится до отпускания', (tester) async {
    // Иначе тянуть приходится наугад: до отпускания игрок не знает, какую
    // капсулу поймал, а поймать он мог соседнюю.
    await pumpArena(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    await gesture.moveTo(tester.getCenter(find.text(options[2])));
    await tester.pump();

    expect(optionColor(tester, options[2]), LumenPalette.starlight);
    expect(optionColor(tester, options[3]), isNot(LumenPalette.starlight));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('тап по варианту тоже отвечает', (tester) async {
    final answers = await pumpArena(tester);

    await tester.tap(find.text(miss));
    await tester.pump();

    expect(answers, hasLength(1));
    expect(answers.single.$1, 2);
  });

  testWidgets('отпускание мимо вариантов ответом не считается',
      (tester) async {
    final answers = await pumpArena(tester);

    final arena = tester.getRect(find.byType(CircleArena));
    final gesture = await tester.startGesture(arena.center);
    // Тянем в пустоту и отпускаем. Пустота выбрана не наугад: в полосе
    // центральной фразы вариантов нет по устройству раскладки, а сама фраза
    // обжата по своей длине и стоит посередине — у края этой полосы пусто при
    // любом содержимом круга.
    await gesture.moveTo(arena.centerLeft + const Offset(4, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(answers, isEmpty);
  });

  testWidgets('на закрытый круг второй раз ответить нельзя', (tester) async {
    final answers = await pumpArena(tester);

    await tester.tap(find.text(answer));
    await tester.pump();
    await tester.tap(find.text(miss));
    await tester.pump();

    expect(answers, hasLength(1));
  });

  testWidgets('замороженный круг ответов не принимает', (tester) async {
    final answers = await pumpArena(tester, enabled: false);

    await tester.tap(find.text(answer));
    await tester.pump();

    expect(answers, isEmpty);
  });

  testWidgets('время отклика измеряется от появления круга', (tester) async {
    // Задержка считается по `DateTime.now()`, и виртуальные часы теста её не
    // двигают — поэтому пауза настоящая. Начнись отсчёт в момент ответа или
    // сбрось его любая перерисовка, задержка была бы почти нулевой, FSRS
    // ставил бы «легко» за каждый ответ, и интервалы уехали бы вверх. Ни на
    // одном экране это не видно.
    final answers = await pumpArena(tester);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.tap(find.text(answer));
    await tester.pump();

    expect(answers.single.$2, greaterThan(const Duration(milliseconds: 50)));
  });

  testWidgets('до ответа верный вариант ничем не выделен', (tester) async {
    // Подсветка — это и есть ответ. Загорись она заранее, круг стал бы
    // показом, а не вопросом, и никакая механика уже ничего не проверяла бы.
    await pumpArena(tester);

    for (final option in options) {
      expect(optionColor(tester, option), isNot(LumenPalette.correct),
          reason: option);
      expect(optionColor(tester, option), isNot(LumenPalette.wrong),
          reason: option);
    }
  });

  testWidgets('после промаха горят оба: верный и выбранный', (tester) async {
    // Верный вариант подсвечивается и тогда, когда игрок выбрал другой: круг
    // закрывается и фраза уходит в очередь, так что второй попытки здесь не
    // будет — единственный момент, когда промахнувшийся видит правильный
    // ответ, вот этот. Показать только красное значит отнять очки и не
    // научить.
    await pumpArena(tester);

    await tester.tap(find.text(miss));
    await tester.pump();

    expect(optionColor(tester, answer), LumenPalette.correct);
    expect(optionColor(tester, miss), LumenPalette.wrong);
    expect(optionColor(tester, untouched), isNot(LumenPalette.correct));
    expect(optionColor(tester, untouched), isNot(LumenPalette.wrong));
  });

  testWidgets('пометка показывается на языке интерфейса, а не как код',
      (tester) async {
    // Раньше пометка печаталась как пришла из контента, и это давало два
    // сорта неправды: под немецким словом русский грамматический ярлык
    // (немецкий файл читает автор контента, а не игрок), а под каждой из 432
    // фраз — английское `casual` из внутреннего кода.
    await pumpArena(
      tester,
      locale: const Locale('uk'),
      q: const CircleQuestion(
        itemId: 'doctor_a1_throat',
        tier: Tier.a1,
        mode: GameMode.pickNative,
        prompt: 'Mein Hals tut weh.',
        promptTag: 'casual',
        options: [
          'У мене болить горло.',
          'Ідіть праворуч.',
          'Я несу лист на пошту.',
          'У мене запис до лікаря.',
          'У мене з учора біль у спині.',
          'На мапі я знаходжу кожну вулицю.',
        ],
        answerIndex: 0,
        lumens: 30,
      ),
    );

    expect(find.text('casual'), findsNothing);
    expect(find.text('розмовне'), findsOneWidget);
  });

  testWidgets('промах, вернувшийся последним, снова принимает ответ',
      (tester) async {
    // Забег возвращает промах в конец очереди. Пока за ним стоят другие
    // круги, следующим показывается другой вопрос и арена сбрасывается. А
    // когда промах — последний круг, следующим идёт он же: если вернуть тот
    // же объект, `didUpdateWidget` не увидит смены, `_chosen` останется, и
    // арена больше не примет ответов. Забег ждёт вечно, уровень висит.
    final answers = <(int, Duration)>[];
    void onAnswer(int i, Duration l) => answers.add((i, l));

    await tester.pumpWidget(arenaApp(question, onAnswer));
    await tester.pump(shown);
    await tester.tap(find.text(miss));
    await tester.pump();
    expect(answers, hasLength(1), reason: 'промах не зарегистрирован');

    // Ровно то, что делает забег: тот же вопрос снова, другим объектом.
    await tester.pumpWidget(arenaApp(question.again(), onAnswer));
    await tester.pump(shown);
    await tester.tap(find.text(answer));
    await tester.pump();

    expect(answers, hasLength(2),
        reason: 'арена не приняла второй ответ — забег завис бы');
  });

  testWidgets('новый вопрос сбрасывает круг', (tester) async {
    final answers = <(int, Duration)>[];
    void onAnswer(int i, Duration l) => answers.add((i, l));

    await tester.pumpWidget(arenaApp(question, onAnswer));
    await tester.pump(shown);
    await tester.tap(find.text(answer));
    await tester.pump();
    expect(answers, hasLength(1));

    // Фраза в центре из семи слов: на прежней раскладке она в круг не
    // помещалась и роняла тест переполнением — теперь центр переносит её сам
    // и место под перенос считает заранее.
    const next = CircleQuestion(
      itemId: 'doctor_a0_pain',
      tier: Tier.a0,
      mode: GameMode.pickTarget,
      prompt: 'У мене з учора біль у спині.',
      options: [
        'Ich habe seit gestern Schmerzen im Rücken.',
        'Gehen Sie nach rechts.',
        'Ich bringe den Brief zur Post.',
        'Ich habe einen Termin beim Arzt.',
        'Auf dem Stadtplan finde ich jede Straße.',
        'Ich muss zum Arzt, mein Kopf tut weh.',
      ],
      answerIndex: 0,
      lumens: 20,
    );
    await tester.pumpWidget(arenaApp(next, onAnswer));
    await tester.pump(shown);

    // Круг снова принимает ответы.
    await tester.tap(find.text('Ich habe seit gestern Schmerzen im Rücken.'));
    await tester.pump();
    expect(answers, hasLength(2));
    expect(answers.last.$1, 0);
  });

  group('окно ответа', () {
    testWidgets('полоса убывает и доходит до нуля', (tester) async {
      // Полоса, которая не двигается, — не окно, а украшение: игрок не
      // узнаёт, что времени осталось меньше, и просрочка приходит для него
      // без предупреждения.
      await pumpArena(tester);

      final start = timeLeft(tester);
      expect(start, greaterThan(0.8), reason: 'полоса начинается почти полной');

      await tester.pump(const Duration(seconds: 2));
      final mid = timeLeft(tester);
      expect(mid, lessThan(start));
      expect(mid, greaterThan(0), reason: 'окно кончилось раньше срока');

      await tester.pump(ScoreBalance.answerWindow);
      expect(timeLeft(tester), 0);
    });

    testWidgets('где отсчёта нет, там нет и полосы', (tester) async {
      // Круг обычный: `isNew` здесь ложь, и прежняя арена рисовала полосу
      // именно по нему — то есть решала за хозяина, торопят ли игрока. В
      // калибровке решение оказалось неверным: круги там идут с `isNew:
      // false`, потому что онбординг не знакомит, а мерит, а таймера в нём
      // нет ни одного. Игрок на первом экране приложения двадцать раз
      // смотрел, как полоса добегает до конца и краснеет, и ничего не
      // происходило — это учит **не смотреть на полосу** ровно перед тем
      // забегом, где она наказывает.
      final answers = await pumpArena(tester, counted: false);
      expect(question.isNew, isFalse,
          reason: 'фикстура перестала быть обычным кругом');

      expect(find.byType(LinearProgressIndicator), findsNothing);
      // И не появляется потом: полосы нет не «пока», а вовсе.
      await tester.pump(ScoreBalance.answerWindow * 2);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Круг при этом играется как обычно — у него отобрали таймер, а не игру.
      await tester.tap(find.text(answer));
      await tester.pump();
      expect(answers.single.$1, 0);
    });

    testWidgets('полоса идёт столько, сколько отсчитывает хозяин',
        (tester) async {
      // Своего срока у полосы нет: она обещает игроку чужой отсчёт. Держи она
      // собственную длительность — на круге с другим окном полоса врала бы
      // либо в запас, либо в спешку, и заметить это было бы нечем.
      await pumpArena(tester, window: const Duration(seconds: 2));

      // Ровно половина двухсекундного окна: `shown` уже прошло на развороте.
      await tester.pump(const Duration(seconds: 1) - shown);
      expect(timeLeft(tester), closeTo(0.5, 0.02),
          reason: 'полоса идёт не по сроку хозяина, а по своему');
      await tester.pump(const Duration(seconds: 1));
      expect(timeLeft(tester), 0);
    });

    testWidgets('на знакомстве полосы нет вовсе', (tester) async {
      // Знакомство устроено исключением: вокруг новой фразы стоят пять уже
      // известных, и чтобы прийти к ответу, игрок читает пять знакомых
      // строчек. Торопить его в этот момент значит требовать угадать, а не
      // сообразить. Полоса, идущая на первом показе, — то же самое, что
      // окно: она подгоняет.
      //
      // Окно здесь заводится так же, как в забеге — из
      // `CircleQuestion.answerWindow`, — поэтому тест проверяет и само
      // правило «у знакомства окна нет», а не только то, что арена слушается
      // параметра.
      await pumpArena(
        tester,
        q: const CircleQuestion(
          itemId: 'city_a0_right',
          tier: Tier.a0,
          mode: GameMode.pickTarget,
          prompt: 'Ідіть праворуч.',
          options: options,
          answerIndex: 0,
          lumens: 0,
          isNew: true,
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      // И это не мешает знакомству быть обычным кругом.
      expect(find.text(answer), findsOneWidget);
    });

    testWidgets('ответ останавливает полосу', (tester) async {
      // Ответ дан, круг закрыт — дальше полоса уже ни о чём не сообщает.
      // Продолжи она идти, игрок смотрел бы, как истекает время на ответ,
      // который он уже дал, и на просрочку, которой не будет.
      final answers = await pumpArena(tester);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text(answer));
      await tester.pump();
      expect(answers, hasLength(1));

      final stopped = timeLeft(tester);
      expect(stopped, greaterThan(0), reason: 'полоса схлопнулась в ноль');

      await tester.pump(const Duration(seconds: 3));
      expect(timeLeft(tester), stopped);
    });

    testWidgets('замороженный круг окна не тратит', (tester) async {
      // Пока круг заморожен — идёт анимация или показывается результат, — он
      // ответов не принимает. Списывать за это время значит отдать игроку
      // круг с уже початым окном.
      await pumpArena(tester, enabled: false);

      expect(timeLeft(tester), 1);
      await tester.pump(const Duration(seconds: 3));
      expect(timeLeft(tester), 1);
    });
  });

  group('механика на слух', () {
    // В центре динамик. Текст в центре отдал бы ответ, а задание в том, чтобы
    // узнать фразу на слух, — поэтому вопрос здесь нарочно несёт её в
    // `prompt`, и арена обязана его не показать.
    const listen = CircleQuestion(
      itemId: 'doctor_a1_throat',
      tier: Tier.a1,
      mode: GameMode.listenNative,
      prompt: 'Mein Hals tut weh.',
      promptSpeech: 'Mein Hals tut weh.',
      options: [
        'У мене болить горло.',
        'Ідіть праворуч.',
        'Я несу лист на пошту.',
        'У мене запис до лікаря.',
        'У мене з учора біль у спині.',
        'На мапі я знаходжу кожну вулицю.',
      ],
      answerIndex: 0,
      lumens: 35,
    );

    testWidgets('центр показывает динамик, а не фразу', (tester) async {
      await pumpArena(tester, q: listen, onReplay: () {});

      expect(find.text('Mein Hals tut weh.'), findsNothing);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      for (final option in listen.options) {
        expect(find.text(option), findsOneWidget, reason: option);
      }
    });

    testWidgets('нажатие на динамик проигрывает заново', (tester) async {
      var replays = 0;
      await pumpArena(tester, q: listen, onReplay: () => replays++);

      // Повторное прослушивание — часть задания, а не подсказка: слушать
      // можно сколько нужно, пока ответ не выбран.
      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();

      expect(replays, 2);
    });

    testWidgets('замороженный круг не проигрывает заново', (tester) async {
      var replays = 0;
      await pumpArena(
        tester,
        enabled: false,
        q: listen,
        onReplay: () => replays++,
      );

      await tester.tap(find.byIcon(Icons.volume_up), warnIfMissed: false);
      await tester.pump();

      expect(replays, 0);
    });
  });

  group('раскладка', () {
    // ── Худший случай, а не удобный ──────────────────────────────────────
    //
    // Шесть самых длинных фраз корпуса и самый длинный перевод в центре —
    // прочитанные из `assets/content/de.db`, а не вписанные сюда.
    //
    // Вписаны они и были: 90, 83, 81, 81, 74, 74 знака вокруг и 66 в центре.
    // Корпус с тех пор вырос до 1500 фраз и потерял многоточия, самая длинная
    // немецкая стала 118 знаков, украинский перевод — 97, и вписанный худший
    // случай перестал быть худшим молча. Один раз он так уже устарел; читать
    // его из того же файла, который открывает приложение, — единственный
    // способ не повторить это в третий раз.
    //
    // Такого круга в игре не бывает: вокруг фразы стоят пять похожих на неё, а
    // в центре — её собственный перевод, и шесть самых длинных фраз из разных
    // тем вместе не соберутся никогда. В этом и смысл: худший случай —
    // верхняя граница, а не сцена. Тест на выдуманных коротких строках
    // охранял бы ровно ничего — обрезка на телефоне пришла как раз с фраз B2.
    late List<String> longest;
    late CircleQuestion worst;

    // Другой конец шкалы: шесть самых длинных фраз яруса A0 и самый длинный
    // перевод того же яруса в центре. Раскладка обязана быть хороша и здесь:
    // подогнанная под B2 она превратила бы A0 в шесть одинаковых плит с одним
    // словом посередине, а круг — в список.
    late List<String> shortest;
    late CircleQuestion easiest;

    // И самый край той же шкалы: шесть **самых коротких** фраз корпуса. На
    // них проверяется, что капсула обжимается по тексту, а не растягивается
    // на всю полосу.
    late List<String> tiniest;
    late CircleQuestion lightest;

    setUpAll(() {
      longest = corpus.longestTarget(ScoreBalance.optionsPerCircle);
      // Пометка стоит нарочно: под центром появляется вторая строка, и худший
      // случай становится ещё на строку выше. Локаль по умолчанию английская,
      // и код пометки совпадает с её строкой — здесь это удобно, а проверяет
      // перевод отдельный тест выше.
      worst = CircleQuestion(
        itemId: 'corpus_worst',
        tier: Tier.b2,
        mode: GameMode.pickTarget,
        prompt: corpus.longestNative(1).single,
        promptTag: 'formal',
        options: longest,
        answerIndex: 0,
        lumens: 60,
      );
      shortest = corpus.longestTarget(
        ScoreBalance.optionsPerCircle,
        on: Tier.a0,
      );
      easiest = CircleQuestion(
        itemId: 'corpus_easiest',
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: corpus.longestNative(1, on: Tier.a0).single,
        options: shortest,
        answerIndex: 0,
        lumens: 20,
      );
      tiniest = corpus.shortestTarget(ScoreBalance.optionsPerCircle);
      lightest = CircleQuestion(
        itemId: 'corpus_lightest',
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: corpus.shortestNative(1, on: Tier.a0).single,
        options: tiniest,
        answerIndex: 0,
        lumens: 20,
      );
    });

    /// Лежит ли [inner] целиком внутри [outer]. Допуск — на округление
    /// замера: раскладка мерит текст сама и округляет размеры вверх.
    bool inside(Rect outer, Rect inner) =>
        inner.left >= outer.left - 0.5 &&
        inner.top >= outer.top - 0.5 &&
        inner.right <= outer.right + 0.5 &&
        inner.bottom <= outer.bottom + 0.5;

    /// Инвариант раскладки, проверяемый по отрисованному: ни одна фраза не
    /// обрезана, ничто ни на что не налезает, ничто не вышло за арену.
    ///
    /// Проверяется по прямоугольникам, а не по картинке: «выглядит нормально»
    /// — это то, что владелец проекта увидел на телефоне и что тесты
    /// пропустили. Прямоугольник же либо пересекается с соседним, либо нет.
    void expectLayoutHolds(WidgetTester tester, List<String> around) {
      final arena = tester.getRect(find.byType(CircleArena));

      // 1. Ничего не обрезано. `didExceedMaxLines` — та самая проверка, из-за
      //    которой всё это считается: прежняя арена ставила `maxLines: 3` с
      //    многоточием, и на фразах B2 многоточие срабатывало почти всегда.
      //    Сейчас число строк не ограничено, и флаг ложь по построению — но
      //    вернись `maxLines`, и он станет истиной ровно на том, что игрок
      //    видел на телефоне.
      for (final element in find
          .descendant(
            of: find.byType(CircleArena),
            matching: find.byType(Text),
          )
          .evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'обрезано многоточием: ${paragraph.text.toPlainText()}',
        );
      }

      // 2. Обрезка бывает и без многоточия: абзац, которому не хватило места,
      //    просто уезжает под край своей капсулы. Поэтому отдельно — что
      //    абзац целиком внутри капсулы, а капсула внутри арены.
      final boxes = [for (var i = 0; i < around.length; i++) capsule(tester, i)];
      for (var i = 0; i < around.length; i++) {
        expect(
          inside(boxes[i], tester.getRect(find.text(around[i]))),
          isTrue,
          reason: 'фраза вышла за капсулу: ${around[i]}',
        );
        expect(inside(arena, boxes[i]), isTrue, reason: 'капсула $i вне арены');
      }

      // 3. Ничто ни на что не налезает. Центр — вместе с вариантами: раньше
      //    его фраза проходила поверх соседних, и не читались уже оба.
      final prompt = tester.getRect(find.byKey(CircleArena.promptKey));
      expect(inside(arena, prompt), isTrue, reason: 'центр вне арены');
      for (var i = 0; i < boxes.length; i++) {
        expect(boxes[i].overlaps(prompt), isFalse,
            reason: 'капсула $i налезла на центр');
        for (var j = i + 1; j < boxes.length; j++) {
          expect(boxes[i].overlaps(boxes[j]), isFalse,
              reason: 'капсулы $i и $j налезают друг на друга');
        }
      }
    }

    testWidgets('худший случай корпуса: ничего не обрезано и не налезает',
        (tester) async {
      await pumpArena(tester, q: worst);

      // Восемь надписей: шесть вариантов, центр и пометка под ним. Число
      // здесь затем, чтобы проверка на обрезку не оказалась однажды пустой:
      // перестань арена показывать пометку — и цикл выше молча ослабнет.
      expect(
        find
            .descendant(
              of: find.byType(CircleArena),
              matching: find.byType(Text),
            )
            .evaluate(),
        hasLength(longest.length + 2),
      );

      expectLayoutHolds(tester, longest);

      // Пометка — тоже часть центра, и налезать на неё нельзя.
      final hint = tester.getRect(find.text('formal'));
      for (var i = 0; i < longest.length; i++) {
        expect(capsule(tester, i).overlaps(hint), isFalse,
            reason: 'капсула $i налезла на пометку');
      }
    });

    testWidgets('короткие фразы: раскладка так же цела', (tester) async {
      await pumpArena(tester, q: easiest);
      expectLayoutHolds(tester, shortest);
    });

    testWidgets('худший случай при системном увеличении шрифта',
        (tester) async {
      // Крупный шрифт в настройках телефона — не экзотика, и обрезка от него
      // возвращалась бы в полном объёме, будь предел читаемости записан в
      // логических точках: логический кегль 13 при увеличении 1.5 выходит на
      // экран как 19.5, шесть фраз по 90 знаков перестают влезать, и
      // раскладка, которой запрещено уменьшать, начинает обрезать. Предел
      // меряется в отрисованном кегле, поэтому здесь фразы становятся мельче
      // логически, но на экране остаются крупнее, чем без увеличения.
      await pumpArena(tester, q: worst, textScale: 1.5);
      expectLayoutHolds(tester, longest);

      final logical = optionFont(tester, longest.first)!;
      expect(logical, lessThan(13.0), reason: 'логический кегль обязан уступить');
      expect(logical * 1.5, greaterThanOrEqualTo(13.0),
          reason: 'на экране — не мельче предела читаемости');
    });

    testWidgets('на плотной кладке тянущийся к своей капсуле её и получает',
        (tester) async {
      // Худший случай — это ещё и самые тесные зазоры: между полосами
      // остаётся минимум, и зоны попадания сходятся ближе всего. Если они
      // пересекутся, игрок получит ответ соседа, целясь в свой, — и обвинит
      // в этом себя.
      final answers = <(int, Duration)>[];
      var q = worst;
      for (var i = 0; i < longest.length; i++) {
        await tester.pumpWidget(arenaApp(q, (i, l) => answers.add((i, l))));
        await tester.pump(shown);
        await dragTo(tester, longest[i]);
        q = q.again();
      }

      expect(answers.map((a) => a.$1).toList(), [0, 1, 2, 3, 4, 5]);
    });

    testWidgets('на плотной кладке нажатие по капсуле доходит до ответа',
        (tester) async {
      // Тот же обход, но нажатием — и это не дубль предыдущего теста.
      //
      // Потяг проверяет раскладку её же словами: жест, начавшийся внутри
      // арены, доставляет точки той же арене и за её пределами, а `hitTest`
      // отвечает по своим прямоугольникам, где бы они ни лежали. Нажатие
      // идёт через настоящий hit-test дерева, а `Stack` клипует: капсула,
      // уехавшая за край, не отвечает вовсе. Ровно этот разрыв и стоил
      // проекту дефекта — критик нашёл его нажатием, а тест на потяге
      // зеленел.
      expect(await tapEveryOption(tester, worst), [0, 1, 2, 3, 4, 5]);
    });

    testWidgets('кегль уменьшается только когда нужно и не ниже предела',
        (tester) async {
      // Два конца шкалы в одном тесте: сравнивать кегль с числом из Material
      // значило бы проверять Material, а сравнить два круга друг с другом —
      // проверить правило. Правило такое: место кончается раньше кегля, но
      // предел читаемости кегль не переходит.
      await pumpArena(tester, q: easiest);
      final onShort = optionFont(tester, shortest.first);
      expect(onShort, isNotNull);

      await pumpArena(tester, q: worst);
      final onLong = optionFont(tester, longest.first);
      expect(onLong, isNotNull);

      expect(onLong, lessThan(onShort!),
          reason: 'на 118 знаках кегль обязан был уменьшиться');
      expect(onLong, greaterThanOrEqualTo(13.0),
          reason: 'ниже предела читаемости: лучше капсула в пять строк');

      // И одним кеглем на весь круг: разный размер у соседних вариантов читался
      // бы как подсказка о том, какой из них главный.
      for (final option in longest) {
        expect(optionFont(tester, option), onLong, reason: option);
      }
    });

    testWidgets('короткая фраза остаётся звездой, а не полосой',
        (tester) async {
      // Капсула обжата по фразе, а не растянута на всю доступную ширину.
      // Иначе круг из коротких фраз превратился бы в шесть одинаковых плит —
      // то есть в список, который метафора неба не допускает.
      //
      // Фразы здесь самые короткие в корпусе, и это не поддавки. На самых
      // длинных фразах A0 капсула одиночной полосы **честно** занимает всю
      // ширину: ей столько и нужно. Проверять обжатие надо там, где обжимать
      // есть что, иначе тест запретил бы раскладке пользоваться шириной,
      // которую фраза требует.
      await pumpArena(tester, q: lightest);
      final arena = tester.getRect(find.byType(CircleArena));

      // Верхняя и нижняя полосы — во всю ширину арены, и обжимать там есть
      // что: 0 — верхний вариант, 3 — нижний.
      for (final index in [0, 3]) {
        expect(capsule(tester, index).width, lessThan(arena.width / 2),
            reason: 'капсула $index растянута на всю полосу');
      }
    });

    testWidgets('на уменьшенной картинке потяг попадает туда, куда видно',
        (tester) async {
      // ── Арена, на которой круг не влезает ──────────────────────────────
      //
      // 568×386 — модель телефона 320×480: арена 284×386, ширина удвоена под
      // тестовый шрифт. Худший случай корпуса там не укладывается ни при
      // каком кегле, и картинка уменьшается целиком.
      const small = Size(568, 386);

      await pumpArena(tester, q: worst, arena: small);
      final scale = pictureScale(tester);
      expect(scale, lessThan(1),
          reason: 'на арене 284×386 худший случай обязан был уменьшиться');

      // Главный жест игры на уменьшенной картинке: тянем от центра к каждой
      // из шести капсул — по тому месту, где надпись **видна**.
      //
      // Уменьшает картинку `FittedBox`, и жест проходит через то же
      // преобразование, которым она нарисована: в раскладку точка приходит уже
      // в её собственных координатах. Считай масштаб раскладка сама — попадание
      // считалось бы вторым кодом, и разъехаться с картинкой он мог бы молча,
      // то есть игрок получал бы ответ не того варианта, к которому тянул.
      final answers = <(int, Duration)>[];
      var q = worst;
      for (var i = 0; i < longest.length; i++) {
        await tester.pumpWidget(
          arenaApp(q, (i, l) => answers.add((i, l)), arena: small),
        );
        await tester.pump(shown);
        await dragTo(tester, longest[i]);
        q = q.again();
      }
      expect(answers.map((a) => a.$1).toList(), [0, 1, 2, 3, 4, 5]);
    });

    testWidgets('на телефоне круг рисуется в натуральную величину',
        (tester) async {
      // Уменьшение картинки — крайний ход, а не обычный режим: на экране, где
      // круг влезает, он обязан рисоваться как есть, привычной кладкой
      // (1 + 2 + 2 + 1). Иначе «влезает всегда» можно было бы получить одним
      // масштабом на все случаи, а игрок получил бы мелкий шрифт там, где
      // места хватало.
      await pumpArena(tester, q: worst);
      expect(pictureScale(tester), 1.0,
          reason: 'худший случай корпуса на телефоне уменьшается');

      // Привычная кладка: верхний вариант стоит один, над полосой из двух.
      expect(capsule(tester, 0).bottom, lessThanOrEqualTo(capsule(tester, 1).top),
          reason: 'верхний вариант перестал быть отдельной полосой');
      expect(capsule(tester, 1).top, closeTo(capsule(tester, 5).top, 0.5),
          reason: 'вторая полоса перестала быть полосой из двух');
    });
  });
}
