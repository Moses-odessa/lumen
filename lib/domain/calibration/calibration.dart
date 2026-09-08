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

  /// Тройное подтверждение границы, минимум один раз «тесным кругом».
  confirm,

  /// Четыре фразы на найденном ярусе.
  phrases,

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

  /// Переспрос подозрительно быстрого ответа: в зачёт не идёт.
  final bool isRepeat;
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
    this.tightConfirmed = false,
    this.phrasesAsked = 0,
    this.phrasesCorrect = 0,
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

  /// Успешных подтверждений границы и был ли среди них тесный круг.
  final int confirmations;
  final bool tightConfirmed;

  /// Промахов при подтверждении.
  ///
  /// Один прощается: тройная проверка стоит против угадывания вверх, а не
  /// против случайного промаха пальцем. Ронять целый ярус из-за одной
  /// осечки — это ошибка в другую сторону, и она обходится дороже.
  final int confirmFailures;

  final int phrasesAsked;
  final int phrasesCorrect;

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
        mode: switch (phase) {
          CalibrationPhase.phrases => GameMode.phrase,
          // Граница обязана быть проверена «тесным кругом» хотя бы раз:
          // шесть вариантов дают 17 % случайного попадания, и на обычном
          // круге это слишком дёшево.
          CalibrationPhase.confirm when !tightConfirmed => GameMode.tight,
          _ => GameMode.circle,
        },
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
    bool? tightConfirmed,
    int? phrasesAsked,
    int? phrasesCorrect,
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
        tightConfirmed: tightConfirmed ?? this.tightConfirmed,
        phrasesAsked: phrasesAsked ?? this.phrasesAsked,
        phrasesCorrect: phrasesCorrect ?? this.phrasesCorrect,
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
            (confirmations / CalibrationBalance.borderConfirmations) * 0.15,
        CalibrationPhase.phrases => 0.85 +
            (phrasesAsked / CalibrationBalance.finalPhraseChecks) * 0.15,
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
      CalibrationPhase.phrases => _phrases(state, correct),
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
      // Верхний ярус взят с ходу — подтверждаем и заканчиваем фразами.
      return next.copyWith(
        phase: CalibrationPhase.phrases,
        confirmed: confirmed,
        lowest: () => state.probe,
        probe: state.probe,
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
    final wasTight = state.step.mode == GameMode.tight;
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
        return next.copyWith(
          phase: CalibrationPhase.phrases,
          probe: Tier.a0,
          result: () => Tier.a0,
        );
      }
      return next.copyWith(
        probe: down,
        confirmations: 0,
        confirmFailures: 0,
        tightConfirmed: false,
        highest: () => _lower(state.highest, state.probe),
      );
    }

    next = next.copyWith(
      confirmations: state.confirmations + 1,
      tightConfirmed: state.tightConfirmed || wasTight,
      confirmed: {...state.confirmed, state.probe},
      lowest: () => _higher(state.lowest, state.probe),
      highest: () => _clearIfStale(state.highest, state.probe),
    );

    final enough = next.confirmations >= CalibrationBalance.borderConfirmations;
    if (enough && next.tightConfirmed) {
      return next.copyWith(phase: CalibrationPhase.phrases, phrasesAsked: 0);
    }
    return next;
  }

  /// Четыре фразы на найденном ярусе.
  ///
  /// Знает слова, но не собирает предложения — типичная картина у человека,
  /// который учил язык по спискам. Ярус в этом случае честнее опустить.
  static CalibrationState _phrases(CalibrationState state, bool correct) {
    final next = state.copyWith(
      asked: state.asked + 1,
      phrasesAsked: state.phrasesAsked + 1,
      phrasesCorrect: state.phrasesCorrect + (correct ? 1 : 0),
    );

    if (next.phrasesAsked < CalibrationBalance.finalPhraseChecks) {
      return next;
    }

    // Меньше половины фраз — сдвиг на ярус вниз.
    final passed = next.phrasesCorrect * 2 >= CalibrationBalance.finalPhraseChecks;
    final tier = passed ? next.probe : (next.probe.down ?? next.probe);

    return next.copyWith(
      phase: CalibrationPhase.done,
      probe: tier,
      result: () => tier,
    );
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
