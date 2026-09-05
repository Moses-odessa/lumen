/// Орбита вместо стрика и недельная цель.
///
/// Главная боль Duolingo — страх потерять полгода из-за одного перелёта.
/// Орбита лечит её тем, что пропуск **опускает**, а не обнуляет: один
/// пропущенный день стоит один день прогресса, а не всю историю.
///
/// Чистый Dart: «сегодня» приходит снаружи, иначе поведение на границе суток
/// невозможно проверить.
library;

import '../scoring/balance.dart';

/// Состояние орбиты.
class OrbitState {
  const OrbitState({
    this.level = 0,
    this.missedInRow = 0,
    this.lastPlayedAt,
    this.eclipseUntil,
  });

  /// Высота орбиты в днях игры.
  final int level;

  /// Пропусков подряд. На третьем орбита обнуляется.
  final int missedInRow;

  final DateTime? lastPlayedAt;

  /// Затмение — оплаченная искрами пауза, во время которой пропуски не
  /// считаются. Не «заморозка стрика за деньги»: искры зарабатываются игрой
  /// и ничего, кроме паузы и косметики, не покупают.
  final DateTime? eclipseUntil;

  bool get hasPlayed => lastPlayedAt != null;

  bool eclipsedAt(DateTime day) =>
      eclipseUntil != null && !_dayStart(day).isAfter(eclipseUntil!);

  OrbitState copyWith({
    int? level,
    int? missedInRow,
    DateTime? Function()? lastPlayedAt,
    DateTime? Function()? eclipseUntil,
  }) =>
      OrbitState(
        level: level ?? this.level,
        missedInRow: missedInRow ?? this.missedInRow,
        lastPlayedAt:
            lastPlayedAt == null ? this.lastPlayedAt : lastPlayedAt(),
        eclipseUntil:
            eclipseUntil == null ? this.eclipseUntil : eclipseUntil(),
      );

  @override
  String toString() => 'Orbit($level, пропусков $missedInRow)';
}

/// Начало суток. Орбита живёт в днях, а не в часах: сессия в 23:50 и сессия
/// в 00:10 — это два разных дня, и никакие часовые пояса этого не меняют.
DateTime _dayStart(DateTime value) =>
    DateTime(value.year, value.month, value.day);

abstract final class Orbit {
  /// Пересчёт орбиты на момент [now] — то, что происходит при открытии
  /// приложения.
  ///
  /// Считаются **пропущенные дни между последней игрой и сегодня**, а не
  /// «сегодня играл или нет»: сегодняшний день ещё не потерян, пока он не
  /// кончился.
  static OrbitState refresh(OrbitState state, DateTime now) {
    final last = state.lastPlayedAt;
    if (last == null) return state;

    final missed = _missedDays(last, now, state);
    if (missed <= 0) return state;

    var level = state.level;
    var inRow = state.missedInRow;

    for (var i = 0; i < missed; i++) {
      inRow++;
      if (inRow >= RetentionBalance.orbitResetAfterMisses) {
        // Полный сброс — только на третьем пропуске подряд.
        level = 0;
        continue;
      }
      level = (level - RetentionBalance.orbitLossPerMiss).clamp(0, level);
    }

    return state.copyWith(level: level, missedInRow: inRow);
  }

  /// День игры: орбита поднимается на один, счётчик пропусков сбрасывается.
  ///
  /// Второй сеанс в тот же день ничего не добавляет — орбита измеряет дни,
  /// а не количество сессий.
  static OrbitState play(OrbitState state, DateTime now) {
    final refreshed = refresh(state, now);
    final last = refreshed.lastPlayedAt;

    if (last != null && _isSameDay(last, now)) {
      return refreshed.copyWith(lastPlayedAt: () => now);
    }

    return refreshed.copyWith(
      level: refreshed.level + RetentionBalance.orbitGainPerDay,
      missedInRow: 0,
      lastPlayedAt: () => now,
    );
  }

  /// Затмение: пауза на [days] дней, купленная искрами.
  static OrbitState eclipse(OrbitState state, DateTime now, {int days = 3}) =>
      state.copyWith(
        eclipseUntil: () => _dayStart(now).add(Duration(days: days)),
      );

  /// Сыграно ли сегодня.
  static bool playedToday(OrbitState state, DateTime now) {
    final last = state.lastPlayedAt;
    return last != null && _isSameDay(last, now);
  }

  /// Сколько дней из последних семи сыграно.
  ///
  /// Цель недели, а не дня: два законных выходных снимают вину и на длинной
  /// дистанции дают лучшее удержание, чем жёсткое «каждый день».
  static int weeklyProgress(Iterable<DateTime> playedDays, DateTime now) {
    final from = _dayStart(now).subtract(const Duration(days: 6));
    final days = <String>{};
    for (final day in playedDays) {
      final start = _dayStart(day);
      if (start.isBefore(from) || start.isAfter(_dayStart(now))) continue;
      days.add('${start.year}-${start.month}-${start.day}');
    }
    return days.length;
  }

  /// Недельная цель выполнена.
  static bool weeklyGoalMet(Iterable<DateTime> playedDays, DateTime now) =>
      weeklyProgress(playedDays, now) >= RetentionBalance.weeklyGoalDays;

  /// Сколько пропусков осталось до полного сброса.
  static int missesBeforeReset(OrbitState state) =>
      (RetentionBalance.orbitResetAfterMisses - state.missedInRow)
          .clamp(0, RetentionBalance.orbitResetAfterMisses);

  /// Пропущенные дни между последней игрой и сегодня, без учёта затмения.
  static int _missedDays(DateTime last, DateTime now, OrbitState state) {
    final lastDay = _dayStart(last);
    final today = _dayStart(now);
    final gap = today.difference(lastDay).inDays;
    if (gap <= 1) return 0;

    var missed = 0;
    for (var i = 1; i < gap; i++) {
      final day = lastDay.add(Duration(days: i));
      // Дни под затмением не считаются пропусками вовсе.
      if (state.eclipsedAt(day)) continue;
      missed++;
    }
    return missed;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

}
