import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/game/presentation/circle_arena.dart';

/// Круг проверяется по поведению, а не по пикселям: главный жест игры должен
/// работать, промах по варианту не должен считаться ответом, а повторный
/// ответ на закрытый круг — проходить.
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

  const question = CircleQuestion(
    conceptId: 'doctor_person',
    tier: Tier.a0,
    mode: GameMode.circle,
    prompt: 'врач',
    options: ['Arzt', 'Art', 'Arm', 'Ast'],
    answerIndex: 0,
    lumens: 45,
  );

  Future<List<(int, Duration)>> pumpArena(
    WidgetTester tester, {
    bool enabled = true,
    CircleQuestion q = question,
  }) async {
    final answers = <(int, Duration)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: CircleArena(
                question: q,
                enabled: enabled,
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
      q: const CircleQuestion(
        conceptId: 'x',
        tier: Tier.a0,
        mode: GameMode.circle,
        prompt: 'счёт',
        promptHint: 'женский род',
        options: ['Rechnung', 'Richtung', 'Rechner'],
        answerIndex: 0,
        lumens: 30,
      ),
    );

    expect(find.text('женский род'), findsOneWidget);
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

    const next = CircleQuestion(
      conceptId: 'pain_noun',
      tier: Tier.a0,
      mode: GameMode.circle,
      prompt: 'боль',
      options: ['Schmerz', 'Scherz', 'Schmelz'],
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
}
