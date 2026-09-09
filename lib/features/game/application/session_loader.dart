import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_service.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/word_state_repository.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/part_of_speech.dart';
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

  /// Забеги по этапам: знакомство → закрепление → проверка → напоминание →
  /// фразы. Уровень — это последовательность забегов, а не один марафон:
  /// комбо сбрасывается между ними, и в этом весь их смысл.
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
    final known = {for (final c in candidates) c.itemId};
    final reviews = SessionPlanner.pool(candidates, now);

    final fresh = await _freshWords(known);
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
      final questions = await _build(stage.circles);
      if (questions.isEmpty) continue;
      // Длинный этап режется на забеги: комбо должно сбрасываться, а полоса
      // прогресса — доходить до конца в обозримое время.
      final perRun =
          difficulty?.circlesPerRun ?? SessionBalance.circlesPerRunMin;
      for (final chunk in SessionPlanner.intoRuns(questions, perRun: perRun)) {
        runs.add(LoadedRun(stage: stage.stage, questions: chunk.toList()));
      }
    }

    // Фразы закрывают уровень отдельным коротким забегом: предложение
    // целиком — другой масштаб задачи, и мешать его со словами не стоит.
    //
    // Их две, и обе на одном материале: сначала заполнить пропуски, потом
    // собрать предложение из слов. Порядок не случаен — вторая механика
    // требует того же предложения по памяти, и увидеть его перед этим
    // полезнее, чем не увидеть.
    final plan = [for (final s in staged) ...s.circles];
    final phrases = await _phraseRuns(plan, difficulty);
    if (phrases.isNotEmpty) {
      runs.add(LoadedRun(stage: LevelStage.check, questions: phrases));
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

    final questions = await _build(staged.circles);
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
    final plan = SessionPlanner.sunrise(
      candidates: candidates,
      now: now,
      capabilities: capabilities,
      random: random,
      // Восход ограничен временем, а не числом кругов: берём с запасом и
      // останавливаемся по таймеру.
      limit: SessionBalance.sessionPoolSize,
    );

    final questions = await _build(plan);
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

  /// Слова яруса, которых игрок ещё не видел, в порядке частотности.
  ///
  /// Берутся только те, у которых форма есть **в обоих** языках пары. Это и
  /// есть то, что делает неполный язык безопасным: раньше нехватку закрывал
  /// английский, и украинский игрок получал в круге английское слово. Это не
  /// мягкая деградация, а другой вопрос вместо заданного. Теперь неполнота
  /// означает меньше слов, а не чужие.
  Future<List<StudyItem>> _freshWords(Set<String> known) async {
    final concepts = await builder.content.playableConcepts(
      targetLang: builder.targetLang,
      nativeLang: builder.nativeLang,
      upTo: tier,
    );
    return [
      for (final concept in concepts)
        // Служебные слова не становятся звёздами: круга из них нет. Они
        // живут только в механиках с пропуском.
        if (!known.contains(concept.id) && !isFunctionWord(concept.pos))
          StudyItem(
            itemId: concept.id,
            tier: Tier.fromCode(concept.tier),
            lumens: 0,
            isNew: true,
          ),
    ];
  }

  /// Собирает круги по плану.
  ///
  /// Сложность захода сюда больше не передаётся: число вариантов приходит в
  /// самом плане. Раньше здесь пересобирался сборщик с `extraOptions`, и он
  /// прибавлял их к каждому кругу — включая знакомство, которому планировщик
  /// намеренно оставил один вариант.
  Future<List<CircleQuestion>> _build(List<PlannedCircle> plan) async {
    final questions = <CircleQuestion>[];
    for (final circle in plan) {
      final question = await builder.build(circle);
      if (question != null) questions.add(question);
    }
    return questions;
  }

  /// Фразовый забег — из того созвездия, которого в уровне больше всего.
  Future<List<CircleQuestion>> _phraseRuns(
    List<PlannedCircle> plan,
    ClimbDifficulty? difficulty,
  ) async {
    if (plan.isEmpty) return const [];

    final byConstellation = <String, int>{};
    for (final circle in plan) {
      final concept = await builder.content.concept(circle.itemId);
      if (concept == null) continue;
      byConstellation.update(
        concept.constellation,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    if (byConstellation.isEmpty) return const [];

    final leading = byConstellation.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // Фраза выбирается **один раз** на оба круга.
    //
    // Комментарий выше обещал «обе на одном материале», а код звал
    // `buildPhrase` дважды — и тот каждый раз тянул случайную фразу из
    // созвездия заново. На четырёх фразах A0 они совпадали примерно в
    // четверти случаев, то есть обещание выполнялось иногда. Обещание,
    // которое выполняется иногда, хуже отсутствующего.
    final phrase = await builder.pickPhrase(
      constellation: leading,
      tier: tier,
    );
    if (phrase == null) return const [];

    final questions = <CircleQuestion>[];

    // Два круга на одном предложении, и различаются они глубиной, а не
    // механикой: сперва вынута часть слов, потом всё предложение. Раньше это
    // были две механики с двумя реализациями, и реализации расходились —
    // одна искала индекс через `indexOf`, другая через `_firstUnused`.
    final extra = difficulty?.extraOptions ?? 0;
    for (final gaps in [
      StageRules.gapsFor(LevelStage.check, extra: extra),
      SessionBalance.phraseGapsAll,
    ]) {
      final question = await builder.buildPhraseQuestion(
        phrase: phrase,
        // Фраза проверяет сборку предложения, а не отдельное слово, поэтому
        // скоростного множителя на ней нет.
        lumens: 0,
        // Заход доходит и до фразы. Пока не доходил, словесные круги
        // дорожали, а закрывающая уровень фраза — нет.
        gaps: gaps,
      );
      // Короткое предложение не даёт двух пропусков — это не поломка, а
      // отказ по длине.
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
