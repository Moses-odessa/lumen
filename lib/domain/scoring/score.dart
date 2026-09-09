/// Очки за связь и состояние комбо в забеге.
///
/// Чистый Dart. Все пороги и множители — из `balance.dart`; здесь только
/// правила, которые из них следуют.
library;

import '../entities/game_mode.dart';
import 'balance.dart';
import 'climb.dart';

/// Состояние комбо. Неизменяемое: каждая связь порождает новое.
class ComboState {
  const ComboState({this.streak = 0, this.lockRemaining = 0});

  /// Верных подряд.
  final int streak;

  /// Сколько ближайших связей комбо не растёт. Так работает наказание за
  /// быструю ошибку: обнулить мало, надо ещё и не дать мгновенно отыграться.
  final int lockRemaining;

  /// Множитель комбо: `1 + шаг × подряд_верных`, не выше потолка.
  double get multiplier =>
      (1 + ScoreBalance.comboStep * streak).clamp(1.0, ScoreBalance.kComboMax);

  bool get isLocked => lockRemaining > 0;

  @override
  String toString() => 'Combo(×$streak, lock $lockRemaining)';

  @override
  bool operator ==(Object other) =>
      other is ComboState &&
      other.streak == streak &&
      other.lockRemaining == lockRemaining;

  @override
  int get hashCode => Object.hash(streak, lockRemaining);
}

/// Результат одной связи: сколько очков и что стало с комбо.
class ConnectionResult {
  const ConnectionResult({
    required this.score,
    required this.combo,
    required this.speedMultiplier,
    required this.comboMultiplier,
    required this.modeMultiplier,
    this.climbMultiplier = 1.0,
  });

  /// Очки за эту связь. Ошибка не приносит очков, но и не отнимает уже
  /// набранные: ошибка стоит очков, но никогда не блокирует.
  final int score;

  final ComboState combo;

  final double speedMultiplier;
  final double comboMultiplier;
  final double modeMultiplier;

  /// Множитель уровня захода. Показывается игроку: множитель, которого не
  /// видно, не мотивирует подниматься.
  final double climbMultiplier;
}

/// Правила начисления очков.
abstract final class ScoreRules {
  /// Множитель скорости.
  ///
  /// Главное здесь — не сама лестница порогов, а условие входа: на слове
  /// тусклее [ScoreBalance.speedBonusMinLm] множитель всегда 1.0. Скорость
  /// измеряет автоматизм уже выученного, а не мешает учить новое.
  /// [fastest] переопределяет порог «автоматизма»: заход сжимает его с
  /// уровнем, и максимальный множитель становится труднее заработать. Это
  /// самая болезненная из ручек сложности — она отбирает уже привычную
  /// награду, а не добавляет новую помеху.
  static double speedMultiplier(
    Duration latency, {
    required Lumens lumens,
    Duration? fastest,
  }) {
    if (lumens < ScoreBalance.speedBonusMinLm) return ScoreBalance.kSpeedSlow;
    if (latency < (fastest ?? ScoreBalance.speedFastest)) {
      return ScoreBalance.kSpeedFastest;
    }
    if (latency < ScoreBalance.speedFast) return ScoreBalance.kSpeedFast;
    if (latency < ScoreBalance.speedMedium) return ScoreBalance.kSpeedMedium;
    // Штрафа за медленность нет: думать не запрещено.
    return ScoreBalance.kSpeedSlow;
  }

  /// Приносит ли режим очки на слове такой яркости.
  ///
  /// Митигация «узнавание вместо владения»: выше порога режимы на узнавание
  /// не приносят очков вообще, иначе выгодно фармить лёгкое на выученном.
  static bool scores(GameMode mode, Lumens lumens) =>
      mode.isProductive || lumens < ScoreBalance.recognitionScoreCapLm;

  /// Начисление за одну связь.
  ///
  /// [latency] — от появления круга до отпускания пальца, [lumens] — яркость
  /// слова **до** этого ответа.
  static ConnectionResult scoreConnection({
    required bool correct,
    required Duration latency,
    required GameMode mode,
    required Lumens lumens,
    required ComboState combo,
    ClimbDifficulty? difficulty,
    double climbMultiplier = 1.0,
    bool replayed = false,
  }) {
    if (!correct) {
      return ConnectionResult(
        score: 0,
        combo: _comboAfterError(combo, latency),
        speedMultiplier: 0,
        comboMultiplier: 0,
        modeMultiplier: 0,
      );
    }

    final next = _comboAfterSuccess(combo);
    // Переслушивание снимает скоростной множитель.
    //
    // Правило было записано в комментариях с самого начала и не работало
    // ни дня: `replayPrompt` просто проигрывал звук, ничего не считая. Без
    // него механика на слух вырождается в обычный круг с лишним тапом —
    // слушать один раз незачем, если второй бесплатен.
    //
    // Снимается именно скорость, а не очки целиком: переслушать — законное
    // действие, и запрещать его вредно. Платит игрок только тем, что
    // перестаёт мерить автоматизм, которого в этот раз не было.
    final speed = replayed
        ? ScoreBalance.kSpeedSlow
        : speedMultiplier(
            latency,
            lumens: lumens,
            fastest: difficulty?.speedFastest,
          );
    final mult = ScoreBalance.modeMultiplier(mode);
    // Комбо берётся то, что действует НА этой связи, а не после неё:
    // иначе первая же верная связь получала бы бонус за саму себя.
    final comboMult = combo.multiplier;

    final score = scores(mode, lumens)
        ? (ScoreBalance.baseConnectionScore *
                speed *
                comboMult *
                mult *
                climbMultiplier)
            .round()
        : 0;

    return ConnectionResult(
      score: score,
      combo: next,
      speedMultiplier: speed,
      comboMultiplier: comboMult,
      modeMultiplier: mult,
      climbMultiplier: climbMultiplier,
    );
  }

  /// Комбо после верного ответа: растёт, если не заблокировано быстрой
  /// ошибкой. Пока блокировка не истечёт, комбо стоит на нуле.
  static ComboState _comboAfterSuccess(ComboState combo) {
    if (combo.isLocked) {
      return ComboState(
        streak: 0,
        lockRemaining: combo.lockRemaining - 1,
      );
    }
    return ComboState(streak: combo.streak + 1);
  }

  /// Комбо после ошибки.
  ///
  /// Быстрая ошибка дороже медленной: ответ быстрее порога «автоматизма»,
  /// оказавшийся неверным, — это тык наугад. Он обнуляет комбо и блокирует
  /// его рост, чтобы угадывание было математически убыточным.
  static ComboState _comboAfterError(ComboState combo, Duration latency) {
    final wasGuess = latency < ScoreBalance.speedFastest;
    return ComboState(
      streak: 0,
      lockRemaining: wasGuess ? ScoreBalance.fastErrorComboLock : 0,
    );
  }

  /// Серия быстрых верных ответов у слова после этой связи.
  ///
  /// Считается только в продуктивных режимах: узнавание не доказывает
  /// владения, сколько бы быстрым оно ни было.
  static int nextFastStreak({
    required int current,
    required bool correct,
    required Duration latency,
    required GameMode mode,
  }) {
    if (!correct || !mode.isProductive) return 0;
    return latency < ScoreBalance.burningLatency ? current + 1 : 0;
  }

  /// Слово «горит»: трижды подряд верно и быстро в продуктивном режиме.
  /// Счётчик горящих слов, а не XP, — главная цифра в профиле.
  static bool isBurning(int fastStreak) =>
      fastStreak >= ScoreBalance.burningFastStreak;
}

/// Итог забега.
class RunSummary {
  const RunSummary({
    required this.baseScore,
    required this.total,
    required this.correct,
    required this.circles,
    required this.maxCombo,
    required this.accuracyBonus,
  });

  /// Сумма очков за связи, до бонуса за точность.
  final int baseScore;

  /// Итог с бонусом.
  final int total;

  final int correct;
  final int circles;
  final int maxCombo;

  /// Применённый множитель за точность.
  final double accuracyBonus;

  double get accuracy => circles == 0 ? 0 : correct / circles;

  bool get isPerfect => circles > 0 && correct == circles;
}

/// Накопитель забега: применяет связи по одной и хранит комбо.
///
/// Отдельный класс, а не поле экрана, потому что забег — это доменное
/// понятие со своими правилами, и его надо уметь тестировать без виджетов.
class RunScore {
  RunScore({
    this.difficulty,
    this.climbMultiplier = 1.0,
    this.stageFactor = 1.0,
  });

  /// Сложность уровня захода: сжатый порог автоматизма. `null` — обычный
  /// забег вне захода, например Восход.
  final ClimbDifficulty? difficulty;

  /// Множитель очков уровня захода.
  final double climbMultiplier;

  /// Множитель этапа: показ платит меньше проверки.
  ///
  /// Не ноль на знакомстве. Ноль означал бы, что первые шесть кругов уровня
  /// не считаются игрой, — а это те самые круги, где человек впервые видит
  /// слово.
  final double stageFactor;

  ComboState _combo = const ComboState();
  int _score = 0;
  int _correct = 0;
  int _circles = 0;
  int _maxCombo = 0;

  ComboState get combo => _combo;
  int get score => _score;
  int get circles => _circles;
  int get correct => _correct;
  int get maxCombo => _maxCombo;

  /// Применяет одну связь и возвращает её результат.
  ConnectionResult apply({
    required bool correct,
    required Duration latency,
    required GameMode mode,
    required Lumens lumens,
    bool replayed = false,
  }) {
    final result = ScoreRules.scoreConnection(
      correct: correct,
      latency: latency,
      mode: mode,
      lumens: lumens,
      combo: _combo,
      difficulty: difficulty,
      climbMultiplier: climbMultiplier * stageFactor,
      replayed: replayed,
    );

    _combo = result.combo;
    _score += result.score;
    _circles++;
    if (correct) _correct++;
    if (_combo.streak > _maxCombo) _maxCombo = _combo.streak;

    return result;
  }

  /// Итог: безошибочный забег получает бонус к сумме.
  RunSummary summary() {
    final perfect = _circles > 0 && _correct == _circles;
    final bonus = perfect ? ScoreBalance.perfectRunBonus : 1.0;
    return RunSummary(
      baseScore: _score,
      total: (_score * bonus).round(),
      correct: _correct,
      circles: _circles,
      maxCombo: _maxCombo,
      accuracyBonus: bonus,
    );
  }
}
