import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/audio/speech_service.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/game/application/run_controller.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';
import 'package:lumen/features/ritual/application/ritual_controller.dart';
import 'package:lumen/features/ritual/presentation/ritual_screen.dart';

/// Выход из начатого забега: крестик, системная «назад» и вопрос между ними.
///
/// Что было до этого файла — решение владельца дословно: «также по крестику
/// всплывающее окно с вопросом, точно ли хотите прервать и возможностью
/// вернутся к игре, таймер при этом приостанавливается». Крестик рвал забег
/// сразу: `reset()` и пересборка неба, без единого вопроса. Одно касание
/// отменяло начатое молча — и, что хуже, отменяло его не до конца: ритуал
/// обнулялся, экран забега уходил из дерева, а сам забег продолжал идти.
///
/// Проверяются здесь три вещи, и вторая — про время, а не про факт вызова.
///
/// 1. Вопрос стоит между касанием и потерей, и у него два названных выхода.
/// 2. Пока вопрос открыт, окно ответа **не тратится**: держим его открытым
///    втрое дольше окна и смотрим, не истекло ли. Проверка «вызвали ли
///    `freeze`» была бы проверкой реализации: заморозка ценна не вызовом, а
///    тем, что за ней не идёт отсчёт.
/// 3. «Прервать» кончает забег, а не только экран. Иначе окно ответа
///    продолжало бы истекать за спиной домашней страницы, просрочки уходили
///    бы в память ответами «не вспомнил», а озвучка читала бы верные варианты
///    в пустоту.
///
/// Локаль русская намеренно: решение владельца сказано по-русски, и разбирать
/// текст вопроса имеет смысл на том языке, на котором он обсуждался. Сами
/// строки берутся у `lookupAppLocalizations`, а не вписаны сюда: перевод
/// правится в ARB, и вписанная строка устарела бы молча — тогда как
/// исчезнувший ключ обрушит компиляцию громко.
void main() {
  late ProviderContainer container;
  late SilentSpeechService speech;
  late AppDatabase db;

  final l10n = lookupAppLocalizations(const Locale('ru'));

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

  /// Пять фраз, которые игрок уже знает: вариантов в круге всегда шесть.
  const known = [
    'Wo ist der Bahnhof',
    'Zwei Kaffee bitte',
    'Ich verstehe nicht',
    'Wie viel kostet das',
    'Bis morgen',
  ];

  /// Круг разговорника: в центре перевод, вокруг шесть фраз на изучаемом.
  ///
  /// Механика с текстовым центром выбрана нарочно: у неё окно открывается с
  /// первого кадра, и «окно не потратилось» видно без озвучки, которая на
  /// круге со слухом сама отодвигает начало отсчёта.
  CircleQuestion question({
    required String id,
    required String prompt,
    required String answer,
  }) =>
      CircleQuestion(
        itemId: id,
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: prompt,
        options: [answer, ...known],
        answerIndex: 0,
        lumens: 50,
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

  RunState run() => container.read(runControllerProvider);
  RitualState ritual() => container.read(ritualControllerProvider);

  /// Экран ритуала с уже идущим уровнем.
  ///
  /// Уровень ставится руками, а не загрузчиком сессии: проверяется выход из
  /// забега, и настоящая сборка сессии притащила бы сюда контентную базу,
  /// планировщик и заход — три источника отказа, ни один из которых к выходу
  /// отношения не имеет.
  Future<void> pumpLevel(WidgetTester tester) async {
    container.read(ritualControllerProvider.notifier).state =
        const RitualState(phase: RitualPhase.level);
    container.read(runControllerProvider.notifier).start([bill, time]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: const RitualScreen(),
        ),
      ),
    );
    // Ровно один кадр, и это не экономия. `pumpAndSettle` здесь не
    // заканчивается никогда: пока круг открыт, полоса окна анимируется, а
    // «дождаться, пока всё успокоится» означает промолчать всё окно и
    // получить промах.
    await tester.pump();
  }

  /// Открывает вопрос о прерывании и ждёт, пока диалог доедет.
  ///
  /// Кадры считаются вручную по той же причине: за спиной диалога живёт
  /// арена со своей анимацией.
  Future<void> openQuestion(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Системная «назад» — платформенным сообщением, а не вызовом метода:
  /// именно так её присылает Android, и по этому пути её видит `PopScope`.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Доводит начатое до конца: прерывает забег.
  ///
  /// Нужен каждому тесту, который оставил круг открытым, и не для чистоты
  /// ради чистоты — живой таймер круга после теста сам уронил бы его
  /// («A Timer is still pending»). То есть хвост проверяет заодно и то, что
  /// прерывание таймеры действительно снимает.
  Future<void> confirmQuit(WidgetTester tester) async {
    await tester.tap(find.text(l10n.ritualQuitConfirm));
    await tester.pumpAndSettle();
  }

  testWidgets('крестик спрашивает, а не рвёт забег молча', (tester) async {
    await pumpLevel(tester);
    expect(find.byType(CircleArena), findsOneWidget);

    await openQuestion(tester);

    expect(find.text(l10n.ritualQuitTitle), findsOneWidget);
    // Оба выхода названы словами. «Вернуться к игре» — это не «закрыть
    // окно»: за диалогом стоит начатый забег, и кнопка обещает вернуть
    // именно его.
    expect(find.text(l10n.ritualQuitConfirm), findsOneWidget);
    expect(find.text(l10n.ritualQuitResume), findsOneWidget);

    // За спиной вопроса всё цело: ритуал не сброшен, круг тот же.
    expect(ritual().phase, RitualPhase.level);
    expect(run().phase, RunPhase.asking);
    expect(run().current?.itemId, bill.itemId);

    await confirmQuit(tester);
  });

  testWidgets('пока вопрос открыт, окно ответа не тратится', (tester) async {
    await pumpLevel(tester);
    final window = bill.answerWindow!;
    expect(run().window, window, reason: 'окно круга не открылось вовсе');

    await openQuestion(tester);

    // Втрое дольше окна — и ничего не произошло. Это и есть «таймер при этом
    // приостанавливается», сказанное про время: не «вызвали остановку», а
    // «за это время не истекло ни одно окно». Проверка стоит первой нарочно —
    // именно она обязана краснеть на коде без заморозки, и краснеть по
    // существу, а не по отсутствующей полосе.
    await tester.pump(window * 3);

    // Очередь той же длины: просроченная фраза возвращается в её конец, и
    // выросшая очередь — самая прямая запись о том, что забег шёл сам.
    expect(run().queue.length, 2,
        reason: 'фраза уехала в конец очереди — значит промах записан');
    // И круг стоит **тот же самый**, по объекту, а не по имени фразы: два
    // круга по одной фразе — два разных вопроса, и совпадение `itemId`
    // отыгранную просрочку не выдало бы.
    expect(identical(run().current, bill), isTrue,
        reason: 'круг сменился, пока игрок читал вопрос');
    expect(run().phase, RunPhase.asking);
    expect(run().answered, 0);
    expect(run().lastCorrect, isNull, reason: 'просрочка засчиталась');
    expect(speech.spoken, isEmpty,
        reason: 'верный вариант прозвучал поверх открытого вопроса');
    // Полосы окна при этом нет: отсчёта нет, и обещать его нечем.
    expect(run().window, isNull,
        reason: 'полоса окна обещает отсчёт, которого за диалогом нет');

    // Возвращение открывает круг заново и с полного времени: с остатка было
    // бы наказанием за чтение вопроса, который игра сама и задала.
    await tester.tap(find.text(l10n.ritualQuitResume));
    await tester.pump();

    expect(ritual().phase, RitualPhase.level);
    expect(run().current?.itemId, bill.itemId);
    expect(run().window, window, reason: 'окно вернулось не с полного времени');
    expect(find.text('Счёт, пожалуйста'), findsOneWidget);

    // И круг снова принимает ответ: вопрос забрал у забега время, а не игру.
    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    expect(run().correct, 1);

    await openQuestion(tester);
    await confirmQuit(tester);
  });

  testWidgets('«Прервать» кончает забег, а не только экран', (tester) async {
    // Что делал крестик до этого: `reset()` обнулял ритуал, экран забега
    // уходил из дерева — а забег оставался жив. Окно ответа истекало по
    // таймеру, просрочка уходила в память, звучал верный вариант, открывался
    // следующий круг. Игрок этого не видел: он уже смотрел на домашнюю
    // страницу ритуала.
    await pumpLevel(tester);
    await openQuestion(tester);
    await confirmQuit(tester);

    expect(ritual().phase, RitualPhase.idle);
    expect(run().isFinished, isTrue);
    expect(run().queue, isEmpty);
    expect(find.byType(CircleArena), findsNothing);

    // Минута после прерывания: ни звука, ни ответа, ни нового круга.
    await tester.pump(const Duration(minutes: 1));
    expect(speech.spoken, isEmpty, reason: 'прерванный забег говорил сам');
    expect(run().queue, isEmpty);

    // И следующий забег начинается живым: флаг заморозки прерывания не
    // пережил. Пережил бы — первый круг не открылся бы никогда, потому что
    // замороженный забег не заводит ни звука, ни отсчёта.
    container.read(runControllerProvider.notifier).start([time]);
    await tester.pump();

    expect(run().phase, RunPhase.asking);
    expect(run().window, time.answerWindow);

    container.read(runControllerProvider.notifier).start(const []);
    await tester.pump();
  });

  testWidgets('прерывание не отменяет уже записанного ответа',
      (tester) async {
    // Это первая половина текста вопроса: «Ответы уже записаны: яркость фраз
    // и очередь повторений сохранятся». Обещание на экране, за которым нет
    // проверки, — худший вид неправды: игрок соглашается, опираясь на него.
    // Поэтому проверяется не формулировка, а тот факт, на который она
    // опирается: ответ уходит в базу по ходу забега, а не в конце уровня, и
    // прерывание его не отзывает.
    await pumpLevel(tester);

    await tester.tap(find.text('Die Rechnung, bitte'));
    await tester.pump();
    expect(run().correct, 1);

    await openQuestion(tester);
    await confirmQuit(tester);

    // База живёт по настоящим часам: под поддельным временем виджет-теста
    // запись надо отпустить наружу, иначе она не дойдёт до диска никогда.
    WordStateRow? row;
    var logged = 0;
    var correct = false;
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      row = await db.loadWordState(bill.itemId);
      final log = await db.select(db.reviews).get();
      logged = log.length;
      correct = log.isNotEmpty && log.first.correct;
    });

    expect(row, isNotNull, reason: 'ответ пропал вместе с прерванным забегом');
    // Яркость и очередь повторений — это тройка FSRS и срок: обе половины
    // обещания лежат в этой строке.
    expect(row!.reps, 1);
    expect(row!.stability, greaterThan(0));
    expect(logged, 1, reason: 'журнал отзывов прерывание не пережил');
    expect(correct, isTrue);
  });

  testWidgets('кнопка «назад» — та же дверь, что крестик', (tester) async {
    // Защитить крестик и оставить системный жест значит не защитить ничего:
    // забег терялся бы тем же единственным действием.
    await pumpLevel(tester);

    await pressBack(tester);

    expect(find.text(l10n.ritualQuitTitle), findsOneWidget);
    expect(ritual().phase, RitualPhase.level);
    expect(run().phase, RunPhase.asking);
    expect(run().window, isNull, reason: '«назад» вопрос задала, а забег нет');

    // И тот же второй выход: возвращаемся к тому же кругу.
    await tester.tap(find.text(l10n.ritualQuitResume));
    await tester.pump();

    expect(find.byType(CircleArena), findsOneWidget);
    expect(run().current?.itemId, bill.itemId);

    await pressBack(tester);
    await confirmQuit(tester);
    expect(ritual().phase, RitualPhase.idle);
  });
}
