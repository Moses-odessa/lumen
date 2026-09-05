import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/word_state_repository.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scheduler/session_planner.dart';
import '../../../domain/scoring/balance.dart';
import 'question_builder.dart';

/// Готовый к игре набор кругов, уже разбитый на забеги.
class LoadedSession {
  const LoadedSession({
    required this.runs,
    required this.newWords,
    required this.reviews,
  });

  /// Забеги по 10–14 кругов. Уровень — это три забега и босс, а не один
  /// марафон: комбо сбрасывается между забегами, и в этом весь их смысл.
  final List<List<CircleQuestion>> runs;

  final int newWords;
  final int reviews;

  bool get isEmpty => runs.isEmpty;

  /// Все круги подряд — для тестов и статистики.
  List<CircleQuestion> get questions => [for (final run in runs) ...run];
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
  Future<LoadedSession> level(DateTime now) async {
    // Между запусками звёзды тускнеют, а база об этом не знает.
    await words.refreshLumens(now);

    final candidates = await words.candidates(now);
    final known = {for (final c in candidates) c.conceptId};
    final reviews = SessionPlanner.pool(candidates, now);

    final fresh = await _freshWords(known);
    final allowed = SessionPlanner.allowedNewWords(
      reviewCount: reviews.length,
      freePace: freePace,
    );

    final plan = SessionPlanner.level(
      reviews: reviews,
      fresh: fresh.take(allowed).toList(),
      capabilities: capabilities,
      random: random,
    );

    final questions = await _build(plan);
    final runs = SessionPlanner.intoRuns(questions)
        .map((run) => run.toList())
        .toList();

    // Босс закрывает уровень отдельным коротким забегом: фраза целиком —
    // это другой масштаб задачи, и мешать её со словами не стоит.
    final boss = await _boss(plan);
    if (boss != null) runs.add([boss]);

    return LoadedSession(
      runs: runs,
      newWords: fresh.take(allowed).length,
      reviews: reviews.length,
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
      // забегом до истечения двух минут.
      runs: questions.isEmpty ? const [] : [questions],
      newWords: 0,
      reviews: plan.length,
    );
  }

  /// Слова яруса, которых игрок ещё не видел, в порядке частотности.
  Future<List<WordCandidate>> _freshWords(Set<String> known) async {
    final concepts = await builder.content.conceptsUpTo(tier);
    return [
      for (final concept in concepts)
        if (!known.contains(concept.id))
          WordCandidate(
            conceptId: concept.id,
            tier: Tier.fromCode(concept.tier),
            lumens: 0,
            isNew: true,
          ),
    ];
  }

  Future<List<CircleQuestion>> _build(List<PlannedCircle> plan) async {
    final questions = <CircleQuestion>[];
    for (final circle in plan) {
      final question = await builder.build(circle);
      // Круг, который не собрался из-за нехватки контента, пропускается:
      // показать сломанный хуже, чем не показать вовсе.
      if (question != null) questions.add(question);
    }
    return questions;
  }

  /// Босс уровня — фраза из того созвездия, которого в уровне больше всего.
  Future<CircleQuestion?> _boss(List<PlannedCircle> plan) async {
    if (plan.isEmpty) return null;

    final byConstellation = <String, int>{};
    for (final circle in plan) {
      final concept = await builder.content.concept(circle.conceptId);
      if (concept == null) continue;
      byConstellation.update(
        concept.constellation,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    if (byConstellation.isEmpty) return null;

    final leading = byConstellation.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    return builder.buildBoss(
      constellation: leading,
      tier: tier,
      // Фраза проверяет сборку предложения, а не отдельное слово, поэтому
      // скоростного множителя на ней нет.
      lumens: 0,
    );
  }
}

final sessionLoaderProvider = Provider<SessionLoader>((ref) {
  final player = ref.watch(playerControllerProvider);
  final content = ref.watch(currentContentDatabaseProvider);

  return SessionLoader(
    words: ref.watch(wordStateRepositoryProvider),
    builder: QuestionBuilder(
      content: content,
      targetLang: player?.targetLang ?? defaultTargetLang,
      nativeLang: player?.nativeLang ?? defaultNativeLang,
    ),
    tier: player?.tier ?? Tier.a0,
    freePace: player?.freePace ?? false,
    capabilities: SessionCapabilities(
      audioEnabled: player?.soundEnabled ?? true,
    ),
    random: Random(),
  );
});
