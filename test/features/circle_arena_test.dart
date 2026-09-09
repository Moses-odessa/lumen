import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/core/theme/palette.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';

/// Круг проверяется по поведению, а не по пикселям: главный жест игры должен
/// работать, промах по варианту не должен считаться ответом, повторный ответ
/// на закрытый круг — не проходить, а полоса окна — идти ровно там, где игрока
/// торопят.
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
void main() {
  // Арена здесь заметно больше телефонной, и это не небрежность. Шрифт
  // тестового окружения шире рабочего примерно вдвое — каждый знак ровно с
  // кегль, — а центр круга фразу переносить не умеет: у текста нет ни
  // `maxLines`, ни сжатия, и когда строка не влезает, Column роняет тест
  // переполнением вместо того, что тест проверяет. На 400 логических точках
  // так падает уже «У мене з учора біль у спині.». Размер выбран так, чтобы
  // фраза из семи слов влезала: тогда проверяется поведение круга, а не
  // ширина шрифта. Само ограничение центра живёт в `lib`, а не здесь.
  const size = 560.0;
  const center = Offset(size / 2, size / 2);

  // Геометрия из _ArenaLayout: вариант 0 — сверху, дальше по часовой.
  const optionRadius = size * 0.15;
  const orbit = size / 2 - optionRadius - 8;

  Offset optionCenter(int index, [int count = ScoreBalance.optionsPerCircle]) {
    final angle = -math.pi / 2 + 2 * math.pi * index / count;
    return center + Offset(math.cos(angle), math.sin(angle)) * orbit;
  }

  // Настоящий контент: шесть фраз яруса A0 из созвездий «Город» и «Тело,
  // здоровье и помощь». Верная — первая, остальные пять это те, которые
  // игрок уже знает: круг теперь устроен так, а не «ответ плюс дистракторы».
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
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: CircleArena(
                question: q,
                enabled: enabled,
                onReplay: onReplay,
                onAnswer: onAnswer,
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
  }) async {
    final answers = <(int, Duration)>[];
    await tester.pumpWidget(
      arenaApp(
        q ?? question,
        (index, latency) => answers.add((index, latency)),
        enabled: enabled,
        onReplay: onReplay,
        locale: locale,
      ),
    );
    await tester.pump(shown);
    return answers;
  }

  /// Сколько времени осталось по полосе окна: 1 — только открылся, 0 — вышло.
  double timeLeft(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ).value!;

  /// Цвет надписи варианта. Свечение звезды рисуется на канве и прочитать его
  /// нельзя, но красит его то же правило из `_buildOption`, что и надпись.
  Color? optionColor(WidgetTester tester, String option) =>
      tester.widget<Text>(find.text(option)).style?.color;

  Future<void> dragTo(WidgetTester tester, int index) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    await gesture.moveTo(
      tester.getTopLeft(find.byType(CircleArena)) + optionCenter(index),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('центр и все шесть вариантов видны', (tester) async {
    await pumpArena(tester);

    expect(find.text('Ідіть праворуч.'), findsOneWidget);
    // Число вариантов задаёт вопрос, а не арена: она рисует то, что пришло в
    // `options`. Сверка с балансом здесь затем, чтобы фикстура осталась
    // настоящим кругом — изменись `optionsPerCircle`, и вся геометрия ниже
    // (шесть звёзд по окружности, соседи почти вплотную) считалась бы уже про
    // другой круг, а тесты продолжали бы зеленеть.
    expect(options, hasLength(ScoreBalance.optionsPerCircle));
    for (final option in options) {
      expect(find.text(option), findsOneWidget, reason: option);
    }
  });

  testWidgets('линия соединяет тот вариант, к которому её тянут',
      (tester) async {
    // Главный жест игры: тянем от центра к нужной звезде. Обход всех шести —
    // это проверка того, что нарисованное и нажимаемое совпадают: зона
    // попадания шире отрисованной звезды, а на шести вариантах соседи стоят
    // почти вплотную. Разъедься геометрия отрисовки с `hitTest`, и игрок
    // получал бы ответ соседа — с полной уверенностью, что тянул к своему.
    final answers = <(int, Duration)>[];
    var q = question;
    for (var i = 0; i < options.length; i++) {
      // Каждый круг принимает один ответ, поэтому на каждый вариант — свой
      // круг: тот же вопрос, но другим объектом.
      await tester.pumpWidget(arenaApp(q, (i, l) => answers.add((i, l))));
      await tester.pump(shown);
      await dragTo(tester, i);
      q = q.again();
    }

    expect(answers.map((a) => a.$1).toList(), [0, 1, 2, 3, 4, 5]);
  });

  testWidgets('вариант под пальцем светится до отпускания', (tester) async {
    // Иначе тянуть приходится наугад: до отпускания игрок не знает, какую
    // звезду поймал, а поймать он мог соседнюю.
    await pumpArena(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    await gesture.moveTo(
      tester.getTopLeft(find.byType(CircleArena)) + optionCenter(2),
    );
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    // Тянем в пустоту между вариантами и отпускаем.
    await gesture.moveBy(const Offset(20, 20));
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

    // Фраза в центре из семи слов — та самая, на которой круг размером с
    // телефон переполняется (см. про размер арены выше).
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

    testWidgets('на знакомстве полосы нет вовсе', (tester) async {
      // Знакомство устроено исключением: вокруг новой фразы стоят пять уже
      // известных, и чтобы прийти к ответу, игрок читает пять знакомых
      // строчек. Торопить его в этот момент значит требовать угадать, а не
      // сообразить. Полоса, идущая на первом показе, — то же самое, что
      // окно: она подгоняет.
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
}
