/// Личная стена рекордов: лучший заход и лучшие час, день, неделя, месяц.
///
/// Чистый Dart. Облака нет, сравниваться не с кем — значит соперник это ты
/// вчерашний, и вся работа стены в том, чтобы у игрока всегда была
/// побиваемая цифра.
///
/// Окна календарные, а не скользящие. «Твой лучший час — вчера с 14 до 15»
/// объяснимо; «лучшие любые 60 минут подряд» посчитать можно, а понять нельзя.
library;

import 'balance.dart';

/// Окно, за которое считается рекорд.
enum RecordWindow {
  /// Один заход — цепочка уровней подряд. Главная цифра, аркадный high score.
  climb,
  hour,
  day,
  week,
  month;

  bool get isCalendar => this != RecordWindow.climb;
}

/// Сыгранный уровень: когда и на сколько очков.
///
/// Заход опознаётся по [climbId], а не считается заново по перерывам: на
/// момент чтения истории перерывы уже случились, и восстанавливать их из
/// таймстампов значило бы дважды применять одно правило.
class ScoredLevel {
  const ScoredLevel({
    required this.at,
    required this.score,
    this.climbId,
  });

  final DateTime at;
  final int score;

  /// Идентификатор захода. `null` у записей, сделанных до появления заходов.
  final String? climbId;
}

/// Рекорд одного окна и то, что накоплено в текущем.
class RecordEntry {
  const RecordEntry({
    required this.window,
    required this.best,
    required this.current,
    this.bestAt,
  });

  final RecordWindow window;

  /// Лучшее значение за всю историю.
  final int best;

  /// Сколько набрано в текущем окне — та половина, из которой берётся
  /// мотивация. Рекорд без текущего значения не говорит, далеко ли до него.
  final int current;

  /// Начало окна, в котором поставлен рекорд. Нужно, чтобы показать когда.
  final DateTime? bestAt;

  /// Текущее окно уже лучше прежнего рекорда.
  bool get isRecordNow => current > 0 && current >= best;

  /// Сколько осталось до рекорда. Ноль — рекорд уже побит.
  int get remaining => best > current ? best - current : 0;
}

/// Стена рекордов.
class RecordWall {
  const RecordWall(this.entries);

  final Map<RecordWindow, RecordEntry> entries;

  RecordEntry? operator [](RecordWindow window) => entries[window];

  /// Считает стену по истории сыгранных уровней.
  ///
  /// Сложность линейная по числу записей: история у одного игрока за годы —
  /// это тысячи строк, и группировать их можно как угодно, но читаются они
  /// на экране профиля, а не в забеге.
  static RecordWall from(List<ScoredLevel> levels, DateTime now) {
    final entries = <RecordWindow, RecordEntry>{};
    for (final window in RecordWindow.values) {
      entries[window] = _entryFor(window, levels, now);
    }
    return RecordWall(entries);
  }

  static RecordEntry _entryFor(
    RecordWindow window,
    List<ScoredLevel> levels,
    DateTime now,
  ) {
    // Сумма по ведру: календарное окно или заход.
    final sums = <String, int>{};
    final starts = <String, DateTime>{};

    for (final level in levels) {
      final key = _keyFor(window, level);
      if (key == null) continue;
      sums.update(key, (v) => v + level.score, ifAbsent: () => level.score);
      final known = starts[key];
      if (known == null || level.at.isBefore(known)) starts[key] = level.at;
    }

    final currentKey = window.isCalendar
        ? _calendarKey(window, now)
        // Текущий заход опознаётся по последней записи: если она свежая,
        // заход тот же, если старая — текущего захода нет.
        : _currentClimbKey(levels, now);

    var best = 0;
    DateTime? bestAt;
    for (final entry in sums.entries) {
      // Текущее окно в рекорд не идёт, пока не закрылось: иначе «рекорд
      // часа» побивался бы сам собой каждым кругом и перестал быть целью.
      if (entry.key == currentKey) continue;
      if (entry.value <= best) continue;
      best = entry.value;
      bestAt = starts[entry.key];
    }

    return RecordEntry(
      window: window,
      best: best,
      current: currentKey == null ? 0 : (sums[currentKey] ?? 0),
      bestAt: bestAt,
    );
  }

  static String? _keyFor(RecordWindow window, ScoredLevel level) =>
      window.isCalendar ? _calendarKey(window, level.at) : level.climbId;

  static String _calendarKey(RecordWindow window, DateTime at) =>
      switch (window) {
        RecordWindow.hour =>
          'h:${at.year}-${at.month}-${at.day}-${at.hour}',
        RecordWindow.day => 'd:${at.year}-${at.month}-${at.day}',
        RecordWindow.week => 'w:${_isoWeekKey(at)}',
        RecordWindow.month => 'm:${at.year}-${at.month}',
        RecordWindow.climb => throw ArgumentError('заход не календарное окно'),
      };

  /// Ключ недели по ISO 8601: неделя начинается с понедельника.
  ///
  /// Год берётся у четверга этой недели, а не у самого дня: 1 января может
  /// принадлежать последней неделе прошлого года, и без этой поправки конец
  /// декабря и начало января попадали бы в одно ведро.
  static String _isoWeekKey(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final firstOfYear = DateTime(thursday.year, 1, 1);
    final week = 1 + thursday.difference(firstOfYear).inDays ~/ 7;
    return '${thursday.year}-$week';
  }

  /// Идентификатор захода, который идёт прямо сейчас. `null` — заход закрыт
  /// перерывом или истории ещё нет.
  static String? _currentClimbKey(List<ScoredLevel> levels, DateTime now) {
    ScoredLevel? last;
    for (final level in levels) {
      if (level.climbId == null) continue;
      if (last == null || level.at.isAfter(last.at)) last = level;
    }
    if (last == null) return null;
    return ClimbWindow.isOpen(last.at, now) ? last.climbId : null;
  }
}

/// Когда заход считается ещё открытым.
///
/// Правило то же, что в `ClimbRules.continues`, и цифра та же — из
/// `balance.dart`. Отдельная функция нужна потому, что стене рекордов не
/// нужно состояние игры: ей нужно только правило, применённое к истории.
abstract final class ClimbWindow {
  static bool isOpen(DateTime lastPlayedAt, DateTime now) =>
      now.difference(lastPlayedAt) < ClimbBalance.idleClosesClimb;
}
