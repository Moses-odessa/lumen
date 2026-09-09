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

  /// Уровень: новые слова вперемешку с повторами, в конце босс-фраза.
  ///
  /// [difficulty] — сложность уровня захода: доля продуктивных режимов,
  /// длина забега и число вариантов. `null` — первый уровень.
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
  /// Известное впереди, и на этом стоит знакомство. Новая фраза даётся среди
  /// пяти знакомых, и игрок приходит к ответу исключением — узнаёт остальные
  /// пять и понимает, какая шестая. Порядок пула это правило и выражает:
  /// сборщик берёт из его начала.
  ///
  /// Известной считается фраза ярче [ScoreBalance.knownForEliminationLm] —
  /// полоса «узнаёте, но не вспоминаете сами». Для исключения этого хватает:
  /// узнать пять знакомых строчек легче, чем вспомнить любую из них.
  ///
  /// **На первом уровне исключать не из чего, и это не поломка.** У нового
  /// игрока не знакомо ничего, поэтому пул добирается остальными фразами
  /// яруса, и первый круг честно оказывается выбором из шести незнакомых.
  /// Дальше пул наполняется сам.
  List<String> _optionPool(List<StudyItem> candidates, List<PhraseRow> all) {
    final known = candidates
        .where((c) => c.lumens >= ScoreBalance.knownForEliminationLm)
        .toList()
      ..sort((a, b) => b.lumens.compareTo(a.lumens));

    final ids = [for (final item in known) item.itemId];
    final seen = ids.toSet();
    for (final row in all) {
      if (seen.add(row.id)) ids.add(row.id);
    }
    return ids;
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
    List<String> pool,
  ) async {
    final questions = <CircleQuestion>[];
    for (final circle in plan) {
      final question = await builder.build(circle, pool: pool);
      if (question != null) questions.add(question);
    }
    return questions;
  }
}

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
