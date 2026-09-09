import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/features/game/presentation/slots_arena.dart';

/// Арена фразы проверяется по поведению пальца, а не по пикселям.
///
/// Способов поставить слово два, и они дают разное: нажатие кладёт слово в
/// первый пустой пропуск слева, перетаскивание — туда, куда его принесли.
/// Пока способ был один, «поставить это слово вот сюда» выражалось порядком
/// нажатий: во второй пропуск нельзя было попасть, не заполнив первый.
void main() {
  /// Два пропуска, два слова: «__ habe __.» с «Ich» и «Zeit».
  ///
  /// Пул здесь — ровно вынутые из предложения слова, ничего постороннего, и
  /// поэтому неверная расстановка возможна только как перестановка.
  CircleQuestion phrase() => const CircleQuestion(
        itemId: 'time_a0_have',
        tier: Tier.a0,
        mode: GameMode.fillGaps,
        prompt: '_____ habe _____.',
        options: ['Ich', 'Zeit'],
        answers: [0, 1],
        lumens: 40,
        translation: 'У меня есть время.',
        answerSpeech: 'Ich habe Zeit.',
      );

  /// Три пропуска: нужны там, где «последнее поставленное» обязано
  /// отличаться от «самого правого». На двух пропусках эти два правила дают
  /// один и тот же ответ, а расстановка из двух слов сразу полна — значит
  /// «отменить» уже скрыто.
  CircleQuestion longPhrase() => const CircleQuestion(
        itemId: 'time_a0_have_long',
        tier: Tier.a0,
        mode: GameMode.buildPhrase,
        prompt: '_____ _____ _____.',
        options: ['Ich', 'habe', 'Zeit'],
        answers: [0, 1, 2],
        lumens: 60,
        translation: 'У меня есть время.',
        answerSpeech: 'Ich habe Zeit.',
      );

  Future<List<(List<int>, Duration)>> pumpArena(
    WidgetTester tester, {
    bool enabled = true,
    CircleQuestion? question,
  }) async {
    final answers = <(List<int>, Duration)>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: SlotsArena(
              question: question ?? phrase(),
              enabled: enabled,
              onAnswer: (bySlot, latency) => answers.add((bySlot, latency)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return answers;
  }

  Finder poolWord(int index) => find.byKey(ValueKey('pool-word-$index'));
  Finder slot(int index) => find.byKey(ValueKey('phrase-slot-$index'));

  /// Что стоит в пропуске. Пустой пропуск несёт пустую строку.
  String slotText(WidgetTester tester, int index) =>
      tester.widget<Text>(find.descendant(
        of: slot(index),
        matching: find.byType(Text),
      )).data ??
      '';

  /// Тащит слово из [from] в [to] и отпускает.
  ///
  /// Через `startGesture`, а не `drag`: `drag` сдвигает палец на вектор, а
  /// здесь важно, **над чем** он окажется в конце — иначе проверка мерила бы
  /// не попадание в пропуск, а арифметику смещений.
  Future<void> dragTo(
    WidgetTester tester,
    Finder from,
    Finder to,
  ) async {
    final gesture = await tester.startGesture(tester.getCenter(from));
    // Первый сдвиг — чтобы `Draggable` признал жест перетаскиванием;
    // остальные ведут палец к цели.
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('нажатие', () {
    testWidgets('кладёт слово в первый пустой пропуск слева', (tester) async {
      await pumpArena(tester);

      await tester.tap(poolWord(1));
      await tester.pump();

      // Нажали «Zeit» — оно встало в первый пропуск, а не в свой.
      expect(slotText(tester, 0), 'Zeit');
      expect(slotText(tester, 1), '');
    });

    testWidgets('заполнение всех пропусков отвечает', (tester) async {
      final answers = await pumpArena(tester);

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      expect(answers, hasLength(1));
      expect(answers.single.$1, [0, 1]);
    });
  });

  group('перетаскивание', () {
    testWidgets('слово встаёт в тот пропуск, куда его принесли',
        (tester) async {
      final answers = await pumpArena(tester);

      // «Zeit» тащится во **второй** пропуск. Нажатием так нельзя: оно кладёт
      // в первый пустой, то есть ровно не туда.
      await dragTo(tester, poolWord(1), slot(1));

      expect(slotText(tester, 1), 'Zeit');
      expect(slotText(tester, 0), '');
      expect(answers, isEmpty, reason: 'ответа быть не может: пропуск пустой');
    });

    testWidgets('расстановка перетаскиванием отвечает своим порядком',
        (tester) async {
      final answers = await pumpArena(tester);

      await dragTo(tester, poolWord(1), slot(1));
      await dragTo(tester, poolWord(0), slot(0));

      expect(answers, hasLength(1));
      expect(answers.single.$1, [0, 1]);
    });

    testWidgets('слово из пропуска меняется местами с другим', (tester) async {
      final answers = await pumpArena(tester);

      // Сначала расставляем неверно: «Zeit» в первый, «Ich» во второй.
      await dragTo(tester, poolWord(1), slot(0));
      await dragTo(tester, poolWord(0), slot(1));

      expect(answers, hasLength(1), reason: 'заполнено — значит отвечено');
      expect(answers.single.$1, [1, 0]);
      expect(slotText(tester, 0), 'Zeit');
      expect(slotText(tester, 1), 'Ich');
    });

    testWidgets('перестановка между пропусками не теряет слово',
        (tester) async {
      await pumpArena(tester);

      await dragTo(tester, poolWord(0), slot(0));
      // «Ich» уносится из первого пропуска во второй: первый становится
      // пустым, а не «Ich» удваивается.
      await dragTo(tester, slot(0), slot(1));

      expect(slotText(tester, 1), 'Ich');
      expect(slotText(tester, 0), '');
    });

    testWidgets('слово, вытащенное в пул, снимается с пропуска',
        (tester) async {
      await pumpArena(tester);

      await dragTo(tester, poolWord(0), slot(0));
      expect(slotText(tester, 0), 'Ich');

      await dragTo(tester, slot(0), poolWord(1));

      expect(slotText(tester, 0), '',
          reason: 'слово вернули в пул, а пропуск остался занятым');
    });

    testWidgets('закрытая арена перетаскивание не принимает', (tester) async {
      final answers = await pumpArena(tester, enabled: false);

      await dragTo(tester, poolWord(0), slot(0));

      expect(slotText(tester, 0), '');
      expect(answers, isEmpty);
    });
  });

  group('после ответа', () {
    testWidgets('перевод проявляется, когда всё заполнено', (tester) async {
      await pumpArena(tester);

      expect(find.text('У меня есть время.'), findsNothing,
          reason: 'перевод до ответа — это отданный ответ');

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      expect(find.text('У меня есть время.'), findsOneWidget);
    });

    testWidgets('после ошибки показывается верный порядок', (tester) async {
      // Длинную паузу после ошибки проект оправдывает словами «игроку надо
      // успеть увидеть верный вариант» — а фразовая арена не показывала его
      // никогда. Круг это правило выполняет: там верный вариант
      // подсвечивается, даже если игрок выбрал другой.
      await pumpArena(tester);

      await dragTo(tester, poolWord(1), slot(0));
      await dragTo(tester, poolWord(0), slot(1));

      // Своя неверная сборка остаётся на месте: сравнить надо с ней.
      expect(slotText(tester, 0), 'Zeit');
      expect(find.text('Ich habe Zeit.'), findsOneWidget);
    });

    testWidgets('после верного ответа верный порядок не дублируется',
        (tester) async {
      await pumpArena(tester);

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      // Предложение и так собрано в шаблоне — второй раз под ним оно значило
      // бы «вот как надо было», сказанное тому, кто сделал как надо.
      expect(find.text('Ich habe Zeit.'), findsNothing);
    });
  });

  group('раскладка пула', () {
    testWidgets('две плитки лежат по одну сторону фразы', (tester) async {
      // Деление пула надвое придумано для восьми-девяти плиток. Калибровка
      // спрашивает фразу на минимальной глубине, то есть ровно с двумя, — и
      // они уезжали к самому верху и самому низу экрана, разделённые всей
      // фразой. Первая фраза, которую человек видит в игре, выглядела так.
      await pumpArena(tester);

      final phrase = tester.getCenter(slot(0)).dy;
      expect(tester.getCenter(poolWord(0)).dy, greaterThan(phrase));
      expect(tester.getCenter(poolWord(1)).dy, greaterThan(phrase));
    });

    testWidgets('длинный пул всё ещё делится надвое', (tester) async {
      // Шесть плиток над фразой не поместятся, не перекрыв её саму, — ради
      // этого деление и существует.
      await pumpArena(
        tester,
        question: const CircleQuestion(
          itemId: 'long',
          tier: Tier.a2,
          mode: GameMode.buildPhrase,
          prompt: '_____ _____ _____ _____ _____ _____',
          options: ['Ich', 'möchte', 'heute', 'noch', 'etwas', 'lernen'],
          answers: [0, 1, 2, 3, 4, 5],
          lumens: 70,
        ),
      );

      final phrase = tester.getCenter(slot(0)).dy;
      expect(tester.getCenter(poolWord(0)).dy, lessThan(phrase));
      expect(tester.getCenter(poolWord(5)).dy, greaterThan(phrase));
    });
  });

  group('отменить', () {
    testWidgets('снимает последнее поставленное, а не правое', (tester) async {
      await pumpArena(tester, question: longPhrase());

      // Третий пропуск заполняется раньше первого — так умеет только
      // перетаскивание. «Отменить» обязано снять «Ich», поставленное
      // последним, а не «Zeit», стоящее правее всех: порядок ключей карты о
      // порядке жестов не говорит ничего, и пока «отменить» читало их, оно
      // снимало не то слово.
      await dragTo(tester, poolWord(2), slot(2));
      await dragTo(tester, poolWord(0), slot(0));

      expect(find.byIcon(Icons.undo), findsOneWidget);
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();

      expect(slotText(tester, 0), '');
      expect(slotText(tester, 2), 'Zeit');
    });
  });
}
