/// Правила прогрессии: когда созвездие считается зажжённым, когда
/// открываются соседние и когда стоит предложить подняться ярусом выше.
///
/// Чистый Dart. Все пороги — из [ProgressionBalance].
library;

import '../entities/tier.dart';
import '../scoring/balance.dart';

/// Состояние одного созвездия на конкретном ярусе — то, что видно на карте.
class ConstellationState {
  const ConstellationState({
    required this.name,
    required this.tier,
    required this.starLumens,
    this.unlocked = false,
    this.levelsDone = 0,
  });

  final String name;
  final Tier tier;

  /// Яркость каждой звезды созвездия. Длина списка — сколько звёзд у него
  /// **открыто**; сколько должно быть по ярусу, знает [ProgressionBalance].
  final List<Lumens> starLumens;

  final bool unlocked;
  final int levelsDone;

  int get starCount => starLumens.length;

  /// Средняя яркость. Пустое созвездие — ноль, а не деление на ноль.
  double get averageLumens => starLumens.isEmpty
      ? 0
      : starLumens.reduce((a, b) => a + b) / starLumens.length;

  /// Сколько звёзд уже светит достаточно ярко.
  int get litStars =>
      starLumens.where((lm) => lm >= ProgressionBalance.litStarMinLm).length;

  /// Созвездие «зажжено»: у 80 % звёзд текущего яруса яркость ≥ 70 lm.
  ///
  /// Именно доля, а не среднее: одна забытая звезда среди девяти горящих
  /// не должна закрывать созвездие, но и десяток полузабытых при двух
  /// идеальных — тоже.
  bool get isLit {
    if (starLumens.isEmpty) return false;
    return litStars / starLumens.length >= ProgressionBalance.litStarShare;
  }

  /// Сколько звёзд не хватает до зажжения.
  int get starsToLight {
    if (starLumens.isEmpty) return 0;
    final needed =
        (starLumens.length * ProgressionBalance.litStarShare).ceil();
    return (needed - litStars).clamp(0, starLumens.length);
  }

  /// Прогресс к зажжению 0..1 — то, что рисуется на карте.
  double get litProgress {
    if (starLumens.isEmpty) return 0;
    final needed =
        (starLumens.length * ProgressionBalance.litStarShare).ceil();
    return needed == 0 ? 1 : (litStars / needed).clamp(0.0, 1.0);
  }

  /// Созвездие набрало среднюю яркость, при которой открываются соседние.
  bool get opensNeighbours =>
      averageLumens >= ProgressionBalance.unlockNeighborsAvgLm;

  ConstellationState copyWith({
    List<Lumens>? starLumens,
    bool? unlocked,
    int? levelsDone,
    Tier? tier,
  }) =>
      ConstellationState(
        name: name,
        tier: tier ?? this.tier,
        starLumens: starLumens ?? this.starLumens,
        unlocked: unlocked ?? this.unlocked,
        levelsDone: levelsDone ?? this.levelsDone,
      );
}

/// Что предложить игроку после сессии.
enum TierSuggestion {
  /// Ничего: играем дальше на своём ярусе.
  stay,

  /// Большая часть открытых созвездий зажжена — пора выше.
  up,

  /// Точность в первые дни слишком низкая: возможно, ярус завышен.
  down,
}

abstract final class Progression {
  /// Какие созвездия открыты сейчас.
  ///
  /// Курс не линейный: соседние открываются, когда текущее набирает 60 %
  /// средней яркости, поэтому в любой момент доступно несколько направлений
  /// на выбор.
  static Set<String> unlocked({
    required List<ConstellationState> constellations,
    required Map<String, List<String>> neighbours,
    required Set<String> starters,
  }) {
    final open = <String>{...starters};

    // Открытие каскадное: зажёгшийся сосед может открыть следующего за ним,
    // поэтому проходим до тех пор, пока множество растёт.
    var changed = true;
    while (changed) {
      changed = false;
      for (final constellation in constellations) {
        if (!open.contains(constellation.name)) continue;
        if (!constellation.opensNeighbours) continue;
        for (final neighbour in neighbours[constellation.name] ?? const []) {
          if (open.add(neighbour)) changed = true;
        }
      }
    }
    return open;
  }

  /// Доля зажжённых среди открытых.
  static double litShare(List<ConstellationState> constellations) {
    final open = constellations.where((c) => c.unlocked).toList();
    if (open.isEmpty) return 0;
    return open.where((c) => c.isLit).length / open.length;
  }

  /// Предложение по ярусу — именно предложение, а не сдвиг.
  ///
  /// Запертого уровня в игре нет: результат калибровки и прогресс дают
  /// подсказку, но решение всегда за игроком (docs/CONCEPT.md).
  static TierSuggestion suggest({
    required List<ConstellationState> constellations,
    required Tier current,
    double? recentAccuracy,
    Duration? medianLatency,
  }) {
    // Спуск важнее подъёма: игрок, которому тяжело, бросит раньше, чем
    // игрок, которому легко.
    if (recentAccuracy != null &&
        recentAccuracy < CalibrationBalance.suggestDownAccuracy &&
        current.down != null) {
      return TierSuggestion.down;
    }

    if (current.up == null) return TierSuggestion.stay;

    if (litShare(constellations) >= ProgressionBalance.tierUpLitShare) {
      return TierSuggestion.up;
    }

    // Автокоррекция первых дней: высокая точность при быстром отклике —
    // признак того, что ярус занижен.
    if (recentAccuracy != null &&
        medianLatency != null &&
        recentAccuracy > CalibrationBalance.suggestUpAccuracy &&
        medianLatency <= CalibrationBalance.suggestUpLatency) {
      return TierSuggestion.up;
    }

    return TierSuggestion.stay;
  }

  // `targetStars` и `addedStars` удалены вместе с таблицей накопительных
  // размеров. Ни у одной из них не было вызова в приложении — они
  // существовали ради теста, который проверял, что 12+12+24+24+24 = 96.
  // Проверять сумму константы саму с собой незачем, а размер созвездия
  // теперь приходит из контента.

  /// Появилось ли созвездие на карте: набралось ли у него звёзд.
  ///
  /// Порог, а не равенство. Тема ждёт того яруса, на котором ей есть что
  /// показать: у «денег» на A0 одно слово, и созвездие из одной звезды — это
  /// не созвездие, а точка.
  static bool appears(int starsUpToTier) =>
      starsUpToTier >= ProgressionBalance.minStarsForConstellation;

  /// Общий прогресс яруса 0..1 — по зажжённым созвездиям.
  static double tierProgress(List<ConstellationState> constellations) =>
      litShare(constellations);
}
