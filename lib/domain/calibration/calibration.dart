/// Адаптивная калибровка: где начинается небо игрока.
///
/// Спрашивать «какой у вас уровень?» бессмысленно — люди систематически
/// ошибаются в обе стороны. Вместо вопроса игрок сразу играет: та же
/// механика круга, те же жесты, только слова со всех пяти ярусов.
///
/// Чистый Dart и чистая функция перехода: `answer(state, ...) → state`.
/// Благодаря этому алгоритм можно прогнать на тысяче синтетических «игроков»
/// с заданным истинным уровнем и измерить, как часто он ошибается — что и
/// требует критерий приёмки M3.
library;

import '../entities/game_mode.dart';
import '../entities/tier.dart';
import '../scoring/balance.dart';

/// Фазы теста.
enum CalibrationPhase {
  /// Гребёнка: по одному кругу с каждого яруса снизу вверх, до первого
  /// промаха. Заодно лучший туториал — правила объясняются одним движением
  /// пальца.
  comb,

  /// Адаптивный поиск: два верных подряд поднимают, две ошибки опускают.
  search,

  /// Тройное подтверждение границы, минимум один раз созвучными вариантами.
  ///
  /// **Фаза не обязательна.** Забег, взявший все пять ярусов гребёнкой с
  /// ходу, уходит прямо к фразам и созвучного круга не видит ни разу — это
  /// примерно 42 % синтетических прогонов на игроке уровня B2. Так и
  /// задумано: угадать всю гребёнку — это (1/6)⁵, один шанс из семи с
  /// половиной тысяч, и подтверждать тут нечего.
  ///
  /// Написано это здесь потому, что докстрока раньше обещала «граница всегда
  /// проверена созвучными», а код обещания не давал.
  confirm,

  // Фаза `phrases` удалена вместе с разницей, которую она мерила.
  //
  // Она спрашивала четыре целых предложения на найденном ярусе и роняла
  // ярус, если игрок собрал меньше половины: «знает слова, но не собирает
  // предложения — типичная картина у человека, который учил язык по
  // спискам». Единицей изучения стала фраза, отдельных слов в игре нет —
  // значит и гребёнка, и поиск, и подтверждение спрашивают ровно то же, что
  // спрашивала эта фаза. Отдельная проверка стала повтором.

  /// Ярус найден.
  done,
}

/// Что показать игроку прямо сейчас.
class CalibrationStep {
  const CalibrationStep({
    required this.tier,
    required this.mode,
    required this.phase,
    this.isRepeat = false,
  });

  final Tier tier;
  final GameMode mode;
  final CalibrationPhase phase;

  /// Тематические варианты или созвучные.
  ///
  /// Поле обязано быть здесь, а не выводиться из механики. Раньше «тесный
  /// круг» был отдельным режимом, и правило «границу нужно подтвердить хотя
  /// бы раз созвучными» читалось как `mode == GameMode.tight`. После слияния
  /// круга и тесного круга в одну механику такая проверка не упала бы — она
  /// просто перестала бы срабатывать никогда, и каждая граница
  /// подтверждалась бы с шансом угадать один к шести. Тесты калибровки при
  /// этом остались бы зелёными.

  /// Переспрос подозрительно быстрого ответа: в зачёт не идёт.
  final bool isRepeat;

  /// Круг с созвучными вариантами: угадать вдвое труднее.
}

/// Состояние теста. Неизменяемое: каждый ответ порождает новое.
class CalibrationState {
  const CalibrationState({
    required this.phase,
    required this.probe,
    this.asked = 0,
    this.repeats = 0,
    this.consecutiveCorrect = 0,
    this.consecutiveWrong = 0,
    this.confirmations = 0,
    this.confirmFailures = 0,
    this.lowest,
    this.highest,
    this.pendingRepeat = false,
    this.confirmed = const {},
    this.result,
  });

  /// Начало теста: гребёнка с самого нижнего яруса.
  factory CalibrationState.start() =>
      const CalibrationState(phase: CalibrationPhase.comb, probe: Tier.a0);

  final CalibrationPhase phase;

  /// Ярус, который проверяется сейчас.
  final Tier probe;

  /// Сколько зачётных кругов задано.
  final int asked;

  /// Сколько было переспросов.
  final int repeats;

  final int consecutiveCorrect;
  final int consecutiveWrong;

  /// Успешных подтверждений границы.
  final int confirmations;

  /// Промахов при подтверждении.
  ///
  /// Один прощается: тройная проверка стоит против угадывания вверх, а не
  /// против случайного промаха пальцем. Ронять целый ярус из-за одной
  /// осечки — это ошибка в другую сторону, и она обходится дороже.
  final int confirmFailures;

  /// Границы поиска: самый высокий подтверждённый и самый низкий
  /// проваленный ярус.
  final Tier? lowest;
  final Tier? highest;

  /// Следующий круг — переспрос.
  final bool pendingRepeat;

  /// Ярусы, слова которых игрок подтвердил: из них засевается память.
  final Set<Tier> confirmed;

  /// Итог; `null`, пока тест не закончен.
  final Tier? result;

  bool get isDone => phase == CalibrationPhase.done;

  /// Что показать сейчас.
  CalibrationStep get step => CalibrationStep(
        tier: probe,
        phase: phase,
        isRepeat: pendingRepeat,
        // Механика одна на весь тест: назвать фразу на изучаемом языке.
        // Это самое требовательное из трёх, и мерить ярус надо им.
        mode: GameMode.pickTarget,
      );

  CalibrationState copyWith({
    CalibrationPhase? phase,
    Tier? probe,
    int? asked,
    int? repeats,
    int? consecutiveCorrect,
    int? consecutiveWrong,
    int? confirmations,
    int? confirmFailures,
    Tier? Function()? lowest,
    Tier? Function()? highest,
    bool? pendingRepeat,
    Set<Tier>? confirmed,
    Tier? Function()? result,
  }) =>
      CalibrationState(
        phase: phase ?? this.phase,
        probe: probe ?? this.probe,
        asked: asked ?? this.asked,
        repeats: repeats ?? this.repeats,
        consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
        consecutiveWrong: consecutiveWrong ?? this.consecutiveWrong,
        confirmations: confirmations ?? this.confirmations,
        confirmFailures: confirmFailures ?? this.confirmFailures,
        lowest: lowest == null ? this.lowest : lowest(),
        highest: highest == null ? this.highest : highest(),
        pendingRepeat: pendingRepeat ?? this.pendingRepeat,
        confirmed: confirmed ?? this.confirmed,
        result: result == null ? this.result : result(),
      );

  /// Примерный прогресс теста 0..1 — для полосы на экране.
  double get progress => switch (phase) {
        CalibrationPhase.comb => (probe.index / Tier.values.length) * 0.25,
        CalibrationPhase.search =>
          0.25 + (asked / CalibrationBalance.searchCirclesMax) * 0.45,
        CalibrationPhase.confirm => 0.7 +
            (confirmations / CalibrationBalance.borderConfirmations) * 0.3,
        CalibrationPhase.done => 1,
      };
}

abstract final class Calibration {
  /// Сколько промахов прощается при подтверждении границы.
  ///
  /// Один — то есть ярус роняет только вторая осечка подряд.
  static const int _allowedConfirmFailures = 2;

  /// Применяет один ответ.
  ///
  /// [latency] нужна не для очков, а для защиты от угадывания: подозрительно
  /// быстрый верный ответ на незнакомом ярусе переспрашивается другим словом.
  static CalibrationState answer(
    CalibrationState state, {
    required bool correct,
    required Duration latency,
  }) {
    if (state.isDone) return state;

    // Переспрос: результат прошлого круга не засчитан, этот идёт вместо него.
    if (state.pendingRepeat) {
      return _apply(state.copyWith(pendingRepeat: false), correct, latency,
          allowRepeat: false);
    }

    return _apply(state, correct, latency, allowRepeat: true);
  }

  static CalibrationState _apply(
    CalibrationState state,
    bool correct,
    Duration latency, {
    required bool allowRepeat,
  }) {
    // Защита от угадывания: верный ответ быстрее человеческого чтения на
    // ярусе выше подтверждённого — это тык, а не знание.
    if (allowRepeat &&
        correct &&
        latency < CalibrationBalance.suspiciousLatency &&
        state.repeats < CalibrationBalance.maxRepeats &&
        _isAboveKnown(state)) {
      return state.copyWith(
        pendingRepeat: true,
        repeats: state.repeats + 1,
      );
    }

    return switch (state.phase) {
      CalibrationPhase.comb => _comb(state, correct),
      CalibrationPhase.search => _search(state, correct),
      CalibrationPhase.confirm => _confirm(state, correct),
      CalibrationPhase.done => state,
    };
  }

  /// Ярус проверки выше всего, что игрок уже подтвердил.
  static bool _isAboveKnown(CalibrationState state) {
    final known = state.lowest;
    return known == null || state.probe.index > known.index;
  }

  /// Гребёнка: поднимаемся по одному кругу с яруса до первого промаха.
  static CalibrationState _comb(CalibrationState state, bool correct) {
    final next = state.copyWith(asked: state.asked + 1);

    if (!correct) {
      // Промах: истинный ярус где-то между последним верным и этим.
      return next.copyWith(
        phase: CalibrationPhase.search,
        highest: () => state.probe,
        probe: state.probe.down ?? Tier.a0,
        consecutiveCorrect: 0,
        consecutiveWrong: 1,
      );
    }

    final confirmed = {...state.confirmed, state.probe};
    final up = state.probe.up;

    if (up == null) {
      // Верхний ярус взят с ходу — подтверждать нечего, тест закончен.
      //
      // Раньше отсюда шли к проверке фразами: она была единственным, что
      // отделяло «прошёл всю гребёнку» от «получил B2». Угадать гребёнку это
      // (1/6)⁵, один шанс из семи с половиной тысяч, так что отдельной
      // проверки такой прогон и не требовал.
      return next.copyWith(
        phase: CalibrationPhase.done,
        confirmed: confirmed,
        lowest: () => state.probe,
        probe: state.probe,
        result: () => state.probe,
      );
    }

    return next.copyWith(
      probe: up,
      confirmed: confirmed,
      lowest: () => state.probe,
    );
  }

  /// Адаптивный поиск: два верных подряд — вверх, две ошибки — вниз.
  static CalibrationState _search(CalibrationState state, bool correct) {
    var next = state.copyWith(asked: state.asked + 1);

    if (correct) {
      next = next.copyWith(
        consecutiveCorrect: state.consecutiveCorrect + 1,
        consecutiveWrong: 0,
        confirmed: {...state.confirmed, state.probe},
        lowest: () => _higher(state.lowest, state.probe),
        // Верный ответ на ярусе не ниже проваленного означает, что тот
        // провал был осечкой, а не границей знания. Без этого одна ошибка
        // в гребёнке навсегда ставила бы потолок: игрок B2, промахнувшийся
        // на A1, уже не мог подняться выше A1.
        highest: () => _clearIfStale(state.highest, state.probe),
      );
    } else {
      next = next.copyWith(
        consecutiveWrong: state.consecutiveWrong + 1,
        consecutiveCorrect: 0,
        highest: () => _lower(state.highest, state.probe),
      );
    }

    // Достаточно кругов и границы сошлись — переходим к подтверждению.
    if (next.asked >= CalibrationBalance.searchCirclesMin &&
        _converged(next)) {
      return next.copyWith(
        phase: CalibrationPhase.confirm,
        probe: _estimate(next),
        consecutiveCorrect: 0,
        consecutiveWrong: 0,
      );
    }

    if (next.asked >= CalibrationBalance.searchCirclesMax) {
      return next.copyWith(
        phase: CalibrationPhase.confirm,
        probe: _estimate(next),
        consecutiveCorrect: 0,
        consecutiveWrong: 0,
      );
    }

    if (next.consecutiveCorrect >= CalibrationBalance.correctToRise) {
      final up = next.probe.up;
      return next.copyWith(
        probe: up ?? next.probe,
        consecutiveCorrect: 0,
      );
    }
    if (next.consecutiveWrong >= CalibrationBalance.errorsToFall) {
      final down = next.probe.down;
      return next.copyWith(
        probe: down ?? next.probe,
        consecutiveWrong: 0,
      );
    }

    return next;
  }

  /// Тройное подтверждение границы.
  ///
  /// Ярус никогда не подтверждается одним кругом: шесть вариантов дают 17 %
  /// случайного попадания, и без повторной проверки каждый шестой игрок
  /// получал бы завышенный результат.
  static CalibrationState _confirm(CalibrationState state, bool correct) {
    var next = state.copyWith(asked: state.asked + 1);

    if (!correct) {
      final failures = state.confirmFailures + 1;

      // Первый промах прощается: игрок остаётся на том же ярусе и
      // продолжает подтверждать. Второй — уже закономерность, спускаемся.
      if (failures < _allowedConfirmFailures) {
        return next.copyWith(confirmFailures: failures);
      }

      final down = state.probe.down;
      if (down == null) {
        // Ниже A0 некуда — тест закончен, и это A0.
        //
        // Раньше здесь начиналась проверка фразами, и `result` не
        // выставлялся, чтобы не нарушить контракт поля «null, пока тест не
        // закончен». Проверки больше нет, значит тест действительно
        // закончен, и `result` выставляется вместе с фазой — как во всех
        // остальных концовках.
        return next.copyWith(
          phase: CalibrationPhase.done,
          probe: Tier.a0,
          result: () => Tier.a0,
        );
      }
      return next.copyWith(
        probe: down,
        confirmations: 0,
        confirmFailures: 0,
        highest: () => _lower(state.highest, state.probe),
      );
    }

    next = next.copyWith(
      confirmations: state.confirmations + 1,
      // Счётчик промахов обнуляется верным ответом.
      //
      // Без этого «промах → верно → промах» ронял ярус, хотя правило рядом
      // сказано так: «ярус роняет только вторая осечка **подряд**». Счётчик
      // копился накопительно, и правило означало не то, что написано, — а
      // расхождение между комментарием и кодом здесь особенно дорого: игрок
      // получал ярус ниже заслуженного и не мог понять, за что.
      confirmFailures: 0,
      confirmed: {...state.confirmed, state.probe},
      lowest: () => _higher(state.lowest, state.probe),
      highest: () => _clearIfStale(state.highest, state.probe),
    );

    // Подтверждений хватило — ярус найден.
    //
    // Второго условия здесь больше нет. Оно требовало, чтобы хотя бы одно
    // подтверждение прошло «тесным кругом» — на созвучных вариантах, потому
    // что шесть тематических дают 17 % случайного попадания. Рукописных
    // дистракторов в игре нет: вокруг фразы стоят другие фразы, и «тесного
    // круга» как отдельного вида круга не существует.
    if (next.confirmations >= CalibrationBalance.borderConfirmations) {
      return next.copyWith(
        phase: CalibrationPhase.done,
        result: () => next.probe,
      );
    }
    return next;
  }

  /// Оценка яруса по границам поиска.
  static Tier _estimate(CalibrationState state) {
    final lowest = state.lowest;
    final highest = state.highest;

    if (lowest == null && highest == null) return state.probe;
    if (lowest == null) return Tier.a0;
    if (highest == null) return lowest;

    // Между «уверенно знает» и «не знает» берём нижнюю границу: завышенный
    // ярус отпугивает сильнее, чем заниженный утомляет. Если границы
    // противоречат друг другу, доверяем подтверждённому: провал мог быть
    // осечкой, а серия верных ответов — нет.
    return lowest.index <= highest.index ? lowest : highest;
  }

  /// Границы сошлись: между подтверждённым и проваленным ярусом не осталось
  /// промежутка.
  static bool _converged(CalibrationState state) {
    final lowest = state.lowest;
    final highest = state.highest;
    if (lowest == null || highest == null) return false;
    return highest.index - lowest.index <= 1;
  }

  /// Забывает проваленный ярус, если игрок только что взял его или выше.
  static Tier? _clearIfStale(Tier? highest, Tier passed) =>
      highest != null && passed.index >= highest.index ? null : highest;

  static Tier? _higher(Tier? current, Tier candidate) =>
      current == null || candidate.index > current.index ? candidate : current;

  static Tier? _lower(Tier? current, Tier candidate) =>
      current == null || candidate.index < current.index ? candidate : current;

  /// Кнопка «я с нуля»: A0 без теста.
  static CalibrationState fromScratch() => CalibrationState(
        phase: CalibrationPhase.done,
        probe: Tier.a0,
        result: Tier.a0,
      );

  // `estimatedVocabulary` отсюда удалён.
  //
  // Он считал «сколько слов игрок уже знает» как размер созвездия по ярусу,
  // умноженный на тридцать созвездий, и на B2 давал ровно 2880 — при том, что
  // созвездий девять, а слов в базе 864. Экран результата обещал человеку
  // втрое больше, чем в приложении есть.
  //
  // Число теперь берётся из базы: сколько концептов на этом ярусе и ниже.
  // Курс растёт файлами контента, и обещание должно расти вместе с ним, а не
  // вместе с константой.
}
