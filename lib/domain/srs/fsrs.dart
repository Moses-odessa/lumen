import 'dart:math' as math;

import '../scoring/balance.dart';
import 'memory_state.dart';
import 'review_grade.dart';

/// FSRS — Free Spaced Repetition Scheduler, модель DSR: difficulty,
/// stability, retrievability.
///
/// Порт эталонной реализации FSRS-5 на чистый Dart. Здесь нет ни Flutter, ни
/// БД, ни времени «сейчас» из системных часов: момент всегда передаётся
/// снаружи, иначе алгоритм невозможно нормально протестировать.
///
/// Почему именно FSRS, а не SM-2 из Anki: SM-2 хранит «фактор лёгкости» и
/// не умеет отвечать на вопрос «какова вероятность вспомнить прямо сейчас».
/// Для Lumen это центральный вопрос — из него берётся яркость звезды.
class Fsrs {
  const Fsrs({this.weights = defaultWeights});

  /// Веса FSRS-5, обученные на открытом датасете повторений.
  ///
  /// TODO(balance): это популяционные веса. Журнал `Reviews` собирается
  /// именно для того, чтобы позже дообучить их под конкретного игрока —
  /// на своих данных FSRS обычно даёт заметно более точные интервалы.
  static const List<double> defaultWeights = [
    0.40255, // w0..w3 — начальная стабильность по оценке
    1.18385,
    3.17300,
    15.69105,
    7.19490, // w4, w5 — начальная сложность
    0.53450,
    1.46040, // w6, w7 — изменение и возврат сложности к среднему
    0.00460,
    1.54575, // w8..w10 — рост стабильности при удачном вспоминании
    0.11920,
    1.01925,
    1.93950, // w11..w14 — стабильность после провала
    0.11000,
    0.29605,
    2.26980,
    0.23150, // w15, w16 — штраф за «трудно» и бонус за «легко»
    2.98980,
    0.51655, // w17, w18 — повторы внутри дня
    0.66210,
  ];

  final List<double> weights;

  /// Новое состояние памяти после одного ответа.
  ///
  /// [now] — момент ответа; [state] — то, что было до него. Для нового слова
  /// передаётся [MemoryState.unseen].
  MemoryState review(
    MemoryState state,
    ReviewGrade grade,
    DateTime now,
  ) {
    if (state.isNew) {
      return MemoryState(
        difficulty: _initialDifficulty(grade),
        stability: _clampStability(weights[grade.value - 1]),
        lastReview: now,
        reps: 1,
        lapses: grade.isForgotten ? 1 : 0,
      );
    }

    final retrievability = state.retrievabilityAt(now);
    final difficulty = _nextDifficulty(state.difficulty, grade);
    final elapsed = now.difference(state.lastReview!);

    final double stability;
    if (elapsed < SrsBalance.sameDayWindow) {
      // Повтор в тот же день: слово ещё в рабочей памяти, обычная формула
      // роста здесь завышала бы интервал в разы.
      stability = _sameDayStability(state.stability, grade);
    } else if (grade.isForgotten) {
      stability = _stabilityAfterLapse(
        difficulty: state.difficulty,
        stability: state.stability,
        retrievability: retrievability,
      );
    } else {
      stability = _stabilityAfterRecall(
        difficulty: state.difficulty,
        stability: state.stability,
        retrievability: retrievability,
        grade: grade,
      );
    }

    return MemoryState(
      difficulty: difficulty,
      stability: _clampStability(stability),
      lastReview: now,
      reps: state.reps + 1,
      lapses: state.lapses + (grade.isForgotten ? 1 : 0),
    );
  }

  /// Каким было бы состояние при каждой из четырёх оценок. Нужно и для
  /// отладки баланса, и для экрана словаря («когда это слово вернётся»).
  Map<ReviewGrade, MemoryState> preview(MemoryState state, DateTime now) => {
        for (final grade in ReviewGrade.values)
          grade: review(state, grade, now),
      };

  // ── Сложность ───────────────────────────────────────────────────────────

  /// D₀(G) = w4 − e^(w5·(G−1)) + 1
  double _initialDifficulty(ReviewGrade grade) => _clampDifficulty(
        weights[4] - math.exp(weights[5] * (grade.value - 1)) + 1,
      );

  /// Сложность ползёт вверх на провалах и вниз на лёгких ответах, но её
  /// постоянно тянет обратно к «лёгкому» началу отсчёта — иначе одна плохая
  /// серия навсегда клеймила бы слово трудным.
  double _nextDifficulty(double difficulty, ReviewGrade grade) {
    final delta = -weights[6] * (grade.value - 3);
    // Линейное затухание: у уже трудного слова шаг меньше, чем у лёгкого.
    final damped = difficulty + delta * (10 - difficulty) / 9;
    final meanReverted = weights[7] * _initialDifficulty(ReviewGrade.easy) +
        (1 - weights[7]) * damped;
    return _clampDifficulty(meanReverted);
  }

  // ── Стабильность ────────────────────────────────────────────────────────

  /// Рост стабильности при удачном вспоминании.
  ///
  /// Здесь заложены три вещи, каждая проверена на данных: труднее слово —
  /// меньше рост; выше текущая стабильность — меньше относительный рост
  /// (насыщение); чем ниже была вероятность вспомнить, тем больше выигрыш —
  /// то самое «вспомнил на грани забывания», ради чего интервальное
  /// повторение и работает.
  double _stabilityAfterRecall({
    required double difficulty,
    required double stability,
    required double retrievability,
    required ReviewGrade grade,
  }) {
    final hardPenalty = grade == ReviewGrade.hard ? weights[15] : 1.0;
    final easyBonus = grade == ReviewGrade.easy ? weights[16] : 1.0;

    final growth = math.exp(weights[8]) *
        (11 - difficulty) *
        math.pow(stability, -weights[9]) *
        (math.exp(weights[10] * (1 - retrievability)) - 1) *
        hardPenalty *
        easyBonus;

    return stability * (1 + growth);
  }

  /// Стабильность после провала. Она не обнуляется: даже забытое слово
  /// восстанавливается быстрее, чем учится с нуля.
  double _stabilityAfterLapse({
    required double difficulty,
    required double stability,
    required double retrievability,
  }) {
    final lapsed = weights[11] *
        math.pow(difficulty, -weights[12]) *
        (math.pow(stability + 1, weights[13]) - 1) *
        math.exp(weights[14] * (1 - retrievability));
    // Провал не может увеличить стабильность.
    return math.min(lapsed, stability);
  }

  /// Повтор внутри того же дня двигает стабильность слабо и в обе стороны.
  double _sameDayStability(double stability, ReviewGrade grade) =>
      stability *
      math.exp(weights[17] * (grade.value - 3 + weights[18]));

  double _clampDifficulty(double value) => value.clamp(
        SrsBalance.minDifficulty,
        SrsBalance.maxDifficulty,
      );

  double _clampStability(double value) => value.isFinite
      ? value.clamp(SrsBalance.minStability, SrsBalance.maxStability)
      : SrsBalance.minStability;
}

/// Оценка из времени отклика — без единого вопроса игроку.
///
/// Пороги те же, что у скоростного множителя очков, и это не совпадение:
/// «быстро» для очков и «легко» для памяти — одно и то же наблюдение.
ReviewGrade gradeFromLatency(Duration latency, {required bool correct}) {
  if (!correct) return ReviewGrade.again;
  if (latency < SrsBalance.gradeEasyBelow) return ReviewGrade.easy;
  if (latency < SrsBalance.gradeGoodBelow) return ReviewGrade.good;
  return ReviewGrade.hard;
}

/// Засев памяти после калибровки: подтверждённое слово стартует не с нуля,
/// а с заданной яркости, и сразу попадает в очередь повторений.
///
/// Обратная задача к кривой забывания: подобрать стабильность так, чтобы
/// через сутки вероятность вспомнить была равна нужной.
MemoryState seedMemory({
  required Lumens lumens,
  required DateTime at,
  double difficulty = 5,
  Duration age = const Duration(days: 1),
}) {
  final retrievability = (lumens / 100).clamp(0.01, 0.99);
  final elapsedDays = age.inMilliseconds / Duration.millisecondsPerDay;
  final factor = math.pow(0.9, 1 / -0.5) - 1;
  final stability =
      factor * elapsedDays / (math.pow(retrievability, 1 / -0.5) - 1);

  return MemoryState(
    difficulty: difficulty.clamp(
      SrsBalance.minDifficulty,
      SrsBalance.maxDifficulty,
    ),
    stability: stability.clamp(
      SrsBalance.minStability,
      SrsBalance.maxStability,
    ),
    // Слово «как будто повторяли вчера»: так оно честно попадает в очередь,
    // а не выглядит новым.
    lastReview: at.subtract(age),
    reps: 1,
  );
}
