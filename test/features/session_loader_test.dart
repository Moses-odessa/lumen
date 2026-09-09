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
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scheduler/session_planner.dart';
import 'package:lumen/domain/scoring/balance.dart';
import 'package:lumen/domain/scoring/climb.dart';
import 'package:lumen/features/game/application/question_builder.dart';
import 'package:lumen/features/game/application/session_loader.dart';

/// Сквозная проверка ядра: настоящий ассет `content.db`, настоящая
/// Drift-схема и настоящий планировщик. Именно здесь ловятся расхождения,
/// которых не видно ни в одном юнит-тесте по отдельности.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late AppDatabase userDb;
  late ContentDatabase content;
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
    loader = SessionLoader(
      words: WordStateRepository(userDb),
      builder: QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'ru',
        random: Random(1),
      ),
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

  group('первый уровень', () {
    test('собирается из настоящего контента', () async {
      final session = await loader.level(now);

      expect(session.isEmpty, isFalse);
      // У нового игрока повторять нечего — только новые слова.
      expect(session.reviews, 0);
      expect(session.newWords, 6);
    });

    test('у каждого круга есть центр, варианты и верный ответ на каждый слот',
        () async {
      final session = await loader.level(now);

      // Раньше здесь стояла оговорка «кроме кругов набора»: у поля ввода
      // вариантов не было вовсе, и на таких кругах проверку приходилось
      // пропускать. Набора больше нет, и оговорка ушла вместе с ним —
      // вариант выбирается во всех шести механиках без исключений.
      for (final q in session.questions) {
        expect(q.itemId, isNotEmpty);
        expect(q.options, isNotEmpty, reason: '${q.itemId}: круг без вариантов');
        expect(q.slotCount, greaterThanOrEqualTo(1), reason: q.itemId);

        // Верный ответ нужен каждому слоту, а не кругу целиком: круг — это
        // фраза с одним слотом, и одного индекса хватало бы лишь на четыре
        // механики из шести.
        for (var slot = 0; slot < q.slotCount; slot++) {
          expect(q.answers[slot], inInclusiveRange(0, q.options.length - 1),
              reason: '${q.itemId}: слот $slot указывает вне пула');
          expect(q.answerFor(slot), isNotEmpty,
              reason: '${q.itemId}: слот $slot без текста');
          expect(q.isCorrectFor(slot, q.answers[slot]), isTrue,
              reason: '${q.itemId}: слот $slot не признаёт свой же ответ');
        }

        // Центр круга — текст, звук или пустые места. Пустой центр без звука
        // и без слотов означал бы круг без задания.
        if (q.prompt.isEmpty) {
          expect(q.mode.needsAudio || q.mode == GameMode.buildPhrase, isTrue,
              reason: '${q.itemId}: пустой центр в механике ${q.mode.name}');
          if (q.mode.needsAudio) {
            expect(q.promptSpeech, isNotNull, reason: q.itemId);
          }
        }

        // Инвариант README: концепт без озвучки не проходит валидацию,
        // значит и в игре у ответа всегда есть, что произнести.
        expect(q.answerSpeech, isNotNull, reason: q.itemId);
      }
    });

    test('вариантов ровно столько, сколько круг обещает игроку', () async {
      final session = await loader.level(now);

      for (final q in session.questions) {
        if (q.isNew) {
          // Знакомство — не проверка, а показ: выбирать не из чего.
          expect(q.options.length, SessionBalance.introductionOptions,
              reason: '${q.itemId}: знакомство с выбором');
          continue;
        }
        if (q.mode.isPhrase) {
          // У фразы вокруг лежат ровно вынутые слова, поэтому пул равен числу
          // пропусков — от двух до всех слов предложения. Потолка у него нет:
          // его задаёт длина предложения, а не ширина экрана.
          expect(q.options.length, q.slotCount,
              reason: '${q.itemId}: в пуле не только вынутые слова');
          expect(q.options.length,
              greaterThanOrEqualTo(SessionBalance.phraseGapsMin),
              reason: '${q.itemId}: пропусков меньше двух');
          continue;
        }
        expect(q.options.length, greaterThanOrEqualTo(3),
            reason: '${q.itemId}: слишком мало вариантов');
        expect(q.options.length, lessThanOrEqualTo(ScoreBalance.optionsMax),
            reason: '${q.itemId}: круг шире экрана');
      }
    });

    test('варианты в круге не повторяются', () async {
      final session = await loader.level(now);

      // «Собери предложение» исключён намеренно: слово может повторяться в
      // самом предложении («Ich habe ... und ich ...»), и два одинаковых
      // слова в пуле там не поломка, а текст. Различает их номер слота —
      // ровно поэтому ответы хранятся индексами, а не формами.
      final choices =
          session.questions.where((q) => q.mode != GameMode.buildPhrase);
      for (final q in choices) {
        final lowered = q.options.map((o) => o.toLowerCase()).toList();
        expect(lowered.toSet().length, lowered.length,
            reason: '${q.itemId}: дубли среди вариантов');
      }
    });

    test('первый показ нового слова — понимание, центр на изучаемом', () async {
      final session = await loader.level(now);
      final first = session.questions.firstWhere((q) => q.isNew);

      expect(first.mode, GameMode.pickNative);
      // Понимание: в центре немецкий, вокруг русский.
      expect(first.prompt, isNotEmpty);
      final lexeme = await content.lexeme(first.itemId, 'de');
      expect(first.prompt, contains(lexeme!.form));
    });

    test('знакомство доходит до игрока даже без дистракторов', () async {
      final session = await loader.level(now);

      // Круг с одним вариантом стал законным, и это не мелочь: прежде
      // сборщик возвращал `null`, не набрав двух дистракторов, и знакомство
      // с редким словом молча исчезало из уровня. Проверяется поэтому не
      // форма круга, а доставка: все обещанные новые слова на месте.
      final introduced =
          session.questions.where((q) => q.isNew).map((q) => q.itemId).toSet();
      expect(introduced.length, session.newWords);

      for (final q in session.questions.where((q) => q.isNew)) {
        expect(q.options.length, 1, reason: q.itemId);
        expect(q.answerIndex, 0, reason: q.itemId);
        expect(q.isCorrectFor(0, 0), isTrue, reason: q.itemId);
        expect(q.isCorrectFor(0, 1), isFalse, reason: q.itemId);
      }
    });

    test('уровень закрывается фразовым забегом', () async {
      final session = await loader.level(now);
      final phrases = session.runs.last.questions;

      // Фраза — другой масштаб задачи, и мешать её со словами не стоит:
      // отдельный короткий забег в конце.
      expect(phrases, isNotEmpty);
      expect(phrases.every((q) => q.mode.isPhrase), isTrue,
          reason: 'в фразовом забеге оказалось слово');
      expect(
        session.runs
            .take(session.runs.length - 1)
            .expand((run) => run.questions)
            .every((q) => q.mode.isWordMode),
        isTrue,
        reason: 'фраза попала в забег со словами',
      );

      final modes = phrases.map((q) => q.mode).toList();
      expect(modes, contains(GameMode.fillGaps));
      // Порядок не случаен: сначала пропуски, потом сборка предложения из
      // слов. Сборка по памяти труднее, и ставить её первой значило бы
      // спрашивать то, чего игрок в этом уровне ещё не видел.
      if (modes.contains(GameMode.buildPhrase)) {
        expect(modes.indexOf(GameMode.fillGaps),
            lessThan(modes.indexOf(GameMode.buildPhrase)));
      }

      for (final q in phrases.where((q) => q.mode == GameMode.fillGaps)) {
        expect(q.prompt, contains('_____'));
        // В пуле обязаны быть ответы всех пропусков: игрок тянет каждое
        // слово к своему месту из одного набора сверху и снизу.
        for (var slot = 0; slot < q.slotCount; slot++) {
          expect(q.options, contains(q.answerFor(slot)));
        }
      }
    });

    test('собранная фраза совпадает с тем, что будет произнесено', () async {
      final session = await loader.level(now);

      for (final q in session.runs.last.questions) {
        // `assembled` — это то, что игрок услышит, закрыв последний слот.
        // Расхождение с озвучкой значит, что он услышит не ту фразу, которую
        // собрал.
        expect(q.assembled, q.answerSpeech, reason: q.itemId);
        expect(q.assembled, isNot(contains('_____')), reason: q.itemId);
      }
    });

    test('одно слово не идёт двумя кругами подряд', () async {
      final session = await loader.level(now);
      // Фразовый забег исключён: обе его механики стоят на одном материале,
      // и повтор опорного концепта там задуман, а не проспан планировщиком.
      // Прежний тест добивался того же, отбрасывая последний круг, — тогда
      // фраза была одна.
      final ids = session.questions
          .where((q) => q.mode.isWordMode)
          .map((q) => q.itemId)
          .toList();

      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]), reason: 'позиция $i');
      }
    });
  });

  group('добор соседями', () {
    test('набор неверных вариантов меняется от круга к кругу', () async {
      // Третий случай одной и той же ошибки: список без порядка плюс
      // обрезка. `siblingForms` порядка не задаёт, в созвездии ровно
      // двенадцать концептов при лимите двенадцать, а `_assembleOptions`
      // берёт первые `wanted - 1`. На родном языке своих дистракторов почти
      // ни у кого нет — и восемь концептов из двенадцати получали одну и ту
      // же четвёрку неверных вариантов в каждой сессии. Игрок учил при этом
      // не слово, а то, что «эти четыре никогда не верны».
      //
      // Финальный `shuffle` в `_assembleOptions` это не лечит: он тасует
      // показанное, а не выбранное. Поэтому тест смотрит на **состав**, а не
      // на порядок.
      final sets = <Set<String>>[];
      for (var seed = 0; seed < 12; seed++) {
        final builder = QuestionBuilder(
          content: content,
          targetLang: 'de',
          nativeLang: 'uk',
          random: Random(seed),
        );
        final question = await builder.build(const PlannedCircle(
          itemId: 'checkout_place',
          mode: GameMode.pickNative,
          isNew: false,
          lumens: 0,
          options: 4,
        ));
        expect(question, isNotNull);
        sets.add(question!.options.toSet());
      }

      expect(sets.toSet().length, greaterThan(1),
          reason: 'состав вариантов один и тот же при любом зерне — значит '
              'соседи снова берутся по фиксированному порядку');
    });
  });

  group('глубина пропусков', () {
    test('пропусков ровно столько, сколько попросили', () async {
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(7),
      );

      // «Город»: все его фразы A0 длиннее порога, значит любая глубина от
      // двух до всех слов на них достижима.
      for (final gaps in [2, 3, 4]) {
        final question = await builder.buildPhrase(
          constellation: 'city',
          tier: Tier.a0,
          lumens: 0,
          gaps: gaps,
        );
        expect(question, isNotNull, reason: 'глубина $gaps');
        expect(question!.slotCount, gaps, reason: 'глубина $gaps');
        // Вокруг лежат ровно вынутые слова — ни одного постороннего.
        expect(question.options.length, gaps, reason: 'глубина $gaps');
      }
    });

    test('ноль означает все слова, а не ни одного', () async {
      // Ноль — максимум шкалы, то самое «собери предложение». Прогон его
      // через `clamp(phraseGapsMin, total)` превращал самую трудную настройку
      // в самую лёгкую, и молча: круг проходился, пропусков было два вместо
      // всех, а заметить это можно было только по числу слотов.
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(11),
      );
      final question = await builder.buildPhrase(
        constellation: 'city',
        tier: Tier.a0,
        lumens: 0,
        gaps: SessionBalance.phraseGapsAll,
      );

      expect(question, isNotNull);
      // Все слова вынуты: в скелете не осталось ничего, кроме знаков
      // препинания. Знаки остаются на месте — они принадлежат предложению, а
      // не слову, и на плитку не уезжают.
      expect(
        question!.prompt
            .replaceAll('_____', '')
            .replaceAll(RegExp(r'[\s.,!?;:…«»„“”()\[\]]'), ''),
        isEmpty,
      );
      expect(question.options.length, question.slotCount);
      expect(question.slotCount,
          greaterThan(SessionBalance.phraseGapsMin),
          reason: 'предложение из двух слов не отличило бы максимум от минимума');
    });

    test('слово, которому учит фраза, вынимается всегда', () async {
      // Иначе круг перестаёт проверять то слово, ради которого существует, —
      // а память всё равно запишется против него.
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(3),
      );
      final phrase = await builder.pickPhrase(
        constellation: 'city',
        tier: Tier.a0,
      );
      expect(phrase, isNotNull);

      final answers = await content.phraseAnswers(phrase!.id);
      final question = await builder.buildPhraseQuestion(
        phrase: phrase,
        lumens: 0,
        gaps: SessionBalance.phraseGapsMin,
      );

      expect(question, isNotNull);
      for (final answer in answers) {
        // Плитка несёт слово, а знак препинания остаётся в предложении.
        // Заглавная при этом на плитке остаётся: это орфография слова в этом
        // предложении, и ей сборка как раз учит.
        expect(
          question!.options.any((o) => o.contains(answer)),
          isTrue,
          reason: 'слово фразы «$answer» не вынуто: ${question.options}',
        );
      }
    });
  });

  group('знаки препинания', () {
    test('знак остаётся в предложении, а на плитке — слово', () async {
      // С устройства: плитка читалась как «Penicillin.» — со точкой, то есть
      // вместе с концом предложения. Игрок видел, куда её ставить, ещё не
      // решив задание, а обещание при этом было неверное: точка принадлежит
      // предложению, как запятая и вопросительный знак, а не слову.
      //
      // Проверяется по всему запущенному корпусу и на самой большой глубине:
      // при максимуме пропусков вынуто каждое слово, значит каждое слово
      // корпуса проходит через плитку.
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(17),
      );

      final marks = RegExp(r'^[.,!?;:…«»„“”()\[\]]|[.,!?;:…«»„“”()\[\]]\$');
      var checked = 0;

      for (final constellation in await content.constellations()) {
        final phrases = await content.phrasesFor(
          constellation,
          Tier.a0,
          lang: 'de',
        );
        for (final phrase in phrases) {
          final question = await builder.buildPhraseQuestion(
            phrase: phrase,
            lumens: 0,
            gaps: SessionBalance.phraseGapsAll,
          );
          if (question == null) continue; // короткие отбрасывает выбор
          checked++;

          for (final option in question.options) {
            expect(marks.hasMatch(option), isFalse,
                reason: '${phrase.id}: на плитке знак препинания — «\$option»');
          }

          // И главное: собранное предложение по-прежнему то самое. Знак не
          // потерялся и не удвоился — он остался в скелете там, где стоял.
          expect(question.assembled, question.answerSpeech,
              reason: '${phrase.id}: сборка разошлась с предложением');
        }
      }

      expect(checked, greaterThan(20), reason: 'корпус не прочитан');
    });

    test('дефис остаётся частью слова, а запятая при нём — нет', () async {
      // «Renten-, Kranken- und Pflegekasse gehören zur Sozialversicherung.» —
      // единственное место в корпусе, где на краю слова стоят сразу два
      // знака. Дефис здесь часть слова, а не знак при нём: снять надо
      // запятую и только её.
      final row = await content.phrase('work_b2_socialinsurance');
      if (row == null) return; // фраза живёт на незапущенном ярусе

      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(19),
      );
      final question = await builder.buildPhraseQuestion(
        phrase: row,
        lumens: 0,
        gaps: SessionBalance.phraseGapsAll,
      );

      expect(question, isNotNull);
      expect(question!.options, contains('Renten-'));
      expect(question.options, contains('Kranken-'));
      expect(question.assembled, question.answerSpeech);
    });
  });

  group('фраза, которую нельзя показать', () {
    test('короткое предложение не выбирается вовсе', () async {
      // «Ich trinke Wasser.» — три слова при пороге четыре. Раньше его
      // отбрасывала сборка, возвращая `null`, а загрузчик молча пропускал
      // круг: уровень «Еды» заканчивался без обеих закрывающих фраз, и
      // заметить это было нельзя — ошибки нет, просто кругов меньше. В
      // калибровке было хуже: `null` превращался в автоматический неверный
      // ответ на невиданный вопрос, то есть в потерянный ярус.
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(5),
      );

      // Все фразы «Еды» на A0 должны быть выбираемы: короткие отбрасывает
      // выбор, а не сборка, значит выбранная всегда собирается.
      for (var seed = 0; seed < 20; seed++) {
        final b = QuestionBuilder(
          content: content,
          targetLang: 'de',
          nativeLang: 'uk',
          random: Random(seed),
        );
        final phrase =
            await b.pickPhrase(constellation: 'food', tier: Tier.a0);
        expect(phrase, isNotNull, reason: 'зерно $seed');
        final question = await b.buildPhraseQuestion(
          phrase: phrase!,
          lumens: 0,
          gaps: SessionBalance.phraseGapsAll,
        );
        expect(question, isNotNull,
            reason: 'зерно $seed: выбрана фраза, которую не собрать — '
                '${phrase.id}');
      }

      expect(builder, isNotNull);
    });

    test('частичный круг оставляет хоть одно слово на месте', () async {
      // Уровень закрывается двумя кругами на одном предложении: сперва часть
      // слов, потом всё. На коротких фразах при заходе от четвёртого уровня
      // запрошенная глубина упиралась в длину, и оба круга вынимали всё —
      // обещанное «сперва часть, потом целиком» превращалось в «целиком,
      // целиком».
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(9),
      );
      final phrase =
          await builder.pickPhrase(constellation: 'transport', tier: Tier.a0);
      expect(phrase, isNotNull);

      // Глубина заведомо больше длины любой фразы A0.
      final partial = await builder.buildPhraseQuestion(
        phrase: phrase!,
        lumens: 0,
        gaps: 99,
      );
      final full = await builder.buildPhraseQuestion(
        phrase: phrase,
        lumens: 0,
        gaps: SessionBalance.phraseGapsAll,
      );

      expect(partial, isNotNull);
      expect(full, isNotNull);
      expect(partial!.slotCount, lessThan(full!.slotCount),
          reason: 'частичный круг совпал с полным');
      // В скелете частичного осталось хоть одно слово.
      expect(partial.prompt.replaceAll('_____', '').trim(), isNotEmpty);
    });
  });

  group('заявленный порядок слов', () {
    test('принимается и забегом, и калибровкой одинаково', () async {
      // Две реализации «верен ли ответ на фразу» расходились: забег собирал
      // предложение и сверял со списком принимаемых порядков, а калибровка
      // сверяла по слотам — то есть заявленные порядки игнорировала. Пока
      // калибровка спрашивала только минимальную глубину, разница не
      // проявлялась; первый же порядок, укладывающийся в два пропуска, дал бы
      // «неверно» на верном ответе при замере уровня.
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'uk',
        random: Random(4),
      );
      final phrases = await content.phrasesFor('health', Tier.a0, lang: 'de');
      final phrase = phrases.firstWhere((p) => p.id == 'doctor_a0_help');

      final question = await builder.buildPhraseQuestion(
        phrase: phrase,
        lumens: 0,
        gaps: SessionBalance.phraseGapsAll,
      );
      expect(question, isNotNull);
      expect(question!.accepted, isNotEmpty,
          reason: 'фраза заявляет порядок, а до вопроса он не доехал');

      // Заявленный порядок собирается из тех же слов и принимается.
      final declared = question.accepted
          .firstWhere((o) => o != question.assembled, orElse: () => '');
      expect(declared, isNotEmpty);
      expect(question.acceptsAssembly(declared), isTrue);

      // А переставленное наугад — нет.
      final scrambled = question.options.reversed.join(' ');
      expect(question.acceptsAssembly(scrambled), isFalse);
    });
  });

  group('добор соседями на больших созвездиях', () {
    test('соседи не обрезаются запросом', () async {
      // Третий случай одного класса, найденный до того, как выстрелил.
      // `siblingForms` обрезал запросом с `limit: 12` — «в созвездии ровно
      // двенадцать концептов». Верно для A0 и A1; на A2 и выше их двадцать
      // четыре, и запрос отдавал половину, выбранную индексом SQLite. Одну и
      // ту же половину навсегда, а перемешивание у вызывающего тасует уже
      // выбранное.
      final all = await content.siblingForms(
        constellation: 'health',
        tier: 'a2',
        lang: 'de',
        excludeConceptId: '',
      );
      final onTier = (await content.conceptsFor('health', Tier.a2))
          .where((c) => c.tier == 'a2')
          .length;

      expect(onTier, greaterThan(12),
          reason: 'ярус мельче лимита — обрезка не проявилась бы');
      expect(all.length, onTier,
          reason: 'запрос вернул не всех соседей яруса');
    });
  });

  group('многослотовая фраза', () {
    test('каждый слот знает только свой вариант', () async {
      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'ru',
        random: Random(3),
      );
      // «Город» взят не наугад: все его фразы A0 длиннее порога
      // `phraseMinWords`, поэтому слотов гарантированно несколько — на одном
      // слоте проверять различимость слотов было бы нечем.
      final question = await builder.buildPhrase(
        constellation: 'city',
        tier: Tier.a0,
        lumens: 0,
        gaps: SessionBalance.phraseGapsAll,
      );

      expect(question, isNotNull);
      expect(question!.slotCount,
          greaterThanOrEqualTo(SessionBalance.phraseMinWords));
      expect(question.isSingleSlot, isFalse);

      for (var slot = 0; slot < question.slotCount; slot++) {
        for (var option = 0; option < question.options.length; option++) {
          // Верным признаётся вариант с тем же **текстом**, а не только с тем
          // же номером: слово в предложении может повторяться, и две
          // неотличимые плитки взаимозаменяемы.
          expect(
            question.isCorrectFor(slot, option),
            question.options[option] == question.answerFor(slot),
            reason: 'слот $slot, вариант $option',
          );
        }
      }

      // Слот вне шаблона не признаёт ничего: лишнее место на экране не
      // должно засчитываться верным.
      expect(question.isCorrectFor(question.slotCount, 0), isFalse);
      expect(question.isCorrectFor(-1, 0), isFalse);

      // Порядок слов — это и есть задание: собранное предложение обязано
      // совпасть с озвучкой целиком. При максимуме пропусков в пуле лежит всё
      // предложение, поэтому слов в нём столько же, сколько слотов.
      expect(question.assembled, question.answerSpeech);
      expect(question.assembled.split(' ').length, question.slotCount);
    });
  });

  group('вид дистракторов', () {
    test('приходит с кругом, а не выводится из механики', () async {
      final concepts = await content.conceptsUpTo(Tier.a0);
      String? itemId;
      var far = const <String>[];
      var near = const <String>[];
      for (final concept in concepts) {
        final thematic = await content.distractorsFor(
            concept.id, 'de', DistractorKind.far.code);
        final phonetic = await content.distractorsFor(
            concept.id, 'de', DistractorKind.near.code);
        if (thematic.isNotEmpty && phonetic.isNotEmpty) {
          itemId = concept.id;
          far = thematic.map((d) => d.form).toList();
          near = phonetic.map((d) => d.form).toList();
          break;
        }
      }
      expect(itemId, isNotNull,
          reason: 'в de.db нет концепта с обоими видами дистракторов');

      final builder = QuestionBuilder(
        content: content,
        targetLang: 'de',
        nativeLang: 'ru',
        random: Random(7),
      );
      // Механика у обоих кругов одна и та же. Раньше «созвучные» означали
      // другой режим — «Тесный круг», — и попросить их, не меняя режима, было
      // нечем. Теперь это параметр круга, и разница видна на одной механике.
      final base = PlannedCircle(
        itemId: itemId!,
        mode: GameMode.pickTarget,
        isNew: false,
        lumens: 60,
      );
      final thematic =
          await builder.build(base.copyWith(distractorKind: DistractorKind.far));
      final phonetic = await builder
          .build(base.copyWith(distractorKind: DistractorKind.near));

      expect(thematic, isNotNull);
      expect(phonetic, isNotNull);
      expect(thematic!.mode, phonetic!.mode);

      // Заданные руками имеют приоритет над добором по созвездию, поэтому
      // весь ручной набор нужного вида обязан оказаться в круге.
      expect(phonetic.options, containsAll(near));
      expect(thematic.options, containsAll(far));
      // Созвучные подобраны по фонетике и соседями по теме не бывают —
      // значит в тематическом круге им взяться неоткуда.
      for (final form in near) {
        expect(thematic.options, isNot(contains(form)), reason: form);
      }
    });
  });

  group('после игры', () {
    test('сыгранные слова возвращаются как повторы, а не как новые', () async {
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

    test('режим повтора растёт вместе с яркостью слова', () async {
      final repository = WordStateRepository(userDb);
      final concepts = await content.conceptsUpTo(Tier.a0);
      final id = concepts.first.id;

      // Доводим слово до высокой яркости серией верных быстрых ответов.
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
      // Слово повторяли шесть раз подряд верно — оно должно уйти далеко.
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
      final concepts = await content.conceptsUpTo(Tier.a0);

      for (final concept in concepts.take(4)) {
        await repository.applyAnswer(
          itemId: concept.id,
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

  group('починенное вехой M10', () {
    // Каждый тест здесь закрывает дефект, найденный при переносе тестов на
    // новый набор механик. Все шесть были в моём собственном коде, и ни один
    // не падал: они делали игру тише — хуже, но работающей.

    test('обе фразовые механики стоят на одном предложении', () async {
      // Комментарий в загрузчике обещал «обе на одном материале», а код звал
      // сборку дважды, и та каждый раз тянула случайную фразу заново. На
      // четырёх фразах A0 они совпадали примерно в четверти случаев —
      // обещание выполнялось иногда. Выполняющееся иногда обещание хуже
      // отсутствующего: игрок не может опереться на то, чего не понимает.
      final session = await loader.level(now);
      final phrases =
          session.questions.where((q) => q.mode.isPhrase).toList();

      // «Собери предложение» может не собраться из короткой фразы — это
      // отказ по длине, а не поломка. Проверяем, когда собрались обе.
      if (phrases.length < 2) return;

      expect(phrases.map((q) => q.mode).toSet(),
          {GameMode.fillGaps, GameMode.buildPhrase});
      expect(
        phrases.map((q) => q.answerSpeech).toSet(),
        hasLength(1),
        reason: 'механики встали на разные предложения: '
            '${phrases.map((q) => q.answerSpeech).toList()}',
      );
    });

    test('знакомство остаётся показом на любом уровне захода', () async {
      // Надбавка вариантов от захода жила в сборщике и прибавлялась к
      // каждому кругу — включая тот, которому планировщик намеренно оставил
      // один вариант. С четвёртого уровня захода первый в жизни показ слова
      // становился выбором из двух, с седьмого — из трёх: показ превращался
      // в проверку слова, которого игрок ещё не видел.
      for (final level in [1, 4, 7, 12, 40]) {
        final session = await loader.level(
          now,
          difficulty: ClimbRules.difficultyFor(level),
        );
        final introductions =
            session.questions.where((q) => q.isNew).toList();
        expect(introductions, isNotEmpty, reason: 'уровень $level');

        for (final question in introductions) {
          expect(
            question.options.length,
            SessionBalance.introductionOptions,
            reason: 'уровень $level: у знакомства '
                '${question.options.length} вариантов',
          );
        }
      }
    });

    test('заход расширяет круг и на словах, и на фразе', () async {
      // Обратная сторона той же ошибки: `_phraseRuns` не получал сложность
      // вовсе, и пул фразы оставался шириной в шесть при любом уровне.
      // Словесные круги дорожали, а закрывающая уровень фраза — нет.
      final easy = await loader.level(now);
      final hard = await loader.level(
        now,
        difficulty: ClimbRules.difficultyFor(40),
      );

      // Мерить надо ту механику, чья ширина и есть параметр сложности.
      // «Собери предложение» под это не подходит: его пул — слова самого
      // предложения, и от захода он не зависит вовсе. Пока фразы были
      // короткими, разницы не было; после того как девятнадцать шаблонов
      // получили придаточное, пул сборки дорос до девяти — и «самый широкий
      // фразовый круг» стал мерить длину предложения вместо сложности.
      int widest(LoadedSession s, bool Function(CircleQuestion) pick) {
        final matching =
            s.questions.where(pick).map((q) => q.options.length);
        return matching.isEmpty ? 0 : matching.reduce(max);
      }

      bool words(CircleQuestion q) => q.mode.isWordMode && !q.isNew;
      bool gaps(CircleQuestion q) => q.mode == GameMode.fillGaps && !q.isNew;

      expect(widest(hard, words), greaterThan(widest(easy, words)),
          reason: 'словесные круги не расширились');
      if (widest(easy, gaps) > 0) {
        expect(widest(hard, gaps), greaterThan(widest(easy, gaps)),
            reason: 'пропуски не расширились вместе с заходом');
      }
    });

    test('повторённое слово во фразе получает свой вариант пула', () async {
      // `_fillGaps` искал индекс через `indexOf`: два пропуска с одним и тем
      // же словом получали один индекс, спорили за один вариант, а второе
      // такое же слово в пуле оставалось недостижимым. Рядом, в сборке
      // предложения из слов, от этого стояла защита — два сборщика фраз
      // расходились друг с другом.
      //
      // В контенте фраз с повторённым ответом пока нет, поэтому проверяется
      // общее свойство: у каждого слота свой индекс.
      final session = await loader.level(now);
      for (final question in session.questions.where((q) => q.mode.isPhrase)) {
        expect(
          question.answers.toSet(),
          hasLength(question.answers.length),
          reason: '${question.itemId}: слоты делят один вариант '
              '(${question.answers})',
        );
      }
    });
  });
}
