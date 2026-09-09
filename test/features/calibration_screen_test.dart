import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/onboarding/application/calibration_controller.dart';
import 'package:lumen/features/onboarding/presentation/calibration_screen.dart';

/// Фраза в калибровке — тот самый стык, на котором проект уже пропустил
/// дефект в продакшен.
///
/// Экран строится **раньше** арены, потому что он её предок. Пока состояние
/// заменялось без вопроса, экран переставал попадать в свою ветку и уходил в
/// `CircularProgressIndicator`, а арену деактивировали в том же кадре, где
/// игрок поставил последнее слово: кадр с собранным предложением и
/// проявившимся переводом не рисовался ни разу. Одна арена, поднятая в тесте
/// без хозяина, этого не показывает — она остаётся на экране сама.
///
/// Здесь подменён контроллер, а не контент: проверяется договор экрана с
/// состоянием, а не алгоритм замера яруса.
class _FakeCalibration extends CalibrationController {
  /// Что ушло в ответ. Пустой список — ответа не было.
  final List<List<int>> submitted = [];

  static const _phrase = CircleQuestion(
    itemId: 'time_a0_have',
    tier: Tier.a0,
    mode: GameMode.fillGaps,
    prompt: '_____ habe _____.',
    options: ['Ich', 'Zeit'],
    answers: [0, 1],
    lumens: 0,
    translation: 'У меня есть время.',
    answerSpeech: 'Ich habe Zeit.',
  );

  @override
  CalibrationUiState build() => CalibrationUiState(
        calibration: CalibrationState.start(),
        question: _phrase,
      );

  /// Экран запускает калибровку в `initState`; настоящий запуск полез бы в
  /// контентную базу.
  @override
  Future<void> start() async {}

  /// Повторяет ровно то, что делает настоящий контроллер в начале паузы:
  /// круг остаётся в состоянии, экран гасит арену через `loading`.
  @override
  Future<void> answerSlots(List<int> bySlot, Duration latency) async {
    submitted.add(bySlot);
    state = CalibrationUiState(
      calibration: state.calibration,
      question: state.question,
      loading: true,
    );
  }
}

void main() {
  late ProviderContainer container;
  late _FakeCalibration fake;

  setUp(() {
    fake = _FakeCalibration();
    container = ProviderContainer(overrides: [
      calibrationControllerProvider.overrideWith(() => fake),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Украинский, а не язык по умолчанию: это язык основной аудитории,
          // и разбор раскладки имеет смысл делать на нём.
          locale: const Locale('uk'),
          home: CalibrationScreen(onDone: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final done = find.byKey(const ValueKey('phrase-done'));
  Finder poolWord(int index) => find.byKey(ValueKey('pool-word-$index'));

  Future<void> fill(WidgetTester tester) async {
    await tester.tap(poolWord(0));
    await tester.pump();
    await tester.tap(poolWord(1));
    await tester.pump();
  }

  testWidgets('заполнение не отвечает — отвечает «Готово»', (tester) async {
    // На двух пропусках вторая же плитка завершала расстановку, поэтому
    // промах пальцем был неисправим именно там, где он дороже всего: ошибка
    // в калибровке стоит яруса.
    await pumpScreen(tester);

    await fill(tester);
    expect(fake.submitted, isEmpty);

    await tester.tap(done);
    await tester.pump();

    expect(fake.submitted, [
      [0, 1]
    ]);
  });

  testWidgets('в паузе арена остаётся на экране с переводом', (tester) async {
    await pumpScreen(tester);

    await fill(tester);
    await tester.tap(done);
    await tester.pump();

    expect(find.text('У меня есть время.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'экран сменил арену на спиннер в кадре ответа');
  });

  testWidgets('в паузе повторное нажатие ничего не отправляет',
      (tester) async {
    await pumpScreen(tester);

    await fill(tester);
    await tester.tap(done);
    await tester.pump();
    await tester.tap(done, warnIfMissed: false);
    await tester.pump();

    expect(fake.submitted, hasLength(1));
  });

  testWidgets('«Готово» и «я с нуля» не читаются как пара', (tester) async {
    // Прямо под ареной стоит постоянная текстовая кнопка, одним нажатием
    // выбрасывающая измеренный ярус. Две текстовые кнопки рядом на первой
    // фразе, которую человек видит в игре, — приглашение нажать не ту.
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpScreen(tester);

    final scratch = find.text('Я з нуля');
    expect(scratch, findsOneWidget, reason: 'кнопка «я с нуля» переехала');

    // Главная кнопка выглядит главной, а не как соседка снизу.
    expect(tester.widget(done), isA<FilledButton>());
    expect(
      find.ancestor(of: scratch, matching: find.byType(TextButton)),
      findsOneWidget,
      reason: 'кнопка «я с нуля» перестала быть текстовой',
    );
    // И лежит выше неё, а не в одной строке.
    expect(tester.getCenter(done).dy, lessThan(tester.getCenter(scratch).dy));
  });
}
