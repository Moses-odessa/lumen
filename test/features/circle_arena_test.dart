import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';

/// Круг проверяется по поведению, а не по пикселям: главный жест игры должен
/// работать, промах по варианту не должен считаться ответом, а повторный
/// ответ на закрытый круг — проходить.
///
/// Арена одна на четыре механики из шести, и знает она о них ровно две вещи:
/// стоит ли в центре текст или динамик и сколько вокруг вариантов. Ни язык
/// вариантов, ни вид дистракторов сюда не доходят — язык арена получает
/// готовым списком, а вид дистракторов остался в плане круга. Поэтому тесты
/// на разницу «тематические против созвучных» здесь и не появляются: с точки
/// зрения арены это один и тот же круг.
void main() {
  const size = 400.0;
  const center = Offset(size / 2, size / 2);

  // Геометрия из _ArenaLayout: вариант 0 — сверху, дальше по часовой.
  const optionRadius = size * 0.15;
  const orbit = size / 2 - optionRadius - 8;

  Offset optionCenter(int index, int count) {
    final angle = -math.pi / 2 + 2 * math.pi * index / count;
    return center + Offset(math.cos(angle), math.sin(angle)) * orbit;
  }

  // Прежний «круг» — это pickTarget: в центре родное слово, вокруг варианты
  // на изучаемом. Один слот, поэтому `single`.
  final question = CircleQuestion.single(
    itemId: 'doctor_person',
    tier: Tier.a0,
    mode: GameMode.pickTarget,
    prompt: 'врач',
    options: const ['Arzt', 'Art', 'Arm', 'Ast'],
    answerIndex: 0,
    lumens: 45,
  );

  Future<List<(int, Duration)>> pumpArena(
    WidgetTester tester, {
    bool enabled = true,
    CircleQuestion? q,
    VoidCallback? onReplay,
    Locale? locale,
  }) async {
    final answers = <(int, Duration)>[];
    await tester.pumpWidget(
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
                question: q ?? question,
                enabled: enabled,
                onReplay: onReplay,
                onAnswer: (index, latency) => answers.add((index, latency)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('центр и все варианты видны', (tester) async {
    await pumpArena(tester);

    expect(find.text('врач'), findsOneWidget);
    for (final option in question.options) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('линия от центра к варианту отвечает на круг', (tester) async {
    final answers = await pumpArena(tester);

    // Главный жест игры: тянем от центра к нужной звезде.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    final target = tester.getTopLeft(find.byType(CircleArena)) +
        optionCenter(0, question.options.length);
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(answers, hasLength(1));
    expect(answers.single.$1, 0);
  });

  testWidgets('тап по варианту тоже отвечает', (tester) async {
    final answers = await pumpArena(tester);

    await tester.tap(find.text('Art'));
    await tester.pump();

    expect(answers, hasLength(1));
    expect(answers.single.$1, 1);
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

    await tester.tap(find.text('Arzt'));
    await tester.pump();
    await tester.tap(find.text('Art'));
    await tester.pump();

    expect(answers, hasLength(1));
  });

  testWidgets('замороженный круг ответов не принимает', (tester) async {
    final answers = await pumpArena(tester, enabled: false);

    await tester.tap(find.text('Arzt'));
    await tester.pump();

    expect(answers, isEmpty);
  });

  testWidgets('время отклика измеряется от появления круга', (tester) async {
    final answers = await pumpArena(tester);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Arzt'));
    await tester.pump();

    expect(answers.single.$2, greaterThan(Duration.zero));
  });

  testWidgets('подсказка под центром показывается, когда она есть',
      (tester) async {
    await pumpArena(
      tester,
      q: CircleQuestion.single(
        itemId: 'x',
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: 'счёт',
        promptHint: 'женский род',
        options: const ['Rechnung', 'Richtung', 'Rechner'],
        answerIndex: 0,
        lumens: 30,
      ),
    );

    expect(find.text('женский род'), findsOneWidget);
  });

  testWidgets('пометка показывается на языке интерфейса, а не как код',
      (tester) async {
    // Раньше пометка печаталась как пришла из контента, и это давало два
    // сорта неправды: под немецким словом русский грамматический ярлык
    // (немецкий файл читает автор контента, а не игрок), а под фразой —
    // английское `casual` из внутреннего кода.
    await pumpArena(
      tester,
      locale: const Locale('uk'),
      q: CircleQuestion.single(
        itemId: 'x',
        tier: Tier.a0,
        mode: GameMode.pickNative,
        prompt: 'das Wasser',
        promptTag: 'uncountable',
        options: const ['вода', 'молоко', 'сок'],
        answerIndex: 0,
        lumens: 30,
      ),
    );

    expect(find.text('uncountable'), findsNothing);
    expect(find.text('незлічуване'), findsOneWidget);
  });

  testWidgets('подсказка и пометка стоят рядом, а не вместо друг друга',
      (tester) async {
    await pumpArena(
      tester,
      locale: const Locale('uk'),
      q: CircleQuestion.single(
        itemId: 'x',
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: 'карта',
        promptHint: 'банковская',
        promptTag: 'uncountable',
        options: const ['Karte', 'Kasse', 'Kunde'],
        answerIndex: 0,
        lumens: 30,
      ),
    );

    expect(find.text('банковская · незлічуване'), findsOneWidget);
  });

  testWidgets('промах, вернувшийся последним, снова принимает ответ',
      (tester) async {
    // Забег возвращает промах в конец очереди. Пока за ним стоят другие
    // круги, следующим показывается другой вопрос и арена сбрасывается. А
    // когда промах — последний круг, следующим идёт он же: если вернуть тот
    // же объект, `didUpdateWidget` не увидит смены, `_chosen` останется, и
    // арена больше не примет ответов. Забег ждёт вечно, уровень висит.
    //
    // Закрывающий уровень фразовый заход — ровно два круга на одном
    // предложении, так что промах на втором вешал уровень целиком. Прежний
    // тест этого не ловил: он подставлял **другой** вопрос.
    final answers = <(int, Duration)>[];

    Widget arena(CircleQuestion q) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: CircleArena(
                  question: q,
                  onAnswer: (i, l) => answers.add((i, l)),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(arena(question));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Art'));
    await tester.pump();
    expect(answers, hasLength(1), reason: 'промах не зарегистрирован');

    // Ровно то, что делает забег: тот же вопрос снова, другим объектом.
    await tester.pumpWidget(arena(question.again()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arzt'));
    await tester.pump();

    expect(answers, hasLength(2),
        reason: 'арена не приняла второй ответ — забег завис бы');
  });

  testWidgets('новый вопрос сбрасывает круг', (tester) async {
    final answers = <(int, Duration)>[];

    Widget arena(CircleQuestion q) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size,
                height: size,
                child: CircleArena(
                  question: q,
                  onAnswer: (i, l) => answers.add((i, l)),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(arena(question));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arzt'));
    await tester.pump();
    expect(answers, hasLength(1));

    final next = CircleQuestion.single(
      itemId: 'pain_noun',
      tier: Tier.a0,
      mode: GameMode.pickTarget,
      prompt: 'боль',
      options: const ['Schmerz', 'Scherz', 'Schmelz'],
      answerIndex: 0,
      lumens: 20,
    );
    await tester.pumpWidget(arena(next));
    await tester.pumpAndSettle();

    // Круг снова принимает ответы.
    await tester.tap(find.text('Schmerz'));
    await tester.pump();
    expect(answers, hasLength(2));
    expect(answers.last.$1, 0);
  });

  // Знакомство с новым словом: вариант один. Раньше такой круг был
  // недостижим — сборщик возвращал `null`, не набрав двух дистракторов, — и
  // проверять, что арена его переживает, было незачем. Теперь это законный
  // круг, и он обязан работать тем же жестом, что и остальные: соединил,
  // услышал, увидел перевод.
  testWidgets('круг из одного варианта отвечает тапом', (tester) async {
    final answers = await pumpArena(
      tester,
      q: CircleQuestion.single(
        itemId: 'nurse_person',
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: 'медсестра',
        options: const ['die Krankenschwester'],
        answerIndex: 0,
        isNew: true,
        lumens: 0,
      ),
    );

    expect(find.text('die Krankenschwester'), findsOneWidget);

    await tester.tap(find.text('die Krankenschwester'));
    await tester.pump();

    expect(answers, hasLength(1));
    expect(answers.single.$1, 0);
  });

  testWidgets('единственный вариант соединяется линией от центра',
      (tester) async {
    final answers = await pumpArena(
      tester,
      q: CircleQuestion.single(
        itemId: 'nurse_person',
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: 'медсестра',
        options: const ['die Krankenschwester'],
        answerIndex: 0,
        isNew: true,
        lumens: 0,
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CircleArena)),
    );
    await gesture.moveTo(
      tester.getTopLeft(find.byType(CircleArena)) + optionCenter(0, 1),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(answers, hasLength(1));
    expect(answers.single.$1, 0);
  });

  // Механики на слух: в центре динамик. Текст в центре отдал бы ответ, а
  // задание в том, чтобы узнать слово на слух, — поэтому вопрос здесь
  // нарочно несёт слово в `prompt`, и арена обязана его не показать.
  testWidgets('центр на слух показывает динамик, а не слово', (tester) async {
    await pumpArena(
      tester,
      q: CircleQuestion.single(
        itemId: 'doctor_person',
        tier: Tier.a0,
        mode: GameMode.listenNative,
        prompt: 'Arzt',
        promptSpeech: 'Arzt',
        options: const ['врач', 'учитель', 'сосед'],
        answerIndex: 0,
        lumens: 35,
      ),
      onReplay: () {},
    );

    expect(find.text('Arzt'), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    for (final option in const ['врач', 'учитель', 'сосед']) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('нажатие на динамик проигрывает заново', (tester) async {
    var replays = 0;
    final listen = CircleQuestion.single(
      itemId: 'doctor_person',
      tier: Tier.a0,
      mode: GameMode.listenNative,
      prompt: '',
      promptSpeech: 'Arzt',
      options: const ['врач', 'учитель', 'сосед'],
      answerIndex: 0,
      lumens: 35,
    );

    await pumpArena(tester, q: listen, onReplay: () => replays++);

    // Повторное прослушивание — часть задания, а не подсказка: слушать можно
    // сколько нужно, пока ответ не выбран.
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
      q: CircleQuestion.single(
        itemId: 'doctor_person',
        tier: Tier.a0,
        mode: GameMode.listenNative,
        prompt: '',
        promptSpeech: 'Arzt',
        options: const ['врач', 'учитель', 'сосед'],
        answerIndex: 0,
        lumens: 35,
      ),
      onReplay: () => replays++,
    );

    await tester.tap(find.byIcon(Icons.volume_up), warnIfMissed: false);
    await tester.pump();

    expect(replays, 0);
  });
}
