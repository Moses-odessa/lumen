import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';
import 'package:lumen/features/onboarding/application/calibration_controller.dart';
import 'package:lumen/features/onboarding/presentation/calibration_screen.dart';

/// Круг в калибровке — тот самый стык, на котором проект уже пропустил дефект
/// в продакшен.
///
/// Экран строится **раньше** арены, потому что он её предок. Пока состояние
/// заменялось без вопроса, экран переставал попадать в свою ветку и уходил в
/// `CircularProgressIndicator`, а арену деактивировали в том же кадре, где
/// игрок ответил: кадр с подсвеченным верным вариантом не рисовался ни разу.
/// Одна арена, поднятая в тесте без хозяина, этого не показывает — она
/// остаётся на экране сама.
///
/// Здесь подменён контроллер, а не контент: проверяется договор экрана с
/// состоянием, а не алгоритм замера яруса.
class _FakeCalibration extends CalibrationController {
  _FakeCalibration({this.initial});

  /// Состояние, с которого экран начинает. `null` — обычный круг.
  final CalibrationUiState? initial;

  /// Индексы, ушедшие в ответ. Пустой список — ответа не было.
  final List<int> submitted = [];

  /// Сколько раз экран запускал тест и сколько — сбрасывал его в A0.
  int started = 0;
  int skipped = 0;

  /// Круг ровно такой, какой собирает `QuestionBuilder` для `pickTarget`: в
  /// центре фраза на родном, вокруг шесть на изучаемом — столько, сколько
  /// требует `ScoreBalance.optionsPerCircle`. Экрану их число безразлично,
  /// поэтому оно здесь не проверяется, а воспроизводится.
  static const question = CircleQuestion(
    itemId: 'time_a0_have',
    tier: Tier.a0,
    mode: GameMode.pickTarget,
    prompt: 'У меня есть время.',
    options: [
      'Ich habe Zeit.',
      'Ich habe Hunger.',
      'Wie geht es dir?',
      'Das ist zu teuer.',
      'Ich komme aus Kyjiw.',
      'Bis morgen!',
    ],
    answerIndex: 0,
    lumens: 0,
    translation: 'У меня есть время.',
    answerSpeech: 'Ich habe Zeit.',
  );

  @override
  CalibrationUiState build() =>
      initial ??
      CalibrationUiState(
        // Потолок A0 — тот же, с которым начинает настоящий контроллер до
        // чтения метаданных. Экрану он безразличен, а вот подставлять здесь
        // разрешающий B2 значило бы держать в тесте состояние, которого в
        // приложении не бывает.
        calibration: CalibrationState.start(ceiling: Tier.a0),
        question: question,
      );

  /// Экран запускает калибровку в `initState`; настоящий запуск полез бы в
  /// контентную базу.
  @override
  Future<void> start() async => started++;

  /// Повторяет ровно то, что делает настоящий контроллер в начале паузы:
  /// круг остаётся в состоянии, экран гасит арену через `loading`.
  @override
  Future<void> answer(int index, Duration latency) async {
    submitted.add(index);
    state = CalibrationUiState(
      calibration: state.calibration,
      question: state.question,
      loading: true,
    );
  }

  /// Настоящая `skip()` записывает игроку A0 и **не** выставляет `granted`.
  @override
  Future<void> skip() async {
    skipped++;
    state = CalibrationUiState(calibration: Calibration.fromScratch());
  }
}

/// Что отсюда удалено вместе с правилами, которых больше нет.
///
/// * «Заполнение не отвечает — отвечает „Готово“» и «в паузе повторное
///   нажатие ничего не отправляет» в их прежнем виде. Они охраняли фразовую
///   арену: игрок расставлял плитки по пропускам, а ответ отправляла кнопка
///   «Готово», потому что на двух пропусках вторая же плитка завершала
///   расстановку — и промах пальцем был неисправим именно там, где он дороже
///   всего. Вставки слов в предложение нет, плиток нет, кнопки нет: круг
///   отвечается одним соединением, и подтверждать нечего. Правило «ответ
///   отправляет игрок, а не последняя плитка» пережило свою механику ровно в
///   той части, которая ещё выразима, — второй ответ по одному кругу не
///   уходит, и она ниже.
/// * «„Готово“ и „я с нуля“ не читаются как пара». Кнопка ответа стояла прямо
///   над постоянной текстовой кнопкой, одним нажатием выбрасывающей
///   измеренный ярус, и тест держал их непохожими: главная — заливкой,
///   соседняя — текстом, и не в одну строку. Кнопки ответа больше нет, на
///   экране одна текстовая кнопка, и пары, в которой можно нажать не ту, тоже
///   нет. Она не может и перекрыть круг: арена лежит в `Expanded`, кнопка
///   под ним в том же `Column`.
/// * Проверка перевода в кадре паузы («в паузе арена остаётся на экране с
///   переводом»). Перевод фразы приходит в `CircleQuestion.translation`, но
///   рисовала его фразовая арена — а `CircleArena` строит подпись под центром
///   из `[null, tag]`, то есть на месте перевода у неё пусто. Тест на текст,
///   которого не рисует никто, был бы тестом на собственную заглушку;
///   осталась половина про то, что круг в паузе вообще на экране.
void main() {
  late _FakeCalibration fake;
  ProviderContainer? container;
  var done = 0;

  setUp(() => done = 0);

  tearDown(() {
    container?.dispose();
    container = null;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    CalibrationUiState? initial,
  }) async {
    fake = _FakeCalibration(initial: initial);
    container = ProviderContainer(overrides: [
      calibrationControllerProvider.overrideWith(() => fake),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Украинский, а не язык по умолчанию: это язык основной аудитории,
          // и разбор экрана имеет смысл делать на нём.
          locale: const Locale('uk'),
          home: CalibrationScreen(onDone: () => done++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final options = _FakeCalibration.question.options;
  final scratch = find.text('Я з нуля');

  testWidgets('экран сам запускает тест и показывает круг', (tester) async {
    // Запуск живёт в `initState` экрана, и без него игрок смотрел бы на
    // спиннер: контроллер сам себя не заводит, а `build()` отдаёт состояние
    // без вопроса.
    await pumpScreen(tester);

    expect(fake.started, 1);
    expect(find.byType(CircleArena), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(_FakeCalibration.question.prompt), findsOneWidget);
    for (final option in options) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('ответ уходит тем вариантом, по которому нажали', (tester) async {
    // Экран обязан передать номер варианта как есть. Свести его к «верно или
    // нет» здесь нельзя: калибровка сама сверяет ответ с кругом, и она же
    // единственная, кто знает, чем считать промах.
    await pumpScreen(tester);

    await tester.tap(find.text(options[2]));
    await tester.pump();

    expect(fake.submitted, [2]);
  });

  testWidgets('в паузе круг остаётся на экране, а не сменяется спиннером',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text(options[0]));
    await tester.pump();

    expect(find.byType(CircleArena), findsOneWidget);
    expect(find.text(_FakeCalibration.question.prompt), findsOneWidget);
    expect(find.text(options[0]), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'экран сменил круг на спиннер в кадре ответа');
  });

  testWidgets('полосы окна ответа в онбординге нет: истечь ей нечем',
      (tester) async {
    // Круги калибровки идут с `isNew: false` — онбординг не знакомит, а мерит,
    // — и ровно по этому признаку арена рисовала полосу окна. Таймера же в
    // онбординге нет ни одного: и отсчёт, и закрытие просроченного круга
    // живут в `RunController`. Игрок на первом экране приложения двадцать раз
    // видел, как полоса добегает до конца и краснеет, а круг оставался
    // открытым — то есть приложение первым делом учило его **не смотреть на
    // полосу**, ровно перед тем забегом, где просрочка наказывает.
    //
    // Теперь окно заводит хозяин круга, а не арена: `CircleArena.answerWindow`
    // задаёт и то, идёт ли полоса, и сколько. Калибровка его не заводит,
    // потому что закрывать круг ей нечем.
    await pumpScreen(tester);
    expect(_FakeCalibration.question.isNew, isFalse,
        reason: 'круг калибровки перестал быть обычным — тест ослаб');

    final windowBar = find.descendant(
      of: find.byType(CircleArena),
      matching: find.byType(LinearProgressIndicator),
    );
    expect(windowBar, findsNothing);
    // И не появляется со временем: окна нет не «пока», а вовсе.
    await tester.pump(ScoreBalance.answerWindow * 2);
    expect(windowBar, findsNothing);

    // Круг при этом живой: у онбординга отобрали полосу, а не игру.
    await tester.tap(find.text(options[0]));
    await tester.pump();
    expect(fake.submitted, [0]);
  });

  testWidgets('в паузе второй ответ по тому же кругу не уходит',
      (tester) async {
    // Пауза — это ещё тот же круг, и второй ответ по нему был бы ответом за
    // игрока: первый уже засчитан, ярус уже сдвинут. Ломается это не только
    // потерей `enabled` — достаточно пересобрать арену новым `CircleQuestion`
    // в кадре паузы, и она сбросит выбор и примет ещё один ответ.
    await pumpScreen(tester);

    await tester.tap(find.text(options[0]));
    await tester.pump();
    await tester.tap(find.text(options[3]));
    await tester.pump();

    expect(fake.submitted, [0]);
  });

  testWidgets('«я с нуля» уводит с экрана сама', (tester) async {
    // `skip()` не выставляет `granted`, а слушатель экрана ждёт именно его —
    // значит уйти с экрана обязана сама кнопка. Без этого игрок, нажавший «я
    // с нуля», остаётся на калибровке навсегда: A0 ему уже записан, и тест
    // больше не сдвинется ни на круг.
    await pumpScreen(tester);
    expect(scratch, findsOneWidget, reason: 'кнопка «я с нуля» переехала');

    await tester.tap(scratch);
    await tester.pump();

    expect(fake.skipped, 1);
    expect(done, 1);
  });

  testWidgets('поломка контента показывается текстом, а не вечным спиннером',
      (tester) async {
    // Онбординг — первый экран приложения, и застрять на нём значит не
    // запустить игру вовсе. Ветка ошибки стоит в `switch` первой, поэтому
    // сообщение видно даже тогда, когда круг в состоянии остался.
    await pumpScreen(
      tester,
      initial: CalibrationUiState(
        calibration: CalibrationState.start(ceiling: Tier.a0),
        question: _FakeCalibration.question,
        error: 'нет фраз на A0',
      ),
    );

    expect(find.text('нет фраз на A0'), findsOneWidget);
    expect(find.byType(CircleArena), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('подпись висит над кругом весь тест, до последней пробы',
      (tester) async {
    // Здесь стояла проверка «хвост засева экран показывает как остальной
    // тест»: подпись выбиралась `switch` по фазе калибровки, и это было
    // единственное место, где фазы перечислены руками. Пропущенная ветвь там
    // не компилировалась, а вот ветвь с пустой строкой компилировалась
    // отлично — игрок последние двадцать кругов смотрел бы на круг без
    // единого слова о том, что происходит.
    //
    // Фаз больше нет, и подпись одна на все двадцать кругов. Охранять
    // осталось то же самое: слова над кругом обязаны быть, в том числе на
    // последней пробе, где прежняя схема уже отдала бы «Готово».
    await pumpScreen(
      tester,
      initial: CalibrationUiState(
        calibration: CalibrationState(
          ceiling: Tier.a0,
          asked: CalibrationBalance.testCircles - 1,
          correct: const {Tier.a0: 6, Tier.a1: 5},
        ),
        question: _FakeCalibration.question,
      ),
    );

    expect(find.byType(CircleArena), findsOneWidget);
    expect(find.text('Просто з’єднуйте те, що знаєте'), findsOneWidget,
        reason: 'над кругом нет ни слова о том, что происходит');
  });

  testWidgets('полоса прогресса считает пробы из двадцати', (tester) async {
    // Полоса уже дважды мерила чужую длину: сперва складывалась из долей фаз
    // и добиралась до конца к двадцатому кругу из тридцати, потом считала
    // показанные круги из тридцати — при том, что тест стал двадцатью
    // пробами. Проверка стоит на экране, потому что врала игроку именно она.
    //
    // Три переспроса при двенадцати пробах — не выдуманный случай: они идут
    // сверх квоты, игрок увидел пятнадцать кругов, а тест продвинулся на
    // двенадцать. Полоса обязана показывать двенадцать из двадцати, иначе
    // самый быстрый игрок увидел бы полосу за единицей.
    await pumpScreen(
      tester,
      initial: CalibrationUiState(
        calibration: CalibrationState(
          ceiling: Tier.a0,
          asked: 12,
          repeats: 3,
          correct: const {Tier.a0: 6, Tier.a1: 5},
        ),
        question: _FakeCalibration.question,
      ),
    );

    // Полоса на экране одна: своя, над кругом, в том же `Column`. Здесь
    // стояло «полос две, и вторая — окно ответа внутри арены» — вторая была
    // как раз той, которая шла в онбординге впустую, и её больше нет (тест
    // «полосы окна ответа в онбординге нет» выше). `.first` оставлен нарочно:
    // появись внутри круга ещё одна, брать надо всё равно свою.
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator).first,
    );
    expect(bar.value, closeTo(12 / CalibrationBalance.testCircles, 1e-9),
        reason: 'полоса мерит не пробы из двадцати');
  });
}
