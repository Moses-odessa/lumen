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
///
/// **Ответ отправляет кнопка, а не последняя плитка**, и это правило почти
/// каждый тест здесь так или иначе проверяет. Пока отправка уходила из того
/// же жеста, которым игрок ставил последнее слово, заметить ошибку было уже
/// поздно: «отменить» возвращалась раньше времени, а её кнопка была скрыта
/// тем же условием.
///
/// Осторожно с проверками вида «ответа нет»: после этой правки они истинны
/// по построению почти везде. Поэтому рядом с каждой стоит утверждение о
/// состоянии кнопки — иначе тест остаётся зелёным, ничего не проверяя.
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
  final done = find.byKey(const ValueKey('phrase-done'));
  final undo = find.byKey(const ValueKey('phrase-undo'));

  /// Включена ли кнопка. Она стоит на месте всегда, и это часть договора:
  /// игрок должен видеть шаг «отправить» с первого кадра, а не узнавать о
  /// нём, заполнив всё.
  bool isEnabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  Future<void> tapDone(WidgetTester tester) async {
    await tester.tap(done);
    await tester.pump();
  }

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

    testWidgets('заполнение не отвечает — отвечает «Готово»', (tester) async {
      final answers = await pumpArena(tester);

      // Кнопка стоит на месте с первого кадра, но выключена: игрок должен
      // видеть, что ответ надо будет отправить, а не узнавать об этом в тот
      // момент, когда шаг уже нужен. Незамеченная кнопка — это молча
      // зависший забег.
      expect(done, findsOneWidget);
      expect(isEnabled(tester, done), isFalse);

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      expect(answers, isEmpty, reason: 'последняя плитка отправила ответ');
      expect(isEnabled(tester, done), isTrue);

      await tapDone(tester);

      expect(answers, hasLength(1));
      expect(answers.single.$1, [0, 1]);
    });

    testWidgets('дважды по «Готово» — один ответ', (tester) async {
      // Хозяин гасит арену своим `enabled` только после колбэка, то есть
      // кадром позже: защита от второго нажатия обязана принадлежать арене.
      final answers = await pumpArena(tester);

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      await tapDone(tester);
      await tapDone(tester);

      expect(answers, hasLength(1));
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
      expect(isEnabled(tester, done), isFalse,
          reason: 'отправлять нечего: расстановка неполная');
    });

    testWidgets('расстановка перетаскиванием отвечает своим порядком',
        (tester) async {
      final answers = await pumpArena(tester);

      await dragTo(tester, poolWord(1), slot(1));
      await dragTo(tester, poolWord(0), slot(0));
      await tapDone(tester);

      expect(answers, hasLength(1));
      expect(answers.single.$1, [0, 1]);
    });

    testWidgets('неверный порядок правится до отправки', (tester) async {
      // Это и есть смысл кнопки. Раньше расстановка уходила ответом в тот же
      // миг, когда встала последняя плитка, и заметивший ошибку игрок не мог
      // сделать ничего: «отменить» возвращалась раньше времени, а её кнопка
      // была скрыта тем же условием.
      final answers = await pumpArena(tester);

      // Сначала неверно: «Zeit» в первый, «Ich» во второй.
      await dragTo(tester, poolWord(1), slot(0));
      await dragTo(tester, poolWord(0), slot(1));

      expect(answers, isEmpty);
      expect(slotText(tester, 0), 'Zeit');

      // Полная расстановка живая: слова меняются местами.
      await dragTo(tester, slot(0), slot(1));

      expect(slotText(tester, 0), 'Ich');
      expect(slotText(tester, 1), 'Zeit');

      await tapDone(tester);

      expect(answers, hasLength(1));
      expect(answers.single.$1, [0, 1], reason: 'уехал неисправленный порядок');
      // Верный ответ подсказки не получает: предложение и так собрано в
      // шаблоне.
      expect(find.text('Ich habe Zeit.'), findsNothing);
    });

    testWidgets('неисправленный порядок уходит неверным', (tester) async {
      final answers = await pumpArena(tester);

      await dragTo(tester, poolWord(1), slot(0));
      await dragTo(tester, poolWord(0), slot(1));
      await tapDone(tester);

      expect(answers.single.$1, [1, 0]);
      expect(find.text('Ich habe Zeit.'), findsOneWidget);
    });

    testWidgets('после «Готово» расстановка застывает', (tester) async {
      final answers = await pumpArena(tester);

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();
      await tapDone(tester);

      // Арена не надеется на `enabled: false` от хозяина: в этом тесте его
      // нет вовсе, а трогать расстановку всё равно нельзя.
      await dragTo(tester, slot(0), slot(1));

      expect(slotText(tester, 0), 'Ich');
      expect(slotText(tester, 1), 'Zeit');
      expect(answers, hasLength(1));
      expect(isEnabled(tester, done), isFalse);
      expect(isEnabled(tester, undo), isFalse);
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
    testWidgets('перевод проявляется по «Готово», а не по заполнению',
        (tester) async {
      await pumpArena(tester);

      expect(find.text('У меня есть время.'), findsNothing,
          reason: 'перевод до ответа — это отданный ответ');

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      // Условие было «все пропуски заполнены», и это перестало значить
      // «отвечено». Задание фразы — порядок, а перевод сообщает смысл
      // целиком: он подтверждал бы или опровергал выбранную расстановку до
      // того, как её оценили, — и больнее всего там, где порядок меняет
      // смысл.
      expect(find.text('У меня есть время.'), findsNothing,
          reason: 'перевод показан тому, кто ещё может переставить плитки');

      await tapDone(tester);

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

      expect(find.text('Ich habe Zeit.'), findsNothing,
          reason: 'верный порядок показан до отправки — фраза бесплатна');

      await tapDone(tester);

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
      await tapDone(tester);

      // Предложение и так собрано в шаблоне — второй раз под ним оно значило
      // бы «вот как надо было», сказанное тому, кто сделал как надо.
      expect(find.text('Ich habe Zeit.'), findsNothing);
      expect(find.text('У меня есть время.'), findsOneWidget,
          reason: 'проверка обессмыслится, если перевода тоже нет');
    });

    testWidgets('вернувшийся промах снова принимает ответ', (tester) async {
      // Промах возвращается в очередь **другим объектом** того же вопроса, и
      // на этом держится сброс состояния арены. Признак «отвечено» здесь
      // производный от вердикта именно поэтому: отдельный флаг пришлось бы
      // сбрасывать вручную, а несброшенный означал бы арену без живой
      // кнопки — то есть уровень, зависший насмерть.
      final answers = <(List<int>, Duration)>[];
      Widget host(CircleQuestion question) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: SlotsArena(
                  question: question,
                  onAnswer: (bySlot, latency) =>
                      answers.add((bySlot, latency)),
                ),
              ),
            ),
          );

      final first = phrase();
      await tester.pumpWidget(host(first));
      await tester.pumpAndSettle();

      await dragTo(tester, poolWord(1), slot(0));
      await dragTo(tester, poolWord(0), slot(1));
      await tapDone(tester);
      expect(answers, hasLength(1));

      // Тот же вопрос, другой объект — как его возвращает забег.
      await tester.pumpWidget(host(first.again()));
      await tester.pumpAndSettle();

      expect(slotText(tester, 0), '', reason: 'расстановка не сброшена');
      expect(find.text('Ich habe Zeit.'), findsNothing,
          reason: 'вердикт прошлого ответа переехал на новый вопрос');

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();
      await tapDone(tester);

      expect(answers, hasLength(2));
      expect(answers.last.$1, [0, 1]);
    });

    testWidgets('время ответа не растёт от проверки перед «Готово»',
        (tester) async {
      // Между последней плиткой и кнопкой игрок проверяет себя, и это время
      // не про скорость ответа. Домен приводит время к одному размещению и по
      // нему ставит оценку памяти и серию «горящего слова»: раздумья перед
      // отправкой вернули бы дефект «всякая верно собранная фраза — hard».
      //
      // Часы здесь настоящие (`DateTime.now()` в арене фейковым временем
      // теста не сдвинуть), поэтому граница взята с запасом.
      final answers = await pumpArena(tester);

      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 700)),
      );
      await tapDone(tester);

      expect(answers, hasLength(1));
      expect(answers.single.$2, lessThan(const Duration(milliseconds: 350)),
          reason: 'в ответ попало время проверки перед отправкой');
    });
  });

  group('правка полной расстановки', () {
    testWidgets('нажатие по занятому пропуску снимает слово', (tester) async {
      // Единственный путь правки, доступный без перетаскивания. При полной
      // расстановке нажимать в пуле нечего — все плитки заняты, — а
      // «отменить» снимает только последнее поставленное: чтобы освободить
      // первый пропуск из трёх, её пришлось бы нажать трижды.
      final answers = await pumpArena(tester, question: longPhrase());

      for (var i = 0; i < 3; i++) {
        await tester.tap(poolWord(i));
        await tester.pump();
      }
      expect(isEnabled(tester, done), isTrue);

      await tester.tap(slot(0));
      await tester.pump();

      expect(slotText(tester, 0), '');
      expect(slotText(tester, 1), 'habe', reason: 'снялось не то слово');
      expect(isEnabled(tester, done), isFalse,
          reason: 'расстановка неполная, а отправить всё ещё можно');
      expect(answers, isEmpty);
    });

    testWidgets('«отменить» живёт при полной расстановке', (tester) async {
      // Раньше кнопка «отменить» скрывалась тем же условием, которым
      // отправлялся ответ: заметивший ошибку игрок не мог ни отменить, ни
      // переставить.
      await pumpArena(tester, question: longPhrase());

      for (var i = 0; i < 3; i++) {
        await tester.tap(poolWord(i));
        await tester.pump();
      }

      expect(isEnabled(tester, undo), isTrue);
      await tester.tap(undo);
      await tester.pump();

      expect(slotText(tester, 2), '', reason: 'снялось не последнее');
    });

    testWidgets('погашенная хозяином арена не отправляет ответ',
        (tester) async {
      // Так выглядит пауза показа: расстановка на месте, хозяин погасил
      // арену. Отправить в этот момент нельзя ничего.
      final answers = <(List<int>, Duration)>[];
      final question = phrase();
      Widget host({required bool enabled}) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 600,
                child: SlotsArena(
                  question: question,
                  enabled: enabled,
                  onAnswer: (bySlot, latency) =>
                      answers.add((bySlot, latency)),
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(enabled: true));
      await tester.pumpAndSettle();
      await tester.tap(poolWord(0));
      await tester.pump();
      await tester.tap(poolWord(1));
      await tester.pump();

      // Тот же объект вопроса — расстановка сохраняется.
      await tester.pumpWidget(host(enabled: false));
      await tester.pump();

      expect(slotText(tester, 0), 'Ich');
      expect(isEnabled(tester, done), isFalse);
      expect(answers, isEmpty);
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
