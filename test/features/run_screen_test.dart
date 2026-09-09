import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

/// Забег вместе со своим экраном — тот самый стык, на котором проект уже
/// пропустил дефект в продакшен.
///
/// Арена, поднятая в тесте одна (`circle_arena_test.dart`), после ответа
/// остаётся на экране, и всё выглядит правильно. Под настоящим хозяином она
/// либо гаснет, либо заменяется — и проверять надо именно это. Экран теперь
/// умеет уходить вперёд и **без** ответа: круг живёт пять секунд, и молчание
/// закрывает его так же, как промах. Одна арена на все три механики: второй,
/// заполнявшей пропуски фразы, больше нет.
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
void main() {
  late ProviderContainer container;
  late SilentSpeechService speech;
  late AppDatabase db;

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
    // «дождаться, пока всё успокоится» означает промолчать пять секунд,
    // получить промах, получить с ним ещё один круг в очередь — и так до
    // таймаута.
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

  testWidgets('вариант отвечает, и следующий круг встаёт на место арены',
      (tester) async {
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();

    expect(state().phase, RunPhase.revealing);
    expect(state().correct, 1);
    expect(speech.spoken, ['Die Rechnung, bitte']);

    await tester.pump(RevealBalance.correct);

    // Арена не осталась прежней: в центре другой вопрос, а прежние варианты
    // из дерева ушли. Тот самый дефект, который проект уже пропускал: арена,
    // не заметившая смены вопроса, показывает старое и не принимает ответов.
    expect(find.text('У меня есть время'), findsOneWidget);
    expect(find.text('Счёт, пожалуйста'), findsNothing);
    expect(find.text('Die Rechnung, bitte'), findsNothing);

    // И второй круг тоже отвечает — забег доходит до итога.
    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);

    expect(state().isFinished, isTrue);
  });

  testWidgets('молчание закрывает круг, и экран уходит вперёд сам',
      (tester) async {
    // Окно на ответ живёт в забеге, полоса окна — в арене, и здесь
    // проверяется, что экран переживает закрытие круга, к которому игрок не
    // прикоснулся: следующий вопрос встаёт на место сам, а верный вариант
    // прозвучал, потому что промолчавшему его никто не назвал.
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.pump(ScoreBalance.answerWindow);

    expect(state().phase, RunPhase.revealing);
    expect(state().lastCorrect, isFalse);
    expect(speech.spoken, ['Die Rechnung, bitte']);

    await tester.pump(RevealBalance.wrong);

    expect(find.text('У меня есть время'), findsOneWidget);
    expect(state().phase, RunPhase.asking);
    // Просроченная фраза не пропала, а вернулась в конец очереди.
    expect(state().queue.map((q) => q.itemId).toList(),
        ['money_a0_bill', 'time_a0_have', 'money_a0_bill']);

    // Забег дожимается до конца, иначе окно следующего круга осталось бы
    // висеть после теста.
    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);

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

    // Ответ по-прежнему принимается: у знакомства отобрали таймер, а не игру.
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);

    expect(state().isFinished, isTrue);
    expect(state().correct, 1);
  });

  testWidgets('нажатие по арене в паузе открывает следующий круг',
      (tester) async {
    // Пауза после промаха длинная нарочно: верный вариант надо успеть
    // увидеть и услышать. Но заставлять ждать того, кто уже всё прочёл, —
    // значит платить его временем за чужую медлительность.
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
    await tester.pump(RevealBalance.correct);
    // Промах вернулся в очередь третьим кругом — забег ещё идёт.
    expect(state().isFinished, isFalse);
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);
    expect(state().isFinished, isTrue);
  });

  testWidgets('нажатие по арене до ответа круг не закрывает', (tester) async {
    // Обратная сторона того же правила: пустое место круга — не «дальше».
    // Иначе игрок, промахнувшийся мимо варианта, терял бы вопрос вместе с
    // яркостью фразы.
    controller().start([bill, time]);
    await pumpRun(tester);

    await tester.tapAt(emptySpot(tester));
    await tester.pump();

    expect(state().phase, RunPhase.asking);
    expect(state().current?.itemId, 'money_a0_bill');
    expect(state().answered, 0);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);
    await tester.tap(find.text('Ich habe Zeit'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);
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
    await tester.pump(RevealBalance.wrong);

    expect(state().phase, RunPhase.asking);
    expect(state().current?.itemId, 'money_a0_bill');

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();

    expect(state().correct, 1,
        reason: 'арена не сбросилась и ответа не приняла');

    await tester.pump(RevealBalance.correct);
    expect(state().isFinished, isTrue);
  });

  testWidgets('после забега на месте арены итог', (tester) async {
    controller().start([bill]);
    await pumpRun(tester);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    await tester.pump(RevealBalance.correct);

    expect(find.byType(RunSummaryView), findsOneWidget);
    expect(find.byType(CircleArena), findsNothing,
        reason: 'арена осталась на экране поверх итога');
  });
}
