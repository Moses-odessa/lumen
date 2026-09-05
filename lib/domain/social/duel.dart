/// Асинхронные дуэли.
///
/// Матч идёт на **пересечении словарей**: играть словами, которых соперник
/// не знает, — не соревнование, а лотерея. Если живого соперника нет, игра
/// предлагает «дуэль с призраком» — повтор собственного прошлого результата
/// или результата случайного игрока, **честно помеченный как реплей**.
///
/// Ботов под видом живых соперников в игре нет и не будет: это единственная
/// механика из списка отказов, которую особенно легко втащить незаметно.
library;

/// Кто соперник.
enum OpponentKind {
  /// Живой игрок, сыгравший этот же набор раньше.
  human,

  /// Реплей: свой прошлый заход или заход случайного игрока.
  ///
  /// Показывается только с явной пометкой. «Призрак» — это запись, а не
  /// имитация человека.
  ghost,
}

class DuelOpponent {
  const DuelOpponent({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.correct,
    required this.total,
    required this.timeMs,
  });

  final String id;
  final String displayName;
  final OpponentKind kind;
  final int correct;
  final int total;
  final int timeMs;

  bool get isGhost => kind == OpponentKind.ghost;
}

/// Итог дуэли.
enum DuelOutcome { win, draw, loss }

class DuelResult {
  const DuelResult({
    required this.outcome,
    required this.playerCorrect,
    required this.opponentCorrect,
    required this.playerTimeMs,
    required this.opponentTimeMs,
    required this.againstGhost,
  });

  final DuelOutcome outcome;
  final int playerCorrect;
  final int opponentCorrect;
  final int playerTimeMs;
  final int opponentTimeMs;

  /// Соперник был реплеем. Показывается игроку, а не прячется.
  final bool againstGhost;
}

abstract final class Duel {
  /// Сколько пар в дуэли и сколько она длится. TODO(balance)
  static const int pairs = 20;
  static const Duration duration = Duration(seconds: 60);

  /// Минимальный размер пересечения, при котором дуэль имеет смысл.
  /// TODO(balance)
  static const int minSharedWords = pairs * 2;

  /// Слова, которые знают оба.
  ///
  /// Порядок детерминирован: оба игрока должны получить один и тот же набор,
  /// иначе сравнивать результаты нельзя.
  static List<String> sharedVocabulary(
    Set<String> player,
    Set<String> opponent,
  ) {
    final shared = player.intersection(opponent).toList()..sort();
    return shared;
  }

  /// Хватает ли общего словаря для честного матча.
  static bool canDuel(Set<String> player, Set<String> opponent) =>
      sharedVocabulary(player, opponent).length >= minSharedWords;

  /// Набор дуэли из пересечения. Детерминирован по [seed], чтобы у обоих
  /// участников он совпал.
  static List<String> pickWords(
    List<String> shared, {
    required int seed,
    int count = pairs,
  }) {
    if (shared.length <= count) return shared;

    var state = seed & 0x7fffffff;
    final taken = <int>{};
    final result = <String>[];
    while (result.length < count && taken.length < shared.length) {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      final index = state % shared.length;
      if (!taken.add(index)) continue;
      result.add(shared[index]);
    }
    return result;
  }

  /// Кто выиграл.
  ///
  /// Сначала верные ответы, потом время: дуэль про знание, а не про скорость
  /// пальцев. При полном равенстве — ничья, а не выигрыш по алфавиту.
  static DuelResult judge({
    required int playerCorrect,
    required int playerTimeMs,
    required DuelOpponent opponent,
  }) {
    final DuelOutcome outcome;
    if (playerCorrect != opponent.correct) {
      outcome = playerCorrect > opponent.correct
          ? DuelOutcome.win
          : DuelOutcome.loss;
    } else if (playerTimeMs != opponent.timeMs) {
      outcome =
          playerTimeMs < opponent.timeMs ? DuelOutcome.win : DuelOutcome.loss;
    } else {
      outcome = DuelOutcome.draw;
    }

    return DuelResult(
      outcome: outcome,
      playerCorrect: playerCorrect,
      opponentCorrect: opponent.correct,
      playerTimeMs: playerTimeMs,
      opponentTimeMs: opponent.timeMs,
      againstGhost: opponent.isGhost,
    );
  }

  /// Подбор соперника.
  ///
  /// Живой берётся первым подходящим по пересечению словарей. Если такого
  /// нет — возвращается призрак, и он обязан быть помечен как призрак.
  static DuelOpponent? matchmake({
    required Set<String> playerVocabulary,
    required List<({DuelOpponent opponent, Set<String> vocabulary})> pool,
    DuelOpponent? ghost,
  }) {
    for (final candidate in pool) {
      if (candidate.opponent.kind != OpponentKind.human) continue;
      if (canDuel(playerVocabulary, candidate.vocabulary)) {
        return candidate.opponent;
      }
    }
    return ghost;
  }
}
