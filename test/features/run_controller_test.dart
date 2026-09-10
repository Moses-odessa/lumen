import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/audio/speech_service.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/local/database_provider.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
// `balance.dart` отсюда ушёл вместе с двумя числами, которые тест называл по
// имени: `ScoreBalance.answerWindow` (одно окно на все круги — теперь его
// длину даёт сам вопрос) и `RevealBalance` (пауза перед автопереходом —
// перехода нет, круг ждёт кнопки). Формулу окна проверяет `balance_test.dart`;
// здесь проверяется, что забег заводит таймер по **своему** кругу.
import 'package:lumen/domain/srs/review_grade.dart';
import 'package:lumen/features/game/application/run_controller.dart';

/// Забег — это состояние, а не экран, поэтому проверяется без виджетов.
///
/// Главное правило, которое здесь охраняется, — **окно ответа**. Круг живёт
/// столько, сколько просит его текст, и молчание закрывает его так же, как
/// промах: фраза тускнеет и возвращается в очередь. Отличие одно — верный
/// вариант при этом звучит, потому что промолчавшему игроку его никто не назвал
/// ни выбором, ни подсветкой выбранного. Единственное исключение — знакомство:
/// там к ответу приходят исключением, читая пять знакомых строчек, и торопить в
/// этот момент значит требовать угадать, а не сообразить.
///
/// Второе правило, и оно новее: **темп круга принадлежит игроку**. Следующий
/// круг открывает кнопка, а не таймер; окно открывается тогда, когда отвечать
/// стало возможно (у круга на слух — после озвучки, а не вместе с ней); а пока
/// приложения нет на экране, не идёт ни один отсчёт и не тратится ни одна
/// секунда срока. Что было до этого — в комментариях к соответствующим
/// группам: забег в фоне доигрывал сам себя и тратил звёзды игрока.
///
/// Биндинг здесь поднимается нарочно, хотя виджетов нет ни одного: забег
/// слушает жизненный цикл приложения, а сигнал о нём приходит от платформы
/// через биндинг. Проверять «услышал ли забег систему» вызовом его же метода
/// значило бы проверять, что метод существует.
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
    // Забег слушает жизненный цикл, а слушать его без биндинга нельзя.
    TestWidgetsFlutterBinding.ensureInitialized();
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
    // Состояние жизненного цикла живёт на биндинге, а биндинг один на весь
    // файл: не сбросив его, следующий тест начинал бы забег в фоне.
    WidgetsBinding.instance.resetInternalState();
  });

  /// Сигнал жизненного цикла — тот самый, что приходит от платформы.
  ///
  /// Обработчик синхронный: к возврату из этого вызова забег уже знает, где он.
  void screen(AppLifecycleState state) {
    unawaited(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        SystemChannels.lifecycle.name,
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      ),
    );
  }

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

  /// Окно круга — то самое число, которым забег заводит таймер.
  ///
  /// Спрашивается у вопроса, а не считается здесь заново: окно зависит от
  /// объёма текста, и своя копия формулы в тесте проверяла бы свою арифметику
  /// против чужой. Проверять саму формулу — работа `balance_test.dart`.
  Duration windowOf(CircleQuestion q) => q.answerWindow!;

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
    test('молчание закрывает круг неверным ответом', () {
      // Смысл окна — учить отвечать быстро: ответ, который игрок вспоминал
      // двадцать секунд, в разговоре ему не поможет. Просрочка не третий
      // исход, а тот же промах: «не успел» значит «не вспомнил».
      fakeAsync((async) {
        final a = question('a');
        controller().start([a, question('b')]);

        async.elapse(windowOf(a) - const Duration(milliseconds: 1));
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

    test('окно длиннее там, где текста больше', () {
      // Плоские пять секунд наказывали за длину фразы, а не за незнание:
      // пройти круг значит прочитать центр и шесть вариантов, а на старших
      // ярусах это четыре сотни знаков. Проверяется здесь не формула
      // (`balance_test.dart`), а то, что забег заводит таймер по **этому**
      // кругу: с одним числом на всё круг B2 закрывался бы просрочкой всегда.
      fakeAsync((async) {
        final short = question('a');
        final long = CircleQuestion(
          itemId: 'l',
          tier: Tier.b2,
          mode: GameMode.pickTarget,
          prompt: 'Індивідуальні рішення важливі, але не замінюють '
              'структурних змін.',
          options: [
            for (var i = 0; i < 6; i++)
              'Individuelle Entscheidungen sind wichtig, ersetzen aber '
                  'keine strukturellen Veränderungen. $i',
          ],
          answerIndex: 0,
          lumens: 50,
          answerSpeech: 'Individuelle Entscheidungen',
        );
        expect(windowOf(long), greaterThan(windowOf(short)),
            reason: 'длинному кругу дали столько же, сколько короткому');

        controller().start([long]);
        async.elapse(windowOf(short));
        expect(state().phase, RunPhase.asking,
            reason: 'длинный круг закрыт по чужому, короткому окну');

        async.elapse(windowOf(long) - windowOf(short));
        expect(state().phase, RunPhase.revealing);
      });
    });

    test('просроченная фраза возвращается в очередь другим экземпляром', () {
      fakeAsync((async) {
        final a = question('a');
        controller().start([a, question('b')]);
        async.elapse(windowOf(a));

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
        final a = question('a');
        controller().start([a]);
        async.elapse(windowOf(a));

        expect(speech.spoken, ['Satz a']);
        expect(speech.hapticCount, 0,
            reason: 'вибрация вместо звука — это про промах, а не просрочку');
      });
    });

    test('просроченный круг ждёт игрока так же, как промах', () {
      // Здесь стояла проверка «просрочке дали паузу верного ответа, а не
      // промаха»: круг стоял открытым 420 мс после верного ответа и 1100 мс
      // после промаха, и просрочке принадлежала длинная пауза — верный вариант
      // надо успеть увидеть и услышать. Пауз по таймеру больше нет ни одной, и
      // разницы между исходами не осталось: круг стоит открытым, пока игрок не
      // нажмёт, и молчаливый круг ждёт его ровно столько же, сколько
      // ошибочный. Правило, которое охраняли два числа, исполняет сам игрок.
      fakeAsync((async) {
        final a = question('a');
        controller().start([a, question('b')]);
        async.elapse(windowOf(a));

        async.elapse(const Duration(minutes: 1));
        expect(state().phase, RunPhase.revealing,
            reason: 'круг сменился сам, без игрока');
        expect(state().current?.itemId, 'a');

        controller().next();
        expect(state().phase, RunPhase.asking);
        expect(state().current?.itemId, 'b');
      });
    });

    test('просрочка уходит в память ответом «не вспомнил»', () {
      // Весь путь целиком: таймер живёт в забеге, оценка — в памяти, и между
      // ними лежит окно, которого в тесте нет. Поэтому база опрашивается
      // изнутри фальшивого времени, а не после него: снаружи ответа не
      // дождаться.
      fakeAsync((async) {
        final a = question('a');
        controller().start([a]);
        async.elapse(windowOf(a));

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
        // ответом. Длина при этом та самая, что у этого круга, а не общая на
        // все: иначе журнал врал бы про то, сколько времени было у игрока.
        expect(reviews!.single.latencyMs, windowOf(a).inMilliseconds);
      });
    });

    test('ответ до истечения окна снимает окно с круга', () {
      fakeAsync((async) {
        controller().start([question('a')]);
        async.elapse(const Duration(seconds: 1));
        controller().answerOption(0, const Duration(seconds: 1));
        final score = state().score;

        // Окно с начала круга давно вышло — и не случилось ничего. Иначе
        // верный ответ превратился бы в промах задним числом, фраза
        // прозвучала бы дважды, а круг вернулся бы в очередь уже отвеченным.
        async.elapse(const Duration(seconds: 30));

        expect(state().score, score);
        expect(state().correct, 1);
        expect(state().queue, hasLength(1));
        expect(speech.spoken, ['Satz a']);
        // Забег ещё не кончен: итог придёт по кнопке.
        expect(state().phase, RunPhase.revealing);
        controller().next();
        expect(state().summary!.isPerfect, isTrue);
      });
    });

    test('окно открывается на каждом круге, а не только на первом', () {
      fakeAsync((async) {
        final b = question('b');
        controller().start([question('a'), b]);
        controller().answerOption(0, const Duration(milliseconds: 900));
        controller().next();
        expect(state().current?.itemId, 'b');

        async.elapse(windowOf(b));

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
        // Полосе окна брать длину неоткуда — и это то же самое правило,
        // высказанное состоянием: нет отсчёта, нет и картинки отсчёта.
        expect(state().window, isNull);
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
        controller().next();
        expect(state().current?.itemId, 'rechnung');

        async.elapse(const Duration(seconds: 20));

        expect(state().phase, RunPhase.asking);
        expect(state().current?.itemId, 'rechnung');
        expect(state().queue, hasLength(2));
        expect(state().answered, 1);
      });
    });

    test('открытое окно лежит в состоянии — полосе неоткуда взять своё', () {
      // Полоса окна над ареной рисует **этот** отсчёт, а не свой: своя
      // длительность у неё была бы вторым источником одного числа, и разойтись
      // они могли бы не длиной, а началом — окно круга на слух открывается
      // после озвучки, а не в кадре появления круга.
      fakeAsync((async) {
        final a = question('a');
        controller().start([a]);

        expect(state().window, windowOf(a));
        controller().answerOption(0, const Duration(seconds: 1));
        expect(state().window, isNull,
            reason: 'полоса осталась бы идти по отвеченному кругу');
        async.flushTimers();
      });
    });
  });

  group('переход к следующему кругу', () {
    test('следующий круг открывает кнопка, а не таймер', () {
      // Решение владельца дословно: «отключаем автоматическое появление
      // следующего круга, давай после выбора варианта активируем кнопку
      // Дальше и уже по ней переходим к следующему заниятию».
      //
      // Прежде круг стоял открытым 420 мс после верного ответа и 1100 мс после
      // промаха и сменялся сам. Разница была нужна затем, чтобы игрок успел
      // увидеть верный вариант; теперь это решает он.
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(0, const Duration(milliseconds: 900));

        async.elapse(const Duration(minutes: 5));
        expect(state().current?.itemId, 'a',
            reason: 'круг сменился без кнопки');
        expect(state().phase, RunPhase.revealing);

        controller().next();

        expect(state().current?.itemId, 'b');
        expect(state().phase, RunPhase.asking);
        expect(state().lastCorrect, isNull);
      });
    });

    test('на ошибке круг ждёт столько же — то есть сколько нужно игроку', () {
      // Здесь проверялось, что пауза после промаха длиннее паузы после верного
      // ответа. Двух длин больше нет: обе стали одной — «пока не нажмут».
      // Ошибка от этого не перестала учить, наоборот: время на верный вариант
      // больше не отмеряет тот, кто его не читает.
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(wrongOption, const Duration(seconds: 2));

        async.elapse(const Duration(minutes: 5));
        expect(state().phase, RunPhase.revealing);

        controller().next();
        expect(state().phase, RunPhase.asking);
      });
    });

    test('забег заканчивается итогом', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);

        controller().answerOption(0, const Duration(milliseconds: 900));
        controller().next();
        controller().answerOption(0, const Duration(milliseconds: 900));
        controller().next();
        async.flushMicrotasks();

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
        controller().next();

        // Фраза вернулась — забег ещё идёт.
        expect(state().isFinished, isFalse);
        expect(state().current?.itemId, 'a');

        controller().answerOption(0, const Duration(seconds: 2));
        controller().next();
        async.flushMicrotasks();

        expect(state().isFinished, isTrue);
        expect(state().summary!.circles, 2);
        expect(state().summary!.correct, 1);
      });
    });

    test('нажатие по арене делает то же, что кнопка', () {
      // `next` — один вход на оба движения. Нажатие по пустому месту круга
      // было досрочным закрытием паузы, которая шла по таймеру; паузы по
      // таймеру нет, а движение осталось: палец после ответа уже на арене.
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        controller().answerOption(wrongOption, const Duration(seconds: 2));

        controller().next();
        async.flushMicrotasks();

        expect(state().current?.itemId, 'b');
        expect(state().phase, RunPhase.asking);
      });
    });

    test('кнопка до ответа ничего не делает', () {
      // Обратная сторона того же правила: «Дальше» не пропускает круг. Иначе
      // игрок терял бы вопрос вместе с яркостью фразы одним нажатием.
      controller().start([question('a'), question('b')]);
      controller().next();

      expect(state().current?.itemId, 'a');
      expect(state().phase, RunPhase.asking);
      expect(state().answered, 0);
    });
  });

  group('окно ждёт озвучку', () {
    // Жалоба владельца дословно: «я не замерял, но мне кажется для ответа
    // дается только 2 секунды а не 5». Ощущение было верным, и причина
    // измерима: окно открывалось **в тот же миг**, что начиналась озвучка, —
    // в `_advance` подряд шли `_speakPrompt()` и `_openWindow()`. На круге со
    // слухом фраза существует только как звук: пока она произносится (две-три
    // секунды на предложение), отвечать физически не на что, а часы уже
    // тикают. Просрочка при этом считается «не вспомнил».
    CircleQuestion heard() => const CircleQuestion(
          itemId: 'h1',
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
          lumens: 80,
          promptSpeech: 'Die Rechnung, bitte',
          answerSpeech: 'Die Rechnung, bitte',
        );

    /// Сколько звучит предложение на устройстве.
    const speaking = Duration(seconds: 2);

    test('часы не идут, пока фраза звучит', () {
      speech.sounds = speaking;
      fakeAsync((async) {
        final h = heard();
        controller().start([h]);

        // Окна нет вовсе, пока звучит центр: отвечать не на что, и полосе
        // нечего показывать.
        expect(state().window, isNull);
        expect(speech.spoken, ['Die Rechnung, bitte']);

        async.elapse(speaking - const Duration(milliseconds: 1));
        expect(state().window, isNull,
            reason: 'часы пошли, пока фраза ещё звучала');

        async.elapse(const Duration(milliseconds: 1));
        expect(state().window, windowOf(h),
            reason: 'окно не открылось после озвучки');

        // Окно целиком принадлежит ответу: от начала озвучки до закрытия
        // круга проходит озвучка **плюс** окно, а не одно окно на оба.
        async.elapse(windowOf(h) - const Duration(milliseconds: 1));
        expect(state().phase, RunPhase.asking,
            reason: 'окно оказалось короче обещанного');
        async.elapse(const Duration(milliseconds: 1));
        expect(state().phase, RunPhase.revealing);
        async.elapse(const Duration(seconds: 1));
      });
    });

    test('текстовый центр окна не ждёт', () {
      // Обратная сторона: там, где читать можно с первого кадра, ждать нечего.
      // Одно правило на две механики означало бы, что круг на чтение получает
      // отсрочку за озвучку, которой у него нет.
      speech.sounds = speaking;
      final a = question('a');
      controller().start([a]);
      expect(state().window, windowOf(a));
    });

    test('переслушивание заводит окно заново', () {
      // Игрок попросил повторить, а не отказался от половины своего окна:
      // часы, идущие сквозь повтор, — это плата за чужую медлительность.
      // Платит переслушивание скоростным множителем, а не отобранными
      // секундами.
      speech.sounds = speaking;
      fakeAsync((async) {
        final h = heard();
        controller().start([h]);
        async.elapse(speaking);
        async.elapse(windowOf(h) - const Duration(seconds: 1));

        controller().replayPrompt();
        expect(state().window, isNull,
            reason: 'полоса шла, пока звучал повтор');
        // Секунда, которая осталась бы от прежнего окна, давно прошла.
        async.elapse(speaking + const Duration(seconds: 2));
        expect(state().phase, RunPhase.asking,
            reason: 'круг закрылся по остатку прежнего окна');

        async.elapse(windowOf(h));
        expect(state().phase, RunPhase.revealing);
        expect(speech.spoken.take(2),
            ['Die Rechnung, bitte', 'Die Rechnung, bitte']);
      });
    });

    test('окно открывает своё произнесение, а не то, что оно вытеснило', () {
      // Сторож здесь сверял **круг**: «тот же вопрос, что был?» — и на двух
      // путях из трёх круг тот же, а звучит уже второе чтение. Первый путь —
      // переслушивание посреди озвучки: игрок нажал динамик на первой секунде,
      // повтор шёл до четвёртой, а окно открылось на третьей, вместе с концом
      // первого чтения. Часы пошли под голос — то есть ровно то, от чего окно
      // и стали ждать.
      speech.sounds = speaking;
      fakeAsync((async) {
        final h = heard();
        controller().start([h]);

        async.elapse(const Duration(seconds: 1));
        controller().replayPrompt();

        // Первое чтение договаривает — и в этот самый миг сторож, сверявший
        // круг, открывал окно.
        async.elapse(const Duration(seconds: 1));
        expect(state().window, isNull,
            reason: 'окно открылось на чтении, которое вытеснил повтор');

        // Окно открывает то чтение, которое игрок слышит последним, — своим
        // концом.
        async.elapse(speaking - const Duration(milliseconds: 1));
        expect(state().window, isNull, reason: 'окно опередило повтор');
        async.elapse(const Duration(milliseconds: 1));
        expect(state().window, windowOf(h),
            reason: 'после повтора окно не открылось вовсе');
        expect(speech.uttered, ['Die Rechnung, bitte', 'Die Rechnung, bitte'],
            reason: 'повтор не прозвучал целиком');
      });
    });

    test('возвращение на экран открывает окно новым чтением, а не концом '
        'отобранного', () {
      // Второй путь того же сторожа, и замер сверки дословно: озвучка 3 с,
      // уход в фон на первой секунде, возврат на второй — окно открылось на
      // третьей, пока второе чтение шло до пятой.
      //
      // Голос здесь нарочно не заперт: в приложении его запирает корень
      // (`SilenceOffScreen`), и отобранное чтение обрывается. Тест держит его
      // звучащим именно затем, чтобы «чужое произнесение» было чем наблюдать:
      // забег обязан ждать своё чтение, а не любое на этом круге.
      speech.sounds = const Duration(seconds: 3);
      fakeAsync((async) {
        final h = heard();
        controller().start([h]);

        async.elapse(const Duration(seconds: 1));
        screen(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 1));
        screen(AppLifecycleState.resumed);

        // Возвращение читает центр заново: звук отобрала игра, и слышал его
        // не игрок.
        expect(speech.spoken.length, 2, reason: 'центр не прозвучал заново');

        async.elapse(const Duration(seconds: 1));
        expect(state().window, isNull,
            reason: 'окно открылось на чтении, которое игрок не слышал');

        // Открывает окно второе чтение — и только когда оно кончится. Что
        // кончилось оно позже, чем началось: первое договаривает, второе идёт
        // за ним, и это то же правило «начатое договаривается».
        async.elapse(const Duration(seconds: 3) - const Duration(milliseconds: 1));
        expect(state().window, isNull, reason: 'окно опередило второе чтение');
        async.elapse(const Duration(milliseconds: 1));
        expect(state().window, windowOf(h),
            reason: 'после второго чтения окно не открылось вовсе');
      });
    });

    test('без голоса круг на слух всё равно открывается', () {
      // Заглушка без голоса отвечает мгновенно, и это условие проверки: ждать
      // сигнала, которого не будет, значило бы никогда не открыть окно. Круг
      // со слухом без синтеза непроходим, но повиснуть он не должен.
      expect(speech.sounds, Duration.zero);
      fakeAsync((async) {
        final h = heard();
        controller().start([h]);
        async.flushMicrotasks();
        expect(state().window, windowOf(h));
        async.elapse(windowOf(h));
      });
    });
  });

  group('забег без игрока', () {
    // Жалоба владельца дословно: «когда я закрыл окно с игрой — она продолжает
    // работать в фоне — я слышу текст». Игра не доигрывала звук, она
    // продолжала играть сама: окно истекало, просрочка уходила в память как
    // «не вспомнил», звучал верный ответ, срабатывал автопереход, новый круг
    // произносил свой вопрос — и так по кругу. За минуту в закрытом окне
    // отыгрывалось десять кругов, каждый просрочкой.
    test('в фоне не идёт ни один отсчёт', () {
      fakeAsync((async) {
        controller().start([question('a'), question('b')]);
        screen(AppLifecycleState.paused);

        async.elapse(const Duration(minutes: 1));

        expect(speech.spoken, isEmpty, reason: 'игра говорила без игрока');
        expect(state().queue.map((q) => q.itemId), ['a', 'b']);
        expect(state().phase, RunPhase.asking);
        expect(state().answered, 0);
        expect(state().window, isNull,
            reason: 'окно осталось открытым в фоне');
      });
    });

    test('возвращение открывает окно с полного времени', () {
      // С остатка было бы наказанием за то, чего игрок не видел: ни фразы, ни
      // полосы, ни того, сколько времени уже съедено.
      fakeAsync((async) {
        final a = question('a');
        controller().start([a]);
        async.elapse(windowOf(a) - const Duration(milliseconds: 200));

        screen(AppLifecycleState.paused);
        async.elapse(const Duration(minutes: 1));
        screen(AppLifecycleState.resumed);

        expect(state().window, windowOf(a));
        async.elapse(windowOf(a) - const Duration(milliseconds: 1));
        expect(state().phase, RunPhase.asking,
            reason: 'круг закрылся по остатку прежнего окна');
        async.elapse(const Duration(milliseconds: 1));
        expect(state().phase, RunPhase.revealing);
      });
    });

    test('круг на слух после возвращения звучит заново и не считается '
        'переслушанным', () {
      // Звук отобрала игра, а не игрок попросил повторить: снимать за это
      // скоростной множитель значило бы наказывать за входящий звонок.
      const listen = CircleQuestion(
        itemId: 'h1',
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
        // Яркая звезда — условие проверки: скоростного множителя ниже 40 lm
        // нет вовсе, и «фон не отнял скорость» проверялось бы ни на чём.
        lumens: 80,
        promptSpeech: 'Die Rechnung, bitte',
        answerSpeech: 'Die Rechnung, bitte',
      );
      speech.sounds = const Duration(seconds: 2);

      fakeAsync((async) {
        controller().start([listen]);
        async.elapse(const Duration(seconds: 3));

        screen(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 10));
        screen(AppLifecycleState.resumed);
        async.elapse(const Duration(seconds: 3));

        expect(speech.spoken.length, 2, reason: 'центр не прозвучал заново');
        controller().answerOption(0, const Duration(milliseconds: 500));
        final afterBackground = state().score;
        // Секунда фальшивого времени — чтобы фоновая запись в память успела
        // дойти до диска: незавершённая, она держала бы тест до таймаута.
        async.elapse(const Duration(seconds: 1));

        // Тот же круг и тот же быстрый ответ, но без ухода с экрана.
        controller().start([listen]);
        async.elapse(const Duration(seconds: 3));
        controller().answerOption(0, const Duration(milliseconds: 500));
        async.elapse(const Duration(seconds: 1));

        expect(afterBackground, state().score,
            reason: 'фон обошёлся игроку в скоростной множитель');
      });
    });

    test('время вне экрана не съедает срок забега', () async {
      // Срок Восхода и спринта — настоящие часы, а не таймер: они идут
      // независимо от игрока, и это замысел. Но время, когда игры не было на
      // экране, забегу не принадлежит — иначе входящий звонок убивал бы спринт,
      // а Восход кончался бы, не показав ни одного круга.
      //
      // Тест на настоящих часах, а не на фальшивых: срок считается по
      // `DateTime.now()`, и `fakeAsync` его не двигает — под ним не сдвинулись
      // бы ни срок, ни время отсутствия, и проверка прошла бы при любом коде.
      controller().start(
        [question('a'), question('b')],
        maxDuration: const Duration(milliseconds: 400),
      );
      screen(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      screen(AppLifecycleState.resumed);

      controller().answerOption(0, const Duration(milliseconds: 300));
      controller().next();

      expect(state().isFinished, isFalse, reason: 'фон съел срок забега');
      expect(state().current?.itemId, 'b');
      controller().leaveScreen();
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
      // окна в игре больше не бывает: круг закрывается сам, и время, которого
      // не может быть, ничего не проверяет. Четыре секунды в окно круга на
      // слух укладываются: его длина считается по объёму текста, а шесть
      // коротких переводов вокруг звучащего центра просят больше четырёх.
      expect(windowOf(heard()), greaterThan(const Duration(seconds: 4)));
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
        controller().next();
        async.flushMicrotasks();

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
