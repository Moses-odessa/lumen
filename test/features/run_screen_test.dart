import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/audio/speech_service.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/features/game/application/run_controller.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';
import 'package:lumen/features/game/presentation/run_screen.dart';
import 'package:lumen/features/game/presentation/run_summary_view.dart';

import 'corpus_extremes.dart';

/// Забег вместе со своим экраном — тот самый стык, на котором проект уже
/// пропустил дефект в продакшен.
///
/// Арена, поднятая в тесте одна (`circle_arena_test.dart`), после ответа
/// остаётся на экране, и всё выглядит правильно. Под настоящим хозяином она
/// либо гаснет, либо заменяется — и проверять надо именно это. Экран теперь
/// умеет закрыть круг и **без** ответа: круг живёт столько, сколько просит его
/// текст, и молчание закрывает его так же, как промах. Одна арена на все три
/// механики: второй, заполнявшей пропуски фразы, больше нет.
///
/// Что удалено вместе с фразовой ареной:
///
/// * «заполненная фраза не двигает забег вперёд» и «„Готово“ отвечает».
///   Охраняли правило «ответ отправляет игрок, а не последняя плитка»: пул
///   слов, расстановка по пропускам и кнопка подтверждения. Ни пропусков, ни
///   плиток, ни второй арены в игре нет — фраза заучивается целиком, и вопрос
///   у неё один, «какая из шести».
/// * «перевод виден в паузе» — часть того же теста. Не перенесена, потому что
///   переносить нечего: `CircleQuestion.translation` по-прежнему собирается
///   вопросом, но в дерево не попадает ни разу. Правило потеряно вместе с
///   ареной, а не заменено новым, и это не то, что тест может исправить.
/// * «нажатие по арене в паузе открывает следующий круг» — не удалён, а
///   перенесён: правило живое, нажимать теперь надо не по проявившемуся
///   переводу, а по пустому месту круга.
///
/// **Что изменилось вместе с темпом круга.** Экран снова уходит вперёд сам — и
/// после ответа, и после просрочки, — но ведёт его не число, а озвучка: круг
/// стоит открытым, пока верный ответ дозвучивает, и не короче низа паузы
/// (`RevealBalance`). Кнопки «Дальше» под ареной больше нет, поэтому её не
/// ищет ни один тест файла; что она охраняла и чем это заменено — в докстроке
/// `RunScreen`. Заглушка речи здесь мгновенна, так что пауза в тестах равна
/// ровно своему низу; что она **ждёт озвучку**, проверяется в
/// `run_controller_test.dart` — там же, где эта пауза и живёт.
void main() {
  late ProviderContainer container;
  late SilentSpeechService speech;
  late AppDatabase db;

  /// Худшие строки корпуса — из ассета. Читаются в `setUpAll`, потому что
  /// внутри `testWidgets` живут поддельные часы и настоящее чтение файла под
  /// ними не завершается.
  late CorpusExtremes corpus;
  setUpAll(() async => corpus = await CorpusExtremes.load());

  setUp(() {
    speech = SilentSpeechService();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      speechServiceProvider.overrideWithValue(speech),
      appDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Пять фраз, которые игрок уже знает: на них держится и знакомство, и
  /// любой другой круг — вариантов всегда шесть.
  const known = [
    'Wo ist der Bahnhof',
    'Zwei Kaffee bitte',
    'Ich verstehe nicht',
    'Wie viel kostet das',
    'Bis morgen',
  ];

  /// Круг разговорника: в центре перевод, вокруг шесть фраз на изучаемом.
  CircleQuestion question({
    required String id,
    required String prompt,
    required String answer,
    bool isNew = false,
  }) =>
      CircleQuestion(
        itemId: id,
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: prompt,
        options: [answer, ...known],
        answerIndex: 0,
        lumens: isNew ? 0 : 50,
        isNew: isNew,
        answerSpeech: answer,
        translation: prompt,
      );

  final bill = question(
    id: 'money_a0_bill',
    prompt: 'Счёт, пожалуйста',
    answer: 'Die Rechnung, bitte',
  );
  final time = question(
    id: 'time_a0_have',
    prompt: 'У меня есть время',
    answer: 'Ich habe Zeit',
  );

  /// Вариант, которого в ответе быть не может.
  const wrongOption = 'Ich verstehe nicht';

  Future<void> pumpRun(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: RunScreen()),
        ),
      ),
    );
    // Ровно один кадр, и это не экономия. `pumpAndSettle` здесь не
    // заканчивается никогда: пока круг открыт, полоса окна анимируется, а
    // «дождаться, пока всё успокоится» означает промолчать всё окно, получить
    // промах и получить с ним ещё один круг в очередь.
    await tester.pump();
  }

  RunState state() => container.read(runControllerProvider);
  RunController controller() =>
      container.read(runControllerProvider.notifier);

  /// Пустое место круга: между вариантами, у левого края арены. Нажатие по
  /// самому варианту до арены не доходит — вариант перехватывает его первым.
  Offset emptySpot(WidgetTester tester) {
    final arena = tester.getRect(find.byType(CircleArena));
    return Offset(arena.left + 8, arena.center.dy);
  }

  /// Полоса окна ответа — та, что внутри круга.
  ///
  /// Полос на экране забега две, и путать их нельзя: своя полоса шапки мерит
  /// пройденные круги и живёт всегда, полоса окна показывает отсчёт до
  /// закрытия круга и обязана быть ровно там, где этот отсчёт идёт.
  final windowBar = find.descendant(
    of: find.byType(CircleArena),
    matching: find.byType(LinearProgressIndicator),
  );

  /// Сколько времени осталось по полосе окна: 1 — только открылся, 0 — вышло.
  double windowLeft(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(windowBar).value!;

  /// Прокручивает паузу после ответа до конца: следующий круг встаёт на место
  /// сам, без игрока.
  ///
  /// Длину даёт низ паузы, и это не срезание угла: заглушка речи мгновенна
  /// (`sounds` == 0), то есть отвечает «дозвучало» в ту же микрозадачу, и
  /// пауза равна ровно низу. Число спрашивается у баланса, потому что здесь
  /// проверяется не величина, а то, что **экран** переживает закрытие круга и
  /// показывает следующий.
  Future<void> afterPause(WidgetTester tester, {bool correct = true}) async {
    await tester.pump(
      RevealBalance.forMode(GameMode.pickTarget, correct: correct) +
          const Duration(milliseconds: 1),
    );
  }

  testWidgets('вариант отвечает, и следующий круг встаёт на место арены',
      (tester) async {
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();

    expect(state().phase, RunPhase.revealing);
    expect(state().correct, 1);
    expect(speech.spoken, ['Die Rechnung, bitte']);

    await afterPause(tester);

    // Арена не осталась прежней: в центре другой вопрос, а прежние варианты
    // из дерева ушли. Тот самый дефект, который проект уже пропускал: арена,
    // не заметившая смены вопроса, показывает старое и не принимает ответов.
    expect(find.text('У меня есть время'), findsOneWidget);
    expect(find.text('Счёт, пожалуйста'), findsNothing);
    expect(find.text('Die Rechnung, bitte'), findsNothing);

    // И второй круг тоже отвечает — забег доходит до итога.
    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await afterPause(tester);

    expect(state().isFinished, isTrue);
  });

  testWidgets('под ареной ничего нет: круг закрывает пауза, а не кнопка',
      (tester) async {
    // Решение владельца дословно: «давай обратно уберем кнопку Дальше, просто
    // дадим время для проигрывания предыдущего ответа».
    //
    // Кнопка стояла под ареной и была единственным, что тогда давало верному
    // ответу дозвучать: пауза до неё была числом, в которое озвучка не
    // укладывалась. Ценой было касание на каждом из десяти-четырнадцати
    // кругов забега.
    //
    // Проверяется здесь именно **экран**, и двумя вещами сразу. Первая —
    // кнопки нет: пока она есть, «пауза сама открывает круг» ничего не
    // говорит о цене, которую платит палец. Вторая — арена не меняет размер
    // между вопросом и паузой: под ней теперь не появляется и не исчезает
    // ничего, а раньше это охранялось тем, что кнопка стояла на экране
    // всегда, даже выключенной. Меняйся высота — круг пересчитывал бы
    // раскладку, и шесть капсул переезжали бы ровно в тот момент, когда игрок
    // смотрит на верный вариант.
    controller().start([bill, time]);
    await pumpRun(tester);

    expect(find.byType(FilledButton), findsNothing,
        reason: 'под ареной снова кнопка — это касание на каждом круге');
    final arena = tester.getRect(find.byType(CircleArena));

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.getRect(find.byType(CircleArena)), arena,
        reason: 'арена переехала между вопросом и паузой');

    await afterPause(tester);
    expect(find.text('У меня есть время'), findsOneWidget);
    expect(find.text('Счёт, пожалуйста'), findsNothing);

    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await afterPause(tester);
    expect(state().isFinished, isTrue);
  });

  testWidgets('молчание закрывает круг, и дальше ведёт пауза', (tester) async {
    // Окно на ответ живёт в забеге, полоса окна — в арене, и здесь
    // проверяется, что экран переживает закрытие круга, к которому игрок не
    // прикоснулся: верный вариант прозвучал, потому что промолчавшему его
    // никто не назвал, и он остаётся на экране, пока звучит.
    //
    // Просрочке достаётся долгий низ паузы — тот же, что промаху: услышать и
    // увидеть верный вариант надо успеть. Проверяется это здесь тем, что за
    // короткий низ круг не уходит.
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.pump(bill.answerWindow!);

    expect(state().phase, RunPhase.revealing);
    expect(state().lastCorrect, isFalse);
    expect(speech.spoken, ['Die Rechnung, bitte']);
    // Просроченная фраза не пропала, а вернулась в конец очереди.
    expect(state().queue.map((q) => q.itemId).toList(),
        ['money_a0_bill', 'time_a0_have', 'money_a0_bill']);
    expect(find.text('Счёт, пожалуйста'), findsOneWidget,
        reason: 'просроченный круг уехал, не показав верный вариант');

    await afterPause(tester, correct: true);
    expect(find.text('Счёт, пожалуйста'), findsOneWidget,
        reason: 'просрочке дали короткую паузу верного ответа');

    await afterPause(tester, correct: false);
    expect(find.text('У меня есть время'), findsOneWidget);
    expect(state().phase, RunPhase.asking);

    // Забег дожимается до конца, иначе окно следующего круга осталось бы
    // висеть после теста.
    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await afterPause(tester);
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await afterPause(tester);

    expect(state().isFinished, isTrue);
  });

  testWidgets('на знакомстве экран не торопит', (tester) async {
    // Первый показ новой фразы: вокруг стоят пять уже известных, и к ответу
    // игрок приходит исключением — читает пять знакомых строчек и понимает,
    // какая шестая. Отсчёт в этот момент требует угадать, а не сообразить,
    // поэтому окна на знакомстве нет вовсе — ни в забеге, ни на экране.
    controller().start([
      question(
        id: 'money_a0_bill',
        prompt: 'Счёт, пожалуйста',
        answer: 'Die Rechnung, bitte',
        isNew: true,
      ),
    ]);
    await pumpRun(tester);

    await tester.pump(const Duration(minutes: 1));

    expect(state().phase, RunPhase.asking);
    expect(find.text('Счёт, пожалуйста'), findsOneWidget);
    expect(state().answered, 0);
    expect(speech.spoken, isEmpty);
    // И полосы окна тоже нет: она обещает отсчёт, а отсчёта здесь не завели.
    // Полоса, идущая там, где круг не закроется, — обещание наказания,
    // которого не будет, и учит она не смотреть на полосу вообще.
    expect(windowBar, findsNothing);

    // Ответ по-прежнему принимается: у знакомства отобрали таймер, а не игру.
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await afterPause(tester);

    expect(state().isFinished, isTrue);
    expect(state().correct, 1);
  });

  testWidgets('нажатие по арене в паузе открывает следующий круг',
      (tester) async {
    // Досрочное закрытие паузы: ждать не обязан тот, кто уже всё прочёл и
    // услышал. Палец после ответа и так на арене, так что движение бесплатно —
    // этим оно и отличается от кнопки, которая требовала его от каждого круга.
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.tap(find.text(wrongOption));
    await tester.pump();
    expect(state().phase, RunPhase.revealing);

    await tester.tapAt(emptySpot(tester));
    await tester.pump();

    expect(state().current?.itemId, 'time_a0_have');
    expect(find.text('У меня есть время'), findsOneWidget);

    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await afterPause(tester);
    // Промах вернулся в очередь третьим кругом — забег ещё идёт.
    expect(state().isFinished, isFalse);
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await afterPause(tester);
    expect(state().isFinished, isTrue);
  });

  testWidgets('нажатие по арене до ответа круг не закрывает', (tester) async {
    // Обратная сторона того же правила: пустое место круга не пропускает
    // вопрос. Иначе игрок, промахнувшийся мимо варианта, терял бы его вместе
    // с яркостью фразы.
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.tapAt(emptySpot(tester));
    await tester.pump();

    expect(state().phase, RunPhase.asking);
    expect(state().current?.itemId, 'money_a0_bill');
    expect(state().answered, 0);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await afterPause(tester);
    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await afterPause(tester);
    expect(state().isFinished, isTrue);
  });

  testWidgets('промах, вернувшийся последним кругом, снова принимает ответ',
      (tester) async {
    // Дефект, который уже был в продакшене. Забег возвращал промах в конец
    // очереди **тем же** объектом вопроса, а арена сбрасывает состояние по
    // смене объекта. Пока за промахом стояли другие круги, разницы не было —
    // а когда промах последний, следующим показывается он же: выбранный
    // вариант остаётся на месте, и арена больше не принимает ответов. Уровень
    // висел.
    controller().start([bill]);
    await pumpRun(tester);

    await tester.tap(find.text(wrongOption));
    await tester.pump();
    await afterPause(tester, correct: false);

    expect(state().phase, RunPhase.asking);
    expect(state().current?.itemId, 'money_a0_bill');

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();

    expect(state().correct, 1,
        reason: 'арена не сбросилась и ответа не приняла');

    await afterPause(tester);
    expect(state().isFinished, isTrue);
  });

  testWidgets('после забега на месте арены итог', (tester) async {
    controller().start([bill]);
    await pumpRun(tester);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await afterPause(tester);

    expect(find.byType(RunSummaryView), findsOneWidget);
    expect(find.byType(CircleArena), findsNothing,
        reason: 'арена осталась на экране поверх итога');
  });

  group('окно ответа', () {
    testWidgets('полоса кончается тем же мгновением, что и окно забега',
        (tester) async {
      // Полоса — картинка отсчёта, а закрывает круг таймер забега. Разойдись
      // они, и полоса стала бы врать в одну из двух сторон: либо краснеет, а
      // круг ещё открыт, либо круг закрылся при непустой полосе. Проверяется
      // это только здесь: арена своего таймера не имеет, забег своей полосы
      // не рисует, и разъехаться они могут лишь на этом шве.
      //
      // Длину обоим даёт одно число — то, которым заведён таймер забега
      // (`RunState.window`). Здесь оно спрашивается у вопроса ровно затем,
      // чтобы тест не повторял ни формулу, ни путь, которым она доходит до
      // полосы.
      controller().start([bill, time]);
      await pumpRun(tester);

      expect(windowBar, findsOneWidget, reason: 'отсчёт идёт, а полосы нет');

      const eyeblink = Duration(milliseconds: 100);
      await tester.pump(bill.answerWindow! - eyeblink);
      expect(state().phase, RunPhase.asking,
          reason: 'забег закрыл круг раньше, чем кончилась полоса');
      expect(windowLeft(tester), greaterThan(0),
          reason: 'полоса кончилась раньше, чем забег закрыл круг');

      await tester.pump(eyeblink);
      expect(state().phase, RunPhase.revealing);
      // Отсчёта больше нет — нет и полосы. Замершая полоса поверх отвеченного
      // круга сообщала бы об истечении времени на ответ, который уже дан.
      expect(windowBar, findsNothing);

      // Забег дожимается до конца, иначе окно следующего круга осталось бы
      // висеть после теста.
      await afterPause(tester, correct: false);
      await tester.tap(find.text('Ich habe Zeit'));
      await tester.pump();
      await afterPause(tester);
      await tester.tap(find.text('Die Rechnung, bitte'));
      await tester.pump();
      await afterPause(tester);
      expect(state().isFinished, isTrue);
    });

    testWidgets('на круге со слухом полоса ждёт, пока фраза дозвучит',
        (tester) async {
      // Жалоба владельца дословно: «я не замерял, но мне кажется для ответа
      // дается только 2 секунды а не 5». Окно открывалось в тот же миг, что
      // начиналась озвучка, а фраза на этом круге существует только как звук:
      // пока она произносится, отвечать не на что — и от окна оставалась
      // половина. Полоса при этом честно показывала, как утекает время, в
      // которое ответить было нельзя.
      const speaking = Duration(seconds: 2);
      speech.sounds = speaking;
      final heard = CircleQuestion(
        itemId: 'money_a0_bill',
        tier: Tier.a0,
        mode: GameMode.listenNative,
        // Центр звучит: текста в нём нет, и в объём круга он не попадает.
        prompt: '',
        options: const [
          'Счёт, пожалуйста',
          'Где вокзал',
          'Два кофе, пожалуйста',
          'Я не понимаю',
          'Сколько это стоит',
          'До завтра',
        ],
        answerIndex: 0,
        lumens: 60,
        promptSpeech: 'Die Rechnung, bitte',
        answerSpeech: 'Die Rechnung, bitte',
      );

      controller().start([heard]);
      await pumpRun(tester);

      expect(windowBar, findsNothing,
          reason: 'полоса пошла раньше, чем фраза дозвучала');
      await tester.pump(speaking);

      expect(windowBar, findsOneWidget, reason: 'полоса не пошла после фразы');
      expect(windowLeft(tester), closeTo(1, 0.02),
          reason: 'полоса начала не с полного окна: часы шли сквозь озвучку');

      await tester.pump(heard.answerWindow! - const Duration(milliseconds: 1));
      expect(state().phase, RunPhase.asking);
      await tester.pump(const Duration(milliseconds: 1));
      expect(state().phase, RunPhase.revealing);

      // По просрочке звучит верный вариант, и заглушка речи честно «звучит»
      // те же две секунды, что и центр: у неё одна цепочка с устройством, а
      // не мгновенный ответ на каждый вызов. Пауза кончается вместе с
      // произнесением — и открывает круг, которым просроченная фраза
      // вернулась в очередь.
      await tester.pump(speaking);
      expect(state().phase, RunPhase.asking);
      expect(state().current?.itemId, 'money_a0_bill');

      // Забег дожимается до конца: второй круг снова читает центр, ждёт
      // ответа и снова кончается паузой. Иначе тест ушёл бы и с открытым
      // окном, и с непогашенным произнесением.
      await tester.pump(speaking);
      await tester.tap(find.text('Счёт, пожалуйста'));
      await tester.pump();
      await tester.pump(speaking);
      expect(state().isFinished, isTrue);
    });

    test('самый тесный круг корпуса всё ещё оставляет медленный ответ', () {
      // Окно считается по объёму текста, а «медленный верный ответ» —
      // обещанный исход: ответ медленнее `speedMedium` приносит множитель 1.0,
      // но приносит. На самом коротком круге, какой корпус способен собрать
      // (шесть самых коротких переводов вокруг звучащего центра), окно обязано
      // этот порог перекрывать — иначе исход исчез бы молча на одном ярусе из
      // пяти.
      //
      // Проверяется по ассету, а не по вписанному числу: корпус уже менялся
      // дважды, и вписанная длина проверяла бы прошлый корпус.
      final tightest = CircleQuestion(
        itemId: 'corpus_tightest',
        tier: Tier.a0,
        mode: GameMode.listenNative,
        prompt: '',
        options: corpus.shortestNative(ScoreBalance.optionsPerCircle),
        answerIndex: 0,
        lumens: 60,
        promptSpeech: 'Danke',
        answerSpeech: 'Danke',
      );

      expect(tightest.answerWindow, greaterThan(ScoreBalance.speedMedium));
      expect(tightest.answerWindow, greaterThan(SrsBalance.gradeGoodBelow));
    });
  });

  group('арена влезает на любом экране', () {
    // ── Зачем это здесь, а не в тестах арены ─────────────────────────────
    //
    // Арену, поднятую в тесте одну, размер ей задаёт сам тест — и тест же
    // решает, какой он щедрости. Проверка, зеленеющая от удвоенной арены,
    // охраняет ровно ничего. Здесь арену выдаёт настоящий `RunScreen`: шапка,
    // отступы забега и рамка реакции забирают своё, и остаётся столько,
    // сколько останется у игрока.
    //
    // Дефект, из-за которого группа появилась: подбор кегля выходил по
    // достижении предела читаемости, ничего не проверив, и полосы уезжали за
    // низ арены. Уехавшая капсула не подрезается — она перестаёт нажиматься:
    // `Stack` клипует, hit-test за границы не идёт. Замер на прежнем корпусе
    // (максимум 90 знаков): арена 284×386 — три варианта из шести не
    // отвечали, лежащая 604×266 — один. С корпусом 1500 стало хуже: немецкая
    // фраза доросла до 118 знаков, украинский перевод до 97.

    /// Экран, на котором арена выйдет **вдвое шире** настоящей.
    ///
    /// В окружении flutter_test каждый знак шириной ровно с кегль, в жизни
    /// средний знак примерно вдвое уже: одна и та же фраза занимает вдвое
    /// больше ширины, а число строк и высота совпадают — высота строки задана
    /// кеглем и там, и здесь. Поэтому ширина модели удвоена, а высота взята
    /// настоящей.
    ///
    /// Удваивается **арена**, а не экран: шапка и отступы забега шириной не
    /// растягиваются, и удвоив экран, мы подарили бы кругу лишние точки — то
    /// есть проверяли бы телефон пошире того, который в руках. Ширину рамки
    /// тест **меряет**: она живёт в `RunScreen`, и вписанное сюда число
    /// устарело бы молча при первой же правке шапки.
    Future<Size> modelOf(WidgetTester tester, Size screen) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screen;
      controller().start([bill]);
      await pumpRun(tester);
      final arena = tester.getRect(find.byType(CircleArena));
      final chrome = screen.width - arena.width;
      return Size(arena.width * 2 + chrome, screen.height);
    }

    /// Лежит ли [inner] целиком внутри [outer]. Допуск — на округление
    /// замера: раскладка мерит текст сама и округляет размеры вверх.
    bool inside(Rect outer, Rect inner) =>
        inner.left >= outer.left - 0.5 &&
        inner.top >= outer.top - 0.5 &&
        inner.right <= outer.right + 0.5 &&
        inner.bottom <= outer.bottom + 0.5;

    /// Круг худшего случая: шесть самых длинных фраз корпуса вокруг самого
    /// длинного перевода, верный — [answerIndex].
    ///
    /// Верный вариант переставляется по всем шести местам нарочно: круг
    /// принимает один ответ, а проверить надо каждую капсулу — и проверка
    /// «нажатие дошло» возможна только через «ответ оказался верным».
    CircleQuestion worst(int answerIndex) {
      final options = corpus.longestTarget(ScoreBalance.optionsPerCircle);
      final prompt = corpus.longestNative(1).single;
      return CircleQuestion(
        itemId: 'corpus_worst',
        tier: Tier.b2,
        mode: GameMode.pickTarget,
        prompt: prompt,
        // Пометка добавляет под центром вторую строку — худший случай
        // становится ещё на строку выше.
        promptTag: 'formal',
        options: options,
        answerIndex: answerIndex,
        lumens: 60,
        answerSpeech: options[answerIndex],
        translation: prompt,
      );
    }

    // Экраны: телефон, на котором игра держалась, и те, на которых она
    // ломалась. Ландшафт здесь потому, что ориентация в приложении не
    // заблокирована: повернув телефон, игрок получал непроходимый круг.
    const screens = [
      (label: '360×640', size: Size(360, 640)),
      (label: '320×568', size: Size(320, 568)),
      (label: '320×480', size: Size(320, 480)),
      (label: '640×360 ландшафт', size: Size(640, 360)),
      (label: '412×915', size: Size(412, 915)),
    ];

    for (final screen in screens) {
      testWidgets('${screen.label}: нажимается каждый из шести',
          (tester) async {
        addTearDown(tester.view.reset);
        final model = await modelOf(tester, screen.size);
        tester.view.physicalSize = model;

        for (var i = 0; i < ScoreBalance.optionsPerCircle; i++) {
          controller().start([worst(i)]);
          await pumpRun(tester);

          final arena = tester.getRect(find.byType(CircleArena));
          final boxes = [
            for (var j = 0; j < ScoreBalance.optionsPerCircle; j++)
              tester.getRect(find.byKey(CircleArena.optionKey(j))),
          ];

          // 1. Главное — нажатие, и проверяется оно первым.
          //
          // Нажатие, а не потяг: потяг, начавшийся внутри арены, доставляет
          // свои точки той же арене и за её краем — жест уже захвачен, а
          // `hitTest` раскладки отвечает по своим прямоугольникам, где бы они
          // ни лежали. Поэтому дефект, из-за которого написана эта группа,
          // тест на потяге не видел, а критик нашёл его первым же нажатием.
          // Целимся в середину капсулы — туда, куда смотрит и жмёт игрок.
          //
          // «Дошло» означает «дошло **до своей** капсулы»: верный вариант
          // переставлен на место $i, и верным ответ окажется только если
          // нажатие попало именно туда, а не в соседа и не в пустоту.
          await tester.tapAt(boxes[i].center);
          await tester.pump();
          expect(state().lastCorrect, isTrue,
              reason: 'нажатие по центру капсулы $i не дошло до ответа '
                  'на ${screen.label}');

          // 2. Всё внутри арены. Прежняя раскладка ставила капсулы и за её
          //    низом — молча, потому что `Stack` не жалуется, а рамка вокруг
          //    арены рисуется всё равно.
          for (var j = 0; j < boxes.length; j++) {
            expect(inside(arena, boxes[j]), isTrue,
                reason: 'капсула $j вышла за арену на ${screen.label}');
          }
          expect(
            inside(arena, tester.getRect(find.byKey(CircleArena.promptKey))),
            isTrue,
            reason: 'центр вышел за арену на ${screen.label}',
          );

          // 3. Ничто ни на что не налезает: круг из шести наложенных капсул
          //    тоже «влезает», и это не то, что нужно.
          for (var a = 0; a < boxes.length; a++) {
            for (var b = a + 1; b < boxes.length; b++) {
              expect(boxes[a].overlaps(boxes[b]), isFalse,
                  reason: 'капсулы $a и $b налезли на ${screen.label}');
            }
          }

          // 4. Ни одна фраза не обрезана многоточием.
          for (final element in find
              .descendant(
                of: find.byType(CircleArena),
                matching: find.byType(Text),
              )
              .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse,
                reason: 'обрезано на ${screen.label}: '
                    '${paragraph.text.toPlainText()}');
          }
          // Догонять круг до итога не нужно: следующий `start` отменяет окно.
          // А вот последний круг дожимается — ниже.
        }

        // Последний круг доигрывается: ответ уже дан и окно снято, осталось
        // прождать паузу. Экран возвращается настоящий: итог забега не про
        // раскладку круга, и мерить его на модельном экране незачем.
        tester.view.reset();
        await afterPause(tester);
        expect(state().isFinished, isTrue);
      });
    }
  });
}
