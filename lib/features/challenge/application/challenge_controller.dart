import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/audio/audio_service.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/retention/sparks.dart';
import 'challenge_client.dart';

/// База CDN с ночными вызовами. Задаётся при сборке:
/// `--dart-define=CHALLENGE_BASE_URL=https://...`.
const String challengeBaseUrl =
    String.fromEnvironment('CHALLENGE_BASE_URL');

/// Что показывает экран вызова.
enum ChallengeStage {
  /// Загружаем файл дня.
  loading,

  /// Вызова нет: нет сети, нет файла или CDN не настроен.
  unavailable,

  /// Сегодня уже играли. Один заход в день — правило, а не ограничение
  /// ресурса: вызов должен быть событием, а не бесконечным режимом.
  alreadyPlayed,

  /// Идёт.
  running,

  /// Закончился.
  finished,
}

/// Один вопрос вызова: слово на изучаемом языке и четыре варианта на родном.
class ChallengeQuestion {
  const ChallengeQuestion({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    this.audioId,
  });

  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String? audioId;
}

class ChallengeState {
  const ChallengeState({
    required this.stage,
    this.questions = const [],
    this.index = 0,
    this.correct = 0,
    this.remaining = Duration.zero,
    this.total = 0,
    this.elapsed = Duration.zero,
    this.sparksEarned = 0,
    this.previous,
  });

  final ChallengeStage stage;
  final List<ChallengeQuestion> questions;
  final int index;
  final int correct;
  final Duration remaining;
  final int total;
  final Duration elapsed;
  final int sparksEarned;

  /// Результат прошлого захода — показывается, если сегодня уже играли.
  final DailyChallengeResultRow? previous;

  ChallengeQuestion? get current =>
      index < questions.length ? questions[index] : null;

  int get answered => index;

  ChallengeState copyWith({
    ChallengeStage? stage,
    List<ChallengeQuestion>? questions,
    int? index,
    int? correct,
    Duration? remaining,
    int? total,
    Duration? elapsed,
    int? sparksEarned,
    DailyChallengeResultRow? previous,
  }) =>
      ChallengeState(
        stage: stage ?? this.stage,
        questions: questions ?? this.questions,
        index: index ?? this.index,
        correct: correct ?? this.correct,
        remaining: remaining ?? this.remaining,
        total: total ?? this.total,
        elapsed: elapsed ?? this.elapsed,
        sparksEarned: sparksEarned ?? this.sparksEarned,
        previous: previous ?? this.previous,
      );
}

/// Ночной вызов: 20 пар, 60 секунд, один заход.
///
/// Он один и тот же для всех игроков языка в этот день — именно поэтому его
/// можно раздавать статическим файлом и именно поэтому результат интересно
/// с кем-то сравнить.
class ChallengeController extends Notifier<ChallengeState> {
  Timer? _ticker;
  DateTime _startedAt = DateTime.now();

  @override
  ChallengeState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const ChallengeState(stage: ChallengeStage.loading);
  }

  Future<void> load() async {
    _ticker?.cancel();
    state = const ChallengeState(stage: ChallengeStage.loading);

    final player = ref.read(playerControllerProvider);
    final lang = player?.targetLang ?? defaultTargetLang;
    final now = DateTime.now();
    final day = ChallengeClient.dayKey(now);

    final db = ref.read(appDatabaseProvider);
    try {
      final previous = await db.loadChallengeResult(day);
      if (previous != null) {
        state = ChallengeState(
          stage: ChallengeStage.alreadyPlayed,
          previous: previous,
        );
        return;
      }
    } catch (_) {
      // Нет базы — просто дадим сыграть.
    }

    final challenge =
        await ChallengeClient(baseUrl: challengeBaseUrl).load(lang, now);
    if (challenge == null || challenge.pairs.length < 4) {
      state = const ChallengeState(stage: ChallengeStage.unavailable);
      return;
    }

    final questions = await _buildQuestions(challenge, player?.nativeLang);
    if (questions.isEmpty) {
      state = const ChallengeState(stage: ChallengeStage.unavailable);
      return;
    }

    _startedAt = DateTime.now();
    state = ChallengeState(
      stage: ChallengeStage.running,
      questions: questions,
      total: questions.length,
      remaining: challenge.duration,
    );
    ref.read(analyticsProvider).log(AnalyticsEvents.challengePlayed, {
      'day': day,
      'pairs': questions.length,
    });
    _startTicker(challenge.duration);
  }

  /// Варианты собираются из того же контента, что и обычные круги: перевод
  /// приходит из локальной базы, а по сети едут только идентификаторы и
  /// формы на изучаемом языке.
  Future<List<ChallengeQuestion>> _buildQuestions(
    DailyChallenge challenge,
    String? nativeLang,
  ) async {
    final content = ref.read(currentContentDatabaseProvider);
    final lang = nativeLang ?? defaultNativeLang;
    final random = Random(challenge.day.hashCode);

    final natives = <String, String>{};
    for (final pair in challenge.pairs) {
      final lexeme = await content.lexeme(pair.conceptId, lang);
      if (lexeme != null) natives[pair.conceptId] = lexeme.form;
    }
    if (natives.length < 4) return const [];

    final questions = <ChallengeQuestion>[];
    for (final pair in challenge.pairs) {
      final answer = natives[pair.conceptId];
      if (answer == null) continue;

      final others = natives.entries
          .where((e) => e.key != pair.conceptId)
          .map((e) => e.value)
          .toList()
        ..shuffle(random);

      final options = [...others.take(3), answer]..shuffle(random);
      questions.add(ChallengeQuestion(
        prompt: pair.article == null
            ? pair.target
            : '${pair.article} ${pair.target}',
        options: options,
        answerIndex: options.indexOf(answer),
        audioId: pair.audioId,
      ));
    }
    return questions;
  }

  void _startTicker(Duration total) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final elapsed = DateTime.now().difference(_startedAt);
      final left = total - elapsed;
      if (left <= Duration.zero) {
        _finish();
        return;
      }
      state = state.copyWith(remaining: left, elapsed: elapsed);
    });
  }

  void answer(int index) {
    if (state.stage != ChallengeStage.running) return;
    final question = state.current;
    if (question == null) return;

    final correct = index == question.answerIndex;
    if (correct && question.audioId != null) {
      ref.read(audioServiceProvider).play(question.audioId!);
    }

    final next = state.index + 1;
    state = state.copyWith(
      index: next,
      correct: state.correct + (correct ? 1 : 0),
    );

    // Пары кончились раньше времени — заход закрыт.
    if (next >= state.questions.length) _finish();
  }

  Future<void> _finish() async {
    if (state.stage == ChallengeStage.finished) return;
    _ticker?.cancel();

    final elapsed = DateTime.now().difference(_startedAt);
    final sparks = Sparks.forChallenge(
      correct: state.correct,
      total: state.total,
    );

    state = state.copyWith(
      stage: ChallengeStage.finished,
      elapsed: elapsed,
      remaining: Duration.zero,
      sparksEarned: sparks,
    );

    try {
      await ref.read(appDatabaseProvider).saveChallengeResult(
            DailyChallengeResultsCompanion.insert(
              day: ChallengeClient.dayKey(DateTime.now()),
              correct: state.correct,
              total: state.total,
              timeMs: elapsed.inMilliseconds,
            ),
          );
    } catch (_) {
      // Результат — не игра: его потеря не повод показывать ошибку.
    }

    final player = ref.read(playerControllerProvider);
    if (player != null && sparks > 0) {
      ref.read(playerControllerProvider.notifier).replace(
            player.copyWith(sparks: player.sparks + sparks),
          );
    }
  }
}

final challengeControllerProvider =
    NotifierProvider<ChallengeController, ChallengeState>(
  ChallengeController.new,
);
