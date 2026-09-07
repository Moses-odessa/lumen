/// Единственное место, где живут числовые константы геймдизайна: пороги
/// яркости, множители очков, размеры созвездий, длины сессий.
///
/// Правило из AGENT.md: любая цифра баланса меняется здесь и нигде больше,
/// каждая помечена `TODO(balance)` — значения взяты из docs/CONCEPT.md и
/// подлежат подстройке на живых данных, а не выведены из чего-либо.
///
/// Файл — чистый Dart: ни Flutter, ни Drift, ни `dart:io`.
library;

import '../entities/game_mode.dart';
import '../entities/tier.dart';

/// Яркость звезды в люменах: вероятность вспомнить слово прямо сейчас,
/// умноженная на 100. Производная величина от тройки FSRS.
typedef Lumens = int;

/// Полосы яркости из docs/CONCEPT.md. Границы — нижние, включительно.
enum LumenBand {
  /// 0–14: практически забыто, вернётся как новое.
  fading(0),

  /// 15–34: тускнеет, попадает в начало завтрашнего Восхода.
  dimming(15),

  /// 35–59: узнаёте, но не вспоминаете сами.
  flickering(35),

  /// 60–84: знаете уверенно, режимы на производство.
  steady(60),

  /// 85–100: всплывает мгновенно, повтор через недели.
  burning(85);

  const LumenBand(this.minLm);

  /// Нижняя граница полосы включительно. TODO(balance)
  final Lumens minLm;

  /// Полоса, в которую попадает данная яркость.
  static LumenBand of(Lumens lm) {
    var band = LumenBand.fading;
    for (final b in values) {
      if (lm >= b.minLm) band = b;
    }
    return band;
  }
}

/// Пороги и множители очков за одну связь:
/// `очки = base × k_speed × k_combo × k_mode`.
abstract final class ScoreBalance {
  /// Базовая стоимость верной связи. TODO(balance)
  static const int baseConnectionScore = 10;

  /// Скоростной множитель включается только начиная с этой яркости.
  /// Инвариант из README: на новом материале таймера нет вообще.
  /// TODO(balance)
  static const Lumens speedBonusMinLm = 40;

  /// Порог «автоматизма»: отклик быстрее — максимальный множитель.
  /// TODO(balance)
  static const Duration speedFastest = Duration(milliseconds: 1200);
  static const Duration speedFast = Duration(milliseconds: 2000);
  static const Duration speedMedium = Duration(milliseconds: 3500);

  /// Множители скорости по порогам выше. Штрафа за медленность нет.
  /// TODO(balance)
  static const double kSpeedFastest = 3.0;
  static const double kSpeedFast = 2.0;
  static const double kSpeedMedium = 1.5;
  static const double kSpeedSlow = 1.0;

  /// `k_combo = 1 + comboStep × подряд_верных`, но не больше [kComboMax].
  /// TODO(balance)
  static const double comboStep = 0.1;
  static const double kComboMax = 2.5;

  /// Быстрая ошибка дороже медленной: ответ быстрее [speedFastest],
  /// оказавшийся неверным, сбрасывает комбо до нуля и блокирует его рост
  /// на столько следующих связей. TODO(balance)
  static const int fastErrorComboLock = 3;

  /// Бонус к итогу забега за точность 100 %. TODO(balance)
  static const double perfectRunBonus = 1.25;

  /// Множитель режима из таблицы docs/CONCEPT.md. TODO(balance)
  static double modeMultiplier(GameMode mode) => switch (mode) {
        GameMode.recognition => 1.0,
        GameMode.circle => 1.4,
        GameMode.tight => 1.7,
        GameMode.audio => 1.7,
        GameMode.typing => 2.0,
        GameMode.phrase => 2.4,
      };

  /// Диапазон яркости, на котором режим уместен. Планировщик выбирает режим
  /// по яркости слова; верхняя граница у «Набора» и «Фразы» отсутствует.
  /// TODO(balance)
  static ({Lumens min, Lumens max}) modeLumenRange(GameMode mode) =>
      switch (mode) {
        GameMode.recognition => (min: 0, max: 25),
        GameMode.circle => (min: 20, max: 50),
        GameMode.tight => (min: 40, max: 70),
        GameMode.audio => (min: 50, max: 80),
        GameMode.typing => (min: 60, max: 100),
        GameMode.phrase => (min: 0, max: 100),
      };

  /// Митигация «узнавание вместо владения»: выше этой яркости режимы на
  /// узнавание не приносят очков вообще. TODO(balance)
  static const Lumens recognitionScoreCapLm = 40;

  /// «Горящее слово»: столько верных подряд быстрее [burningLatency] в
  /// продуктивном режиме. TODO(balance)
  static const int burningFastStreak = 3;
  static const Duration burningLatency = Duration(milliseconds: 1500);

  /// Сколько вариантов в круге.
  ///
  /// В узнавании их меньше: там и так легко, а шесть вариантов на родном
  /// языке читаются дольше, чем сам ответ. В остальных режимах шесть — это
  /// 17 % случайного попадания, что и заложено в защиту от угадывания.
  /// TODO(balance)
  /// [extra] добавляет заход: чем выше уровень, тем меньше шанс угадать.
  /// «Набор» остаётся без вариантов при любом уровне — там поле ввода.
  static int optionsFor(GameMode mode, {int extra = 0}) {
    final base = switch (mode) {
      GameMode.recognition => 4,
      GameMode.circle ||
      GameMode.tight ||
      GameMode.audio ||
      GameMode.phrase =>
        6,
      GameMode.typing => 0,
    };
    return base == 0 ? 0 : base + extra;
  }
}

/// Память: как время отклика превращается в оценку и какую вероятность
/// вспомнить планировщик считает достаточной.
abstract final class SrsBalance {
  /// Ответ быстрее — «легко»: игрок не вспоминал, а знал. TODO(balance)
  static const Duration gradeEasyBelow = Duration(milliseconds: 1200);

  /// Ответ быстрее — «хорошо». Медленнее — «трудно»: вспомнил, но с усилием,
  /// и это ровно тот материал, который стоит показать раньше. TODO(balance)
  static const Duration gradeGoodBelow = Duration(milliseconds: 2000);

  /// Целевая вероятность вспомнить на момент следующего повтора. Стандарт
  /// FSRS — 0.9; ниже даёт более длинные интервалы ценой забывания.
  /// TODO(balance)
  static const double targetRetention = 0.9;

  /// Границы стабильности в днях: ниже первой FSRS вырождается в нули, выше
  /// второй интервалы уходят за горизонт осмысленного планирования.
  static const double minStability = 0.01;
  static const double maxStability = 36500;

  /// Границы сложности: шкала FSRS 1..10.
  static const double minDifficulty = 1;
  static const double maxDifficulty = 10;

  /// Повторы внутри одного дня считаются «коротким» интервалом: слово ещё в
  /// рабочей памяти, и обычная формула стабильности к нему неприменима.
  static const Duration sameDayWindow = Duration(hours: 12);
}

/// Заход: цепочка уровней подряд, где каждый следующий чуть сложнее и
/// заметно дороже.
///
/// Почему заход, а не «уровень игрока». Аркадная петля — это не «через месяц
/// всё стало тяжелее», а «сколько выдержу за один присест». Бесконечно
/// растущая сложность через месяц сделала бы игру неиграбельной, а рекорд
/// часа — недостижимым. Заход обнуляется, когда игрок перестал играть, и
/// поэтому побить его можно всегда.
///
/// Провала в аркадном смысле здесь нет: в `score.dart` записано, что ошибка
/// стоит очков, но никогда не блокирует, и это правило сильнее жанра.
/// Аркадную форму даёт другое — слабый уровень сбрасывает множитель захода,
/// то есть игрок перестаёт зарабатывать эскалацию, но ничего не теряет.
abstract final class ClimbBalance {
  /// Прирост множителя очков за уровень: `k = 1 + step × (уровень − 1)`.
  ///
  /// Награда обгоняет сложность нарочно. На пятом уровне угадывание падает с
  /// 1/6 до 1/7, скоростное окно сжимается на пятую часть — а очки
  /// удваиваются. Если сделать наоборот, оптимальной игрой станет топтание
  /// на первом уровне, и вся аркадность умрёт. TODO(balance)
  static const double levelStep = 0.25;

  /// Потолок множителя: дальше сложность растёт, а награда нет.
  /// Достигается на девятом уровне. TODO(balance)
  static const double levelMultiplierMax = 3.0;

  /// Точность уровня, ниже которой множитель захода сбрасывается на первый.
  /// TODO(balance)
  static const double resetBelowAccuracy = 0.7;

  /// Перерыв, после которого заход считается закрытым. TODO(balance)
  static const Duration idleClosesClimb = Duration(minutes: 30);

  /// Сколько уровней добавляют один лишний вариант в круг. TODO(balance)
  static const int levelsPerExtraOption = 3;

  /// Потолок добавленных вариантов: восемь в круге — предел читаемости
  /// экрана, а не баланса. TODO(balance)
  static const int extraOptionsMax = 2;

  /// На сколько сжимается порог «автоматизма» за уровень и где он
  /// останавливается. Ниже 800 мс порог перестаёт мерить автоматизм и
  /// начинает мерить скорость пальца. TODO(balance)
  static const Duration speedTighteningPerLevel = Duration(milliseconds: 60);
  static const Duration speedFastestFloor = Duration(milliseconds: 800);

  /// Смещение к продуктивным режимам: из подходящих берётся лучший из N
  /// случайных, и N растёт с уровнем. TODO(balance)
  static const int modeDrawsBase = 2;
  static const int levelsPerExtraDraw = 2;
  static const int modeDrawsMax = 5;

  /// Насколько удлиняется забег и где останавливается. TODO(balance)
  static const int circlesPerRunGrowthEvery = 1;
  static const int circlesPerRunCap = 16;
}

/// Размеры сессий: круг → забег → уровень → ритуал.
abstract final class SessionBalance {
  /// Кругов в одном забеге. TODO(balance)
  static const int circlesPerRunMin = 10;
  static const int circlesPerRunMax = 14;

  /// Уровень: столько новых слов и столько повторов. TODO(balance)
  static const int newWordsPerLevel = 6;
  static const int reviewsPerLevel = 12;

  /// Забегов в уровне плюс один босс. TODO(balance)
  static const int runsPerLevel = 3;

  /// Планировщик берёт на сессию пул такого размера. TODO(balance)
  static const int sessionPoolSize = 40;

  /// Сколько раз новое слово показывается за уровень: первый показ без
  /// таймера плюс два вплетения в забеги. Отсюда и берётся длина забега:
  /// 6 новых × 3 + 12 повторов = 30 кругов на три забега по десять.
  /// TODO(balance)
  static const int newWordRepeats = 3;

  /// Минимальный разрыв между показами одного и того же слова внутри
  /// уровня. Без него два показа подряд превращаются в проверку буфера
  /// кратковременной памяти, а не в повторение. TODO(balance)
  static const int minGapBetweenRepeats = 3;

  /// Восход: только повторения, столько времени. TODO(balance)
  static const Duration sunriseDuration = Duration(minutes: 2);

  /// Ограничение доли новых слов, когда игрок включил «свой темп» — иначе
  /// очередь повторений растёт быстрее, чем он способен её разгребать.
  /// TODO(balance)
  static const double maxNewWordShare = 0.35;
}

/// Прогрессия: размеры созвездий по ярусам и пороги открытия/зажигания.
abstract final class ProgressionBalance {
  /// Сколько звёзд у одного созвездия на каждом ярусе. Значения
  /// накопительные: на A2 в созвездии 48 звёзд, включая 24 с A1.
  /// TODO(balance)
  static int starsPerConstellation(Tier tier) => switch (tier) {
        Tier.a0 => 12,
        Tier.a1 => 24,
        Tier.a2 => 48,
        Tier.b1 => 72,
        Tier.b2 => 96,
      };

  /// Сколько фраз у созвездия на ярусе. TODO(balance)
  static int phrasesPerConstellation(Tier tier) => switch (tier) {
        Tier.a0 => 4,
        Tier.a1 => 8,
        Tier.a2 => 16,
        Tier.b1 => 24,
        Tier.b2 => 32,
      };

  /// Уровней в созвездии на ярусе. TODO(balance)
  static int levelsPerConstellation(Tier tier) => switch (tier) {
        Tier.a0 => 2,
        Tier.a1 => 4,
        Tier.a2 => 8,
        Tier.b1 => 12,
        Tier.b2 => 16,
      };

  /// Соседние созвездия открываются при такой средней яркости текущего.
  /// TODO(balance)
  static const double unlockNeighborsAvgLm = 60;

  /// Созвездие «зажжено», когда у такой доли звёзд текущего яруса яркость
  /// не ниже [litStarMinLm]. TODO(balance)
  static const double litStarShare = 0.8;
  static const Lumens litStarMinLm = 70;

  /// Подъём яруса предлагается при такой доле зажжённых открытых созвездий.
  /// Только предложение: запертого уровня в игре нет. TODO(balance)
  static const double tierUpLitShare = 0.7;
}

/// Калибровка и автокоррекция яруса на первых днях.
abstract final class CalibrationBalance {
  /// Гребёнка: по одному кругу с каждого яруса до первого промаха.
  /// TODO(balance)
  static int get combStepsMax => Tier.values.length;

  /// Адаптивный поиск: столько кругов, два верных подряд — вверх,
  /// две ошибки — вниз. TODO(balance)
  static const int searchCirclesMin = 12;
  static const int searchCirclesMax = 16;
  static const int correctToRise = 2;
  static const int errorsToFall = 2;

  /// Граница яруса подтверждается столько раз, из них минимум один раз
  /// обязательно в «тесном круге»: шесть вариантов дают 17 % случайного
  /// попадания. TODO(balance)
  static const int borderConfirmations = 3;

  /// Финальная проверка фразами; провал сдвигает результат на ярус вниз.
  /// TODO(balance)
  static const int finalPhraseChecks = 4;

  /// Подтверждённые слова засеваются такой яркостью и сразу попадают в
  /// очередь повторений — не с нуля. TODO(balance)
  static const Lumens seedLmMin = 50;
  static const Lumens seedLmMax = 60;

  /// Ответ быстрее этого на незнакомом ярусе подозрителен: скорее всего
  /// это тык наугад, попавший в цель. Такой круг переспрашивается другим
  /// словом и в зачёт не идёт. TODO(balance)
  static const Duration suspiciousLatency = Duration(milliseconds: 600);

  /// Сколько переспросов допускается за калибровку. Без ограничения игрок,
  /// который просто быстро отвечает, застрял бы в бесконечном тесте.
  /// TODO(balance)
  static const int maxRepeats = 4;

  /// Автокоррекция в первые дни: точность выше [suggestUpAccuracy] при
  /// медианном отклике до [suggestUpLatency] → предложение подняться;
  /// ниже [suggestDownAccuracy] → предложение опуститься. TODO(balance)
  static const double suggestUpAccuracy = 0.9;
  static const Duration suggestUpLatency = Duration(milliseconds: 1500);
  static const double suggestDownAccuracy = 0.5;
}

/// Орбита вместо стрика и недельная цель.
abstract final class RetentionBalance {
  /// День игры поднимает орбиту на столько, пропуск опускает на столько.
  /// TODO(balance)
  static const int orbitGainPerDay = 1;
  static const int orbitLossPerMiss = 1;

  /// Полный сброс орбиты только после столько пропусков подряд.
  /// TODO(balance)
  static const int orbitResetAfterMisses = 3;

  /// Цель недели: столько дней из семи. TODO(balance)
  static const int weeklyGoalDays = 5;
}
