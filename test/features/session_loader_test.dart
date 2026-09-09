import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/data/local/app_database.dart';
import 'package:lumen/data/repositories/word_state_repository.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/prompt_tag.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/level_stage.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/features/game/application/question_builder.dart';
import 'package:lumen/features/game/application/session_loader.dart';

/// Сквозная проверка ядра: настоящий ассет `content.db`, настоящая
/// Drift-схема и настоящий планировщик. Именно здесь ловятся расхождения,
/// которых не видно ни в одном юнит-тесте по отдельности.
///
/// Единица изучения — фраза. Ассет несёт 432 немецких фразы и ровно столько
/// же украинских переводов; запущен один ярус A0 — тридцать шесть фраз, по
/// четыре на каждое из девяти созвездий.
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
///   самое с другой стороны и теперь перевёрнут: состав пяти других обязан
///   быть **одинаковым** при любом зерне, потому что берётся с начала
///   упорядоченного пула. Перенесён под новым именем.
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

    test('состав пяти других задаёт пул, а не зерно', () async {
      // Раньше здесь стоял обратный тест — «набор неверных вариантов меняется
      // от круга к кругу». Он охранял добор соседями по созвездию: список без
      // порядка плюс обрезка давали восьми концептам из двенадцати одну и ту
      // же четвёрку неверных вариантов в каждой сессии, и игрок учил не
      // слово, а то, что «эти четыре никогда не верны».
      //
      // Правило перевернулось вместе с механикой. Пять других — это не
      // дистракторы, а фразы, которые игрок уже знает, и берутся они с начала
      // упорядоченного пула именно потому, что там стоит самое знакомое.
      // Состав обязан быть одинаковым при любом зерне; зерно решает только
      // порядок — иначе верный вариант всегда стоял бы на одном месте круга,
      // и игрок отвечал бы, не читая.
      final pool = [for (final row in await content.phrasesUpTo(Tier.a0)) row.id];
      const circle = PlannedCircle(
        itemId: 'about_me_a0_01',
        mode: GameMode.pickNative,
        isNew: false,
        lumens: 0,
      );

      // Состав сравнивается склеенной строкой, а не множеством множеств:
      // у `Set` в Dart нет равенства по значению, и `Set<Set<String>>` считал
      // бы одинаковые составы разными элементами. Прежний тест на этом и
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
      }

      expect(compositions, hasLength(1),
          reason: 'состав вариантов зависит от зерна — значит пул тасуется '
              'до отбора, и вокруг новой фразы встают случайные');
      expect(answerPlaces.length, greaterThan(1),
          reason: 'верный вариант всегда на одном месте круга');
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
        // стоит там, где различие «ты/Вы» существенно, и таких фраз 25 из
        // 1000. Проверяется поэтому не наличие, а то, что пришёл код из
        // набора: свободный текст показался бы игроку на языке файла.
        if (question.promptTag != null) {
          expect(promptTags, contains(question.promptTag), reason: row.id);
        }
      }

      // Проход обязан прочитать ярус, а не пустой список: A0 — это пять тем
      // по двадцать фраз. Порог, а не равенство: ярус можно дописать, но
      // усохнуть он не должен молча.
      expect(rows.length, greaterThanOrEqualTo(100),
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
