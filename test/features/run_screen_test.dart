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
import 'package:lumen/features/game/application/run_controller.dart';
import 'package:lumen/features/game/presentation/run_screen.dart';

/// Забег вместе со своим экраном — тот самый стык, на котором проект уже
/// пропустил дефект в продакшен.
///
/// Арена, поднятая в тесте одна, после ответа остаётся на экране, и всё
/// выглядит правильно. Под настоящим хозяином она либо гаснет, либо
/// заменяется — и проверять надо именно это.
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

  CircleQuestion phrase() => const CircleQuestion(
        itemId: 'time_a0_have',
        tier: Tier.a0,
        mode: GameMode.fillGaps,
        prompt: '_____ habe _____.',
        options: ['Ich', 'Zeit'],
        answers: [0, 1],
        // Фразовый круг приходит с нулевой яркостью — так его собирают и
        // забег, и калибровка: фраза проверяет сборку предложения, а не
        // отдельное слово, поэтому скоростного множителя на ней нет.
        lumens: 0,
        translation: 'У меня есть время.',
        answerSpeech: 'Ich habe Zeit.',
      );

  CircleQuestion word(String id) => CircleQuestion.single(
        itemId: id,
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: id,
        options: const ['Zeit', 'Uhr'],
        answerIndex: 0,
        lumens: 50,
        answerSpeech: 'Zeit',
      );

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
    await tester.pumpAndSettle();
  }

  final done = find.byKey(const ValueKey('phrase-done'));
  Finder poolWord(int index) => find.byKey(ValueKey('pool-word-$index'));

  RunState state() => container.read(runControllerProvider);

  testWidgets('заполненная фраза не двигает забег вперёд', (tester) async {
    container
        .read(runControllerProvider.notifier)
        .start([phrase(), word('время')]);
    await pumpRun(tester);

    await tester.tap(poolWord(0));
    await tester.pump();
    await tester.tap(poolWord(1));
    await tester.pump();

    expect(state().phase, RunPhase.asking,
        reason: 'ответ ушёл с последней плиткой');
    expect(state().current?.itemId, 'time_a0_have');
    expect(find.text('У меня есть время.'), findsNothing);
  });

  testWidgets('«Готово» отвечает, и перевод виден в паузе', (tester) async {
    container
        .read(runControllerProvider.notifier)
        .start([phrase(), word('время')]);
    await pumpRun(tester);

    await tester.tap(poolWord(0));
    await tester.pump();
    await tester.tap(poolWord(1));
    await tester.pump();
    await tester.tap(done);
    await tester.pump();

    expect(state().phase, RunPhase.revealing);
    expect(state().correct, 1);
    // Пауза показа существует ровно затем, чтобы это было видно и слышно.
    expect(find.text('У меня есть время.'), findsOneWidget);
    expect(speech.spoken, ['Ich habe Zeit.']);

    // Фразовая пауза длиннее словесной: 600 мс её не закрывают.
    await tester.pump(const Duration(milliseconds: 600));
    expect(state().current?.itemId, 'time_a0_have');

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(state().current?.itemId, 'время');
    expect(state().phase, RunPhase.asking);
  });

  testWidgets('нажатие по арене в паузе открывает следующий круг',
      (tester) async {
    container
        .read(runControllerProvider.notifier)
        .start([phrase(), word('время')]);
    await pumpRun(tester);

    await tester.tap(poolWord(0));
    await tester.pump();
    await tester.tap(poolWord(1));
    await tester.pump();
    await tester.tap(done);
    await tester.pump();

    // Нажатие по проявившемуся переводу — то есть по арене, а не по кнопке.
    // Сам шаблон фразы нажать нельзя: он собран в `Text.rich`, и отдельного
    // виджета со словом «habe» в дереве нет.
    await tester.tap(find.text('У меня есть время.'));
    await tester.pumpAndSettle();

    expect(state().current?.itemId, 'время');
  });
}
