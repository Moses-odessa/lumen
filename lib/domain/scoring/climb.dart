/// Заход: сколько уровней подряд игрок выдержит за один присест.
///
/// Чистый Dart. Все пороги — из `balance.dart`; здесь только правила,
/// которые из них следуют.
library;

import 'dart:math';

import 'balance.dart';

/// Настройки сложности одного уровня захода.
///
/// Ручек три, и все они двигаются мелкими шагами: аркада ломается не когда
/// сложно, а когда сложность прыгает.
///
/// Четвёртой была «лишний вариант в круге», самая мягкая из всех: она только
/// снижала шанс угадать. Её больше нет — вариантов в круге всегда шесть, и
/// на полном круге держится знакомство методом исключения
/// ([ScoreBalance.optionsPerCircle]). Осиротевшая от неё докстрока
/// («Сколько вариантов добавить…») стояла над [speedFastest] и обещала
/// поле, которого в классе нет.
class ClimbDifficulty {
  const ClimbDifficulty({
    required this.speedFastest,
    required this.modeDraws,
    required this.circlesPerRun,
  });

  /// Порог «автоматизма» для максимального скоростного множителя.
  ///
  /// Самая болезненная ручка: она отбирает уже заработанный множитель, а не
  /// снижает шанс угадать.
  final Duration speedFastest;

  /// Сколько случайных попыток делает выбор режима: берётся самая сложная.
  /// Чем больше попыток, тем выше доля продуктивных режимов.
  final int modeDraws;

  /// Кругов в забеге.
  final int circlesPerRun;
}

/// Состояние захода. Неизменяемое: каждый уровень порождает новое.
class ClimbState {
  const ClimbState({
    this.level = 1,
    this.total = 0,
    this.levelsPlayed = 0,
    this.startedAt,
  });

  /// Текущий уровень сложности, начиная с первого.
  final int level;

  /// Сумма очков захода — та самая цифра, которая идёт на стену рекордов.
  final int total;

  /// Сколько уровней уже сыграно. Отличается от [level] после сброса:
  /// сложность вернулась к первому уровню, а пройдено уже пять.
  final int levelsPlayed;

  /// Когда заход начался. `null` — заход ещё не начинался.
  final DateTime? startedAt;

  bool get isEmpty => levelsPlayed == 0;

  /// Множитель очков текущего уровня.
  double get multiplier => ClimbRules.multiplierFor(level);

  /// Сложность текущего уровня.
  ClimbDifficulty get difficulty => ClimbRules.difficultyFor(level);

  @override
  String toString() =>
      'Climb(L$level, $total очков, уровней $levelsPlayed)';

  @override
  bool operator ==(Object other) =>
      other is ClimbState &&
      other.level == level &&
      other.total == total &&
      other.levelsPlayed == levelsPlayed &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(level, total, levelsPlayed, startedAt);
}

/// Правила захода.
abstract final class ClimbRules {
  /// Множитель очков уровня: растёт линейно до потолка.
  static double multiplierFor(int level) {
    final raw = 1 + ClimbBalance.levelStep * (max(level, 1) - 1);
    return min(raw, ClimbBalance.levelMultiplierMax);
  }

  /// Сложность уровня.
  static ClimbDifficulty difficultyFor(int level) {
    final steps = max(level, 1) - 1;
    return ClimbDifficulty(
      speedFastest: _speedFastest(steps),
      modeDraws: min(
        ClimbBalance.modeDrawsBase + steps ~/ ClimbBalance.levelsPerExtraDraw,
        ClimbBalance.modeDrawsMax,
      ),
      circlesPerRun: min(
        SessionBalance.circlesPerRunMin +
            steps * ClimbBalance.circlesPerRunGrowthEvery,
        ClimbBalance.circlesPerRunCap,
      ),
    );
  }

  static Duration _speedFastest(int steps) {
    final tightened = ScoreBalance.speedFastest -
        ClimbBalance.speedTighteningPerLevel * steps;
    return tightened < ClimbBalance.speedFastestFloor
        ? ClimbBalance.speedFastestFloor
        : tightened;
  }

  /// Заход после уровня.
  ///
  /// Слабый уровень сбрасывает сложность на первую, но не отнимает
  /// накопленное: очки уже заработаны, а «потерять прогресс» в игре про
  /// память — способ отучить от неё насовсем.
  static ClimbState afterLevel(
    ClimbState climb, {
    required int score,
    required double accuracy,
    required DateTime at,
  }) {
    final weak = accuracy < ClimbBalance.resetBelowAccuracy;
    return ClimbState(
      level: weak ? 1 : climb.level + 1,
      total: climb.total + score,
      levelsPlayed: climb.levelsPlayed + 1,
      startedAt: climb.startedAt ?? at,
    );
  }

  /// Продолжается ли заход, начатый в [lastPlayedAt], к моменту [now].
  ///
  /// Перерыв закрывает заход: иначе «один присест» растянется на сутки, и
  /// рекорд часа перестанет что-либо означать.
  static bool continues(DateTime? lastPlayedAt, DateTime now) {
    if (lastPlayedAt == null) return false;
    return now.difference(lastPlayedAt) < ClimbBalance.idleClosesClimb;
  }

  /// Заход, с которым начинается уровень: тот же, если перерыв короткий, и
  /// новый, если игрок уже уходил.
  static ClimbState resume(
    ClimbState climb, {
    required DateTime? lastPlayedAt,
    required DateTime now,
  }) =>
      continues(lastPlayedAt, now) ? climb : const ClimbState();
}
