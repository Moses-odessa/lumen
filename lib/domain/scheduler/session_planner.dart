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
import 'level_stage.dart';

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

/// Забег одного этапа: чем спрашивают и что именно.
class StagedRun {
  const StagedRun({required this.stage, required this.circles, this.goal});

  final LevelStage stage;
  final List<PlannedCircle> circles;

  /// Цель, если этап идёт на время. `null` у обычных забегов.
  final SprintGoal? goal;

  int get length => circles.length;

  @override
  String toString() => '${stage.name}: ${circles.length} кругов';
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

  /// Уровень этапами: знакомство → закрепление → проверка → напоминание.
  ///
  /// Новое слово встречается [SessionBalance.newWordRepeats] раза — по разу
  /// на каждом из первых трёх этапов. Раньше показы вплетались между
  /// повторами и разводились правилом «не ближе трёх кругов»; теперь их
  /// разводят сами этапы, и разведены они максимально: между двумя показами
  /// одного слова лежит целый забег.
  ///
  /// Возвращает этапы в порядке прохождения. Пустые этапы отсеиваются: забег
  /// из нуля кругов — это экран, который нечем показать.
  static List<StagedRun> level({
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

    final extra = difficulty?.extraOptions ?? 0;
    final draws = difficulty?.modeDraws ?? ClimbBalance.modeDrawsBase;

    // Повторы делятся между этапами: закрепление, проверка и напоминание
    // берут по своей доле, а не одни и те же слова трижды. Напоминанию
    // достаются самые тусклые — те, что ближе всего к тому, чтобы быть
    // забытыми совсем.
    final withReviews = [
      LevelStage.consolidation,
      LevelStage.check,
      LevelStage.reminder,
    ];
    final perStage = (reviewWords / withReviews.length).ceil();
    final queue = chosenReviews.take(reviewWords).toList();

    final runs = <StagedRun>[];
    for (final stage in StageRules.levelOrder) {
      final circles = <PlannedCircle>[];

      if (stage.takesNewWords) {
        for (final word in chosenNew) {
          circles.add(_circleFor(
            word,
            stage: stage,
            capabilities: capabilities,
            random: random,
            draws: draws,
            extra: extra,
            // Первый в жизни показ помечается новым: на нём нет таймера.
            isNew: stage == LevelStage.introduction,
          ));
        }
      }

      if (withReviews.contains(stage)) {
        // Напоминанию идут самые тусклые: очередь отсортирована по яркости,
        // и последний этап забирает её хвост.
        final take = stage == LevelStage.reminder
            ? queue.length
            : min(perStage, queue.length);
        for (final word in queue.take(take)) {
          circles.add(_circleFor(
            word,
            stage: stage,
            capabilities: capabilities,
            random: random,
            draws: draws,
            extra: extra,
          ));
        }
        queue.removeRange(0, take);
      }

      if (circles.isEmpty) continue;
      // Порядок внутри этапа перемешивается: иначе новые слова всегда
      // стоят первыми, и игрок узнаёт их по месту в забеге, а не по слову.
      if (random != null) circles.shuffle(random);
      runs.add(StagedRun(stage: stage, circles: circles));
    }

    return runs;
  }

  /// Спринт: гонка по тому, что уже держится в памяти.
  ///
  /// Слова ниже порога яркости не берутся, даже если просрочены сильнее
  /// остальных: гонка на незнакомом материале учит панике, а не языку.
  /// Новых слов здесь нет по построению — [pool] их не возвращает.
  ///
  /// Круги повторяются по кругу до конца времени: планка спринта в связях, а
  /// не в словах, и слов может не хватить на планку.
  static StagedRun? sprint({
    required List<StudyItem> candidates,
    required SprintGoal goal,
    SessionCapabilities capabilities = const SessionCapabilities(),
    Random? random,
    ClimbDifficulty? difficulty,
  }) {
    final bright = candidates
        .where((c) => !c.isNew)
        .where((c) => c.lumens >= StageRules.minLumensFor(LevelStage.sprint))
        .toList();
    if (bright.isEmpty) return null;

    final extra = difficulty?.extraOptions ?? 0;
    final draws = difficulty?.modeDraws ?? ClimbBalance.modeDrawsBase;

    final order = bright.toList();
    if (random != null) order.shuffle(random);

    // Кругов ставится с запасом: связей нужно [goal.connections], но ошибка
    // возвращает слово в конец очереди, и упереться в конец списка раньше
    // времени нельзя.
    final circles = <PlannedCircle>[];
    for (var i = 0; circles.length < goal.connections * 2; i++) {
      circles.add(_circleFor(
        order[i % order.length],
        stage: LevelStage.sprint,
        capabilities: capabilities,
        random: random,
        draws: draws,
        extra: extra,
      ));
    }

    return StagedRun(stage: LevelStage.sprint, circles: circles, goal: goal);
  }

  /// Круг для слова на этапе.
  static PlannedCircle _circleFor(
    StudyItem word, {
    required LevelStage stage,
    required SessionCapabilities capabilities,
    required Random? random,
    required int draws,
    required int extra,
    bool isNew = false,
  }) =>
      PlannedCircle(
        itemId: word.itemId,
        mode: modeFor(
          word.lumens,
          capabilities: capabilities,
          hasAudio: word.hasAudio,
          random: random,
          draws: draws,
          allowed: StageRules.mechanicsFor(stage),
        ),
        isNew: isNew,
        lumens: word.lumens,
        options: StageRules.optionsFor(stage, extra: extra),
        distractorKind: StageRules.distractorFor(stage),
      );

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

  // `_weave`, `_freeSlot`, `_gapOk` и `_spread` удалены вместе с однородным
  // уровнем.
  //
  // Они раздвигали показы одного слова так, чтобы между ними лежало не меньше
  // трёх кругов: без этого два показа подряд проверяли буфер кратковременной
  // памяти, а не повторение. Теперь показы разводят сами этапы, и разведены
  // они максимально — между двумя показами одного слова лежит целый забег.
  // Держать сто строк раскладки ради задачи, которой больше нет, значит
  // оставить их следующему читателю как загадку.
}
