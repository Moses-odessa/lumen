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
import '../scoring/climb.dart';

/// Слово-кандидат на показ. Всё, что планировщику нужно знать о слове;
/// перевод и озвучка берутся позже из `content.db` по [itemId].
class StudyItem {
  const StudyItem({
    required this.itemId,
    required this.tier,
    required this.lumens,
    this.due,
    this.isNew = false,
    this.hasAudio = true,
  });

  final String itemId;
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
///
/// [options] и [distractorKind] появились здесь потому, что раньше их решала
/// механика внутри сборщика вопросов, и между планировщиком и экраном не было
/// ничего, что могло бы сказать «этот круг — с одним вариантом» или «этот —
/// с созвучными». Вариантность и вид дистракторов есть шкала сложности, и
/// распоряжаться ею должен тот, кто отвечает за сложность.
class PlannedCircle {
  const PlannedCircle({
    required this.itemId,
    required this.mode,
    required this.isNew,
    required this.lumens,
    this.options = ScoreBalance.optionsMax,
    this.distractorKind = DistractorKind.far,
  });

  final String itemId;
  final GameMode mode;

  /// Первый показ нового слова: на нём таймера нет.
  final bool isNew;

  final Lumens lumens;

  /// Сколько вариантов показать. Один — это не проверка, а показ.
  final int options;

  /// Тематические варианты или созвучные.
  final DistractorKind distractorKind;

  PlannedCircle copyWith({
    GameMode? mode,
    bool? isNew,
    int? options,
    DistractorKind? distractorKind,
  }) =>
      PlannedCircle(
        itemId: itemId,
        mode: mode ?? this.mode,
        isNew: isNew ?? this.isNew,
        lumens: lumens,
        options: options ?? this.options,
        distractorKind: distractorKind ?? this.distractorKind,
      );

  @override
  String toString() =>
      '$itemId (${mode.name}, $lumens lm, $options вар., '
      '${distractorKind.name})';
}

/// Что умеет текущая сессия. Механику, которую невозможно показать,
/// планировщик не выбирает — вместо того чтобы поставить круг без задания.
class SessionCapabilities {
  const SessionCapabilities({this.audioEnabled = true});

  /// Беззвучный режим или отсутствие голоса в системе: механики на слух
  /// недоступны, остальное работает.
  ///
  /// Настройки «выключить набор» больше нет вместе с самим набором.
  final bool audioEnabled;
}

abstract final class SessionPlanner {
  /// Пул на сессию: просроченные слова, самые тусклые первыми.
  ///
  /// Это ровно тот запрос, под который в `user.db` заведён индекс
  /// `(due, lm_cached)`: `WHERE due <= now ORDER BY lm_cached ASC LIMIT 40`.
  /// Тусклые вперёд, потому что они ближе всего к тому, чтобы быть забытыми
  /// совсем — а вернуть почти забытое дешевле, чем учить заново.
  static List<StudyItem> pool(
    List<StudyItem> candidates,
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

  /// Механика по яркости слова.
  ///
  /// Правило простое: берём **самую требовательную** механику из тех, чей
  /// диапазон накрывает текущую яркость. Сложность растёт вслед за владением,
  /// а не по расписанию. Фразовые механики сюда не попадают: их материал —
  /// предложение, а не звезда, и ставятся они явно.
  ///
  /// [allowed] сужает набор: этап уровня разрешает не все механики.
  /// [random] добавляет разнообразия: без него игрок с яркими словами видел
  /// бы одну и ту же механику и ничего больше.
  static GameMode modeFor(
    Lumens lumens, {
    SessionCapabilities capabilities = const SessionCapabilities(),
    bool hasAudio = true,
    Random? random,
    int draws = ClimbBalance.modeDrawsBase,
    Set<GameMode>? allowed,
  }) {
    bool playable(GameMode m) =>
        !m.needsAudio || (hasAudio && capabilities.audioEnabled);

    final permitted = _selectableModes
        .where((m) => allowed == null || allowed.contains(m))
        .where(playable)
        .toList();

    final eligible = permitted.where((m) => _fits(m, lumens)).toList();

    if (eligible.isNotEmpty) {
      if (random == null) return eligible.last;

      // Смещение к сложным механикам: берём лучшую из [draws] случайных
      // попыток. Чем больше попыток, тем выше доля продуктивных — так заход
      // и повышает сложность, не отбирая у планировщика право выбирать по
      // яркости.
      var index = 0;
      for (var i = 0; i < max(draws, 1); i++) {
        index = max(index, random.nextInt(eligible.length));
      }
      return eligible[index];
    }

    // Яркость вне разрешённых диапазонов бывает не только при битых данных.
    // Этап тоже может так сузить набор: «знакомство» разрешает a и c, а слово
    // на 90 lm не попадает ни в один из их диапазонов. Прежний код в такой
    // ситуации молча возвращал «Круг» — механику, которую этап не разрешал.
    //
    // Правильный ответ — самая требовательная из **разрешённых**, а не из
    // всех: этап решает, что можно, яркость решает лишь порядок внутри.
    if (permitted.isNotEmpty) return permitted.last;

    // Не осталось ничего: звука нет, а этап разрешил только механики на слух.
    // Такой круг показать нельзя, и притворяться нечем.
    return _fallback;
  }

  /// Уровень: новые слова вперемешку с повторами.
  ///
  /// Новое слово показывается [SessionBalance.newWordRepeats] раз: первый раз
  /// без таймера, потом вплетается в забеги. Повтор — по одному разу.
  /// Отсюда длина уровня: 6 × 3 + 12 = 30 кругов, то есть три забега по
  /// десять.
  static List<PlannedCircle> level({
    required List<StudyItem> reviews,
    required List<StudyItem> fresh,
    SessionCapabilities capabilities = const SessionCapabilities(),
    Random? random,
    int newWords = SessionBalance.newWordsPerLevel,
    int reviewWords = SessionBalance.reviewsPerLevel,
    ClimbDifficulty? difficulty,
  }) {
    final chosenNew = fresh.take(newWords).toList();
    // Тусклые повторы вперёд — порядок задаёт планировщик, а не вызывающий:
    // иначе приоритет тусклым держался бы на честном слове.
    final chosenReviews = reviews.toList()
      ..sort((a, b) => a.lumens.compareTo(b.lumens));

    // Надбавка вариантов от захода живёт здесь, а не в сборщике вопросов.
    //
    // Сначала она была там, и это ломало знакомство: сборщик прибавлял
    // `extraOptions` к КАЖДОМУ кругу, включая тот, которому планировщик
    // намеренно поставил один вариант. С четвёртого уровня захода первый в
    // жизни показ слова становился выбором из двух, с седьмого — из трёх, то
    // есть показ превращался в проверку слова, которого игрок ещё не видел.
    //
    // Вариантность по новому контракту живёт в плане. Значит и надбавка
    // должна применяться там, где известно, что за круг: [_markFirstShows]
    // ставит знакомству свой один вариант последним и надбавку не наследует.
    final extra = difficulty?.extraOptions ?? 0;

    PlannedCircle circleFor(StudyItem word) => PlannedCircle(
          itemId: word.itemId,
          mode: modeFor(
            word.lumens,
            capabilities: capabilities,
            hasAudio: word.hasAudio,
            random: random,
            draws: difficulty?.modeDraws ?? ClimbBalance.modeDrawsBase,
          ),
          isNew: false,
          lumens: word.lumens,
          options: ScoreBalance.defaultOptions(extra: extra),
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
      {for (final word in chosenNew) word.itemId},
    );
  }

  /// Помечает первый по порядку показ каждого нового слова.
  ///
  /// Первый показ — это знакомство, а не проверка: механика на понимание,
  /// один вариант, таймера нет. Один вариант выбран не для лёгкости: выбирать
  /// не из чего, и круг превращается в показ — соединил, услышал, увидел
  /// перевод. Остальные показы остаются такими, какими их выбрал [modeFor].
  static List<PlannedCircle> _markFirstShows(
    List<PlannedCircle> circles,
    Set<String> newWordIds,
  ) {
    final seen = <String>{};
    return [
      for (final circle in circles)
        if (newWordIds.contains(circle.itemId) && seen.add(circle.itemId))
          circle.copyWith(
            mode: GameMode.pickNative,
            isNew: true,
            options: SessionBalance.introductionOptions,
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
    required List<StudyItem> candidates,
    required DateTime now,
    SessionCapabilities capabilities = const SessionCapabilities(),
    Random? random,
    int limit = SessionBalance.sessionPoolSize,
  }) =>
      [
        for (final word in pool(candidates, now, size: limit))
          PlannedCircle(
            itemId: word.itemId,
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
      ids.add(c.itemId);
      if (c.isNew) newIds.add(c.itemId);
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

  /// Механики, которые планировщик выбирает сам, в порядке возрастания
  /// требовательности. Фразовых здесь нет: их ставит этап.
  static const List<GameMode> _selectableModes = [
    GameMode.pickNative,
    GameMode.listenNative,
    GameMode.pickTarget,
    GameMode.listenTarget,
  ];

  /// Механика на случай, когда не подошла ни одна: без звука и без выбора.
  ///
  /// Единственная механика на слово, которая не требует ни звука, ни
  /// вариантов на изучаемом языке, — то есть работает при любом контенте и
  /// любых настройках.
  static const GameMode _fallback = GameMode.pickNative;

  static bool _fits(GameMode mode, Lumens lumens) {
    final range = ScoreBalance.modeLumenRange(mode);
    return lumens >= range.min && lumens <= range.max;
  }

  static int _compareDue(StudyItem a, StudyItem b) {
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
      result.insert(_freeSlot(result, extra[i].itemId, target), extra[i]);
    }
    return result;
  }

  /// Ближайшая к [target] позиция, где слово не окажется рядом со своим же
  /// показом.
  static int _freeSlot(
    List<PlannedCircle> circles,
    String itemId,
    int target,
  ) {
    for (var offset = 0; offset <= circles.length; offset++) {
      for (final position in {target + offset, target - offset}) {
        if (position < 0 || position > circles.length) continue;
        if (_gapOk(circles, itemId, position)) return position;
      }
    }
    return target;
  }

  static bool _gapOk(
    List<PlannedCircle> circles,
    String itemId,
    int position,
  ) {
    const gap = SessionBalance.minGapBetweenRepeats;
    final from = max(0, position - gap);
    final to = min(circles.length, position + gap);
    for (var i = from; i < to; i++) {
      if (circles[i].itemId == itemId) return false;
    }
    return true;
  }

  /// Раскладка, когда повторов нет вообще — только новые слова.
  static List<PlannedCircle> _spread(List<PlannedCircle> circles) {
    final byWord = <String, List<PlannedCircle>>{};
    for (final circle in circles) {
      byWord.putIfAbsent(circle.itemId, () => []).add(circle);
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
