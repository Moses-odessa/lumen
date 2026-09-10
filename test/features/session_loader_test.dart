import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/repositories/word_state_repository.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/prompt_tag.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/level_stage.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/features/game/application/question_builder.dart';
import 'package:lumen/features/game/application/session_loader.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

// `tool/` — отдельная программа и не лежит в `lib/`, поэтому импорт по
// относительному пути. Нужен он ради `contentSchemaDdl`: самодельный корпус
// для проверки двусмысленности собирается тем же DDL, что и ассет, — иначе он
// проверял бы выдуманную схему. Так же импортирует его
// `test/data/content_schema_test.dart`.
//
// С префиксом, а не как там: `promptTags` объявлены и в инструменте, и в
// `lib/domain/entities/prompt_tag.dart`, который здесь тоже нужен. Один набор
// кодов регистра в двух программах — намеренное дублирование (`tool/` не
// тянет за собой `lib/`), и префикс говорит, чей именно набор читается.
import '../../tool/content_schema.dart' as schema;

/// Сквозная проверка ядра: настоящий ассет `content.db`, настоящая
/// Drift-схема и настоящий планировщик. Именно здесь ловятся расхождения,
/// которых не видно ни в одном юнит-тесте по отдельности.
///
/// Единица изучения — фраза. Ассет несёт 1500 немецких фраз и ровно столько
/// же переводов на каждый из четырёх языков подсказок; запущен один ярус
/// A0 — сто пятьдесят фраз, по тридцать на каждое из пяти созвездий. Прежде
/// было 1000 и по двадцать: корпус расширен и заодно потерял многоточия, и
/// это видно здесь дважды — числами в проверках и самодельным корпусом, на
/// котором проверяется запрет двух верных ответов (материала для него в
/// ассете больше нет).
///
/// **Родной язык здесь `uk`, и это не вкус.** Переводы фраз живут в
/// `content/lang/<код>.yaml`, и есть они только у украинского: `ru` и `en`
/// лежат черновиками, где секции `phrases` нет вовсе. Со `ru` загрузчик
/// собрал бы пустую сессию — каждый круг отказался бы собираться из-за
/// отсутствия перевода, — и сквозной тест проверял бы пустоту.
///
/// ── Что этот файл охранял и чего больше нет ────────────────────────────────
///
/// Всё удалённое ниже держалось на вставке слов в предложение — пропуски,
/// плитки, порядок сборки. Механики нет, и вместе с ней нет `slotCount`,
/// `answers`, `assembled`, `accepted`, `phrase_slots`, `phrase_orders`.
///
/// * «уровень закрывается фразовым забегом» — охранял пятый забег в конце
///   уровня: `fillGaps`, потом `buildPhrase`, обе на одном предложении, и
///   слова с фразами не мешались. Фраза стала единицей изучения, и закрывать
///   уровень фразами отдельно значило бы закрывать его тем же, чем он и шёл.
///   Перенесён на новое правило: последний забег — последний этап.
/// * «собранная фраза совпадает с тем, что будет произнесено» — охранял
///   `assembled`: игрок, закрыв последний пропуск, обязан услышать ту фразу,
///   которую собрал. Собирать нечего; перенесён на то, что от обещания
///   осталось, — озвучка ответа это сама фраза, а не её перевод.
/// * «глубина пропусков»: «пропусков ровно столько, сколько попросили», «ноль
///   означает все слова, а не ни одного», «слово, которому учит фраза,
///   вынимается всегда». Шкалы глубины нет: `SessionBalance.phraseGapsMin`,
///   `phraseGapsAll` и `QuestionBuilder.buildPhrase` удалены.
/// * «знаки препинания»: «знак остаётся в предложении, а на плитке — слово» и
///   «дефис остаётся частью слова, а запятая при нём — нет». Плитки нет,
///   фраза показывается целиком, и делить её на слово и знак больше не надо.
///   Сплошной проход по корпусу, которым первый из них это проверял,
///   перенесён — им теперь проверяется, что каждая фраза яруса собирается в
///   круг.
/// * «частичный круг оставляет хоть одно слово на месте» — охранял, что два
///   закрывающих круга на одном предложении отличаются глубиной: сперва часть
///   слов, потом все. Кругов на предложение теперь один, и глубины у него нет.
/// * «заявленный порядок слов принимается и забегом, и калибровкой
///   одинаково» — охранял `phrase_orders`: у фразы был список верных порядков
///   сборки, и две реализации сверки расходились. Порядок слов больше не
///   спрашивается: фраза заучивается целиком.
/// * «многослотовая фраза: каждый слот знает только свой вариант» — охранял
///   `answers` по слотам и то, что верным признаётся вариант с тем же
///   **текстом**, а не только с тем же номером. Слотов нет, ответ один;
///   правило про текст живёт в `CircleQuestion.isCorrectOption`, и на
///   настоящем контенте его сторожит «у каждого круга есть центр, шесть
///   вариантов и один верный ответ»: принятым обязан оказаться ровно один.
/// * «повторённое слово во фразе получает свой вариант пула» — охранял, что
///   два пропуска с одним и тем же словом не спорят за один вариант.
///   Пропусков нет.
/// * «вид дистракторов приходит с кругом, а не выводится из механики» и
///   «добор соседями на больших созвездиях: соседи не обрезаются запросом» —
///   охраняли рукописные дистракторы и добор по созвездию.
///   `distractors`, `concepts` и `lexemes` из схемы удалены: вокруг фразы
///   стоят другие **фразы**, и берутся они из пула, который приносит
///   загрузчик.
/// * «набор неверных вариантов меняется от круга к кругу» — охранял то же
///   самое с другой стороны и был перевёрнут в «состав пяти других задаёт пул,
///   а не зерно»: пул приходил одним упорядоченным списком, сборщик брал первые
///   пять, и состав обязан был совпадать при любом зерне. Перевёрнут ещё раз и
///   стал «зерно тасует внутри самых похожих, а не по всему пулу»: варианты
///   подбираются по совпадению слов с ответом, и жёсткий максимум давал бы одну
///   и ту же пятёрку из забега в забег — игрок запоминал бы расположение, а не
///   фразы. Разнообразие вернулось, но заперто среди похожих: тест требует и
///   того, что состав меняется, и того, что каждый вариант порогом разрешён.
/// * «вокруг ответа стоят самые похожие фразы, а не случайные» — охранял окно
///   `ScoreBalance.confusableWindow = 12`: каждый вариант обязан быть не хуже
///   двенадцатого кандидата по похожести. Счётчик про похожесть не знал
///   ничего и молчал с двух концов — пока пройденных меньше дюжины, окно
///   равнялось всей полосе; на длинных фразах дюжина вычерпывалась до
///   кандидатов с одним общим служебным словом. Заменён порогом от лучшего
///   кандидата ([ScoreBalance.confusableShare], [ScoreBalance.confusableFloor])
///   и переписан в «каждый вариант либо похож по порогу, либо стоит сразу за
///   похожими»; рядом встали два теста, которые меряют само улучшение
///   числом, — по одному на каждый конец, которым окно ломалось: «порог даёт
///   круг похожее, чем окно на дюжину» на полном пуле и «на полосе из дюжины
///   известных окно не значило ничего» на короткой полосе.
/// * «на полосе из дюжины известных окно не значило ничего» — сторожил силу
///   правила там, где она и так есть (полоса 12, 2.14×), а полосу, с которой
///   игрок выходит из онбординга, не проверял вовсе. Обещание «варианты похожи
///   по словам» читалось поэтому как безусловное, хотя на полосе из пяти-шести
///   фраз сила правила равна единице **по построению**: пять кандидатов на
///   пять мест. Переписан в «на полосе из шести правилу не из чего выбирать,
///   на полосе из дюжины есть» — утверждаются оба конца, — и рядом встал
///   «после онбординга полоса — 5–6 фраз, и правило на ней почти молчит»: тот
///   же факт на настоящей раскладке первого уровня.
/// * «порог сбивает шум с 42–53 % до 34–44 %» не охранялось ничем, и охранять
///   было нечего: шумом назывался кандидат с одним общим **служебным** словом,
///   а определения служебного слова в проекте нет. Число заменено долей
///   потолка в той же мере, которой пользуется код, и встал тест «выбранное
///   берёт свою долю потолка».
/// * «шаблон не встаёт рядом с фразой, которая его заполняет» — охранял запрет
///   двух верных ответов, но проверял его на языке вариантов и в `pickTarget`,
///   то есть ровно там, где двусмысленности нет. Дефект он поэтому пропускал:
///   двусмысленность создаёт язык **центра**. Перенесён на «шаблон в центре не
///   встаёт рядом с фразой, которая его заполняет» плюс обратная сторона —
///   «в обратную сторону шаблон законный вариант, а не второй ответ», — и
///   вместе с третьим, «Де ...?»: девять законных ответов в круг не
///   попадают», переставлен с ассета на самодельный корпус: многоточий в
///   ассете больше нет, а на фразах без дыр все три зеленели бы и до правки.
/// * «обе фразовые механики стоят на одном предложении» — фразовых механик
///   как отдельного вида нет: фразовые все три.
/// * «заход расширяет круг и на словах, и на фразе» — надбавки вариантов от
///   захода нет: `ClimbBalance.levelsPerExtraOption` и `extraOptionsMax`
///   удалены, круг всегда шестивариантный. Обратная сторона той же ошибки
///   («знакомство остаётся показом на любом уровне захода») перенесена на
///   новое правило: заход ширины круга не трогает.
/// * «короткое предложение не выбирается вовсе» — порога длины фразы нет
///   (`phraseMinWords` удалён), и отбраковывать по нему нечего. Перенесён на
///   то, из-за чего круг может не собраться теперь: нет перевода или в пуле
///   меньше пяти других.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase userDb;
  late ContentDatabase content;
  late QuestionBuilder builder;
  late SessionLoader loader;

  final now = DateTime.utc(2026, 5, 1, 9);

  setUp(() {
    support = Directory.systemTemp.createTempSync('lumen_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? support.path
          : null,
    );

    userDb = AppDatabase(NativeDatabase.memory());
    content = ContentDatabase.forLanguage('de');
    builder = QuestionBuilder(
      content: content,
      targetLang: 'de',
      nativeLang: 'uk',
      random: Random(1),
    );
    loader = SessionLoader(
      words: WordStateRepository(userDb),
      builder: builder,
      tier: Tier.a0,
      freePace: false,
      capabilities: const SessionCapabilities(),
      random: Random(1),
    );
  });

  tearDown(() async {
    await content.close();
    await userDb.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    support.deleteSync(recursive: true);
  });

  /// Фразы запущенного яруса: `id → предложение на изучаемом`.
  Future<Map<String, String>> targetTexts() async => {
        for (final row in await content.phrasesUpTo(Tier.a0))
          row.id: row.sentence,
      };

  /// Их же переводы на родной: `id → предложение на родном`.
  Future<Map<String, String>> nativeTexts() async => content.translationsFor(
        (await content.phrasesUpTo(Tier.a0)).map((row) => row.id),
        'uk',
      );

  /// Тексты вариантов круга на том языке, на котором их показывает механика.
  Map<String, String> shownIn(
    GameMode mode, {
    required Map<String, String> target,
    required Map<String, String> native,
  }) =>
      mode.optionsInTargetLanguage ? target : native;

  group('первый уровень', () {
    test('собирается из настоящего контента', () async {
      final session = await loader.level(now);

      expect(session.isEmpty, isFalse);
      // У нового игрока повторять нечего — только новые фразы.
      expect(session.reviews, 0);
      expect(session.newWords, 6);
    });

    test('последний забег уровня — последний его этап', () async {
      final session = await loader.level(now);

      // Раньше уровень закрывался пятым забегом на фразах. Теперь фраза — это
      // и есть материал каждого круга, и отдельный фразовый забег стал бы
      // повтором уровня самим собой. Забеги остались ровно этапами
      // планировщика, и «напоминания» у нового игрока нет: повторять нечего.
      expect(session.runs.map((r) => r.stage), [
        LevelStage.introduction,
        LevelStage.consolidation,
        LevelStage.check,
      ]);
    });

    test('у каждого круга есть центр, шесть вариантов и один верный ответ',
        () async {
      final session = await loader.level(now);

      // Раньше здесь стояла оговорка «кроме кругов набора»: у поля ввода
      // вариантов не было вовсе. Потом добавилась вторая — «кроме фразовых»:
      // там вариантов было столько, сколько пропусков. Обеих механик нет, и
      // оговорок нет: круг во всех трёх механиках устроен одинаково.
      for (final q in session.questions) {
        expect(q.itemId, isNotEmpty);
        expect(q.options, hasLength(ScoreBalance.optionsPerCircle),
            reason: '${q.itemId}: круг не на шесть вариантов');
        expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1),
            reason: '${q.itemId}: верный вариант указывает вне круга');
        expect(q.answer, isNotEmpty, reason: '${q.itemId}: ответ без текста');

        // Принятым обязан оказаться ровно один вариант. Проверка не про
        // `isCorrectOption`, а про контент: круг принимает вариант с тем же
        // текстом, что у ответа, — и если две фразы яруса переведены одной
        // строкой, у круга окажется два верных ответа, а игрок получит
        // «неверно» на верном.
        final accepted = [
          for (var i = 0; i < q.options.length; i++)
            if (q.isCorrectOption(i)) i,
        ];
        expect(accepted, [q.answerIndex],
            reason: '${q.itemId}: принятых вариантов не один — $accepted');

        // Центр круга — текст или звук. Пустой центр без звука означал бы
        // круг без задания.
        if (q.prompt.isEmpty) {
          expect(q.mode.needsAudio, isTrue,
              reason: '${q.itemId}: пустой центр в механике ${q.mode.name}');
          expect(q.promptSpeech, isNotNull, reason: q.itemId);
        }

        // Озвучка ответа есть всегда: за пять минут игрок слышит полсотни
        // образцов произношения, ничего для этого не делая.
        expect(q.answerSpeech, isNotNull, reason: q.itemId);
      }
    });

    test('вариантов шесть и на знакомстве тоже', () async {
      final session = await loader.level(now);

      // Прежде знакомство было исключением из этого правила: один вариант,
      // соединил и услышал. Теперь оно устроено методом исключения — вокруг
      // новой фразы стоят пять уже известных, — и неполный круг ломал бы
      // ровно это: при одном варианте исключать нечего вовсе.
      final introductions = session.questions.where((q) => q.isNew).toList();
      expect(introductions, isNotEmpty);
      for (final q in introductions) {
        expect(q.options, hasLength(ScoreBalance.optionsPerCircle),
            reason: '${q.itemId}: показ с неполным кругом');
      }
    });

    test('варианты в круге не повторяются', () async {
      final session = await loader.level(now);

      // Два одинаковых варианта — это круг с двумя верными ответами, и
      // «неверно» на верном ответе. Раньше отсюда исключалась сборка
      // предложения: слово могло повторяться в самом предложении, и две
      // одинаковые плитки там были текстом, а не поломкой. Исключать больше
      // некого — вокруг стоят целые фразы.
      for (final q in session.questions) {
        final lowered = q.options.map((o) => o.toLowerCase()).toList();
        expect(lowered.toSet().length, lowered.length,
            reason: '${q.itemId}: дубли среди вариантов');
      }
    });

    test('первый показ новой фразы — понимание, центр на изучаемом', () async {
      final session = await loader.level(now);
      final first = session.questions.firstWhere((q) => q.isNew);

      expect(first.mode, GameMode.pickNative);
      // Понимание: в центре немецкая фраза, вокруг украинские переводы.
      final row = await content.phrase(first.itemId);
      expect(first.prompt, row!.sentence);
      expect(first.answer, await content.translation(first.itemId, 'uk'));
      // Перевод вокруг и есть ответ — показывать его второй раз незачем.
      expect(first.translation, isNull);
    });

    test('на первом уровне известного нет, и круг всё равно собирается',
        () async {
      final session = await loader.level(now);

      // Знакомство идёт исключением, но у нового игрока не знакомо ничего, и
      // исключать не из чего. Это не поломка: `_optionPool` добирает пул
      // остальными фразами яруса, и первый круг честно оказывается выбором из
      // шести незнакомых. Проверяется поэтому не «вокруг стоят известные», а
      // доставка: все обещанные новые фразы на месте, и каждая пришла с
      // полным кругом из настоящего контента.
      final introduced =
          session.questions.where((q) => q.isNew).map((q) => q.itemId).toSet();
      expect(introduced, hasLength(session.newWords));

      final native = await nativeTexts();
      for (final q in session.questions.where((q) => q.isNew)) {
        expect(q.options, hasLength(ScoreBalance.optionsPerCircle),
            reason: q.itemId);
        expect(q.options.every(native.values.contains), isTrue,
            reason: '${q.itemId}: в круге не перевод фразы яруса — '
                '${q.options}');
        expect(q.answer, native[q.itemId], reason: q.itemId);
      }
    });

    test('озвучка ответа — сама фраза, а не её перевод', () async {
      final session = await loader.level(now);
      final target = await targetTexts();

      // То, что игрок слышит, соединив верно, обязано быть той же фразой,
      // которую круг про неё и спрашивал. В `pickNative` и `listenNative`
      // ответ выбирается на родном языке — если озвучить выбранное, игрок
      // услышит украинскую строчку вместо немецкой и выучит не то.
      for (final q in session.questions) {
        expect(q.answerSpeech, target[q.itemId], reason: q.itemId);
      }
    });

    test('внутри забега фраза не повторяется', () async {
      final session = await loader.level(now);

      // Два круга на одной фразе внутри забега проверяли бы буфер
      // кратковременной памяти, а не повторение. Между забегами повтор
      // законен: там лежит экран итогов и сброс комбо — ровно затем, чтобы
      // повторение было повторением.
      for (final run in session.runs) {
        final ids = run.questions.map((q) => q.itemId).toList();
        expect(ids.toSet(), hasLength(ids.length),
            reason: '${run.stage.name}: $ids');
      }
    });
  });

  group('знакомство методом исключения', () {
    /// Шесть фраз, засеянных как уже известные — по одной из созвездий A0.
    ///
    /// Взяты из разных тем нарочно: круг собирается через весь ярус, а не
    /// внутри темы, и подмена известной фразы соседкой по теме была бы не
    /// видна, если бы все шесть лежали в одной.
    const known = [
      'about_me_a0_01',
      'first_contact_a0_01',
      'needs_help_a0_01',
      'place_time_price_a0_01',
      'understanding_a0_01',
      'about_me_a0_02',
    ];

    /// Игрок, который уже знает эти фразы, садится за уровень.
    ///
    /// Яркость засева — 55 lm: выше порога
    /// [ScoreBalance.knownForEliminationLm], то есть полоса «узнаёте, но не
    /// вспоминаете сами». Именно её загрузчик считает достаточной, чтобы
    /// фраза встала вокруг новой.
    Future<LoadedSession> levelKnowing(List<String> ids) async {
      await WordStateRepository(userDb).seed(
        confirmed: {for (final id in ids) id: Tier.a0},
        lumens: 55,
        now: now,
      );
      return loader.level(now);
    }

    test('вокруг фразы стоят те, что игрок уже знает', () async {
      final session = await levelKnowing(known);
      final target = await targetTexts();
      final native = await nativeTexts();

      // Это и есть правило пула: `_optionPool` кладёт известное впереди, а
      // сборщик берёт **первые** пять. Перемешать пул до отбора значило бы
      // ставить вокруг новой фразы случайные — то есть сломать исключение,
      // на котором держится знакомство.
      for (final q in session.questions) {
        final shown = shownIn(q.mode, target: target, native: native);
        final others = q.options.toSet().difference({q.answer});
        expect(others, hasLength(ScoreBalance.optionsPerCircle - 1),
            reason: q.itemId);

        final fromKnown = {
          for (final id in known)
            if (id != q.itemId) shown[id]!,
        };
        expect(fromKnown, containsAll(others),
            reason: '${q.itemId} (${q.mode.name}): вокруг стоит незнакомое — '
                '${others.difference(fromKnown)}');
      }
    });

    test('знакомство идёт среди пяти известных', () async {
      // Известных ровно пять: тогда «пять известных вокруг» проверяется на
      // равенство, а не на вложенность, и подмена одного из них случайной
      // фразой яруса будет видна.
      final session = await levelKnowing(known.take(5).toList());
      final native = await nativeTexts();
      final around = {for (final id in known.take(5)) native[id]!};

      final introductions = session.questions.where((q) => q.isNew).toList();
      expect(introductions, isNotEmpty);
      for (final q in introductions) {
        // Новая фраза известной быть не может: засеянные в новые не идут.
        expect(known.take(5), isNot(contains(q.itemId)));
        expect(q.mode, GameMode.pickNative);
        expect(q.options.toSet().difference({q.answer}), around,
            reason: q.itemId);
      }
    });

    test('просто виденные фразы идут раньше невиданных', () async {
      // Правил про варианты два, и они не совпадают. Знакомство исключением
      // требует, чтобы вокруг новой фразы стояли **известные**: не узнав пять,
      // шестую не исключишь. Правило владельца требует, чтобы варианты были
      // уже **пройденными**: круг из незнакомого не спрашивает, а гадает.
      // Пройденное шире известного, и загрузчик поэтому передаёт две метки.
      //
      // Здесь проверяется вторая. Восемь фраз засеяны яркостью 10 lm — это
      // ниже [ScoreBalance.knownForEliminationLm], то есть «видел и забыл»:
      // известными они не считаются, но пройденными являются. Вокруг новой
      // фразы обязаны встать именно они, а не свежие фразы яруса — даже те,
      // что похожи на ответ сильнее.
      const dim = [
        'first_contact_a0_02',
        'first_contact_a0_03',
        'first_contact_a0_04',
        'needs_help_a0_03',
        'needs_help_a0_04',
        'place_time_price_a0_03',
        'place_time_price_a0_04',
        'understanding_a0_03',
      ];
      await WordStateRepository(userDb).seed(
        confirmed: {for (final id in dim) id: Tier.a0},
        lumens: 10,
        now: now,
      );

      final session = await loader.level(now);
      final target = await targetTexts();
      final native = await nativeTexts();

      final introductions = session.questions.where((q) => q.isNew).toList();
      expect(introductions, isNotEmpty);
      for (final q in introductions) {
        final shown = shownIn(q.mode, target: target, native: native);
        final others = q.options.toSet().difference({q.answer});
        final fromDim = {
          for (final id in dim)
            if (id != q.itemId) shown[id]!,
        };
        expect(fromDim, containsAll(others),
            reason: '${q.itemId} (${q.mode.name}): вокруг стоит непройденное — '
                '${others.difference(fromDim)}');
      }
    });
  });

  group('мера похожести', () {
    test('нормализация: регистр, знаки и многоточие', () {
      // Многоточие — не знак, а место под своё слово: слова оно не даёт, но
      // след оставляет, и по этому следу считается «шаблон заполняется
      // ответом».
      //
      // В нынешнем корпусе многоточий ноль (в прежней тысяче было 239), и
      // строки здесь набраны от руки — как и весь разбор дыр, который
      // оставлен дремлющим: форма законна и вернётся с первой же правкой
      // листа контента. Проверка на ноль совпадений стоит дешевле, чем
      // восстановление разбора вместе с забытым правилом про два верных
      // ответа.
      expect(ShownPhrase.of('Ich heiße ...').key, 'ich heiße');
      expect(ShownPhrase.of('Ich heiße ...').hasHole, isTrue);
      expect(ShownPhrase.of('Wie heißt du?').key, 'wie heißt du');
      expect(ShownPhrase.of('Wie heißt du?').hasHole, isFalse);
      // Регистр и знаки сравнению не мешают, а «heiße» не разваливается на
      // «hei» и «e»: класс слова задан через `\p{L}`, а не через `\w`.
      expect(ShownPhrase.of('DANKE, gern!').key, 'danke gern');
      expect(ShownPhrase.of('Мені ... років.').words, ['мені', 'років']);
      // Апостроф и дефис внутри слова — часть слова, по краям — знак.
      expect(ShownPhrase.of("L'acqua, E-Mail — так.").words,
          ["l'acqua", 'e-mail', 'так']);
    });

    test('Жаккар не даёт длинной фразе побеждать длиной', () {
      final answer = ShownPhrase.of('Ich weiß nicht.');
      // Общих слов у обеих ровно два — «ich» и «nicht». Простое пересечение
      // множеств не отличило бы их вовсе, а на длинных фразах повело бы прямо
      // в обратную сторону: у фразы из двенадцати слов общих слов с чем угодно
      // больше, чем у фразы из трёх, и вокруг короткого ответа встали бы пять
      // длинных — то есть пять заведомо неверных. Жаккар делит на
      // объединение, и ближе оказывается та фраза, у которой из общих слов
      // состоит большая часть.
      final tight = ShownPhrase.of('Ich verstehe nicht.');
      final loose = ShownPhrase.of('Ich bin nicht sicher.');
      expect(answer.overlapWith(tight), greaterThan(answer.overlapWith(loose)));

      // А фраза, у которой общее только «ich», дальше обеих.
      final far = ShownPhrase.of(
          'Ich möchte wissen, wie meine Daten verwendet werden.');
      expect(answer.overlapWith(loose), greaterThan(answer.overlapWith(far)));
    });

    test('совпадение начала весит больше совпадения слов вразброс', () {
      // Пара собрана нарочно: у обоих кандидатов те же два общих слова и тот
      // же Жаккар, и различает их только порядок. В корпусе такой пары не
      // нашлось, а правило проверить надо — без надбавки за начало «Ich habe
      // Hunger.» ничем не отличалось бы от перестановки тех же слов, хотя
      // читается как ответ до последнего слова.
      final answer = ShownPhrase.of('Ich habe Durst.');
      final sameStart = ShownPhrase.of('Ich habe Hunger.');
      final sameWords = ShownPhrase.of('Wasser habe ich.');
      expect(answer.overlapWith(sameStart),
          greaterThan(answer.overlapWith(sameWords)));
      expect(answer.overlapWith(sameStart) - answer.overlapWith(sameWords),
          closeTo(ScoreBalance.confusablePrefixWeight * 2 / 3, 1e-9));
    });

    test('центр описывает и кандидата — значит верны оба', () {
      final template = ShownPhrase.of('Ich brauche ...');
      final filled = ShownPhrase.of('Ich brauche Hilfe.');

      // Шаблон в центре описывает и заполненную фразу: многоточие это место
      // под своё слово, «Hilfe» его заполняет, и игрок, ткнувший в перевод
      // заполненной фразы, прав ровно так же.
      expect(template.describes(filled), isTrue);

      // **Направленно.** Обратное — центр конкретен, кандидат шаблон — не
      // двусмысленность, а самый трудный законный вариант: на «Ich brauche
      // Hilfe.» перевод с незаполненной дырой не отвечает. Здесь стоял
      // симметричный `isSameAnswerAs`, и он выбрасывал из круга именно эти
      // законные варианты, а двусмысленные оставлял — потому что считался на
      // языке вариантов, а не на языке центра.
      expect(filled.describes(template), isFalse);

      // Тот же текст с точностью до регистра и знаков — в обе стороны: это
      // уже не описание, а совпадение.
      expect(ShownPhrase.of('До завтра!').describes(ShownPhrase.of('до завтра')),
          isTrue);
      expect(ShownPhrase.of('до завтра').describes(ShownPhrase.of('До завтра!')),
          isTrue);

      // Худший случай прежнего корпуса — на языке центра. «Де ...?»
      // описывало девять фраз пула, и каждая из них законный ответ на этот
      // центр. В нынешнем корпусе многоточий нет, и пара здесь собрана
      // вручную; тот же случай целиком, вместе со сборщиком, проверяется
      // ниже — «Де ...?»: девять законных ответов в круг не попадают».
      expect(ShownPhrase.of('Де ...?').describes(ShownPhrase.of('Де ти живеш?')),
          isTrue);

      // Дыра в середине заполняется одним словом...
      final middle = ShownPhrase.of('Ich bin gegen ... allergisch.');
      expect(
          middle.describes(ShownPhrase.of('Ich bin gegen Nüsse allergisch.')),
          isTrue);
      // ...но хвост шаблона обязан стоять в конце: без этого «... allergisch.»
      // заполнялся бы любой фразой, где это слово просто встречается.
      expect(
          middle.describes(
              ShownPhrase.of('Ich bin gegen Nüsse allergisch geworden.')),
          isFalse);

      // Начало шаблона обязано стоять в начале — по той же причине.
      expect(
          ShownPhrase.of('Wo ist ...?').describes(ShownPhrase.of('Ist das richtig?')),
          isFalse);

      // Слова, похожие, но не те: «потрібно» и «потрібна» — разные формы, и
      // одна фраза другую не описывает. Такие пары как раз и должны стоять
      // рядом в круге — и именно на этой паре молчала проверка, стоявшая на
      // языке вариантов: по-украински двусмысленности нет, а по-немецки
      // («Ich brauche ...» против «Ich brauche Hilfe.») она есть.
      expect(
          ShownPhrase.of('Мені потрібно ...')
              .describes(ShownPhrase.of('Мені потрібна допомога.')),
          isFalse);

      // Шаблон из одного многоточия заполнялся бы чем угодно и вымел бы из
      // круга весь пул. Он не шаблон.
      expect(ShownPhrase.of('...').describes(ShownPhrase.of('Hallo!')), isFalse);
    });

    test('одинаковый показанный текст — это одна плитка, а не две', () {
      // Вторая проверка сборщика и второй язык: одинаковый **показанный**
      // текст круг принял бы обоими нажатиями. Сравнивается ключ — слова без
      // регистра и знаков, — потому что «До завтра!» и «до завтра» это одна
      // плитка, набранная дважды.
      expect(ShownPhrase.of('Danke!').key, ShownPhrase.of('DANKE.').key);
      expect(ShownPhrase.of('Danke!').key,
          isNot(ShownPhrase.of('Danke schön!').key));
    });
  });

  group('варианты подбираются по совпадению слов', () {
    /// Кандидаты ответа с их похожестью, по убыванию — ровно то и в том
    /// порядке, что считает сборщик.
    ///
    /// Негодные выброшены заранее, иначе порог считался бы по кандидатам,
    /// которых сборщику ставить и не разрешено. Негодность двух родов, и у
    /// каждого свой язык: второй верный ответ — на языке **центра**,
    /// одинаковая плитка — на языке **вариантов**.
    ///
    /// Ничьи разрешаются порядком пула — так же, как у сборщика: `List.sort` в
    /// Dart не стабилен, и без явного разрешения два одинаково похожих
    /// кандидата вставали бы по-разному от запуска к запуску.
    List<({String id, double overlap})> ranked(
      String itemId, {
      required Map<String, ShownPhrase> shown,
      required Map<String, ShownPhrase> centre,
      required List<String> pool,
    }) {
      final answer = shown[itemId]!;
      final centreAnswer = centre[itemId]!;
      final out = <({String id, double overlap, int order})>[];
      for (var order = 0; order < pool.length; order++) {
        final id = pool[order];
        if (id == itemId) continue;
        if (centreAnswer.describes(centre[id]!)) continue;
        if (answer.key == shown[id]!.key) continue;
        out.add((
          id: id,
          overlap: answer.overlapWith(shown[id]!),
          order: order,
        ));
      }
      out.sort((a, b) {
        final byOverlap = b.overlap.compareTo(a.overlap);
        return byOverlap != 0 ? byOverlap : a.order.compareTo(b.order);
      });
      return [for (final c in out) (id: c.id, overlap: c.overlap)];
    }

    /// Порог похожести: [ScoreBalance.confusableShare] от лучшего, но не ниже
    /// [ScoreBalance.confusableFloor]. Если и лучший ниже дна, похожих не
    /// существует и порога нет.
    double barOf(List<({String id, double overlap})> candidates) {
      final best = candidates.map((c) => c.overlap).reduce(max);
      if (best < ScoreBalance.confusableFloor) return 0;
      return max(ScoreBalance.confusableFloor,
          best * ScoreBalance.confusableShare);
    }

    /// Кому разрешено стоять в круге: похожие по порогу, а если их меньше
    /// пяти — ещё столько же следующих по похожести, на добор.
    ///
    /// Это и есть обещание сборщика целиком. «Пятёрка из дюжины самых
    /// похожих» больше не сказано нигде: дюжина была счётчиком и молчала,
    /// пока пройденных меньше дюжины.
    Set<String> allowed(List<({String id, double overlap})> candidates) {
      final need = ScoreBalance.optionsPerCircle - 1;
      final bar = barOf(candidates);
      final similar = candidates.where((c) => c.overlap >= bar).toList();
      return {
        for (final c in similar) c.id,
        if (similar.length < need)
          for (final c in candidates.skip(similar.length).take(need)) c.id,
      };
    }

    /// Весь корпус, а не только запущенный ярус: пул решает загрузчик, а
    /// сборщику можно передать любой.
    ///
    /// Пул здесь **нарочно** полный. На одном A0 половина фраз не имеет в
    /// ярусе ни одной соседки хотя бы с одним общим словом — порог окна
    /// оказывается нулевым, и тест зеленел бы при любом отборе, в том числе
    /// при случайном. На полутора тысячах фраз порог ненулевой у 95 % кругов
    /// A0, и правило начинает охраняться.
    Future<List<String>> wholeCorpus() async =>
        [for (final row in await content.phrasesUpTo(Tier.values.last)) row.id];

    /// Тексты всего корпуса на языке изучения и на родном.
    ///
    /// Переводы спрашиваются пачками: полторы тысячи идентификаторов в одном
    /// `IN (...)` упираются в предел параметров SQLite.
    Future<Map<String, String>> corpusTexts({required bool onTarget}) async {
      final rows = await content.phrasesUpTo(Tier.values.last);
      if (onTarget) return {for (final row in rows) row.id: row.sentence};
      final texts = <String, String>{};
      for (var i = 0; i < rows.length; i += 400) {
        final chunk = rows.sublist(i, min(i + 400, rows.length));
        texts.addAll(
            await content.translationsFor(chunk.map((r) => r.id), 'uk'));
      }
      return texts;
    }

    Map<String, ShownPhrase> shapesOf(Map<String, String> texts) =>
        {for (final e in texts.entries) e.key: ShownPhrase.of(e.value)};

    /// Обратная карта «показанный текст → идентификатор».
    ///
    /// Однозначна: одинаковых текстов в корпусе нет ни в одном языке — ноль
    /// пар на 1500 фразах. Ровно поэтому запрет «двух одинаковых плиток»
    /// нельзя проверить на настоящем контенте, и проверяется он там, где
    /// живёт, — на ключе [ShownPhrase.key].
    Map<String, String> idsByText(Map<String, String> texts) =>
        {for (final e in texts.entries) e.value: e.key};

    test('каждый вариант либо похож по порогу, либо стоит сразу за похожими',
        () async {
      // Правило владельца: варианты это фразы, которые игрок уже проходил и
      // которые по словам максимально совпадают с верным ответом. Смысл в
      // том, что круг из шести непохожих фраз решается по одному знакомому
      // слову, и игрок учится узнавать не фразу, а случайную примету.
      //
      // Обещание при этом стало другим, и это исправление. Прежде здесь
      // проверялось «каждый вариант не хуже двенадцатого кандидата»: окно
      // отсчитывалось счётчиком, а счётчик про похожесть не знает ничего.
      // Пока пройденных меньше дюжины, окно равнялось всей полосе и правило не
      // влияло ни на что; на длинных фразах дюжина вычерпывалась до
      // кандидатов с одним общим служебным словом. Теперь похожих отбирает
      // порог от лучшего в полосе, и обещание проверяемое: вариант либо похож
      // по порогу, либо стоит сразу за похожими — там, где похожих не
      // набралось пяти.
      final pool = await wholeCorpus();
      final shapes = {
        true: shapesOf(await corpusTexts(onTarget: true)),
        false: shapesOf(await corpusTexts(onTarget: false)),
      };
      final byText = {
        true: idsByText(await corpusTexts(onTarget: true)),
        false: idsByText(await corpusTexts(onTarget: false)),
      };
      final rows = await content.phrasesUpTo(Tier.a0);

      var withBar = 0;
      var toppedUp = 0;
      for (final row in rows) {
        for (final mode in GameMode.values) {
          final onTarget = mode.optionsInTargetLanguage;
          final question = await builder.build(
            PlannedCircle(
              itemId: row.id,
              mode: mode,
              isNew: false,
              lumens: 40,
            ),
            pool: pool,
          );
          expect(question, isNotNull, reason: '${row.id} (${mode.name})');

          final candidates = ranked(
            row.id,
            shown: shapes[onTarget]!,
            centre: shapes[!onTarget]!,
            pool: pool,
          );
          final bar = barOf(candidates);
          final may = allowed(candidates);
          final similar = candidates.where((c) => c.overlap >= bar).length;
          if (bar > 0) withBar++;
          if (similar < ScoreBalance.optionsPerCircle - 1) toppedUp++;

          for (var i = 0; i < question!.options.length; i++) {
            if (i == question.answerIndex) continue;
            final id = byText[onTarget]![question.options[i]]!;
            expect(may, contains(id),
                reason: '${row.id} (${mode.name}): «${question.options[i]}» '
                    'похож на ${candidates.firstWhere((c) => c.id == id).overlap} '
                    'при пороге $bar, и в добор ($similar похожих) не входит');
          }
        }
      }

      // Порог бывает и нулевым: у фразы может не оказаться ни одной соседки
      // хотя бы с одним общим словом, и тогда правило честно ничего не
      // требует. Но если таких кругов окажется большинство, тест перестанет
      // что-либо охранять, и знать об этом надо сразу.
      final circles = rows.length * GameMode.values.length;
      expect(withBar, greaterThan(circles * 2 / 3),
          reason: 'порог почти всюду нулевой — тест зеленеет и при случайном '
              'отборе');
      // И наоборот: добор обязан быть редкостью, а не обычным делом. По
      // корпусу похожих меньше пяти примерно в каждом четвёртом круге: 103
      // круга из 450, а порог ненулевой в 426 из них.
      expect(toppedUp, lessThan(circles / 3),
          reason: 'похожих почти всюду меньше пяти — порог слишком высок');
    });

    test('порог даёт круг похожее, чем окно на дюжину, которое здесь стояло',
        () async {
      // Само исправление проверяется числом, иначе «правило стало сильнее»
      // остаётся словами. Тестов на это два, потому что окно ломалось с двух
      // концов, и числа у концов разные: на полном пуле разрыв 3–4 %, на
      // полосе из дюжины известных — вдвое.
      //
      // Сравнивается **выход настоящего сборщика** с ожиданием старого
      // правила: равномерная жеребьёвка пятёрки из дюжины самых похожих даёт
      // в среднем похожесть этой дюжины. Двенадцать — снятое число
      // (`ScoreBalance.confusableWindow`), и стоит оно здесь литералом:
      // правила больше нет, а история обязана остаться проверяемой.
      //
      // **Запас двухпроцентный, и он тут не для красоты.** С окном на месте
      // обе величины равны **по построению** — жеребьёвка из дюжины и есть
      // средняя дюжины, — и прежний тест, строгое «>» без запаса, падал на
      // разнице в седьмом знаке: 0.234898 против 0.234905. Такую разницу
      // решает шум выборки, и от другого зерна тест зазеленел бы прямо на
      // дефекте. Запас требует не «чуть больше», а «больше на измеримую
      // величину», и снятое правило проваливает его на все два процента.
      //
      // Измерено при зерне сборщика 1 (`setUp`, поэтому число
      // воспроизводимо): 0.4214 против 0.4078 на A0 (+3.3 %) и 0.2436 против
      // 0.2349 на B2 (+3.7 %). Запаса остаётся 1.3–1.7 процентных пункта — на
      // полном пуле разрыв и правда невелик, потому что среди полутора тысяч
      // фраз первая дюжина сама почти вся похожа. Настоящую цену правила
      // видно на короткой полосе, и это следующий тест.
      //
      // Ярусы взяты крайние: на A0 фразы по три-четыре слова и дюжина была
      // неплоха, на B2 по девять — и там дюжина вычерпывалась до кандидатов с
      // одним общим служебным словом.
      final pool = await wholeCorpus();
      final shapes = {
        true: shapesOf(await corpusTexts(onTarget: true)),
        false: shapesOf(await corpusTexts(onTarget: false)),
      };

      for (final tier in [Tier.a0, Tier.b2]) {
        final rows = (await content.phrasesUpTo(Tier.values.last))
            .where((row) => row.tier == tier.code)
            .toList();
        expect(rows, isNotEmpty, reason: 'ярус ${tier.code} пуст');

        var chosen = 0.0;
        var picks = 0;
        var window = 0.0;
        var circles = 0;
        for (final row in rows) {
          for (final mode in GameMode.values) {
            final onTarget = mode.optionsInTargetLanguage;
            final shown = shapes[onTarget]!;
            final answer = shown[row.id]!;
            final candidates = ranked(
              row.id,
              shown: shown,
              centre: shapes[!onTarget]!,
              pool: pool,
            );
            final dozen = candidates.take(12).toList();
            window +=
                dozen.fold<double>(0, (a, c) => a + c.overlap) / dozen.length;
            circles++;

            final question = await builder.build(
              PlannedCircle(
                itemId: row.id,
                mode: mode,
                isNew: false,
                lumens: 40,
              ),
              pool: pool,
            );
            for (var i = 0; i < question!.options.length; i++) {
              if (i == question.answerIndex) continue;
              chosen += answer.overlapWith(ShownPhrase.of(question.options[i]));
              picks++;
            }
          }
        }

        expect(chosen / picks, greaterThan(window / circles * 1.02),
            reason: 'ярус ${tier.code}: порог даёт '
                '${(chosen / picks).toStringAsFixed(4)} против '
                '${(window / circles).toStringAsFixed(4)} у окна на дюжину');
      }
    });

    test('выбранное берёт свою долю потолка', () async {
      // **Тест на месте невоспроизводимого числа.** В `balance.dart` было
      // записано, что порог сбивает шум среди выбранных вариантов с 42–53 % до
      // 34–44 %, где шумом назывался кандидат, у которого с ответом общее
      // только **служебное** слово. Проверить это нечем: определения
      // служебного слова в проекте нет — ни списка, ни функции, — а заводить
      // его значит возвращать словарный слой и содержать его на четырёх языках
      // подсказок. Независимая сверка намерила по своему определению 66–79 %,
      // то есть число расходилось вдвое и никем не сторожилось.
      //
      // Взамен меряется та же величина, которой пользуется сборщик
      // ([ShownPhrase.overlapWith]), и меряется против **потолка**: средней
      // пяти самых похожих **годных** кандидатов. Потолок — это лучший круг,
      // который отбор мог бы собрать в принципе, поэтому доля от него говорит
      // ровно то, что обещано вариантам: насколько они похожи на ответ по
      // сравнению с тем, как похожи могли бы быть. Годность считается так же,
      // как у сборщика: второй верный ответ на языке центра, одинаковая
      // плитка — на языке вариантов.
      //
      // Измерено при зерне сборщика 1 (`setUp`, поэтому число воспроизводимо),
      // пул — весь корпус: A0 даёт 0.4214 при потолке 0.4795, B2 — 0.2435 при
      // 0.2754. И там и там это 88 % потолка. Середина шкалы, тем же замером по
      // восьми зёрнам: A1 0.4076/0.4519, A2 0.3664/0.4152, B1 0.3084/0.3518 —
      // 88–90 %. Доля устойчивее самих величин: с ростом длины фраз похожесть
      // падает вся, а доля не съезжает, и сторожить осмысленно её.
      //
      // Ярусы взяты крайние — на них похожесть отличается вдвое, и если доля
      // держится на обоих концах, она держится.
      //
      // Вторая половина — единственное, что от прежнего утверждения считается
      // без словаря: доля выбранных, у которых с ответом **ни одного** общего
      // слова. Это уже не «шум», а его крайний случай, зато определимый: 7.9 %
      // на A0 и 0.5 % на B2. На A0 фразы по три-четыре слова, и пересечься им
      // труднее — потолок там низкий не потому, что отбор плох.
      final pool = await wholeCorpus();
      final shapes = {
        true: shapesOf(await corpusTexts(onTarget: true)),
        false: shapesOf(await corpusTexts(onTarget: false)),
      };

      // Пороги на ярус: измеренное минус запас. Доля потолка сторожится снизу
      // (отбор не вправе сползти к случайному), доля нулевых пересечений —
      // сверху.
      const floors = {'a0': 0.80, 'b2': 0.80};
      const noiseCaps = {'a0': 0.15, 'b2': 0.05};

      for (final tier in [Tier.a0, Tier.b2]) {
        final rows = (await content.phrasesUpTo(Tier.values.last))
            .where((row) => row.tier == tier.code)
            .toList();
        expect(rows, isNotEmpty, reason: 'ярус ${tier.code} пуст');

        var chosen = 0.0;
        var picks = 0;
        var zeroShared = 0;
        var ceiling = 0.0;
        var circles = 0;
        for (final row in rows) {
          for (final mode in GameMode.values) {
            final onTarget = mode.optionsInTargetLanguage;
            final shown = shapes[onTarget]!;
            final answer = shown[row.id]!;
            final candidates = ranked(
              row.id,
              shown: shown,
              centre: shapes[!onTarget]!,
              pool: pool,
            );
            // Потолок — пятёрка лучших: `ranked` уже отсортирован по убыванию.
            final best = candidates.take(ScoreBalance.optionsPerCircle - 1);
            ceiling +=
                best.fold<double>(0, (a, c) => a + c.overlap) / best.length;
            circles++;

            final question = await builder.build(
              PlannedCircle(
                itemId: row.id,
                mode: mode,
                isNew: false,
                lumens: 40,
              ),
              pool: pool,
            );
            expect(question, isNotNull, reason: '${row.id} (${mode.name})');
            for (var i = 0; i < question!.options.length; i++) {
              if (i == question.answerIndex) continue;
              final other = ShownPhrase.of(question.options[i]);
              chosen += answer.overlapWith(other);
              if (answer.words
                  .toSet()
                  .intersection(other.words.toSet())
                  .isEmpty) {
                zeroShared++;
              }
              picks++;
            }
          }
        }

        final share = (chosen / picks) / (ceiling / circles);
        expect(share, greaterThan(floors[tier.code]!),
            reason: 'ярус ${tier.code}: выбранное даёт '
                '${(chosen / picks).toStringAsFixed(4)} при потолке '
                '${(ceiling / circles).toStringAsFixed(4)} — '
                '${(share * 100).toStringAsFixed(1)} % против измеренных 88 %');
        expect(zeroShared / picks, lessThan(noiseCaps[tier.code]!),
            reason: 'ярус ${tier.code}: у '
                '${(zeroShared / picks * 100).toStringAsFixed(1)} % выбранных с '
                'ответом ни одного общего слова — таких было 7.9 % на A0 и '
                '0.5 % на B2');
      }
    });

    test('на полосе из шести правилу не из чего выбирать, на полосе из дюжины '
        'есть', () async {
      // **Здесь сторожатся два факта, и первого прежде не было.** Тест
      // проверял только полосу из дюжины — то есть ровно то место, где правило
      // и так работает, — и обещание «варианты похожи по словам» читалось как
      // безусловное. Оно не безусловное: на полосе, с которой игрок выходит из
      // онбординга, силы у правила ноль, и не потому, что сборщик сломан.
      //
      // **Полоса из шести не оставляет выбора по построению.** Других
      // вариантов в круге пять, а полоса из шести фраз даёт ровно пять
      // кандидатов: сборщик обязан взять всех, и как он их ранжирует, не
      // значит ничего. Отношение похожести выбранного к средней по полосе
      // равно поэтому **единице точно**, а не приблизительно, — и проверяется
      // равенством, а не порогом: приблизительное сравнение спрятало бы
      // разницу между «выбора нет» и «выбор есть, но плохой».
      //
      // **Полоса из дюжины даёт 2.14×**, и это тот же замер на том же
      // материале — меняется только размер полосы. Между концами лежит
      // лестница (8 — 1.38×, 10 — 1.74×, 20 — 2.58×, весь ярус 150 — 8.23×), и
      // смысл её в том, что правило включается само по мере роста полосы.
      //
      // **Почему единица слева — это правильно, а не плохо.** Правил про
      // варианты два, и они спорят: знакомство исключением требует, чтобы
      // вокруг стояли **узнаваемые** фразы, совпадение слов — чтобы стояли
      // **путающие**. На полосе из пяти-шести оба требования одним материалом
      // не выполнить, и уступает второе: без первого новую фразу нечем
      // показать вовсе, без второго круг всего лишь легче. Отсюда и порядок
      // полос в `QuestionBuilder._pickOthers`. Без первой половины этого теста
      // следующий читатель примет единицу за регрессию и «починит» её, подняв
      // похожесть над памятью.
      //
      // Полоса — первые фразы яруса в авторском порядке, то есть то, что игрок
      // и проходит первым: тема знакомства. Замер идёт по восьми зёрнам на
      // круг; на дюжине это 0.1562 против 0.0731. На дюжине, разбросанной по
      // темам, разрыв меньше (1.8×), потому что похожести в такой полосе
      // меньше: правило её не выдумывает, оно перестаёт её выбрасывать.
      //
      // Заодно здесь остаётся запись о снятом окне `confusableWindow = 12`:
      // пока полоса короче дюжины, окно накрывало её целиком, жеребьёвка
      // становилась равномерной по всему пройденному, и ранжирование не влияло
      // ни на что. Ожидание старого правила поэтому и есть средняя по всей
      // полосе — воспроизводить окно не нужно, достаточно проверить, что
      // полоса короче него.
      final shapes = {
        true: shapesOf(await targetTexts()),
        false: shapesOf(await nativeTexts()),
      };
      final a0 = [for (final row in await content.phrasesUpTo(Tier.a0)) row.id];

      // По сборщику на зерно, а не по сборщику на круг: каждый читает корпус
      // целиком при первом обращении, и триста коротких кругов заняли бы
      // тремя сотнями чтений полторы тысячи фраз. Зерно задаётся при
      // создании, поэтому их восемь — ровно столько, сколько зёрен.
      final builders = [
        for (var seed = 0; seed < 8; seed++)
          QuestionBuilder(
            content: content,
            targetLang: 'de',
            nativeLang: 'uk',
            random: Random(seed),
          ),
      ];

      /// Сила правила на полосе из [size] фраз: похожесть выбранного против
      /// средней по полосе. Пул равен полосе — игрок знает ровно её и ничего
      /// больше.
      ///
      /// [forced] — сколько кругов набралось без всякого выбора: кандидатов
      /// ровно пять на пять мест. Считается затем, чтобы «единица» была
      /// доказана устройством круга, а не только средним.
      Future<({double strength, int forced, int circles})> strengthOn(
        int size,
      ) async {
        final band = a0.take(size).toList();
        var chosen = 0.0;
        var picks = 0;
        var wholeBand = 0.0;
        var circles = 0;
        var forced = 0;
        for (final id in band) {
          for (final mode in GameMode.values) {
            final onTarget = mode.optionsInTargetLanguage;
            final answer = shapes[onTarget]![id]!;
            final candidates = ranked(
              id,
              shown: shapes[onTarget]!,
              centre: shapes[!onTarget]!,
              pool: band,
            );
            final need = ScoreBalance.optionsPerCircle - 1;
            expect(candidates.length, greaterThanOrEqualTo(need),
                reason: '$id (${mode.name}): полоса не даёт пяти кандидатов');
            // Ожидание снятого окна на дюжину — вся полоса: она короче окна.
            expect(candidates.length, lessThan(12),
                reason: 'полоса длиннее окна — тест проверяет не то');
            if (candidates.length == need) forced++;
            wholeBand += candidates.fold<double>(0, (a, c) => a + c.overlap) /
                candidates.length;
            circles++;

            for (var seed = 0; seed < builders.length; seed++) {
              final question = await builders[seed].build(
                PlannedCircle(
                  itemId: id,
                  mode: mode,
                  isNew: false,
                  lumens: 40,
                ),
                pool: band,
              );
              expect(question, isNotNull, reason: '$id (${mode.name}), $seed');
              for (var i = 0; i < question!.options.length; i++) {
                if (i == question.answerIndex) continue;
                chosen +=
                    answer.overlapWith(ShownPhrase.of(question.options[i]));
                picks++;
              }
            }
          }
        }
        return (
          strength: chosen / picks / (wholeBand / circles),
          forced: forced,
          circles: circles,
        );
      }

      final six = await strengthOn(ScoreBalance.optionsPerCircle);
      final dozen = await strengthOn(12);

      // Полоса из шести: выбора нет ни в одном круге, и сила равна единице
      // точно. Равенство, а не `closeTo` с широким допуском: единица здесь
      // берётся из арифметики — пять кандидатов на пять мест, — и разойтись
      // она может только на округлении сложения.
      expect(six.forced, six.circles,
          reason: 'на полосе из ${ScoreBalance.optionsPerCircle} у сборщика '
              'появился выбор в ${six.circles - six.forced} кругах из '
              '${six.circles} — значит кандидатов больше пяти, и тест меряет '
              'не тот конец');
      expect(six.strength, closeTo(1, 1e-9),
          reason: 'на полосе из ${ScoreBalance.optionsPerCircle} сила правила '
              '${six.strength.toStringAsFixed(3)}× — единица здесь по '
              'построению, и всё, кроме неё, означает, что круг собран не из '
              'всей полосы');

      // Полоса из дюжины: выбор есть в каждом круге, и правило им пользуется.
      // Полуторный запас при измеренных 2.14×: правило обязано быть заметно
      // сильнее равномерной жеребьёвки, а не сильнее на проценты. Ниже
      // полутора — значит порог на короткой полосе снова выродился в окно.
      expect(dozen.forced, 0,
          reason: 'на полосе из дюжины кандидатов оказалось ровно пять — '
              'сравнивать концы не с чем');
      expect(dozen.strength, greaterThan(1.5),
          reason: 'на полосе из дюжины сила правила '
              '${dozen.strength.toStringAsFixed(3)}× против измеренных 2.14× — '
              'ранжирование по совпадению слов перестало работать и там, где '
              'полоса его позволяет');
    });

    test('после онбординга полоса — 5–6 фраз, и правило на ней почти молчит',
        () async {
      // Тот же факт на настоящей раскладке первого уровня, а не на пуле,
      // равном полосе: пул здесь — весь ярус, метки памяти держат шесть
      // засеянных фраз, а спрашиваются фразы, которых игрок не знает. Ровно
      // так выглядит уровень человека, только что прошедшего онбординг.
      //
      // Засев даёт 5–6 фраз (в среднем 5.5, от 3 до 6, меньше пяти в 7 %
      // забегов — печатает `calibration_diagnostic_test.dart`), потому что
      // засеять можно только вычитанное, а вычитан один A0, и на нём
      // калибровка спрашивает шесть кругов. Отсюда два измеренных конца:
      //
      // * пять известных — пять кандидатов на пять мест, сила **1.00× точно**;
      // * шесть известных — 1.20×, то есть выбор один из шести и почти ничего.
      //
      // Полоса взята разбросанной по созвездиям, как её и даёт калибровка
      // (`calibration_items`), а не первой шестёркой одной темы: внутри темы
      // похожесть выше, и полоса из одной темы завысила бы силу правила.
      //
      // Проверяется ещё и то, что похожести местами нет вовсе: есть круги, где
      // у **всех** кандидатов полосы с ответом ноль общих слов. Там правилу не
      // из чего выбирать даже в принципе, и никакой порог этого не изменит —
      // на первом уровне таких кругов 11 из 36 при пяти известных и 8 из 36
      // при шести. Требуется хотя бы один: точное число зависит от того, какие
      // фразы засеялись, а сам факт — нет.
      const seeded = [
        'about_me_a0_01',
        'first_contact_a0_01',
        'needs_help_a0_01',
        'place_time_price_a0_01',
        'understanding_a0_01',
        'about_me_a0_02',
      ];
      final shapes = {
        true: shapesOf(await targetTexts()),
        false: shapesOf(await nativeTexts()),
      };
      final a0 = [for (final row in await content.phrasesUpTo(Tier.a0)) row.id];
      final builders = [
        for (var seed = 0; seed < 8; seed++)
          QuestionBuilder(
            content: content,
            targetLang: 'de',
            nativeLang: 'uk',
            random: Random(seed),
          ),
      ];

      Future<({double strength, int blind, int circles})> afterSeeding(
        int known,
      ) async {
        final band = seeded.take(known).toSet();
        final asked = a0.where((id) => !band.contains(id)).take(12).toList();
        var chosen = 0.0;
        var picks = 0;
        var wholeBand = 0.0;
        var circles = 0;
        var blind = 0;
        for (final id in asked) {
          for (final mode in GameMode.values) {
            final onTarget = mode.optionsInTargetLanguage;
            final answer = shapes[onTarget]![id]!;
            final candidates = ranked(
              id,
              shown: shapes[onTarget]!,
              centre: shapes[!onTarget]!,
              pool: band.toList(),
            );
            // Полоса целиком годна: в A0 ни многоточий, ни одинаковых текстов,
            // и отсеивать сборщику нечего. Иначе средняя считалась бы не по
            // той полосе, из которой он выбирает.
            expect(candidates, hasLength(band.length), reason: '$id: полоса '
                'отсеялась — средняя считается не по ней');
            if (candidates.every((c) => c.overlap == 0)) blind++;
            wholeBand += candidates.fold<double>(0, (a, c) => a + c.overlap) /
                candidates.length;
            circles++;

            for (final builder in builders) {
              // Круг знакомства: фраза новая, вокруг обязаны встать
              // засеянные — это и есть исключение.
              final question = await builder.build(
                PlannedCircle(
                  itemId: id,
                  mode: mode,
                  isNew: true,
                  lumens: 0,
                ),
                pool: a0,
                known: band,
                seen: band,
              );
              expect(question, isNotNull, reason: '$id (${mode.name})');
              for (var i = 0; i < question!.options.length; i++) {
                if (i == question.answerIndex) continue;
                chosen +=
                    answer.overlapWith(ShownPhrase.of(question.options[i]));
                picks++;
              }
            }
          }
        }
        return (
          strength: chosen / picks / (wholeBand / circles),
          blind: blind,
          circles: circles,
        );
      }

      final five = await afterSeeding(ScoreBalance.optionsPerCircle - 1);
      final six = await afterSeeding(ScoreBalance.optionsPerCircle);

      // Пять известных — пятёрка вокруг новой фразы определена полностью, и
      // похожесть не решает ничего.
      expect(five.strength, closeTo(1, 1e-9),
          reason: 'при пяти известных сила правила '
              '${five.strength.toStringAsFixed(3)}× — а вокруг новой фразы '
              'обязаны стоять все пять, кем бы они ни были');
      // Шесть известных — выбор один из шести, и правило от него почти не
      // усиливается. Верхняя граница здесь важнее нижней: она и есть
      // утверждение «на первом уровне обещанной силы нет».
      expect(six.strength, lessThan(1.3),
          reason: 'при шести известных сила правила '
              '${six.strength.toStringAsFixed(3)}× против измеренных 1.20× — '
              'если она выросла, вокруг новой фразы встали не только '
              'засеянные, и знакомству больше не из чего исключать');
      expect(six.strength, greaterThan(five.strength),
          reason: 'шестая известная фраза не дала сборщику никакого выбора');
      // И круги, где похожести нет вовсе: правило не «слабое», а неприменимое.
      expect(five.blind, greaterThan(0),
          reason: 'у каждого круга нашёлся хоть один похожий кандидат — на '
              'засеянной полосе так не бывает, и замер идёт не по ней');
    });

    test('похожесть считается на том языке, на котором варианты показаны',
        () async {
      // «Ich bin dreißig Jahre alt.» и «Мені тридцять років.» — одна и та же
      // фраза, но похожие на неё соседки в двух языках разные, и разные
      // полностью: дюжина самых похожих в немецком («Ich bin ledig.», «Ich
      // bin müde.» — общее начало «ich bin») и дюжина в украинском («Мені
      // шкода.», «Мені холодно.» — общее «мені») **не пересекаются вовсе**,
      // ноль общих идентификаторов. Значит на этой фразе видно, каким языком
      // мерил сборщик: перепутай язык — и в круге окажутся соседки не той
      // дюжины.
      //
      // `pickTarget` показывает фразы изучаемого языка, `pickNative` —
      // переводы. Мерить похожесть не на языке показа значит мерить не то,
      // что игрок читает: варианты будут «похожими» в базе и случайными на
      // экране.
      const probe = 'about_me_a0_07';
      final pool = await wholeCorpus();
      final target = await corpusTexts(onTarget: true);
      final native = await corpusTexts(onTarget: false);
      final inTarget = shapesOf(target);
      final inNative = shapesOf(native);
      // Текст уникален в обоих языках — обратная карта однозначна.
      final idByTarget = {for (final e in target.entries) e.value: e.key};
      final idByNative = {for (final e in native.entries) e.value: e.key};

      Future<List<String>> chosen(GameMode mode, int seed) async {
        final question = await QuestionBuilder(
          content: content,
          targetLang: 'de',
          nativeLang: 'uk',
          random: Random(seed),
        ).build(
          PlannedCircle(itemId: probe, mode: mode, isNew: false, lumens: 40),
          pool: pool,
        );
        final byText =
            mode.optionsInTargetLanguage ? idByTarget : idByNative;
        return [
          for (var i = 0; i < question!.options.length; i++)
            if (i != question.answerIndex) byText[question.options[i]]!,
        ];
      }

      double meanOverlap(
        Iterable<String> ids,
        Map<String, ShownPhrase> shapes,
      ) {
        final answer = shapes[probe]!;
        final values = [for (final id in ids) answer.overlapWith(shapes[id]!)];
        return values.reduce((a, b) => a + b) / values.length;
      }

      final byTargetLang = <String>[];
      final byNativeLang = <String>[];
      for (var seed = 0; seed < 8; seed++) {
        byTargetLang.addAll(await chosen(GameMode.pickTarget, seed));
        byNativeLang.addAll(await chosen(GameMode.pickNative, seed));
      }

      // Каждый набор похож на ответ **на своём** языке сильнее, чем чужой
      // набор. Обе половины нужны: одна ловит подмену языка, вторая — отказ
      // от меры вовсе.
      expect(meanOverlap(byTargetLang, inTarget),
          greaterThan(meanOverlap(byNativeLang, inTarget)));
      expect(meanOverlap(byNativeLang, inNative),
          greaterThan(meanOverlap(byTargetLang, inNative)));
    });

    test('зерно тасует внутри похожих, а не по всему пулу', () async {
      // Прежде здесь стояло обратное требование: состав пятёрки обязан быть
      // одинаковым при любом зерне, потому что берётся с начала
      // упорядоченного пула. Пул перестал быть одним списком, и правило
      // перевернулось: если пятёрку брать строго по максимуму похожести, один
      // и тот же круг повторится из забега в забег, и игрок запомнит
      // расположение вариантов, а не фразы.
      //
      // Разнообразие вернулось, но заперто: каждый из пяти жеребится среди
      // похожих. Поэтому проверяются обе половины — что состав меняется и что
      // ни один вариант не вышел за то, что порог разрешает.
      final pool = await wholeCorpus();
      final shapes = shapesOf(await corpusTexts(onTarget: false));
      final byText = idsByText(await corpusTexts(onTarget: false));
      const circle = PlannedCircle(
        itemId: 'understanding_a0_11',
        mode: GameMode.pickNative,
        isNew: false,
        lumens: 0,
      );
      final candidates = ranked(
        circle.itemId,
        shown: shapes,
        centre: shapesOf(await corpusTexts(onTarget: true)),
        pool: pool,
      );
      final may = allowed(candidates);
      expect(barOf(candidates), greaterThan(0),
          reason: 'порог нулевой — тест бессилен');

      // Состав сравнивается склеенной строкой, а не множеством множеств: у
      // `Set` в Dart нет равенства по значению, и `Set<Set<String>>` считал бы
      // одинаковые составы разными элементами. Прежний тест на этом и
      // держался — он требовал «составов больше одного» и получал это
      // бесплатно, по ссылочному равенству, ни разу не заглянув внутрь.
      final compositions = <String>{};
      final answerPlaces = <int>{};
      for (var seed = 0; seed < 12; seed++) {
        final question = await QuestionBuilder(
          content: content,
          targetLang: 'de',
          nativeLang: 'uk',
          random: Random(seed),
        ).build(circle, pool: pool);

        expect(question, isNotNull, reason: 'зерно $seed');
        compositions.add((question!.options.toList()..sort()).join(' | '));
        answerPlaces.add(question.answerIndex);

        for (var i = 0; i < question.options.length; i++) {
          if (i == question.answerIndex) continue;
          expect(may, contains(byText[question.options[i]]),
              reason: 'зерно $seed: «${question.options[i]}» порогом не '
                  'разрешён');
        }
      }

      expect(compositions.length, greaterThan(1),
          reason: 'состав не зависит от зерна — круг будет повторяться из '
              'забега в забег, и игрок запомнит расположение');
      expect(answerPlaces.length, greaterThan(1),
          reason: 'верный вариант всегда на одном месте круга');
    });

    // ── Двусмысленность: материал ушёл из корпуса, правило осталось ────────
    //
    // Четыре теста ниже собирают свой `content.db` вместо того, чтобы взять
    // фразы ассета, и это не удобство, а следствие правки корпуса.
    // Многоточий в нём **ноль**: корпус вырос до 1500 фраз и потерял место
    // под своё слово («с ним не понятно как читать»). Без дыры
    // [ShownPhrase.describes] сводится к равенству показанных текстов, а
    // одинаковых текстов в корпусе тоже ноль — ни в немецком, ни в
    // украинском. Замерено на отгруженном ассете: 0 многоточий и 0 пар
    // «центр описывает чужую фразу» на 1500 фразах, и в обе стороны — с
    // центром на изучаемом и с центром на родном.
    //
    // Отсюда два следствия, и оба записаны здесь же.
    //
    // * Сплошной проход по ассету («двух верных ответов не бывает ни в одном
    //   круге корпуса») доказывает, что ловить сегодня нечего, — но не то,
    //   что проверка работает. Он зеленел бы и с удалённым правилом.
    // * Значит правило проверяется на самодельном корпусе. Иначе тест на
    //   «два верных ответа» зеленел бы до правки — а он такой уже был и
    //   ровно этот дефект пропустил: сверял язык вариантов, тот же, что и
    //   сборщик.
    //
    // Из четырёх тестов трём нужна дыра, а четвёртому — нет: две фразы,
    // переведённые одной строкой, дают и второго верного ответа, и вторую
    // плитку без всякого многоточия. Этот случай приходит от руки
    // переводчика, а не от формы записи, и потому он самый вероятный из
    // четырёх на нынешнем корпусе.
    //
    // Прежние тесты стояли на фразах ассета: `needs_help_a0_18` было
    // «Ich brauche ...», `place_time_price_a0_18` — «Wo ist ...?» / «Де
    // ...?». Идентификаторы живы, текст другой («Ich brauche einen Stift.» и
    // «Wo ist die Apotheke?»), то есть материала не стало, а правило нужным
    // осталось: форма с многоточием законна и возвращается одной правкой
    // листа, а пару одинаковых переводов может дать первая же добавленная
    // тема. Проверка, снятая как «защищающая от несуществующего», вернула бы
    // круг с двумя верными ответами — тот самый, где игрок нажимает верное и
    // получает «неверно».

    /// Строки самодельного корпуса: `id`, фраза на изучаемом, перевод.
    ///
    /// Двадцать пять фраз: две пары «шаблон — заполнение», группа из девяти
    /// законных ответов на один центр и тройка вокруг двух фраз с одним
    /// переводом. Пары нарочно **несимметричны по языкам**, потому что языком
    /// дефект и был:
    ///
    /// * `brauche_*` — дыра заполняется только на изучаемом. «Ich brauche
    ///   ...» описывает «Ich brauche Hilfe.», а «Мені потрібно ...» фразу
    ///   «Мені потрібна допомога.» не описывает: потрібно ≠ потрібна.
    /// * `wollen_*` — зеркало. «Я хочу ...» описывает «Я хочу заплатити.», а
    ///   «Ich möchte ...» фразу «Ich will zahlen.» не описывает: möchte ≠
    ///   will.
    ///
    /// Пара, двусмысленная в оба языка, правильную проверку от неправильной
    /// не отличает — там любой язык даёт один и тот же ответ. Поэтому пар
    /// две, и каждая молчит на одном из языков.
    ///
    /// Наполнитель нужен затем, чтобы круг собирался и после отсева: у
    /// центра-шаблона негодных кандидатов до десяти, а других вариантов в
    /// круге пять.
    const fixture = <({String id, String de, String uk})>[
      (id: 'brauche_template', de: 'Ich brauche ...', uk: 'Мені потрібно ...'),
      (
        id: 'brauche_filled',
        de: 'Ich brauche Hilfe.',
        uk: 'Мені потрібна допомога.'
      ),
      (id: 'wollen_template', de: 'Ich möchte ...', uk: 'Я хочу ...'),
      (id: 'wollen_filled', de: 'Ich will zahlen.', uk: 'Я хочу заплатити.'),
      (id: 'where_template', de: 'Wo ist ...?', uk: 'Де ...?'),
      (id: 'where_01', de: 'Wo wohnst du?', uk: 'Де ти живеш?'),
      (id: 'where_02', de: 'Wo arbeitest du?', uk: 'Де ти працюєш?'),
      (id: 'where_03', de: 'Wo lernst du?', uk: 'Де ти вчишся?'),
      (id: 'where_04', de: 'Wo kaufst du ein?', uk: 'Де ти купуєш?'),
      (id: 'where_05', de: 'Wo treffen wir uns?', uk: 'Де ми зустрічаємось?'),
      (id: 'where_06', de: 'Wo findet der Kurs statt?', uk: 'Де проходить курс?'),
      (id: 'where_07', de: 'Wo ist die Kasse?', uk: 'Де каса?'),
      (id: 'where_08', de: 'Wo ist der Bahnhof?', uk: 'Де вокзал?'),
      (id: 'where_09', de: 'Wo ist die Apotheke?', uk: 'Де аптека?'),
      // Две фразы, переведённые одной строкой, и третья рядом с ними. Дыр
      // здесь нет вовсе: этот дефект приходит не от многоточия, а от руки
      // переводчика, и первая же добавленная тема может его принести.
      (id: 'same_uk_a', de: 'Ich bin fertig.', uk: 'Я готовий.'),
      (id: 'same_uk_b', de: 'Ich bin bereit.', uk: 'Я готовий.'),
      (id: 'near_twins', de: 'Ich bin müde.', uk: 'Я втомився.'),
      (id: 'filler_01', de: 'Guten Morgen!', uk: 'Доброго ранку!'),
      (id: 'filler_02', de: 'Vielen Dank!', uk: 'Дуже дякую!'),
      (id: 'filler_03', de: 'Bis morgen!', uk: 'До завтра!'),
      (id: 'filler_04', de: 'Alles gut.', uk: 'Все добре.'),
      (id: 'filler_05', de: 'Kein Problem.', uk: 'Без проблем.'),
      (id: 'filler_06', de: 'Bitte schön.', uk: 'Будь ласка.'),
      (id: 'filler_07', de: 'Es tut mir leid.', uk: 'Мені шкода.'),
      (id: 'filler_08', de: 'Bis später!', uk: 'До зустрічі!'),
    ];

    /// Самодельный корпус, открытый так же, как ассет: голый SQL по
    /// `contentSchemaDdl`, `PRAGMA user_version`, и только потом Drift.
    ///
    /// Через Drift, а не мимо него: сборщик круга читает содержимое теми же
    /// четырьмя запросами, что и в игре, и проверяется здесь именно он — а не
    /// [ShownPhrase.describes] в отрыве от того, на каком языке его
    /// спрашивают. Дефект был ровно в этом стыке: предикат был верен, а
    /// вызывали его с чужим языком.
    Future<ContentDatabase> madeUpContent() async {
      // Ассет закрывается, и закрытие дожидается: этим трём тестам он не
      // нужен, а два живых `ContentDatabase` в одном процессе Drift встречает
      // предупреждением о гонке за общий исполнитель. Гонки здесь нет —
      // исполнители разные, — но глушить предупреждение флагом значило бы
      // глушить его и там, где оно правдиво. `tearDown` закроет ассет второй
      // раз, и это безвредно.
      await content.close();
      final source = raw.sqlite3.openInMemory();
      for (final ddl in schema.contentSchemaDdl) {
        source.execute(ddl);
      }
      for (var i = 0; i < fixture.length; i++) {
        final row = fixture[i];
        source.execute(
          'INSERT INTO phrases (id, lang, tier, constellation, idx, text, '
          "kind) VALUES (?, 'de', 'a0', 'first_contact', ?, ?, 'phrase')",
          [row.id, i, row.de],
        );
        source.execute(
          'INSERT INTO phrase_translations (phrase_id, lang, text) '
          "VALUES (?, 'uk', ?)",
          [row.id, row.uk],
        );
      }
      source.execute('PRAGMA user_version = ${schema.contentSchemaVersion}');
      return ContentDatabase(NativeDatabase.opened(source));
    }

    /// Круг по самодельному корпусу: зерно снаружи, пул по умолчанию весь.
    ///
    /// [pool] сужается там, где полный пул прячет дефект: пятёрка жеребится, и
    /// на двадцати пяти фразах нужная пара попадает в круг не на каждом зерне.
    /// Узкий пул делает попадание обязательным, а проверку — не зависящей от
    /// того, как легли кости.
    Future<CircleQuestion> madeUpCircle(
      ContentDatabase content, {
      required String itemId,
      required GameMode mode,
      required int seed,
      List<String>? pool,
    }) async {
      final question = await QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(seed),
      ).build(
        PlannedCircle(itemId: itemId, mode: mode, isNew: false, lumens: 40),
        pool: pool ?? [for (final row in fixture) row.id],
      );
      expect(question, isNotNull, reason: '$itemId ($mode, зерно $seed)');
      return question!;
    }

    final deOf = {for (final row in fixture) row.id: row.de};
    final ukOf = {for (final row in fixture) row.id: row.uk};

    test('шаблон в центре не встаёт рядом с фразой, которая его заполняет',
        () async {
      // Случай, пойманный критиком на настоящем коде, дословно. Центр — «Ich
      // brauche ...», вокруг переводы; среди них «Мені потрібна допомога.»,
      // то есть перевод фразы «Ich brauche Hilfe.». Многоточие центра это
      // место под своё слово, «Hilfe» его заполняет — игрок, ткнувший в этот
      // вариант, **прав** и получает «неверно».
      //
      // Проверка стояла на языке вариантов и потому молчала именно здесь:
      // по-украински «Мені потрібно ...» фразу «Мені потрібна допомога.» не
      // заполняет, а двусмысленность создавал немецкий центр.
      //
      // Вторая половина — то же на другом языке: центр `pickTarget`
      // украинский, и негодным становится немецкий вариант. Без неё правку
      // можно было бы сделать наполовину — переставить проверку с языка
      // вариантов на изучаемый вместо языка центра, и в `pickTarget` она
      // снова смотрела бы не туда.
      final content = await madeUpContent();
      addTearDown(content.close);

      // Сперва — что материал настоящий: на языке центра пара двусмысленна, а
      // на языке вариантов различима. Иначе тест ловил бы не то.
      expect(
          ShownPhrase.of(deOf['brauche_template']!)
              .describes(ShownPhrase.of(deOf['brauche_filled']!)),
          isTrue);
      expect(
          ShownPhrase.of(ukOf['brauche_template']!)
              .describes(ShownPhrase.of(ukOf['brauche_filled']!)),
          isFalse,
          reason: 'на языке вариантов пара неразличима — тест ловил бы не то');
      expect(
          ShownPhrase.of(ukOf['wollen_template']!)
              .describes(ShownPhrase.of(ukOf['wollen_filled']!)),
          isTrue);
      expect(
          ShownPhrase.of(deOf['wollen_template']!)
              .describes(ShownPhrase.of(deOf['wollen_filled']!)),
          isFalse);

      for (var seed = 0; seed < 12; seed++) {
        // Центр на изучаемом: `pickNative` показывает переводы, `listenNative`
        // те же переводы под звучащий центр.
        for (final mode in [GameMode.pickNative, GameMode.listenNative]) {
          final question = await madeUpCircle(content,
              itemId: 'brauche_template', mode: mode, seed: seed);
          expect(question.options, isNot(contains(ukOf['brauche_filled'])),
              reason: '${mode.name}, зерно $seed: в круге два верных ответа — '
                  '«${ukOf['brauche_filled']}» это '
                  '«${deOf['brauche_filled']}»');
        }

        // Центр на родном: вокруг фразы изучаемого языка.
        final mirrored = await madeUpCircle(content,
            itemId: 'wollen_template', mode: GameMode.pickTarget, seed: seed);
        expect(mirrored.options, isNot(contains(deOf['wollen_filled'])),
            reason: 'pickTarget, зерно $seed: центр «${ukOf['wollen_template']}» '
                'описывает и «${deOf['wollen_filled']}» — в круге два верных '
                'ответа');
      }
    });

    test('в обратную сторону шаблон — законный вариант, а не второй ответ',
        () async {
      // Направление правила проверяется здесь, и без этого теста симметричный
      // запрет прошёл бы незамеченным: он тоже не даёт двух верных ответов —
      // он выметает из круга законные варианты, и заметить это можно только
      // так.
      //
      // Две стороны, по одной на язык.
      //
      // * Центр «Ich will zahlen.» конкретен, кандидат «Я хочу ...» —
      //   шаблон. На конкретный вопрос перевод с незаполненной дырой не
      //   отвечает: это самый трудный законный вариант, и выбрасывать его
      //   значит убирать из круга ровно то усилие, ради которого он собран.
      //   Симметричная проверка выбрасывала: по-украински шаблон
      //   заполняется.
      // * Центр «Мені потрібно ...» — шаблон, но на украинском, и
      //   по-украински он «Мені потрібна допомога.» не заполняет. Значит в
      //   `pickTarget` немецкая заполненная фраза законна тоже, хотя на
      //   немецком пара двусмысленна.
      //
      // Оба кандидата — самые похожие в своём круге, поэтому требуется не
      // «хоть раз», а каждый раз: жеребьёвка среди похожих их не теряет.
      final content = await madeUpContent();
      addTearDown(content.close);

      for (var seed = 0; seed < 12; seed++) {
        final around = await madeUpCircle(content,
            itemId: 'wollen_filled', mode: GameMode.pickNative, seed: seed);
        expect(around.options, contains(ukOf['wollen_template']),
            reason: 'зерно $seed: шаблон «${ukOf['wollen_template']}» не встал '
                'в круг про «${deOf['wollen_filled']}» — запрет считается '
                'симметрично и выметает законные варианты');

        final mirrored = await madeUpCircle(content,
            itemId: 'brauche_template', mode: GameMode.pickTarget, seed: seed);
        expect(mirrored.options, contains(deOf['brauche_filled']),
            reason: 'зерно $seed: «${deOf['brauche_filled']}» не встала в круг '
                'pickTarget про «${ukOf['brauche_template']}» — '
                'двусмысленность считается не на языке центра');
      }
    });

    test('«Де ...?»: девять законных ответов в круг не попадают', () async {
      // Худший случай, найденный критиком в прежнем корпусе, воспроизведён
      // числом. Центр `pickTarget` — украинское «Де ...?», вокруг немецкие
      // фразы, и законным ответом на такой центр является каждая, чей перевод
      // начинается с «Де»: «Wo wohnst du?», «Wo arbeitest du?», «Wo ist die
      // Kasse?».
      //
      // Фильтр же сверял немецкий, где «Wo ist ...?» заполняется только теми
      // тремя, что случайно начинаются с «Wo ist». Шесть остальных он
      // пропускал — и они вставали в круг: пять вариантов из пяти оказывались
      // верными ответами, и пройти такой круг игрок не мог никак.
      final content = await madeUpContent();
      addTearDown(content.close);
      final centre = {
        for (final row in fixture) row.id: ShownPhrase.of(row.uk),
      };
      final shown = {
        for (final row in fixture) row.id: ShownPhrase.of(row.de),
      };
      final idByDe = {for (final row in fixture) row.de: row.id};

      // Материал теста: сколько фраз описывает центр на своём языке и сколько
      // из них видел прежний фильтр на чужом. Разница этих двух чисел и есть
      // дефект.
      final legitimate = {
        for (final row in fixture)
          if (row.id != 'where_template' &&
              centre['where_template']!.describes(centre[row.id]!))
            row.id,
      };
      final seenOnOptionsLanguage = {
        for (final id in legitimate)
          if (shown['where_template']!.describes(shown[id]!)) id,
      };
      expect(legitimate, hasLength(9));
      expect(seenOnOptionsLanguage, hasLength(3),
          reason: 'на языке вариантов прежний фильтр видел '
              '${seenOnOptionsLanguage.length} из ${legitimate.length}');

      for (var seed = 0; seed < 12; seed++) {
        final question = await madeUpCircle(content,
            itemId: 'where_template', mode: GameMode.pickTarget, seed: seed);
        final extra = [
          for (var i = 0; i < question.options.length; i++)
            if (i != question.answerIndex &&
                legitimate.contains(idByDe[question.options[i]]))
              question.options[i],
        ];
        expect(extra, isEmpty,
            reason: 'зерно $seed: на центре «${ukOf['where_template']}» верны '
                'ещё ${extra.length} варианта — $extra');
      }
    });

    test('два перевода одной строкой: и второй верный ответ, и вторая плитка',
        () async {
      // Единственный из четырёх случаев, которому многоточие не нужно вовсе, —
      // и потому единственный, который придёт от обычной работы над
      // контентом: две фразы, переведённые одной строкой. Сегодня таких пар в
      // корпусе ноль (проверено на 1500 фразах), но перевод пишет человек.
      //
      // Одна причина даёт **два разных дефекта**, по одному на язык, и ловят
      // их две разные проверки сборщика.
      //
      // * `pickTarget`: центр — «Я готовий.», вокруг немецкие фразы. Верных
      //   среди них две, «Ich bin fertig.» и «Ich bin bereit.», и это в
      //   точности «два верных ответа» — считается на языке центра, где
      //   тексты совпали.
      // * `pickNative`: центр — «Ich bin müde.», вокруг переводы, и среди них
      //   «Я готовий.» дважды. Верных ответов тут по-прежнему один, но плиток
      //   с одним текстом две, и круг ([CircleQuestion.isCorrectOption]
      //   сверяет текст) принял бы любую из них — то есть игрок ткнул бы в
      //   заведомо неверную и получил бы «верно». Считается на языке
      //   вариантов, и не только с ответом, но и кандидатов между собой:
      //   ответ «Я втомився.» ни одной из двух плиток не равен.
      //
      // Прежняя проверка сверяла кандидата только с ответом и только на языке
      // вариантов, поэтому пропускала оба: в `pickTarget` она смотрела на
      // немецкий, где фразы разные, а в `pickNative` сравнивала «Я готовий.» с
      // «Я втомився.», а не с другой такой же плиткой.
      final content = await madeUpContent();
      addTearDown(content.close);

      // Материал: перевод один и тот же, фразы разные.
      expect(ukOf['same_uk_a'], ukOf['same_uk_b']);
      expect(deOf['same_uk_a'], isNot(deOf['same_uk_b']));

      for (var seed = 0; seed < 12; seed++) {
        final asked = await madeUpCircle(content,
            itemId: 'same_uk_a', mode: GameMode.pickTarget, seed: seed);
        expect(asked.options, isNot(contains(deOf['same_uk_b'])),
            reason: 'зерно $seed: на центре «${ukOf['same_uk_a']}» верны и '
                '«${deOf['same_uk_a']}», и «${deOf['same_uk_b']}»');

        // Пул узкий нарочно: шесть кандидатов на пять мест, и обе плитки
        // «Я готовий.» обязаны попасть в круг, если сборщик их не отсеет. На
        // полном пуле обе выпадали бы вместе примерно в каждом седьмом круге,
        // и тест зависел бы от зерна.
        final shown = await madeUpCircle(content,
            itemId: 'near_twins',
            mode: GameMode.pickNative,
            seed: seed,
            pool: const [
              'near_twins',
              'same_uk_a',
              'same_uk_b',
              'filler_01',
              'filler_02',
              'filler_03',
              'filler_04',
            ]);
        expect(shown.options.toSet(), hasLength(shown.options.length),
            reason: 'зерно $seed: в круге две плитки с одним текстом — '
                '${shown.options}');
      }
    });

    test('двух верных ответов не бывает ни в одном круге корпуса', () async {
      // Сплошной проход: каждая фраза запущенного яруса, все три механики,
      // пул — все 1500 фраз, то есть весь корпус в пределах досягаемости.
      // Проверяются две стороны одного правила: круг не содержит второго
      // варианта, который был бы верен, и принятым оказывается ровно один.
      //
      // **Что этот тест доказывает, а что нет.** Двусмысленных пар в корпусе
      // ноль (ни многоточий, ни одинаковых переводов), поэтому он говорит
      // «ловить нечего» — и зеленел бы с удалённой проверкой тоже. Правило
      // как таковое сторожат три теста на самодельном корпусе выше; здесь
      // сторожится корпус, а не код. Оба нужны: без первых правило можно
      // снять незамеченным, без этого — незаметно завести в контенте пару,
      // на которой круг станет непроходимым.
      //
      // Прежде тест сверял язык вариантов, тот же, что и сборщик, и потому
      // зеленел на дефекте: круг с двумя верными ответами он один раз уже
      // пропустил. Теперь двусмысленность считается на языке **центра** —
      // так же, как её считает сборщик.
      //
      // Вторая проверка — не про `isCorrectOption`, а про контент: круг
      // принимает вариант с тем же **текстом**, что у ответа, и если две
      // фразы переведены одной строкой, игрок получит «неверно» на верном.
      final pool = await wholeCorpus();
      final shapes = {
        true: shapesOf(await corpusTexts(onTarget: true)),
        false: shapesOf(await corpusTexts(onTarget: false)),
      };
      final byText = {
        true: idsByText(await corpusTexts(onTarget: true)),
        false: idsByText(await corpusTexts(onTarget: false)),
      };

      for (final row in await content.phrasesUpTo(Tier.a0)) {
        for (final mode in GameMode.values) {
          final onTarget = mode.optionsInTargetLanguage;
          final question = await builder.build(
            PlannedCircle(
              itemId: row.id,
              mode: mode,
              isNew: false,
              lumens: 40,
            ),
            pool: pool,
          );
          expect(question, isNotNull, reason: '${row.id} (${mode.name})');

          // Центр — тот же ответ на другом языке: в `pickNative` и
          // `listenNative` это изучаемая фраза, в `pickTarget` её перевод.
          final centre = shapes[!onTarget]!;
          final centreAnswer = centre[row.id]!;
          for (var i = 0; i < question!.options.length; i++) {
            if (i == question.answerIndex) continue;
            final id = byText[onTarget]![question.options[i]]!;
            expect(centreAnswer.describes(centre[id]!), isFalse,
                reason: '${row.id} (${mode.name}): центр '
                    '«${centreAnswer.key}» описывает и «${question.options[i]}» '
                    '($id) — в круге два верных ответа');
          }

          final accepted = [
            for (var i = 0; i < question.options.length; i++)
              if (question.isCorrectOption(i)) i,
          ];
          expect(accepted, [question.answerIndex],
              reason: '${row.id} (${mode.name}): принятых не один — $accepted');
        }
      }
    });

    test('порог круг не запрещает: похожих нет — вокруг встают любые',
        () async {
      // Правило улучшает круг, а не отменяет его. Пул здесь — пять фраз, у
      // которых с ответом нет ни одного общего слова: похожих не существует
      // вовсе, порога нет, и все пять обязаны встать вокруг. Иначе порог
      // съел бы круг целиком, и фраза молча выпала бы из уровня.
      const answerId = 'understanding_a0_11';
      const dissimilar = [
        'first_contact_a0_02',
        'first_contact_a0_03',
        'first_contact_a0_04',
        'place_time_price_a0_03',
        'place_time_price_a0_04',
      ];
      final native = await nativeTexts();
      final shapes = shapesOf(native);
      final answer = shapes[answerId]!;
      for (final id in dissimilar) {
        expect(answer.overlapWith(shapes[id]!), 0, reason: id);
      }

      final question = await builder.build(
        const PlannedCircle(
          itemId: answerId,
          mode: GameMode.pickNative,
          isNew: false,
          lumens: 0,
        ),
        pool: dissimilar,
      );
      expect(question, isNotNull, reason: 'порог запретил круг');
      expect(question!.options.toSet().difference({question.answer}),
          {for (final id in dissimilar) native[id]!});
    });

    test('похожих меньше пяти — они всё равно все в круге', () async {
      // «Лучше четыре похожих и один любой, чем пять любых». Пул собран так,
      // что похожих в нём заведомо меньше пяти: два самых похожих кандидата
      // яруса плюс двадцать фраз без единого общего слова. Похожие обязаны
      // оказаться в круге все, а добор — только дополнить их до пяти.
      //
      // Окно на дюжину этого не давало: оно тянуло пятёрку равномерно из всех
      // двенадцати, и похожие выпадали ровно с той же вероятностью, что шум.
      final rows = await content.phrasesUpTo(Tier.a0);
      final native = await nativeTexts();
      final shapes = shapesOf(native);

      for (final answerId in const [
        'understanding_a0_11',
        'needs_help_a0_01',
        'about_me_a0_07',
      ]) {
        final answer = shapes[answerId]!;
        final others = [for (final row in rows) row.id]
          ..remove(answerId)
          ..sort((a, b) => answer
              .overlapWith(shapes[b]!)
              .compareTo(answer.overlapWith(shapes[a]!)));
        final noise = others
            .where((id) => answer.overlapWith(shapes[id]!) == 0)
            .take(20)
            .toList();
        expect(noise, hasLength(20), reason: '$answerId: шума не набралось');
        final pool = [...others.take(2), ...noise];

        final bar = barOf([
          for (final id in pool)
            (id: id, overlap: answer.overlapWith(shapes[id]!)),
        ]);
        final similar = pool
            .where((id) => answer.overlapWith(shapes[id]!) >= bar)
            .toSet();
        expect(similar.length, lessThan(ScoreBalance.optionsPerCircle - 1),
            reason: '$answerId: похожих набралось пять — тест проверяет не то');

        for (var seed = 0; seed < 12; seed++) {
          final question = await QuestionBuilder(
            content: content,
            targetLang: 'de',
            nativeLang: 'uk',
            random: Random(seed),
          ).build(
            PlannedCircle(
              itemId: answerId,
              mode: GameMode.pickNative,
              isNew: false,
              lumens: 40,
            ),
            pool: pool,
          );

          for (final id in similar) {
            expect(question!.options, contains(native[id]),
                reason: '$answerId, зерно $seed: похожий «${native[id]}» '
                    'вытеснен шумом');
          }
        }
      }
    });

    test('на уникальной по лексике фразе шум идёт только в добор', () async {
      // Вырождение, названное на разборе, пересчитанное на новом корпусе:
      // у `ecology_decisions_b2_05` («Individuelle Entscheidungen sind
      // wichtig, ersetzen aber keine strukturellen Veränderungen.») лучший
      // кандидат даёт 0.154, а начиная с седьмого идут фразы с одним общим
      // служебным словом — «Wir sind Kollegen.», «Ich habe keine Kinder.»,
      // 0.091 и ниже. Окно на дюжину тянуло пятёрку из всех двенадцати, и
      // ниже дна оказывалось три варианта из пяти.
      //
      // **Связывает здесь дно, а не доля**, и это тот случай, ради которого
      // дно и стоит: три пятых от 0.154 это 0.092, то есть «Wir sind
      // Kollegen.» прошло бы по доле. Дно поднимает порог до 0.100 и
      // оставляет шесть честных кандидатов — больше пяти, поэтому добора нет
      // вовсе и ниже дна не попадает ни один вариант. Требуется не ноль, а
      // «не больше одного»: похожих может стать меньше пяти от правки
      // корпуса, и тогда один добор законен.
      const probe = 'ecology_decisions_b2_05';
      final pool = await wholeCorpus();
      final shapes = shapesOf(await corpusTexts(onTarget: true));
      final answer = shapes[probe]!;

      for (var seed = 0; seed < 12; seed++) {
        final question = await QuestionBuilder(
          content: content,
          targetLang: 'de',
          nativeLang: 'uk',
          random: Random(seed),
        ).build(
          const PlannedCircle(
            itemId: probe,
            mode: GameMode.pickTarget,
            isNew: false,
            lumens: 40,
          ),
          pool: pool,
        );

        final below = [
          for (var i = 0; i < question!.options.length; i++)
            if (i != question.answerIndex &&
                answer.overlapWith(ShownPhrase.of(question.options[i])) <
                    ScoreBalance.confusableFloor)
              question.options[i],
        ];
        expect(below.length, lessThanOrEqualTo(1),
            reason: 'зерно $seed: ниже дна похожести ${below.length} '
                'вариантов — $below');
      }
    });

    test('известное вперёд похожего, виденное вперёд невиданного', () async {
      // Здесь совмещаются два правила, и порядок между ними виден только на
      // таком материале: пять фраз, которые игрок знает, **не похожи** на
      // ответ вовсе, а в ярусе есть незнакомые, похожие сильно. Знакомство
      // исключением требует, чтобы вокруг встали известные; правило
      // совпадения решает лишь то, кого из известных выбрать. Если бы
      // похожесть перебивала память, вокруг новой фразы встали бы незнакомые
      // строчки, и исключать стало бы не из чего.
      const answerId = 'understanding_a0_11';
      const dissimilar = [
        'first_contact_a0_02',
        'first_contact_a0_03',
        'first_contact_a0_04',
        'place_time_price_a0_03',
        'place_time_price_a0_04',
      ];
      final rows = await content.phrasesUpTo(Tier.a0);
      final pool = [for (final row in rows) row.id];
      final native = await nativeTexts();
      final shapes = shapesOf(native);
      const circle = PlannedCircle(
        itemId: answerId,
        mode: GameMode.pickNative,
        isNew: false,
        lumens: 0,
      );

      // Материал теста годен только если непохожесть настоящая: у каждой из
      // пяти общих слов с ответом нет, а в ярусе есть заметно похожие.
      final answer = shapes[answerId]!;
      for (final id in dissimilar) {
        expect(answer.overlapWith(shapes[id]!), 0, reason: id);
      }
      expect(
          pool
              .where((id) => id != answerId)
              .map((id) => answer.overlapWith(shapes[id]!))
              .reduce(max),
          greaterThan(0.5));

      final expected = {for (final id in dissimilar) native[id]!};

      final asKnown = await builder.build(circle,
          pool: pool, known: dissimilar.toSet(), seen: dissimilar.toSet());
      expect(asKnown!.options.toSet().difference({asKnown.answer}), expected,
          reason: 'похожесть перебила память: вокруг известных встали чужие');

      // Просто виденное — вторая полоса. Она слабее известного, но сильнее
      // невиданного: правило владельца требует, чтобы варианты были
      // пройденными, а пройденное шире известного.
      final asSeen =
          await builder.build(circle, pool: pool, seen: dissimilar.toSet());
      expect(asSeen!.options.toSet().difference({asSeen.answer}), expected);

      // Без памяти обе полосы пусты, и решает уже только похожесть — те же
      // пять непохожих фраз в круг не попадают.
      final asFresh = await builder.build(circle, pool: pool);
      expect(asFresh!.options.toSet().difference({asFresh.answer}),
          isNot(expected));
    });
  });

  group('круг, который нельзя собрать', () {
    const circle = PlannedCircle(
      itemId: 'about_me_a0_01',
      mode: GameMode.pickNative,
      isNew: false,
      lumens: 0,
    );

    test('фраза без перевода на родной круг не собирает', () async {
      // Раньше непоказуемое отбраковывала длина: «Ich trinke Wasser.» — три
      // слова при пороге четыре, — и сборка возвращала `null`, а загрузчик
      // молча пропускал круг. Порога длины больше нет: фраза показывается
      // целиком, и короткая показывается так же, как длинная.
      //
      // Причина отказа осталась одна — нехватка текста. Язык подсказок берётся
      // французский: он есть в интерфейсе, но в контенте его нет вовсе, то
      // есть переводов ноль. Это и есть неполный язык, и он обязан давать
      // меньше кругов, а не чужие.
      //
      // Раньше здесь стоял русский: в прежнем ассете украинских переводов
      // было 432, а русских ноль. Разговорник пришёл одним источником на пять
      // языков сразу, и неполного среди них не осталось — пример пришлось
      // взять снаружи контента.
      final fr = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'fr',
        random: Random(5),
      );
      final pool = [for (final row in await content.phrasesUpTo(Tier.a0)) row.id];

      expect(await fr.build(circle, pool: pool), isNull);
      // А на языке с переводами тот же круг собирается — значит отказ именно
      // из-за перевода, а не из-за фразы или пула.
      expect(await builder.build(circle, pool: pool), isNotNull);
    });

    test('пула меньше чем на пять других круг не собирает', () async {
      // Пять — это ровно то, из чего исключают. Неполный круг ломает
      // знакомство: при четырёх вариантах исключать приходится из четырёх, и
      // угадывание дешевеет с 17 % до 25 %. Показать такой круг молча хуже,
      // чем пропустить фразу.
      const others = [
        'about_me_a0_02',
        'about_me_a0_03',
        'about_me_a0_04',
        'about_me_a0_05',
        'about_me_a0_06',
      ];

      expect(await builder.build(circle, pool: others.take(4).toList()), isNull);
      expect(await builder.build(circle, pool: others), isNotNull);
    });
  });

  group('весь корпус запущенного яруса', () {
    test('каждая фраза собирается в круг', () async {
      // Сплошным проходом по корпусу раньше проверялись знаки препинания: при
      // максимуме пропусков через плитку проходило каждое слово яруса, и надо
      // было убедиться, что точка остаётся в предложении. Плиток нет, а проход
      // ценен сам по себе — он ловит фразу, которую нельзя показать, до того
      // как она молча выпадет из уровня. Молча — потому что отказ сборки не
      // ошибка: кругов просто становится меньше.
      final rows = await content.phrasesUpTo(Tier.a0);
      final pool = [for (final row in rows) row.id];
      final native = await nativeTexts();

      var tagged = 0;
      for (final row in rows) {
        final question = await builder.build(
          PlannedCircle(
            itemId: row.id,
            mode: GameMode.pickTarget,
            isNew: false,
            lumens: 40,
          ),
          pool: pool,
        );

        expect(question, isNotNull, reason: '${row.id}: круг не собрался');
        expect(question!.options, hasLength(ScoreBalance.optionsPerCircle),
            reason: row.id);
        // Воспроизведение: в центре родной язык, вокруг изучаемый.
        expect(question.prompt, native[row.id], reason: row.id);
        expect(question.answer, row.sentence, reason: row.id);
        expect(question.tier, Tier.a0, reason: row.id);
        // Регистр приезжает кодом, а не текстом: строку к нему даёт
        // локализация. Пометка при этом необязательна — в разговорнике она
        // стоит там, где различие «ты/Вы» существенно, и таких фраз 185 из
        // 1500, из них 21 на A0. Проверяется поэтому не наличие, а то, что
        // пришёл код из набора: свободный текст показался бы игроку на языке
        // файла.
        if (question.promptTag != null) {
          tagged++;
          expect(promptTags, contains(question.promptTag), reason: row.id);
        }
      }

      // Проверка кода регистра стоит под `if`, и без этой строки она зеленела
      // бы **не сработав ни разу**: пометка необязательна, и корпус без
      // пометок прошёл бы проход молча. Здесь стояло «таких фраз 25 из 1000» —
      // число из прежнего словника, разошедшееся с корпусом на порядок
      // (185 из 1500, 21 на A0) и ничем не сторожившееся. Порог, а не
      // равенство: пометок можно добавить, но исчезнуть они не должны молча.
      expect(tagged, greaterThanOrEqualTo(15),
          reason: 'на A0 пометок регистра $tagged из ${rows.length} при '
              'измеренных 21 — проверка кода не сработала ни разу');

      // Проход обязан прочитать ярус, а не пустой список: A0 — это пять тем
      // по тридцать фраз, то есть сто пятьдесят. Порог, а не равенство: ярус
      // можно дописать, но усохнуть он не должен молча.
      //
      // Здесь стояло `>= 100` при пяти темах по двадцать — число из прежней
      // тысячи фраз. С корпусом на 1500 оно перестало охранять что-либо: треть
      // яруса могла пропасть, и проход всё равно зеленел бы.
      expect(rows.length, greaterThanOrEqualTo(150),
          reason: 'корпус усох — проход прочитал не то, что думает');
    });
  });

  group('заход', () {
    test('заход не расширяет круг: вариантов шесть на любом уровне', () async {
      // Надбавка вариантов от захода жила в сборщике и прибавлялась к каждому
      // кругу — включая тот, которому планировщик намеренно оставил один
      // вариант. С четвёртого уровня захода первый в жизни показ фразы
      // становился выбором из двух, с седьмого — из трёх.
      //
      // Шкалы вариантности больше нет вовсе, и охраняется теперь это:
      // `ClimbDifficulty` двигает порог «автоматизма» и смещение к трудным
      // механикам, а ширину круга не трогает — на полном круге держится
      // знакомство исключением.
      for (final level in [1, 4, 7, 12, 40]) {
        final session = await loader.level(
          now,
          difficulty: ClimbRules.difficultyFor(level),
        );
        expect(session.questions.where((q) => q.isNew), isNotEmpty,
            reason: 'уровень $level: знакомства не осталось');

        for (final q in session.questions) {
          expect(q.options, hasLength(ScoreBalance.optionsPerCircle),
              reason: 'уровень $level, ${q.itemId}: '
                  '${q.options.length} вариантов');
        }
      }
    });
  });

  group('после игры', () {
    test('сыгранные фразы возвращаются как повторы, а не как новые', () async {
      final repository = WordStateRepository(userDb);
      final session = await loader.level(now);

      // Играем первые пять кругов верно.
      for (final q in session.questions.take(5)) {
        await repository.applyAnswer(
          itemId: q.itemId,
          tier: q.tier,
          mode: q.mode,
          correct: true,
          latency: const Duration(milliseconds: 1400),
          now: now,
        );
      }

      // Через неделю звёзды потускнели и просятся на повтор.
      final later = now.add(const Duration(days: 7));
      final second = await loader.level(later);

      expect(second.reviews, greaterThan(0));
      final playedIds = session.questions.take(5).map((q) => q.itemId);
      final reviewedIds =
          second.questions.where((q) => !q.isNew).map((q) => q.itemId);
      expect(reviewedIds, containsAll(playedIds.toSet().take(1)));
    });

    test('шесть верных быстрых ответов уводят фразу на недели', () async {
      final repository = WordStateRepository(userDb);
      final phrases = await content.phrasesUpTo(Tier.a0);
      final id = phrases.first.id;

      // Доводим фразу до высокой яркости серией верных быстрых ответов,
      // каждый — в свой срок повторения.
      var at = now;
      for (var i = 0; i < 6; i++) {
        await repository.applyAnswer(
          itemId: id,
          tier: Tier.a0,
          mode: GameMode.pickTarget,
          correct: true,
          latency: const Duration(milliseconds: 700),
          now: at,
        );
        final state = await repository.load(id);
        at = state.dueAt() ?? at.add(const Duration(days: 1));
      }

      final state = await repository.load(id);
      // Фразу повторяли шесть раз подряд верно — она должна уйти далеко.
      expect(state.stability, greaterThan(10));
      expect(state.reps, 6);
    });
  });

  group('Восход', () {
    test('у нового игрока повторять нечего', () async {
      final session = await loader.sunrise(now);
      expect(session.isEmpty, isTrue);
    });

    test('после игры Восход показывает самые тусклые звёзды', () async {
      final repository = WordStateRepository(userDb);
      final phrases = await content.phrasesUpTo(Tier.a0);

      for (final phrase in phrases.take(4)) {
        await repository.applyAnswer(
          itemId: phrase.id,
          tier: Tier.a0,
          mode: GameMode.pickTarget,
          correct: true,
          latency: const Duration(milliseconds: 1400),
          now: now,
        );
      }

      final later = now.add(const Duration(days: 30));
      final session = await loader.sunrise(later);

      expect(session.isEmpty, isFalse);
      expect(session.newWords, 0);
      expect(session.questions.every((q) => !q.isNew), isTrue);

      // Порядок — от самых тусклых.
      final lumens = session.questions.map((q) => q.lumens).toList();
      final sorted = [...lumens]..sort();
      expect(lumens, sorted);
    });
  });
}
