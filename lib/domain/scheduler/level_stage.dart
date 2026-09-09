/// Этапы уровня: знакомство → закрепление → проверка → напоминание → спринт.
///
/// Чистый Dart.
///
/// **Зачем этапы.** До них уровень был однородным: тридцать кругов, где
/// сложность каждого решалась яркостью слова, а число вариантов — механикой.
/// Из этого следовало странное: новое слово можно было встретить сразу
/// шестью вариантами, а выученное — четырьмя, и человек не мог понять, по
/// какому правилу игра то легчает, то тяжелеет.
///
/// Этап — это ответ на «насколько трудно сейчас», и он отделён от ответа на
/// «какие слова сейчас». Второе по-прежнему решает яркость по FSRS: этап не
/// выбирает слова, он выбирает, чем их спрашивать. Одно не заменяет другое,
/// и путать их нельзя — иначе либо сложность перестаёт расти, либо слова
/// перестают повторяться вовремя.
library;

import '../entities/game_mode.dart';
import '../scoring/balance.dart';

/// Этап уровня.
enum LevelStage {
  /// Знакомство: один вариант, механики на понимание.
  ///
  /// Один вариант — это не поблажка, а отказ от проверки: выбирать не из
  /// чего, и круг превращается в показ. Проверять то, чего человек ещё не
  /// видел, — способ научить его, что игра непроходима.
  introduction,

  /// Закрепление: 2–4 варианта, тематические дистракторы.
  ///
  /// Появляется выбор, но неверные варианты далеки по смыслу: задача —
  /// вспомнить значение, а не различить оттенок.
  consolidation,

  /// Проверка: 5–6 вариантов, созвучные дистракторы, звук и грамматика.
  check,

  /// Напоминание: старые слова, которые начали тускнеть.
  ///
  /// Единственный этап, где механика не сужена: слова здесь разной яркости,
  /// и подбирать её должен планировщик, а не расписание.
  reminder,

  /// Спринт: успеть N связей за T секунд.
  ///
  /// Только по пройденному материалу. Гонка на незнакомых словах учит
  /// панике, а не языку.
  sprint;

  /// Показ, а не проверка: за него и очков меньше.
  bool get isShowing => this == LevelStage.introduction;

  /// Этап берёт новые слова.
  bool get takesNewWords =>
      this == LevelStage.introduction ||
      this == LevelStage.consolidation ||
      this == LevelStage.check;

  /// Этап идёт на время.
  bool get isTimed => this == LevelStage.sprint;
}

/// Правила этапов. Все числа — из [StageBalance].
abstract final class StageRules {
  /// Порядок этапов в уровне. Спринта здесь нет: он не часть каждого уровня,
  /// а финальная проверка пройденной темы.
  static const List<LevelStage> levelOrder = [
    LevelStage.introduction,
    LevelStage.consolidation,
    LevelStage.check,
    LevelStage.reminder,
  ];

  /// Сколько вариантов показывает этап.
  ///
  /// [extra] — надбавка захода. К знакомству она **не** применяется: круг с
  /// одним вариантом на то и рассчитан, и добавить к нему второй значит
  /// превратить показ в проверку слова, которого игрок ещё не видел.
  static int optionsFor(LevelStage stage, {int extra = 0}) {
    if (stage.isShowing) return SessionBalance.introductionOptions;
    final base = switch (stage) {
      LevelStage.introduction => SessionBalance.introductionOptions,
      LevelStage.consolidation => StageBalance.consolidationOptions,
      LevelStage.check => StageBalance.checkOptions,
      LevelStage.reminder => StageBalance.reminderOptions,
      LevelStage.sprint => StageBalance.sprintOptions,
    };
    return (base + extra).clamp(
      ScoreBalance.optionsMin,
      ScoreBalance.optionsMax + extra,
    );
  }

  /// Сколько слов вынимать из фразы.
  ///
  /// Та же шкала сложности, что число вариантов в круге, и живёт она здесь по
  /// той же причине: вариантность и глубина пропусков есть сложность, а
  /// сложностью распоряжается тот, кто за неё отвечает. Сборщик знает только,
  /// как вынуть.
  ///
  /// Ноль означает «все слова» — это и есть «собери предложение»: не отдельная
  /// механика, а максимум этой шкалы. Раньше их было две, с двумя
  /// реализациями, и реализации расходились.
  ///
  /// Надбавка захода прибавляется, как и к вариантам: закрывающая уровень
  /// фраза обязана дорожать вместе с уровнем. Пока не прибавлялась, словесные
  /// круги дорожали, а фраза — нет.
  static int gapsFor(LevelStage stage, {int extra = 0}) {
    final base = switch (stage) {
      // Знакомство фразой не спрашивает: слово только что показали.
      LevelStage.introduction => SessionBalance.phraseGapsMin,
      LevelStage.consolidation => SessionBalance.phraseGapsMin,
      LevelStage.check => SessionBalance.phraseGapsMin + 1,
      LevelStage.reminder => SessionBalance.phraseGapsMin + 1,
      // Спринт — финальная проверка темы: предложение целиком.
      LevelStage.sprint => SessionBalance.phraseGapsAll,
    };
    if (base == SessionBalance.phraseGapsAll) return base;
    return base + extra;
  }

  /// Какими механиками этап спрашивает. `null` — любыми.
  static Set<GameMode>? mechanicsFor(LevelStage stage) => switch (stage) {
        // Понимание: слово только что показали, требовать воспроизведения
        // рано.
        LevelStage.introduction => const {
            GameMode.pickNative,
            GameMode.listenNative,
          },
        LevelStage.consolidation => const {
            GameMode.pickNative,
            GameMode.pickTarget,
            GameMode.listenNative,
          },
        // Проверка спрашивает только воспроизведение: этап решает, знает ли
        // игрок слово настолько, чтобы выдать его, а не узнать. Вопрос на
        // слух отсюда ушёл вместе с `listenTarget` — тот был продуктивным
        // (варианты на изучаемом), а оставшийся `listenNative` спрашивает
        // узнавание, и проверять им нечего.
        LevelStage.check => const {GameMode.pickTarget},
        // Напоминание не сужает набор: слова здесь разной яркости, и выбор
        // механики — работа планировщика.
        LevelStage.reminder => null,
        LevelStage.sprint => const {
            GameMode.pickNative,
            GameMode.pickTarget,
          },
      };

  /// Тематические варианты или созвучные.
  static DistractorKind distractorFor(LevelStage stage) => switch (stage) {
        LevelStage.check => DistractorKind.near,
        _ => DistractorKind.far,
      };

  /// Минимальная яркость слова для этапа.
  ///
  /// Ноль у всех, кроме спринта: гонка идёт только по тому, что уже держится
  /// в памяти. Слово ниже порога в спринт не попадает, даже если оно
  /// просрочено сильнее остальных.
  static Lumens minLumensFor(LevelStage stage) =>
      stage == LevelStage.sprint ? StageBalance.sprintMinLumens : 0;

  /// Множитель очков за этап.
  ///
  /// Показ дешевле проверки, и это не наказание за незнание: очки в игре
  /// платят за вспоминание, а на знакомстве вспоминать нечего.
  static double scoreFactorFor(LevelStage stage) => switch (stage) {
        LevelStage.introduction => StageBalance.introductionScoreFactor,
        _ => 1.0,
      };
}

/// Цель спринта: сколько связей за сколько времени.
class SprintGoal {
  const SprintGoal({required this.connections, required this.duration});

  /// Планка попытки: номер попытки, считая с нуля.
  ///
  /// Каждая следующая требует больше связей за то же время. Растёт планка, а
  /// не сжимается время: сжатое время превращает спринт в проверку скорости
  /// пальца, а не автоматизма.
  factory SprintGoal.attempt(int attempt) => SprintGoal(
        connections: StageBalance.sprintConnections +
            attempt * StageBalance.sprintConnectionsPerAttempt,
        duration: StageBalance.sprintDuration,
      );

  /// Сколько верных связей нужно успеть.
  ///
  /// Считаются **верные**, а не все ответы. Иначе спринт проходился бы
  /// перебором: ошибка возвращает слово в конец очереди, и длина очереди,
  /// а не планка, решала бы, когда забег кончился.
  final int connections;

  final Duration duration;

  /// Достигнута ли цель.
  bool reachedBy(int correct) => correct >= connections;
}
