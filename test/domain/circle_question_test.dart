import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';

void main() {
  CircleQuestion question({
    GameMode mode = GameMode.circle,
    List<String> options = const ['Arzt', 'Art', 'Arm'],
    int answerIndex = 0,
    String? article,
  }) =>
      CircleQuestion(
        conceptId: 'doctor_person',
        tier: Tier.a0,
        mode: mode,
        prompt: 'врач',
        options: options,
        answerIndex: answerIndex,
        lumens: 50,
        answerArticle: article,
      );

  group('выбор варианта', () {
    test('верен только ответ', () {
      final q = question(answerIndex: 1);
      expect(q.isCorrectOption(1), isTrue);
      expect(q.isCorrectOption(0), isFalse);
      expect(q.answer, 'Art');
    });

    test('индекс вне списка не считается верным', () {
      final q = question();
      expect(q.isCorrectOption(-1), isFalse);
      expect(q.isCorrectOption(99), isFalse);
    });

    test('у «Набора» ответ есть, но выбирать нечего', () {
      final q = question(mode: GameMode.typing, options: ['Rechnung']);
      expect(q.isTyped, isTrue);
      expect(q.answer, 'Rechnung');
    });
  });

  group('ввод текста', () {
    final typed = CircleQuestion(
      conceptId: 'bill',
      tier: Tier.a1,
      mode: GameMode.typing,
      prompt: 'счёт',
      options: const ['Rechnung'],
      answerIndex: 0,
      lumens: 70,
      answerArticle: 'die',
    );

    test('точный ответ принимается', () {
      expect(typed.isCorrectInput('Rechnung'), isTrue);
    });

    test('регистр и пробелы не важны', () {
      expect(typed.isCorrectInput('  rechnung '), isTrue);
      expect(typed.isCorrectInput('RECHNUNG'), isTrue);
    });

    test('артикль принимается и с ним, и без него', () {
      expect(typed.isCorrectInput('die Rechnung'), isTrue);
      expect(typed.isCorrectInput('Rechnung'), isTrue);
    });

    test('опечатка в одну букву засчитывается', () {
      // Игра проверяет знание слова, а не меткость на телефонной клавиатуре.
      expect(typed.isCorrectInput('Rechnug'), isTrue);
      expect(typed.isCorrectInput('Rechnunk'), isTrue);
    });

    test('две опечатки уже не проходят', () {
      expect(typed.isCorrectInput('Rehnug'), isFalse);
    });

    test('другое слово не проходит', () {
      expect(typed.isCorrectInput('Richtung'), isFalse);
      expect(typed.isCorrectInput('Rechner'), isFalse);
    });

    test('пустой ввод не проходит', () {
      expect(typed.isCorrectInput(''), isFalse);
      expect(typed.isCorrectInput('   '), isFalse);
    });

    test('в коротком слове опечатки не прощаются', () {
      // «Bad» и «Bar» — разные слова, а не опечатка.
      const short = CircleQuestion(
        conceptId: 'bath',
        tier: Tier.a0,
        mode: GameMode.typing,
        prompt: 'ванна',
        options: ['Bad'],
        answerIndex: 0,
        lumens: 70,
      );
      expect(short.isCorrectInput('Bad'), isTrue);
      expect(short.isCorrectInput('Bar'), isFalse);
    });

    test('лишние слова не проходят', () {
      expect(typed.isCorrectInput('die Rechnung bitte'), isFalse);
    });
  });
}
