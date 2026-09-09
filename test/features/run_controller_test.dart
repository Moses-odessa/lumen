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
import 'package:lumen/domain/srs/review_grade.dart';
import 'package:lumen/features/game/application/run_controller.dart';

/// Забег — это состояние, а не экран, поэтому проверяется без виджетов.
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

  /// Круг с одним слотом: центр на родном, варианты на изучаемом. Вид
  /// дистракторов забег не интересует — он остался в плане, а не в вопросе.
  CircleQuestion question(String id, {int answerIndex = 0}) =>
      CircleQuestion.single(
        itemId: id,
        tier: Tier.a0,
        mode: GameMode.pickTarget,
        prompt: id,
        options: const ['a', 'b', 'c'],
        answerIndex: answerIndex,
        lumens: 50,
        answerSpeech: 'Wort $id',
      );

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
      expect(speech.spoken, ['Wort a']);
    });

    test('неверный ответ не озвучивается и не даёт очков', () {
      controller().start([question('a')]);
      controller().answerOption(2, const Duration(seconds: 2));

      expect(speech.spoken, isEmpty);
      expect(state().score, 0);
      expect(state().lastCorrect, isFalse);
    });

    test('ошибка возвращает слово в конец забега', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(2, const Duration(seconds: 2));

      // Жизней нет: слово вернётся, но забег не остановится.
      expect(state().queue.map((q) => q.itemId), ['a', 'b', 'a']);
      expect(state().phase, RunPhase.revealing);
    });

    test('прогресс считается по плану, а не по очереди', () {
      controller().start([question('a'), question('b')]);
      controller().answerOption(2, const Duration(seconds: 2));

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

    test('круг с одним вариантом играется как обычный', () {
      // Знакомство с новым словом: выбирать не из чего — соединил, услышал,
      // увидел перевод. Раньше такой круг был недостижим, сборщик отдавал
      // `null`, не набрав двух дистракторов, и круг молча исчезал из уровня.
      final intro = CircleQuestion.single(
        itemId: 'rechnung',
        tier: Tier.a1,
        mode: GameMode.pickTarget,
        prompt: 'счёт',
        options: const ['Rechnung'],
        answerIndex: 0,
        lumens: 0,
        isNew: true,
        answerSpeech: 'Rechnung',
        translation: 'счёт',
      );

      controller().start([intro]);
      expect(state().phase, RunPhase.asking);

      controller().answerOption(0, const Duration(seconds: 3));

      expect(state().correct, 1);
      expect(state().score, greaterThan(0));
      expect(speech.spoken, ['Rechnung']);
    });
  });

  group('переход к следующему кругу', () {
    test('после паузы открывается следующий круг', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(0, const Duration(milliseconds: 900));

        expect(state().current?.itemId, 'a');
        async.elapse(const Duration(seconds: 2));

        expect(state().current?.itemId, 'b');
        expect(state().phase, RunPhase.asking);
        expect(state().lastCorrect, isNull);
      });
    });

    test('на ошибке пауза длиннее — верный вариант надо успеть увидеть', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(2, const Duration(seconds: 2));

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
        async.elapse(const Duration(seconds: 2));
        controller().answerOption(0, const Duration(milliseconds: 900));
        async.elapse(const Duration(seconds: 2));

        expect(state().isFinished, isTrue);
        expect(state().summary, isNotNull);
        expect(state().summary!.isPerfect, isTrue);
        expect(state().summary!.circles, 2);
      });
    });

    test('ошибочное слово доигрывается до конца очереди', () {
      fakeAsync((async) {
        controller().start([question('a')]);

        controller().answerOption(2, const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));

        // Слово вернулось — забег ещё идёт.
        expect(state().isFinished, isFalse);
        expect(state().current?.itemId, 'a');

        controller().answerOption(0, const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));

        expect(state().isFinished, isTrue);
        expect(state().summary!.circles, 2);
        expect(state().summary!.correct, 1);
      });
    });
  });

  // УДАЛЕНО: группа «ввод текста».
  //
  // Она держала правило «ответ вводом проверяется по тексту, а не по индексу»
  // и вместе с ним допуск в одну опечатку: `answerInput('rechnung')`
  // засчитывался за `Rechnung`. Механики набора больше нет — ни поля ввода,
  // ни `answerInput`, ни сравнения строк, — поэтому и правила нет: любой
  // ответ в игре теперь индекс варианта. Ближайшее по смыслу место, где
  // форму приходится восстанавливать по памяти, — `buildPhrase` ниже, но
  // написание там не проверяется вовсе, и это осознанный размен.
  group('слоты', () {
    /// Фраза с двумя пропусками: пул общий на оба слота, лишние слова в нём —
    /// дистракторы.
    CircleQuestion gaps() => const CircleQuestion(
          itemId: 'rechnung',
          tier: Tier.a1,
          mode: GameMode.fillGaps,
          prompt: 'Die _____ bitte, ich _____ zahlen',
          options: ['Rechnung', 'möchte', 'Fahrkarte', 'kann'],
          answers: [0, 1],
          lumens: 70,
          answerSpeech: 'Die Rechnung bitte, ich möchte zahlen',
          translation: 'Счёт, пожалуйста, я хочу заплатить',
        );

    /// Максимум пропусков: вынуто всё предложение, скелета не осталось.
    ///
    /// Скелет всё равно есть — строка из одних пропусков. Отдельного вида
    /// центра для максимума больше нет: одна механика, одна шкала, один
    /// рисовальщик.
    CircleQuestion scattered() => const CircleQuestion(
          itemId: 'pay-today',
          tier: Tier.a2,
          mode: GameMode.buildPhrase,
          prompt: '_____ _____ _____ _____',
          options: ['zahlen', 'Ich', 'heute', 'möchte'],
          answers: [1, 3, 2, 0],
          lumens: 80,
          answerSpeech: 'Ich möchte heute zahlen',
        );

    test('заполненная фраза звучит целиком', () {
      final phrase = gaps();
      controller().start([phrase]);
      controller().answerSlots([0, 1], const Duration(seconds: 3));

      expect(state().correct, 1);
      expect(state().score, greaterThan(0));
      // Звучит собранное предложение, а не слово из пропуска: пропуск,
      // заполненный верно и не услышанный целиком, учит подбирать форму и
      // ничему больше.
      expect(speech.spoken, [phrase.assembled]);
      expect(phrase.assembled, 'Die Rechnung bitte, ich möchte zahlen');
    });

    test('половина пропусков — это не половина ответа', () {
      controller().start([gaps()]);
      controller().answerSlots([0], const Duration(seconds: 3));

      // Незаконченный ответ считается ошибкой целиком: иначе фразу можно
      // сдавать по одному пропуску, пока не угадаются все.
      expect(state().correct, 0);
      expect(state().lastCorrect, isFalse);
      expect(state().queue, hasLength(2));

      // А звучит при этом **верный** порядок, и проверка тут раньше стояла на
      // тишине. У круга со словом озвучка ошибки была бы подсказкой к тому же
      // вопросу — слово вернётся тем же кругом. Во фразе ответ это порядок,
      // он уже показан рядом с неверной сборкой, и услышать его правильным —
      // ровно то, зачем длинная пауза после ошибки и существует.
      expect(speech.spoken, [gaps().assembled]);
    });

    test('темп фразы считается на размещение, а не на весь ответ', () async {
      // Фраза с двумя пропусками, собранная за 2.4 с, — это 1.2 с на слово,
      // то есть уверенный ответ. По исходному времени это `hard`: пороги
      // (1.2 с и 2.0 с) рассчитаны на один тап в круге, а фразовая арена
      // сообщает время до последней плитки. Так самая дорогая механика игры
      // систематически укорачивала интервал и повышала трудность того
      // самого слова, которое должна была подтвердить.
      controller().start([gaps()]);
      controller().answerSlots([0, 1], const Duration(milliseconds: 2400));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final reviews = await db.select(db.reviews).get();
      expect(reviews, hasLength(1));
      expect(
        ReviewGrade.fromValue(reviews.single.grade),
        ReviewGrade.good,
        reason: 'верно собранная фраза записана как «вспомнил медленно»',
      );
      // Время в журнале — исходное: судить по нему нельзя, а знать полезно.
      expect(reviews.single.latencyMs, 2400);
    });

    test('быстрая сборка дороже медленной', () async {
      // Проверка того же с другой стороны: скоростной множитель фразе теперь
      // доступен вообще. Пока время не приводилось к размещению, любая сборка
      // была «медленной», и множитель на самой дорогой механике не работал
      // никогда.
      controller().start([gaps()]);
      controller().answerSlots([0, 1], const Duration(milliseconds: 2000));
      final fast = state().score;

      controller().start([gaps()]);
      controller().answerSlots([0, 1], const Duration(seconds: 9));

      expect(fast, greaterThan(state().score));
    });

    test('фраза стоит открытой дольше слова', () {
      // Пауза после фразы длинная нарочно: предложение проигрывается целиком
      // и под ним проявляется перевод. На 420 мс не влезало ни то, ни другое
      // — игрок ставил последнее слово и получал следующий вопрос, так и не
      // увидев, что собрал, а озвучка играла уже поверх следующего задания.
      fakeAsync((async) {
        controller().start([gaps(), question('after')]);
        controller().answerSlots([0, 1], const Duration(seconds: 2));

        async.elapse(const Duration(milliseconds: 600));
        expect(state().phase, RunPhase.revealing,
            reason: 'словесной паузы фразе мало');
        expect(state().current?.itemId, 'rechnung');

        async.elapse(const Duration(seconds: 3));
        expect(state().current?.itemId, 'after');
        expect(state().phase, RunPhase.asking);
      });
    });

    test('нажатие по арене закрывает паузу досрочно', () {
      // Ждать не обязан никто, пропускать не обязан тоже.
      fakeAsync((async) {
        controller().start([gaps(), question('after')]);
        controller().answerSlots([0, 1], const Duration(seconds: 2));

        controller().skipReveal();
        async.flushMicrotasks();

        expect(state().current?.itemId, 'after');
        expect(state().phase, RunPhase.asking);
      });
    });

    test('пропуск паузы до ответа ничего не делает', () {
      controller().start([question('a'), question('b')]);
      controller().skipReveal();

      expect(state().current?.itemId, 'a');
      expect(state().phase, RunPhase.asking);
    });

    test('верный слот не спасает неверный', () {
      final phrase = gaps();
      controller().start([phrase]);
      // Первый пропуск угадан, второй — созвучный дистрактор из того же пула.
      controller().answerSlots([0, 3], const Duration(seconds: 3));

      expect(phrase.isCorrectFor(0, 0), isTrue);
      expect(phrase.isCorrectFor(1, 3), isFalse);
      expect(state().correct, 0);
      expect(state().lastCorrect, isFalse);
    });

    test('порядок слов проверяется, а не набор', () {
      final phrase = scattered();
      controller().start([phrase]);
      // Те же четыре слова, но глагол не на втором месте — по-немецки это и
      // есть ошибка, и механика существует ровно ради неё.
      controller().answerSlots([1, 2, 3, 0], const Duration(seconds: 3));

      expect(state().lastCorrect, isFalse);
      expect(phrase.assembled, 'Ich möchte heute zahlen');
    });

    test('собранное предложение засчитывается', () {
      final phrase = scattered();
      controller().start([phrase]);
      controller().answerSlots(phrase.answers, const Duration(seconds: 3));

      expect(state().correct, 1);
      expect(speech.spoken, [phrase.assembled]);
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
    });

    test('быстрые верные ответы зажигают слово', () async {
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

    test('понимание на слух слово не зажигает', () async {
      // Непроизводящих механик теперь две, и вторая коварнее первой: со
      // слуха отвечать быстро легко, а произвести слово всё ещё не нужно.
      CircleQuestion heard() => CircleQuestion.single(
            itemId: 'b',
            tier: Tier.a0,
            mode: GameMode.listenNative,
            prompt: '',
            options: const ['счёт', 'поезд', 'дом'],
            answerIndex: 0,
            lumens: 50,
            promptSpeech: 'Rechnung',
            answerSpeech: 'Rechnung',
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

  group('многослотовый вопрос', () {
    CircleQuestion phrase() => const CircleQuestion(
          itemId: 'p1',
          tier: Tier.a0,
          mode: GameMode.fillGaps,
          prompt: 'Ich _____ einen _____.',
          options: ['brauche', 'Arzt', 'gehe', 'Hals'],
          answers: [0, 1],
          lumens: 40,
          answerSpeech: 'Ich brauche einen Arzt.',
        );

    test('один тап не закрывает фразу с двумя пропусками', () async {
      // `isCorrectOption(i)` — это `isCorrectFor(0, i)`, то есть проверка
      // только первого слота. Пока верный индекс был один, попасть сюда
      // фразой было нельзя; теперь оба обработчика приходят в одну арену, и
      // ошибка в разводке виджета молча превратилась бы в бесплатные очки.
      //
      // В debug-сборке путь падает ассертом — на это и рассчитано: тихо
      // проглотить неверный вызов значило бы оставить дефект незаметным.
      controller().start([phrase()]);
      expect(
        () => controller().answerOption(0, const Duration(milliseconds: 900)),
        throwsA(isA<AssertionError>()),
      );
      expect(controller().state.score, 0);
      expect(controller().state.answered, 0);
    });

    test('фраза закрывается только полным набором слотов', () async {
      controller().start([phrase()]);

      controller().answerSlots([0, 1], const Duration(milliseconds: 1500));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller().state.answered, 1);
      expect(controller().state.score, greaterThan(0));
    });

    test('верное слово в чужом пропуске — ошибка', () async {
      controller().start([phrase()]);

      controller().answerSlots([1, 0], const Duration(milliseconds: 1500));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller().state.answered, 0);
      expect(controller().state.score, 0);
      // Ошибка возвращает вопрос в конец очереди, а не отнимает доступ.
      expect(controller().state.queue.length, 2);
    });

    test('незаполненные слоты не считаются половиной знания', () async {
      controller().start([phrase()]);

      controller().answerSlots([0], const Duration(milliseconds: 1500));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller().state.answered, 0);
      expect(controller().state.score, 0);
    });
  });

  group('переслушивание', () {
    CircleQuestion heard() => const CircleQuestion(
          itemId: 'h1',
          tier: Tier.a0,
          mode: GameMode.listenNative,
          prompt: '',
          // Варианты на родном: вопрос на слух проверяет смысл, а не то,
          // какая из двух немецких строчек похожа на услышанное.
          options: ['рахунок', 'напрямок'],
          answers: [0],
          // Яркая звезда — и это условие проверки, а не деталь. Скоростного
          // множителя ниже 40 lm нет вовсе, так что «переслушивание снимает
          // скорость» проверяется только выше этой границы.
          lumens: 80,
          promptSpeech: 'Rechnung',
          answerSpeech: 'Rechnung',
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
      // был сообразить, что по нему надо нажать. Задание — узнать слово, а не
      // догадаться, как его услышать.
      controller().start([heard()]);

      expect(speech.spoken, ['Rechnung']);
    });

    test('автопроигрывание не считается переслушиванием', () {
      // Это не мелочь, а починка правила, которое не работало ни дня.
      // `replayPrompt` снимал множитель на **каждом** нажатии, включая первое,
      // а услышать слово иначе было нельзя — то есть скоростной множитель на
      // «Слухе» терялся всегда, вопреки собственному условию «его снимает
      // переслушивание».
      //
      // Проверяется тем, что множитель вообще есть: если бы автопроигрывание
      // ставило флаг, быстрый и медленный ответы стоили бы одинаково.
      controller().start([heard()]);
      controller().answerOption(0, const Duration(milliseconds: 500));
      final fast = controller().state.score;

      controller().start([heard()]);
      controller().answerOption(0, const Duration(seconds: 6));
      final slow = controller().state.score;

      expect(fast, greaterThan(slow),
          reason: 'скорость не оплачена: круг сочтён переслушанным');
    });

    test('следующий круг тоже звучит сам', () {
      fakeAsync((async) {
        controller().start([heard(), heard()]);
        controller().answerOption(0, const Duration(milliseconds: 500));
        async.elapse(const Duration(seconds: 2));

        // Три произнесения: центр первого круга, верный ответ, центр второго.
        expect(speech.spoken, ['Rechnung', 'Rechnung', 'Rechnung']);
      });
    });
  });
}
