import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/audio/speech_service.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/srs/review_grade.dart';
import 'package:lumen/features/game/application/run_controller.dart';

/// Забег — это состояние, а не экран, поэтому проверяется без виджетов.
///
/// Главное правило, которое здесь охраняется, — **окно ответа**. Круг живёт
/// пять секунд, и молчание закрывает его так же, как промах: фраза тускнеет и
/// возвращается в очередь. Отличие одно — верный вариант при этом звучит,
/// потому что промолчавшему игроку его никто не назвал ни выбором, ни
/// подсветкой выбранного. Единственное исключение — знакомство: там к ответу
/// приходят исключением, читая пять знакомых строчек, и торопить в этот момент
/// значит требовать угадать, а не сообразить.
///
/// Что удалено вместе с правилами, которые эти тесты охраняли:
///
/// * Группа «ввод текста» (удалена раньше механики фраз). Держала правило
///   «ответ вводом проверяется по тексту, а не по индексу» и допуск в одну
///   опечатку: `answerInput('rechnung')` засчитывался за `Rechnung`. Поля
///   ввода в игре нет — любой ответ теперь индекс варианта.
/// * Группа «слоты», восемь тестов. Охраняли вставку слов в предложение:
///   заполненная фраза звучит целиком, а не словом из пропуска; половина
///   пропусков не половина ответа; верный слот не спасает неверный; порядок
///   слов проверяется, а не набор; темп считается на размещение, а не на весь
///   ответ (`ScoreRules.paceFor`); фразовая пауза длиннее словесной. Механики
///   нет: единица изучения — фраза целиком, вопрос у неё один, «какая из
///   шести», и вместе с пропусками ушли `answerSlots`, `answers`,
///   `assembled`, `isCorrectFor`, `paceFor` и фразовые длины `RevealBalance`.
///   Два теста из этой группы не удалены, а переехали в «переход к следующему
///   кругу»: досрочное закрытие паузы нажатием — правило живое, оно просто
///   больше не про фразовую арену.
/// * Группа «многослотовый вопрос», четыре теста. Стерегла дыру, в которой
///   фраза с двумя пропусками засчитывалась бы полностью верной от одного
///   тапа, и ассерт в `answerOption`, который эту дыру закрывал. Слот теперь
///   один, обработчик один, стеречь нечего.
///
/// Тест «круг с одним вариантом играется как обычный» не удалён, а перенесён:
/// круга с одним вариантом больше нет — вариантов всегда шесть, — но
/// знакомство как круг, который считается наравне с остальными, осталось.
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

  /// Круг разговорника: в центре фраза на родном, вокруг шесть на изучаемом.
  ///
  /// Полный круг — не украшение раскладки: пять из шести вариантов это фразы,
  /// которые игрок уже знает, и на них держится знакомство методом
  /// исключения. Забег получает круг уже собранным и о том, откуда взялись
  /// варианты, не знает ничего.
  CircleQuestion question(String id) => CircleQuestion(
        itemId: id,
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: 'фраза $id',
        options: [
          'Satz $id',
          'Wo ist der Bahnhof',
          'Zwei Kaffee bitte',
          'Ich verstehe nicht',
          'Wie viel kostet das',
          'Bis morgen',
        ],
        answerIndex: 0,
        lumens: 50,
        answerSpeech: 'Satz $id',
      );

  /// Знакомство: новая фраза среди пяти известных.
  ///
  /// От обычного круга отличается одним флагом, и этим флагом целиком
  /// определяется, есть ли на круге окно на ответ.
  CircleQuestion intro() => const CircleQuestion(
        itemId: 'rechnung',
        tier: Tier.a1,
        mode: GameMode.pickTarget,
        prompt: 'Счёт, пожалуйста',
        options: [
          'Die Rechnung, bitte',
          'Wo ist der Bahnhof',
          'Zwei Kaffee bitte',
          'Ich verstehe nicht',
          'Wie viel kostet das',
          'Bis morgen',
        ],
        answerIndex: 0,
        lumens: 0,
        isNew: true,
        answerSpeech: 'Die Rechnung, bitte',
        translation: 'Счёт, пожалуйста',
      );

  /// Индекс варианта, которого в ответе быть не может: тексты в круге разные,
  /// а `isCorrectOption` сравнивает именно текст.
  const wrongOption = 3;

  RunController controller() =>
      container.read(runControllerProvider.notifier);
  RunState state() => container.read(runControllerProvider);

  group('старт', () {
    test('забег начинается с первого круга', () {
      controller().start([question('a'), question('b')]);

      expect(state().phase, RunPhase.asking);
      expect(state().current?.itemId, 'a');
      expect(state().total, 2);
      expect(state().progress, 0);
    });

    test('пустой список кругов не начинает забег', () {
      controller().start([]);
      expect(state().isFinished, isTrue);
      expect(state().current, isNull);
    });
  });

  group('ответ', () {
    test('верный ответ даёт очки и растит комбо', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(0, const Duration(milliseconds: 900));

      expect(state().score, greaterThan(0));
      expect(state().combo.streak, 1);
      expect(state().correct, 1);
      expect(state().lastCorrect, isTrue);
      expect(state().phase, RunPhase.revealing);
    });

    test('верное соединение озвучивается', () {
      controller().start([question('a')]);
      controller().answerOption(0, const Duration(milliseconds: 900));

      // Инвариант README: каждое верное соединение озвучивается.
      expect(speech.spoken, ['Satz a']);
    });

    test('неверный ответ не озвучивается и не даёт очков', () {
      controller().start([question('a')]);
      controller().answerOption(wrongOption, const Duration(seconds: 2));

      // Вместо звука вибрация: озвучить верную фразу здесь значило бы дать
      // подсказку к тому же вопросу — он вернётся тем же кругом. Единственный
      // неверный исход, который всё-таки звучит, — просроченное окно: там
      // игрок ничего не выбрал, и ответ ему не назвали вовсе.
      expect(speech.spoken, isEmpty);
      expect(speech.hapticCount, 1);
      expect(state().score, 0);
      expect(state().lastCorrect, isFalse);
    });

    test('ошибка возвращает фразу в конец забега', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(wrongOption, const Duration(seconds: 2));

      // Жизней нет: фраза вернётся, но забег не остановится.
      expect(state().queue.map((q) => q.itemId), ['a', 'b', 'a']);
      expect(state().phase, RunPhase.revealing);
    });

    test('прогресс считается по плану, а не по очереди', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(wrongOption, const Duration(seconds: 2));

      // Ошибка удлиняет очередь — полоса прогресса не должна ползти назад.
      expect(state().progress, 0);
      expect(state().total, 2);
    });

    test('повторный ответ на тот же круг игнорируется', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(0, const Duration(milliseconds: 900));
      final score = state().score;

      controller().answerOption(0, const Duration(milliseconds: 900));
      expect(state().score, score);
    });

    test('знакомство считается ответом наравне с остальными кругами', () {
      // Перенос теста про круг с одним вариантом. Тогда знакомство было
      // показом: выбирать не из чего — соединил, услышал, увидел перевод.
      // Теперь оно устроено исключением, вариантов шесть, и `isNew` меняет
      // ровно одно — отсутствие окна на ответ. Всё остальное на этом круге
      // работает как везде: ответ засчитывается, очки идут, фраза звучит.
      // Обратное означало бы, что первые шесть кругов уровня — те самые, где
      // человек впервые видит фразу, — проходят мимо игры.
      controller().start([intro()]);
      expect(state().phase, RunPhase.asking);

      controller().answerOption(0, const Duration(seconds: 3));

      expect(state().correct, 1);
      expect(state().score, greaterThan(0));
      expect(speech.spoken, ['Die Rechnung, bitte']);
    });
  });

  group('окно ответа', () {
    test('молчание пять секунд закрывает круг неверным ответом', () {
      // Смысл окна — учить отвечать быстро: ответ, который игрок вспоминал
      // двадцать секунд, в разговоре ему не поможет. Просрочка не третий
      // исход, а тот же промах: «не успел» значит «не вспомнил».
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);

        async.elapse(
          ScoreBalance.answerWindow - const Duration(milliseconds: 1),
        );
        expect(state().phase, RunPhase.asking,
            reason: 'круг закрылся раньше срока');

        async.elapse(const Duration(milliseconds: 1));

        expect(state().phase, RunPhase.revealing);
        expect(state().lastCorrect, isFalse);
        expect(state().correct, 0);
        expect(state().score, 0);
        expect(state().answered, 0);
      });
    });

    test('просроченная фраза возвращается в очередь другим экземпляром', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        async.elapse(ScoreBalance.answerWindow);

        expect(state().queue.map((q) => q.itemId), ['a', 'b', 'a']);
        // Другим объектом, а не тем же, и это не мелочь: арена сбрасывает
        // своё состояние по смене объекта вопроса. Когда просроченный круг
        // последний в забеге, следующим показывается он же — тот же объект
        // означал бы, что арена не сбросилась и больше не принимает ответов.
        expect(state().queue.last, isNot(same(state().queue.first)));
        // Просрочка не считается пройденным кругом: полоса прогресса стоит.
        expect(state().progress, 0);
      });
    });

    test('по просрочке звучит верный вариант', () {
      // Единственное отличие просрочки от промаха. Промах молчит нарочно:
      // фраза вернётся тем же кругом, и озвучка была бы подсказкой. Но
      // промолчавшему игроку ответ не назвали ничем — ни выбором, ни
      // подсветкой выбранного, — и услышать его он должен хотя бы раз.
      fakeAsync((async) {
        controller().start([question('a')]);
        async.elapse(ScoreBalance.answerWindow);

        expect(speech.spoken, ['Satz a']);
        expect(speech.hapticCount, 0,
            reason: 'вибрация вместо звука — это про промах, а не просрочку');
      });
    });

    test('просроченный круг стоит открытым столько же, сколько промах', () {
      // Пауза после промаха длиннее нарочно: надо успеть увидеть и услышать
      // верный вариант. У просрочки увидеть и услышать надо ровно то же —
      // короткая пауза «верного ответа» проглотила бы озвучку и подсветку, и
      // молчаливый круг не научил бы вообще ничему.
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        async.elapse(ScoreBalance.answerWindow);

        async.elapse(RevealBalance.correct);
        expect(state().phase, RunPhase.revealing,
            reason: 'просрочке дали паузу верного ответа');

        async.elapse(RevealBalance.wrong - RevealBalance.correct);
        expect(state().phase, RunPhase.asking);
        expect(state().current?.itemId, 'b');
      });
    });

    test('просрочка уходит в память ответом «не вспомнил»', () {
      // Весь путь целиком: таймер живёт в забеге, оценка — в памяти, и между
      // ними лежат пять секунд, которых в тесте нет. Поэтому база
      // опрашивается изнутри фальшивого времени, а не после него: снаружи
      // ответа не дождаться.
      fakeAsync((async) {
        controller().start([question('a')]);
        async.elapse(ScoreBalance.answerWindow);

        List<ReviewRow>? reviews;
        db.select(db.reviews).get().then((rows) => reviews = rows);
        async.elapse(const Duration(seconds: 1));

        expect(reviews, hasLength(1));
        expect(reviews!.single.correct, isFalse);
        expect(
          ReviewGrade.fromValue(reviews!.single.grade),
          ReviewGrade.again,
          reason: 'просрочка записана как что-то кроме «не вспомнил»',
        );
        // В журнале — длина окна, а не ноль: игрок думал ровно столько,
        // сколько ему дали, и запись об этом не должна выглядеть мгновенным
        // ответом.
        expect(
          reviews!.single.latencyMs,
          ScoreBalance.answerWindow.inMilliseconds,
        );
      });
    });

    test('ответ до истечения окна снимает окно с круга', () {
      fakeAsync((async) {
        controller().start([question('a')]);
        async.elapse(const Duration(seconds: 1));
        controller().answerOption(0, const Duration(seconds: 1));
        final score = state().score;

        // Пять секунд с начала круга давно прошли — и не случилось ничего.
        // Иначе верный ответ превратился бы в промах задним числом, фраза
        // прозвучала бы дважды, а круг вернулся бы в очередь уже отвеченным.
        async.elapse(const Duration(seconds: 10));

        expect(state().score, score);
        expect(state().correct, 1);
        expect(state().queue, hasLength(1));
        expect(speech.spoken, ['Satz a']);
        expect(state().summary!.isPerfect, isTrue);
      });
    });

    test('окно открывается на каждом круге, а не только на первом', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(0, const Duration(milliseconds: 900));
        async.elapse(RevealBalance.correct);
        expect(state().current?.itemId, 'b');

        async.elapse(ScoreBalance.answerWindow);

        expect(state().lastCorrect, isFalse);
        expect(state().queue.map((q) => q.itemId), ['a', 'b', 'b']);
      });
    });

    test('на знакомстве окна нет: молчание ничего не делает', () {
      // Вокруг новой фразы стоят пять уже известных, и к ответу игрок
      // приходит исключением — читает пять знакомых строчек и понимает, какая
      // шестая. Отсчёт в этот момент требует угадать, а не сообразить.
      fakeAsync((async) {
        controller().start([intro()]);
        async.elapse(const Duration(minutes: 1));

        expect(state().phase, RunPhase.asking);
        expect(state().current?.itemId, 'rechnung');
        expect(state().queue, hasLength(1));
        expect(state().answered, 0);
        expect(speech.spoken, isEmpty);
      });
    });

    test('окно прошлого круга не закрывает знакомство', () {
      // Порядок внутри `_openWindow` — сначала снять прежнее окно, потом
      // решать, ставить ли новое. Наоборот — и таймер обычного круга
      // доживает до знакомства, закрывая промахом фразу, которую игрок видит
      // впервые. Ошибка на первом же показе роняет яркость новой фразы в ноль
      // и отправляет её в очередь как забытую.
      fakeAsync((async) {
        controller().start([question('a'), intro()]);
        async.elapse(const Duration(seconds: 1));
        controller().answerOption(0, const Duration(seconds: 1));
        async.elapse(RevealBalance.correct);
        expect(state().current?.itemId, 'rechnung');

        async.elapse(const Duration(seconds: 20));

        expect(state().phase, RunPhase.asking);
        expect(state().current?.itemId, 'rechnung');
        expect(state().queue, hasLength(2));
        expect(state().answered, 1);
      });
    });
  });

  group('переход к следующему кругу', () {
    test('после паузы открывается следующий круг', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(0, const Duration(milliseconds: 900));

        expect(state().current?.itemId, 'a');
        async.elapse(RevealBalance.correct);

        expect(state().current?.itemId, 'b');
        expect(state().phase, RunPhase.asking);
        expect(state().lastCorrect, isNull);
      });
    });

    test('на ошибке пауза длиннее — верный вариант надо успеть увидеть', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(wrongOption, const Duration(seconds: 2));

        async.elapse(const Duration(milliseconds: 500));
        expect(state().phase, RunPhase.revealing,
            reason: 'на ошибке пауза не может быть такой же короткой');

        async.elapse(const Duration(seconds: 1));
        expect(state().phase, RunPhase.asking);
      });
    });

    test('забег заканчивается итогом', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);

        controller().answerOption(0, const Duration(milliseconds: 900));
        async.elapse(RevealBalance.correct);
        controller().answerOption(0, const Duration(milliseconds: 900));
        async.elapse(RevealBalance.correct);

        expect(state().isFinished, isTrue);
        expect(state().summary, isNotNull);
        expect(state().summary!.isPerfect, isTrue);
        expect(state().summary!.circles, 2);
      });
    });

    test('ошибочная фраза доигрывается до конца очереди', () {
      fakeAsync((async) {
        controller().start([question('a')]);

        controller().answerOption(wrongOption, const Duration(seconds: 2));
        async.elapse(RevealBalance.wrong);

        // Фраза вернулась — забег ещё идёт.
        expect(state().isFinished, isFalse);
        expect(state().current?.itemId, 'a');

        controller().answerOption(0, const Duration(seconds: 2));
        async.elapse(RevealBalance.correct);

        expect(state().isFinished, isTrue);
        expect(state().summary!.circles, 2);
        expect(state().summary!.correct, 1);
      });
    });

    test('нажатие по арене закрывает паузу досрочно', () {
      // Ждать не обязан никто, пропускать не обязан тоже. Пауза после промаха
      // длинная нарочно — верный вариант надо услышать, — но заставлять ждать
      // того, кто уже всё увидел, значит платить его временем за чужую
      // медлительность.
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(wrongOption, const Duration(seconds: 2));

        controller().skipReveal();
        async.flushMicrotasks();

        expect(state().current?.itemId, 'b');
        expect(state().phase, RunPhase.asking);
      });
    });

    test('пропуск паузы до ответа ничего не делает', () {
      controller().start([question('a'), question('b')]);
      controller().skipReveal();

      expect(state().current?.itemId, 'a');
      expect(state().phase, RunPhase.asking);
    });
  });

  group('память', () {
    test('ответ доходит до базы и переживает забег', () async {
      controller().start([question('a')]);
      controller().answerOption(0, const Duration(milliseconds: 900));

      // Запись идёт в фоне, чтобы не тормозить забег, — ждём её отдельно.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final row = await db.loadWordState('a');
      expect(row, isNotNull);
      expect(row!.reps, 1);
      expect(row.stability, greaterThan(0));

      final reviews = await db.select(db.reviews).get();
      expect(reviews, hasLength(1));
      expect(reviews.single.correct, isTrue);
      expect(reviews.single.mode, GameMode.pickTarget.code);
      // Время в журнале — то, что было на самом деле: приводить его к чему-то
      // другому больше некому и незачем.
      expect(reviews.single.latencyMs, 900);
    });

    test('быстрые верные ответы зажигают фразу', () async {
      controller().start([
        question('a'),
        question('a'),
        question('a'),
      ]);

      for (var i = 0; i < 3; i++) {
        controller().answerOption(0, const Duration(milliseconds: 600));
        await Future<void>.delayed(const Duration(milliseconds: 120));
        // Ручной переход: fakeAsync и настоящая база вместе не дружат.
        controller().state = controller().state.copyWith(
              index: i + 1,
              phase: RunPhase.asking,
            );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final row = await db.loadWordState('a');
      expect(row!.fastStreak, 3);
      expect(row.burning, isTrue);
      expect(await db.countBurning(), 1);
    });

    test('понимание на слух фразу не зажигает', () async {
      // Механика на слух непроизводящая и коварнее чтения: отвечать со слуха
      // быстро легко, а произнести фразу самому всё ещё не нужно.
      CircleQuestion heard() => const CircleQuestion(
            itemId: 'b',
            tier: Tier.a0,
            mode: GameMode.listenNative,
            prompt: '',
            options: [
              'Счёт, пожалуйста',
              'Где вокзал',
              'Два кофе, пожалуйста',
              'Я не понимаю',
              'Сколько это стоит',
              'До завтра',
            ],
            answerIndex: 0,
            lumens: 50,
            promptSpeech: 'Die Rechnung, bitte',
            answerSpeech: 'Die Rechnung, bitte',
          );

      controller().start([heard(), heard(), heard()]);

      for (var i = 0; i < 3; i++) {
        controller().answerOption(0, const Duration(milliseconds: 600));
        await Future<void>.delayed(const Duration(milliseconds: 120));
        controller().state = controller().state.copyWith(
              index: i + 1,
              phase: RunPhase.asking,
            );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final row = await db.loadWordState('b');
      expect(row!.reps, 3, reason: 'ответы всё равно должны дойти до памяти');
      expect(row.fastStreak, 0);
      expect(row.burning, isFalse);
      expect(await db.countBurning(), 0);
    });
  });

  group('переслушивание', () {
    CircleQuestion heard() => const CircleQuestion(
          itemId: 'h1',
          tier: Tier.a0,
          mode: GameMode.listenNative,
          prompt: '',
          // Варианты на родном: вопрос на слух проверяет смысл, а не то,
          // какая из шести немецких строчек похожа на услышанное.
          options: [
            'Счёт, пожалуйста',
            'Где вокзал',
            'Два кофе, пожалуйста',
            'Я не понимаю',
            'Сколько это стоит',
            'До завтра',
          ],
          answerIndex: 0,
          // Яркая звезда — и это условие проверки, а не деталь. Скоростного
          // множителя ниже 40 lm нет вовсе, так что «переслушивание снимает
          // скорость» проверяется только выше этой границы.
          lumens: 80,
          promptSpeech: 'Die Rechnung, bitte',
          answerSpeech: 'Die Rechnung, bitte',
        );

    test('снимает скоростной множитель, но не запрещает ответ', () async {
      // Правило было записано в комментариях с самого начала и не работало
      // ни дня: `replayPrompt` просто проигрывал звук, ничего не считая. Без
      // него механика на слух вырождается в обычный круг с лишним тапом —
      // слушать один раз незачем, если второй бесплатен.
      controller().start([heard()]);
      controller().answerOption(0, const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final fast = controller().state.score;

      controller().start([heard()]);
      controller().replayPrompt();
      controller().answerOption(0, const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final replayed = controller().state.score;

      expect(fast, greaterThan(replayed),
          reason: 'переслушивание не изменило цену ответа');
      expect(replayed, greaterThan(0),
          reason: 'переслушивание не должно отнимать очки целиком');
    });

    test('первое проигрывание делает игра, а не игрок', () {
      // До этого круг на слух начинался тишиной: игрок видел динамик и должен
      // был сообразить, что по нему надо нажать. Задание — узнать фразу, а не
      // догадаться, как её услышать.
      controller().start([heard()]);

      expect(speech.spoken, ['Die Rechnung, bitte']);
    });

    test('автопроигрывание не считается переслушиванием', () {
      // Это не мелочь, а починка правила, которое не работало ни дня.
      // `replayPrompt` снимал множитель на **каждом** нажатии, включая первое,
      // а услышать фразу иначе было нельзя — то есть скоростной множитель на
      // «Слухе» терялся всегда, вопреки собственному условию «его снимает
      // переслушивание».
      //
      // Проверяется тем, что множитель вообще есть: если бы автопроигрывание
      // ставило флаг, быстрый и медленный ответы стоили бы одинаково.
      //
      // «Медленный» — четыре секунды, а не шесть, как было. Ответа длиннее
      // окна в игре больше не бывает: на пятой секунде круг закрывается сам,
      // и время, которого не может быть, ничего не проверяет.
      controller().start([heard()]);
      controller().answerOption(0, const Duration(milliseconds: 500));
      final fast = controller().state.score;

      controller().start([heard()]);
      controller().answerOption(0, const Duration(seconds: 4));
      final slow = controller().state.score;

      expect(fast, greaterThan(slow),
          reason: 'скорость не оплачена: круг сочтён переслушанным');
    });

    test('следующий круг тоже звучит сам', () {
      fakeAsync((async) {
        controller().start([heard(), heard()]);
        controller().answerOption(0, const Duration(milliseconds: 500));
        async.elapse(RevealBalance.correct);

        // Три произнесения: центр первого круга, верный ответ, центр второго.
        expect(speech.spoken, [
          'Die Rechnung, bitte',
          'Die Rechnung, bitte',
          'Die Rechnung, bitte',
        ]);
      });
    });
  });
}
