/// Подбор материала на сессию: какие слова показать, в каком режиме и в
/// каком порядке.
///
/// Чистый Dart: ни БД, ни Flutter, ни системных часов — момент и список
/// кандидатов приходят снаружи.
library;

import 'dart:math';

import '../entities/game_mode.dart';
import '../entities/tier.dart';
import '../scoring/balance.dart';

/// Слово-кандидат на показ. Всё, что планировщику нужно знать о слове;
/// перевод и озвучка берутся позже из `content.db` по [conceptId].
class WordCandidate {
  const WordCandidate({
    required this.conceptId,
    required this.tier,
    required this.lumens,
    this.due,
    this.isNew = false,
    this.hasAudio = true,
  });

  final String conceptId;
  final Tier tier;

  /// Яркость на момент планирования.
  final Lumens lumens;

  /// Когда слово стоит повторить; `null` у нового.
  final DateTime? due;

  final bool isNew;

  /// Есть ли озвучка. Без неё режим «Слух» невозможен.
  final bool hasAudio;

  /// Слово просрочено — его пора показать.
  bool isDue(DateTime now) => due == null || !due!.isAfter(now);
}

/// Один запланированный круг.
class PlannedCircle {
  const PlannedCircle({
    required this.conceptId,
    required this.mode,
    required this.isNew,
    required this.lumens,
  });

  final String conceptId;
  final GameMode mode;

  /// Первый показ нового слова: на нём таймера нет.
  final bool isNew;

  final Lumens lumens;

  @override
  String toString() => '$conceptId (${mode.name}, $lumens lm)';
}

/// Что умеет текущая сессия. Режим, который невозможно показать, планировщик
/// не выбирает — вместо того чтобы упасть на пустом аудиофайле.
class SessionCapabilities {
  const SessionCapabilities({
    this.audioEnabled = true,
    this.typingEnabled = true,
  });

  /// Беззвучный режим: «Слух» недоступен, остальное работает.
  final bool audioEnabled;

  /// Клавиатура на маленьком экране в транспорте — сомнительное удовольствие,
  /// поэтому «Набор» отключаем настройкой.
  final bool typingEnabled;
}

abstract final class SessionPlanner {
  /// Пул на сессию: просроченные слова, самые тусклые первыми.
  ///
  /// Это ровно тот запрос, под который в `user.db` заведён индекс
  /// `(due, lm_cached)`: `WHERE due <= now ORDER BY lm_cached ASC LIMIT 40`.
  /// Тусклые вперёд, потому что они ближе всего к тому, чтобы быть забытыми
  /// совсем — а вернуть почти забытое дешевле, чем учить заново.
  static List<WordCandidate> pool(
    List<WordCandidate> candidates,
    DateTime now, {
    int size = SessionBalance.sessionPoolSize,
  }) {
    final due = candidates
        .where((c) => !c.isNew && c.isDue(now))
        .toList()
      ..sort((a, b) {
        final byLumens = a.lumens.compareTo(b.lumens);
        // При равной яркости раньше показываем то, что дольше ждало.
        return byLumens != 0 ? byLumens : _compareDue(a, b);
      });
    return due.take(size).toList();
  }

  /// Режим по яркости слова.
  ///
  /// Правило простое: берём **самый требовательный** режим из тех, чей
  /// диапазон накрывает текущую яркость. Сложность растёт вслед за владением,
  /// а не по расписанию. Режим «Фраза» сюда не попадает: это босс уровня,
  /// его ставят явно, а не по яркости.
  ///
  /// [random] добавляет разнообразия: без него игрок выше 60 lm видел бы
  /// один «Набор» и ничего больше.
  static GameMode modeFor(
    Lumens lumens, {
    SessionCapabilities capabilities = const SessionCapabilities(),
    bool hasAudio = true,
    Random? random,
  }) {
    final eligible = _selectableModes
        .where((m) => _fits(m, lumens))
        .where((m) => m != GameMode.audio || (hasAudio && capabilities.audioEnabled))
        .where((m) => m != GameMode.typing || capabilities.typingEnabled)
        .toList();

    if (eligible.isEmpty) {
      // Яркость вне всех диапазонов бывает только при битых данных.
      // Круг — самый нейтральный режим, играть можно всегда.
      return GameMode.circle;
    }
    if (random == null) return eligible.last;

    // Смещение к сложным режимам: из подходящих выбираем случайный, но
    // предпочитаем верхнюю половину списка.
    final index = max(
      random.nextInt(eligible.length),
      random.nextInt(eligible.length),
    );
    return eligible[index];
  }

  /// Уровень: новые слова вперемешку с повторами.
  ///
  /// Новое слово показывается [SessionBalance.newWordRepeats] раз: первый раз
  /// без таймера, потом вплетается в забеги. Повтор — по одному разу.
  /// Отсюда длина уровня: 6 × 3 + 12 = 30 кругов, то есть три забега по
  /// десять.
  static List<PlannedCircle> level({
    required List<WordCandidate> reviews,
    required List<WordCandidate> fresh,
    SessionCapabilities capabilities = const SessionCapabilities(),
    Random? random,
    int newWords = SessionBalance.newWordsPerLevel,
    int reviewWords = SessionBalance.reviewsPerLevel,
  }) {
    final chosenNew = fresh.take(newWords).toList();
    // Тусклые повторы вперёд — порядок задаёт планировщик, а не вызывающий:
    // иначе приоритет тусклым держался бы на честном слове.
    final chosenReviews = reviews.toList()
      ..sort((a, b) => a.lumens.compareTo(b.lumens));

    PlannedCircle circleFor(WordCandidate word) => PlannedCircle(
          conceptId: word.conceptId,
          mode: modeFor(
            word.lumens,
            capabilities: capabilities,
            hasAudio: word.hasAudio,
            random: random,
          ),
          isNew: false,
          lumens: word.lumens,
        );

    final slots = [
      for (final word in chosenReviews.take(reviewWords)) circleFor(word),
    ];

    // Новые слова вплетаются между повторами, а не идут блоком: шесть новых
    // подряд — это зубрёжка, после которой ни одно не остаётся.
    final occurrences = <PlannedCircle>[
      for (final word in chosenNew)
        for (var i = 0; i < SessionBalance.newWordRepeats; i++)
          circleFor(word),
    ];

    // Роль показа назначается ПОСЛЕ раскладки, а не до неё: вплетение
    // раздвигает круги и может поменять их порядок местами, и тогда «первый
    // показ» перестал бы быть первым.
    return _markFirstShows(
      _weave(slots, occurrences),
      {for (final word in chosenNew) word.conceptId},
    );
  }

  /// Помечает первый по порядку показ каждого нового слова: узнавание,
  /// без таймера. Остальные показы остаются такими, какими их выбрал
  /// [modeFor].
  static List<PlannedCircle> _markFirstShows(
    List<PlannedCircle> circles,
    Set<String> newWordIds,
  ) {
    final seen = <String>{};
    return [
      for (final circle in circles)
        if (newWordIds.contains(circle.conceptId) && seen.add(circle.conceptId))
          PlannedCircle(
            conceptId: circle.conceptId,
            mode: GameMode.recognition,
            isNew: true,
            lumens: circle.lumens,
          )
        else
          circle,
    ];
  }

  /// Восход: только повторения, самые тусклые первыми, без новых слов.
  ///
  /// Это первая фаза дневного ритуала — две минуты на то, чтобы вернуть небу
  /// люмены, а не выучить что-то новое.
  static List<PlannedCircle> sunrise({
    required List<WordCandidate> candidates,
    required DateTime now,
    SessionCapabilities capabilities = const SessionCapabilities(),
    Random? random,
    int limit = SessionBalance.sessionPoolSize,
  }) =>
      [
        for (final word in pool(candidates, now, size: limit))
          PlannedCircle(
            conceptId: word.conceptId,
            mode: modeFor(
              word.lumens,
              capabilities: capabilities,
              hasAudio: word.hasAudio,
              random: random,
            ),
            isNew: false,
            lumens: word.lumens,
          ),
      ];

  /// Разбиение на забеги.
  ///
  /// Обобщено по типу элемента намеренно: делить приходится и план кругов,
  /// и уже собранные вопросы — часть из которых отсеялась из-за нехватки
  /// контента, так что резать надо после сборки, а не до.
  static List<List<T>> intoRuns<T>(
    List<T> circles, {
    int perRun = SessionBalance.circlesPerRunMin,
  }) {
    if (circles.isEmpty) return const [];
    final runs = <List<T>>[];
    for (var i = 0; i < circles.length; i += perRun) {
      runs.add(circles.sublist(i, min(i + perRun, circles.length)));
    }
    // Хвост короче половины забега приклеиваем к предыдущему, иначе
    // последний забег из двух кругов выглядит как ошибка.
    if (runs.length > 1 && runs.last.length < perRun / 2) {
      final tail = runs.removeLast();
      runs.last.addAll(tail);
    }
    return runs;
  }

  /// Доля новых слов в плане. Нужна, чтобы предупредить игрока со «своим
  /// темпом», что очередь повторений растёт быстрее, чем он её разгребает.
  static double newWordShare(List<PlannedCircle> circles) {
    if (circles.isEmpty) return 0;
    final ids = <String>{};
    final newIds = <String>{};
    for (final c in circles) {
      ids.add(c.conceptId);
      if (c.isNew) newIds.add(c.conceptId);
    }
    return newIds.length / ids.length;
  }

  /// Сколько новых слов можно добавить, не превысив допустимую долю.
  static int allowedNewWords({
    required int reviewCount,
    required bool freePace,
  }) {
    if (!freePace) return SessionBalance.newWordsPerLevel;
    // При «своём темпе» число новых слов ограничено долей от повторов, а не
    // фиксированным числом: чем длиннее очередь, тем меньше новых.
    final share = SessionBalance.maxNewWordShare;
    final allowed = (reviewCount * share / (1 - share)).floor();
    return max(SessionBalance.newWordsPerLevel, allowed);
  }

  // ── Внутреннее ──────────────────────────────────────────────────────────

  /// Режимы, которые планировщик выбирает сам, в порядке возрастания
  /// требовательности.
  static const List<GameMode> _selectableModes = [
    GameMode.recognition,
    GameMode.circle,
    GameMode.tight,
    GameMode.audio,
    GameMode.typing,
  ];

  static bool _fits(GameMode mode, Lumens lumens) {
    final range = ScoreBalance.modeLumenRange(mode);
    return lumens >= range.min && lumens <= range.max;
  }

  static int _compareDue(WordCandidate a, WordCandidate b) {
    final ad = a.due;
    final bd = b.due;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  /// Вплетает [extra] в [base], раздвигая одинаковые слова.
  ///
  /// Алгоритм намеренно простой: раскладываем вставки по равномерным
  /// позициям, а если два показа одного слова оказались ближе допустимого,
  /// сдвигаем более поздний дальше. Идеальной раскладки не ищем — важно лишь
  /// то, чтобы слово не встречалось дважды подряд.
  static List<PlannedCircle> _weave(
    List<PlannedCircle> base,
    List<PlannedCircle> extra,
  ) {
    if (extra.isEmpty) return base;
    if (base.isEmpty) return _spread(extra);

    final result = <PlannedCircle>[...base];
    final step = (result.length + extra.length) / (extra.length + 1);

    for (var i = 0; i < extra.length; i++) {
      final target = ((i + 1) * step).round().clamp(0, result.length);
      result.insert(_freeSlot(result, extra[i].conceptId, target), extra[i]);
    }
    return result;
  }

  /// Ближайшая к [target] позиция, где слово не окажется рядом со своим же
  /// показом.
  static int _freeSlot(
    List<PlannedCircle> circles,
    String conceptId,
    int target,
  ) {
    for (var offset = 0; offset <= circles.length; offset++) {
      for (final position in {target + offset, target - offset}) {
        if (position < 0 || position > circles.length) continue;
        if (_gapOk(circles, conceptId, position)) return position;
      }
    }
    return target;
  }

  static bool _gapOk(
    List<PlannedCircle> circles,
    String conceptId,
    int position,
  ) {
    const gap = SessionBalance.minGapBetweenRepeats;
    final from = max(0, position - gap);
    final to = min(circles.length, position + gap);
    for (var i = from; i < to; i++) {
      if (circles[i].conceptId == conceptId) return false;
    }
    return true;
  }

  /// Раскладка, когда повторов нет вообще — только новые слова.
  static List<PlannedCircle> _spread(List<PlannedCircle> circles) {
    final byWord = <String, List<PlannedCircle>>{};
    for (final circle in circles) {
      byWord.putIfAbsent(circle.conceptId, () => []).add(circle);
    }

    // Круговой обход: по одному показу каждого слова, потом второй круг.
    final result = <PlannedCircle>[];
    var added = true;
    while (added) {
      added = false;
      for (final queue in byWord.values) {
        if (queue.isEmpty) continue;
        result.add(queue.removeAt(0));
        added = true;
      }
    }
    return result;
  }
}
