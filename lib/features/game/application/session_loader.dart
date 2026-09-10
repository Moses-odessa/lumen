import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_service.dart';
import '../../../data/content/content_database.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/word_state_repository.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scheduler/level_stage.dart';
import '../../../domain/scheduler/session_planner.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/scoring/climb.dart';
import 'question_builder.dart';

/// Готовый к игре забег: этап, вопросы и цель, если этап на время.
class LoadedRun {
  const LoadedRun({
    required this.stage,
    required this.questions,
    this.goal,
  });

  final LevelStage stage;
  final List<CircleQuestion> questions;

  /// Цель спринта. `null` у обычных забегов.
  final SprintGoal? goal;

  bool get isEmpty => questions.isEmpty;
}

/// Готовый к игре набор кругов, уже разбитый на забеги по этапам.
class LoadedSession {
  const LoadedSession({
    required this.runs,
    required this.newWords,
    required this.reviews,
  });

  /// Забеги по этапам: знакомство → закрепление → проверка → напоминание.
  /// Уровень — это последовательность забегов, а не один марафон: комбо
  /// сбрасывается между ними, и в этом весь их смысл.
  ///
  /// Пятого забега, фразового, больше нет: фразы стали единицей изучения, и
  /// закрывать ими уровень отдельно значило бы закрывать его тем же, чем он
  /// и шёл.
  ///
  /// Раньше здесь лежали безымянные списки по 10–14 кругов, нарезанные из
  /// однородного плана. Игрок видел, что сложность то растёт, то падает, и
  /// не мог понять, по какому правилу.
  final List<LoadedRun> runs;

  final int newWords;
  final int reviews;

  bool get isEmpty => runs.isEmpty;

  /// Все круги подряд — для тестов и статистики.
  List<CircleQuestion> get questions =>
      [for (final run in runs) ...run.questions];
}

/// Собирает сессию из двух баз: план — по состоянию памяти из `user.db`,
/// содержимое кругов — из `content.db`.
///
/// Отдельный слой нужен потому, что планировщик — чистый Dart и про базы не
/// знает, а виджеты не должны знать про планировщик. Здесь они встречаются.
class SessionLoader {
  const SessionLoader({
    required this.words,
    required this.builder,
    required this.tier,
    required this.freePace,
    required this.capabilities,
    this.random,
  });

  final WordStateRepository words;
  final QuestionBuilder builder;
  final Tier tier;
  final bool freePace;
  final SessionCapabilities capabilities;
  final Random? random;

  /// Уровень: новые фразы вперемешку с повторами, по четырём этапам.
  ///
  /// Босс-фразы в конце нет и не было с тех пор, как уровень разделили на
  /// этапы: последний забег — «напоминание», самые тусклые повторы, и от
  /// прочих кругов он ничем не отличается. Обещание отдельного финального
  /// круга стоило дороже, чем выглядит: по нему считалась точность уровня —
  /// то есть заход поднимался или сбрасывался по одному кругу из тридцати.
  ///
  /// [difficulty] — сложность уровня захода: доля продуктивных режимов и
  /// длина забега. Числа вариантов в ней нет: их всегда шесть
  /// ([ScoreBalance.optionsPerCircle]). `null` — первый уровень.
  Future<LoadedSession> level(DateTime now, {ClimbDifficulty? difficulty}) async {
    // Между запусками звёзды тускнеют, а база об этом не знает.
    await words.refreshLumens(now);

    final candidates = await words.candidates(now);
    final seen = {for (final c in candidates) c.itemId};
    final reviews = SessionPlanner.pool(candidates, now);

    final all = await builder.content.phrasesUpTo(tier);
    final fresh = _freshPhrases(all, seen);
    final pool = _optionPool(candidates, all);
    final allowed = SessionPlanner.allowedNewWords(
      reviewCount: reviews.length,
      freePace: freePace,
    );

    final staged = SessionPlanner.level(
      reviews: reviews,
      fresh: fresh.take(allowed).toList(),
      capabilities: capabilities,
      random: random,
      difficulty: difficulty,
    );

    final runs = <LoadedRun>[];
    for (final stage in staged) {
      final questions = await _build(stage.circles, pool);
      if (questions.isEmpty) continue;
      // Длинный этап режется на забеги: комбо должно сбрасываться, а полоса
      // прогресса — доходить до конца в обозримое время.
      final perRun =
          difficulty?.circlesPerRun ?? SessionBalance.circlesPerRunMin;
      for (final chunk in SessionPlanner.intoRuns(questions, perRun: perRun)) {
        runs.add(LoadedRun(stage: stage.stage, questions: chunk.toList()));
      }
    }

    return LoadedSession(
      runs: runs,
      newWords: fresh.take(allowed).length,
      reviews: reviews.length,
    );
  }

  /// Спринт: финальная проверка пройденной темы на время.
  ///
  /// Отдельный вход, а не этап уровня: спринт появляется на завершении темы,
  /// а не каждый раз. Возвращает пустую сессию, если ярких слов нет — гонка
  /// на незнакомом материале учит панике, а не языку.
  Future<LoadedSession> sprintRun(
    DateTime now, {
    required int attempt,
    ClimbDifficulty? difficulty,
  }) async {
    await words.refreshLumens(now);
    final candidates = await words.candidates(now);
    final pool = _optionPool(candidates, await builder.content.phrasesUpTo(tier));

    final staged = SessionPlanner.sprint(
      candidates: candidates,
      goal: SprintGoal.attempt(attempt),
      capabilities: capabilities,
      random: random,
      difficulty: difficulty,
    );
    if (staged == null) {
      return const LoadedSession(runs: [], newWords: 0, reviews: 0);
    }

    final questions = await _build(staged.circles, pool);
    if (questions.isEmpty) {
      return const LoadedSession(runs: [], newWords: 0, reviews: 0);
    }

    return LoadedSession(
      runs: [
        LoadedRun(
          stage: LevelStage.sprint,
          questions: questions,
          goal: staged.goal,
        ),
      ],
      newWords: 0,
      reviews: questions.length,
    );
  }

  /// Восход: две минуты только повторений, самые тусклые первыми.
  Future<LoadedSession> sunrise(DateTime now) async {
    await words.refreshLumens(now);
    final candidates = await words.candidates(now);
    final pool = _optionPool(candidates, await builder.content.phrasesUpTo(tier));
    final plan = SessionPlanner.sunrise(
      candidates: candidates,
      now: now,
      capabilities: capabilities,
      random: random,
      // Восход ограничен временем, а не числом кругов: берём с запасом и
      // останавливаемся по таймеру.
      limit: SessionBalance.sessionPoolSize,
    );

    final questions = await _build(plan, pool);
    return LoadedSession(
      // Восход ограничен временем, а не числом кругов: он идёт одним
      // забегом до истечения двух минут. Этапа у него нет — это не уровень,
      // а возвращение яркости небу; помечен напоминанием, потому что именно
      // им и является.
      runs: questions.isEmpty
          ? const []
          : [LoadedRun(stage: LevelStage.reminder, questions: questions)],
      newWords: 0,
      reviews: plan.length,
    );
  }

  /// Фразы яруса, которых игрок ещё не видел, в авторском порядке.
  ///
  /// Порядок задаёт контент, а не частотность: у фразы частотности нет, а у
  /// темы есть последовательность, в которой её осмысленно проходить.
  /// Раньше здесь стоял отбор «форма есть в обоих языках пары» — он и делал
  /// неполный язык безопасным. Теперь то же самое обеспечивает сборщик:
  /// фраза без перевода круг не собирает, и неполнота означает меньше фраз,
  /// а не чужие.
  List<StudyItem> _freshPhrases(List<PhraseRow> all, Set<String> seen) => [
        for (final row in all)
          if (!seen.contains(row.id))
            StudyItem(
              itemId: row.id,
              tier: Tier.fromCode(row.tier),
              lumens: 0,
              isNew: true,
            ),
      ];

  /// Пул вариантов: из чего собирать пять других фраз круга.
  ///
  /// Загрузчик отвечает здесь за одно — за память. Он говорит, какие фразы
  /// игрок **знает** ([OptionPool.known]) и какие хотя бы **видел**
  /// ([OptionPool.seen]); чем эти фразы похожи на верный ответ и не окажется
  /// ли кандидат вторым верным ответом, решает сборщик. Оба вопроса про язык,
  /// и языки у них разные: похожесть считается на языке вариантов, потому что
  /// его игрок читает в плитках, а двусмысленность — на языке центра, потому
  /// что вопрос задаёт центр. Оба языка знает механика круга, а не память.
  ///
  /// Известной считается фраза ярче [ScoreBalance.knownForEliminationLm] —
  /// полоса «узнаёте, но не вспоминаете сами». Для исключения этого хватает:
  /// узнать пять знакомых строчек легче, чем вспомнить любую из них. Виденной
  /// считается любая, о которой в `user.db` есть запись, — включая ту, что
  /// потускнела до нуля: она **пройдена**, но узнать её игрок уже не может.
  /// Поэтому две метки, а не одна: знакомство исключением стоит на первой,
  /// правило «варианты — из пройденного» на второй.
  ///
  /// Порядок внутри списка — яркие впереди, дальше авторский порядок яруса.
  /// Это уже не главное правило, а разрешение ничьих: при равной похожести
  /// раньше стоит то, что ярче, и в круг оно попадёт скорее.
  ///
  /// **На первом уровне исключать не из чего, и это не поломка.** У нового
  /// игрока не знакомо ничего, обе метки пусты, пул — весь ярус, и первый
  /// круг честно оказывается выбором из шести незнакомых. Дальше метки
  /// наполняются сами.
  OptionPool _optionPool(List<StudyItem> candidates, List<PhraseRow> all) {
    final known = candidates
        .where((c) => c.lumens >= ScoreBalance.knownForEliminationLm)
        .toList()
      ..sort((a, b) => b.lumens.compareTo(a.lumens));

    final ids = [for (final item in known) item.itemId];
    final inPool = ids.toSet();
    for (final row in all) {
      if (inPool.add(row.id)) ids.add(row.id);
    }

    return (
      ids: ids,
      known: {for (final item in known) item.itemId},
      seen: {for (final item in candidates) item.itemId},
    );
  }

  /// Собирает круги по плану.
  ///
  /// Сложность захода сюда не передаётся: круг всегда шестивариантный, а
  /// заход повышает сложность порогом «автоматизма» и смещением к трудным
  /// механикам. Раньше здесь пересобирался сборщик с `extraOptions`, и он
  /// прибавлял варианты к каждому кругу — включая знакомство, которому
  /// планировщик намеренно оставил один вариант.
  Future<List<CircleQuestion>> _build(
    List<PlannedCircle> plan,
    OptionPool pool,
  ) async {
    final questions = <CircleQuestion>[];
    for (final circle in plan) {
      final question = await builder.build(
        circle,
        pool: pool.ids,
        known: pool.known,
        seen: pool.seen,
      );
      if (question != null) questions.add(question);
    }
    return questions;
  }
}

/// Пул вариантов вместе с тем, что игрок о них помнит.
///
/// Три поля, а не один упорядоченный список, и это следствие того, что
/// правила два. Порядок в [ids] выражал бы только одно из них: сперва
/// известные, потом остальные. Второе правило — «варианты максимально
/// совпадают словами с ответом» — порядком не выражается вовсе, потому что
/// зависит от того, какая фраза в центре и на каком языке показаны варианты.
/// Метки отвечают на вопрос про память, ранжирование внутри метки достаётся
/// сборщику круга.
typedef OptionPool = ({
  /// Все фразы, из которых можно брать варианты: ярус игрока плюс всё, что он
  /// уже проходил.
  List<String> ids,

  /// Те, что игрок знает достаточно, чтобы узнать в круге.
  Set<String> known,

  /// Те, что игрок хотя бы видел. Надмножество [known].
  Set<String> seen,
});

final sessionLoaderProvider = Provider<SessionLoader>((ref) {
  final player = ref.watch(playerControllerProvider);
  final content = ref.watch(currentContentDatabaseProvider);

  // Ярус урезается до запущенного, даже если в базе игрока записан выше.
  //
  // Это последняя линия обороны, а не единственная: калибровка тоже не
  // должна поднимать выше потолка. Но записи уже могут лежать на
  // устройствах, а невычитанный ярус — это текст, который человек не читал.
  // Синтез произнесёт его с той же готовностью, что и вычитанный, поэтому
  // звук больше не сигнализирует о готовности яруса — сигналит только этот
  // потолок.
  final maxTier = ref.watch(maxTierProvider);
  final tier = player?.tier ?? Tier.a0;

  return SessionLoader(
    words: ref.watch(wordStateRepositoryProvider),
    builder: QuestionBuilder(
      content: content,
      targetLang: player?.targetLang ?? defaultTargetLang,
      nativeLang: player?.nativeLang ?? defaultNativeLang,
    ),
    tier: tier.atMost(maxTier),
    freePace: player?.freePace ?? false,
    capabilities: SessionCapabilities(
      // Режим «Слух» — единственный, где без звука играть нельзя: в центре
      // круга нет ничего, кроме произнесённого слова. Раньше его выключала
      // только настройка; теперь ещё и отсутствие голоса в системе.
      //
      // Пока проверка не ответила, режим не планируется. Осторожность
      // дешевле ошибки: круг без звука — это круг без задания.
      audioEnabled: (player?.soundEnabled ?? true) &&
          (ref.watch(speechStatusProvider).value?.canSpeak ?? false),
    ),
    random: Random(),
  );
});
