import 'dart:math' as math;

import '../scoring/balance.dart';

/// Состояние памяти по одному слову — источник правды о том, помнит игрок
/// слово или нет.
///
/// Инвариант из README: правда — это тройка `(difficulty, stability,
/// lastReview)`. Яркость в люменах из неё **вычисляется** и кешируется в
/// колонке только для сортировки; при расхождении верна тройка.
class MemoryState {
  const MemoryState({
    required this.difficulty,
    required this.stability,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
  });

  /// Слово, которое игрок ещё ни разу не видел. Отличается от «забытого»:
  /// у забытого есть история, у нового её нет.
  static const MemoryState unseen = MemoryState(
    difficulty: 0,
    stability: 0,
  );

  /// Сложность материала для этого игрока, шкала FSRS 1..10.
  final double difficulty;

  /// Стабильность в днях: через сколько дней вероятность вспомнить упадёт
  /// до 90 %.
  final double stability;

  /// Когда слово показывали в последний раз.
  final DateTime? lastReview;

  /// Сколько раз повторяли и сколько раз забывали. Нужны для статистики и
  /// для того, чтобы отличать «трудное слово» от «нового».
  final int reps;
  final int lapses;

  /// Слово ещё не показывали ни разу.
  bool get isNew => lastReview == null;

  /// Вероятность вспомнить прямо сейчас, 0..1.
  ///
  /// Кривая забывания FSRS: `R(t) = (1 + F·t/S)^C`. Это степенная функция,
  /// а не экспонента — эмпирически она заметно лучше описывает реальные
  /// данные повторений на длинных интервалах.
  double retrievabilityAt(DateTime now) {
    if (isNew || stability <= 0) return 0;
    final elapsedDays = _daysBetween(lastReview!, now);
    if (elapsedDays <= 0) return 1;
    return math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();
  }

  /// Яркость звезды в люменах: та же вероятность, умноженная на 100.
  ///
  /// Метафора неба здесь не украшение — это ровно то число, которое FSRS и
  /// так считает. Поэтому игроку не нужно объяснять интервальное повторение:
  /// он открывает карту и видит, что часть неба потускнела.
  Lumens lumensAt(DateTime now) =>
      (retrievabilityAt(now) * 100).round().clamp(0, 100);

  /// Когда слово стоит показать снова, чтобы застать его на целевой
  /// вероятности вспомнить.
  DateTime? dueAt({double retention = SrsBalance.targetRetention}) {
    if (isNew || stability <= 0) return null;
    return lastReview!.add(intervalFor(retention: retention));
  }

  /// Интервал до следующего повтора — обратная функция к кривой забывания.
  Duration intervalFor({double retention = SrsBalance.targetRetention}) {
    if (stability <= 0) return Duration.zero;
    final days =
        stability / _factor * (math.pow(retention, 1 / _decay) - 1);
    // Меньше часа планировать бессмысленно: это тот же забег.
    final ms = (days * Duration.millisecondsPerDay).round();
    return Duration(milliseconds: math.max(ms, Duration.millisecondsPerHour));
  }

  MemoryState copyWith({
    double? difficulty,
    double? stability,
    DateTime? lastReview,
    int? reps,
    int? lapses,
  }) =>
      MemoryState(
        difficulty: difficulty ?? this.difficulty,
        stability: stability ?? this.stability,
        lastReview: lastReview ?? this.lastReview,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
      );

  @override
  String toString() => 'MemoryState(D: ${difficulty.toStringAsFixed(2)}, '
      'S: ${stability.toStringAsFixed(2)}d, reps: $reps, lapses: $lapses)';
}

/// Показатель кривой забывания FSRS.
const double _decay = -0.5;

/// Множитель, подобранный так, чтобы `R = 0.9` ровно при `t = S`.
final double _factor = math.pow(0.9, 1 / _decay) - 1;

/// Прошедшее время в днях. Дробное: внутри дня повторы тоже считаются.
double _daysBetween(DateTime from, DateTime to) =>
    to.difference(from).inMilliseconds / Duration.millisecondsPerDay;
