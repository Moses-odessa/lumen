import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/calibration/calibration.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';
import 'package:lumen/domain/scoring/balance.dart';

/// Синтетический игрок с заданным истинным уровнем.
///
/// Он знает всё на своём ярусе и ниже, а выше — угадывает с вероятностью
/// 1/[ScoreBalance.optionsPerCircle]: круг всегда полный, и наугад попадают в
/// один из шести. Плюс немного шума: живой человек ошибается и на знакомом.
///
/// Штрафы за трудность круга отсюда ушли вместе с тем, что их порождало.
/// Раньше их было два: фразовая механика (собрать предложение труднее, чем
/// узнать слово) и созвучные дистракторы. Механика в тесте теперь одна на все
/// круги, а «неверный вариант» никто не пишет руками — вокруг фразы стоят
/// другие фразы. Модель, в которой один и тот же круг то труднее, то легче,
/// врала бы калибровке в её же пользу.
class _Player {
  _Player({
    required this.trueTier,
    required this.random,
    this.slip = 0.08,
    this.guessRate = 1 / ScoreBalance.optionsPerCircle,
  });

  final Tier trueTier;
  final Random random;

  /// Ошибка на знакомом материале — усталость, промах пальцем.
  final double slip;

  /// Вероятность угадать на незнакомом ярусе.
  final double guessRate;

  bool answer(CalibrationStep step) {
    if (step.tier.index <= trueTier.index) {
      return random.nextDouble() > slip;
    }
    return random.nextDouble() < guessRate;
  }

  /// Время отклика: на знакомом быстро, на незнакомом дольше.
  Duration latency(CalibrationStep step) {
    final known = step.tier.index <= trueTier.index;
    final base = known ? 1100 : 2600;
    return Duration(milliseconds: base + random.nextInt(900));
  }
}

/// Прогоняет калибровку целиком.
///
/// Потолок по умолчанию верхний — то есть не ограничивает ничего: почти все
/// проверки здесь про измерение яруса, и урезание в них только мешало бы
/// читать. Про сам потолок есть отдельная группа.
CalibrationState _run(
  _Player player, {
  int maxSteps = 200,
  Tier ceiling = Tier.b2,
}) {
  var state = CalibrationState.start(ceiling: ceiling);
  var steps = 0;
  while (!state.isDone && steps < maxSteps) {
    final step = state.step;
    state = Calibration.answer(
      state,
      correct: player.answer(step),
      latency: player.latency(step),
    );
    steps++;
  }
  return state;
}

/// Отвечает на весь тест по правилу «верно на этом ярусе и ниже».
CalibrationState _runKnowing(Tier tier, {Tier ceiling = Tier.b2}) {
  var state = CalibrationState.start(ceiling: ceiling);
  var guard = 0;
  while (!state.isDone && guard++ < 200) {
    state = Calibration.answer(
      state,
      correct: state.step.tier.index <= tier.index,
      latency: const Duration(seconds: 2),
    );
  }
  expect(state.isDone, isTrue, reason: 'тест не кончился за 200 кругов');
  return state;
}

/// Полностью верные ответы по квоте: столько, сколько задано на каждом ярусе.
Map<Tier, int> _allCorrectUpTo(Tier tier) => {
      for (final t in Tier.values)
        if (t.index <= tier.index) t: CalibrationBalance.quotaFor(t),
    };

/// Что отсюда удалено вместе с правилами, которых больше нет.
///
/// * Группа «гребёнка», четыре теста: «начинается с самого нижнего яруса»,
///   «верный ответ поднимает на ярус выше», «первый промах переводит в
///   поиск», «взятая с ходу гребёнка находит ярус, но тест не кончает». Они
///   охраняли фазу `comb`: по одному кругу с яруса снизу вверх до первого
///   промаха, дальше адаптивный поиск между последним верным и первым
///   промахом. Тест перестал искать ярус — он спрашивает квоту с каждого
///   яруса и считает точность, — и «шага вверх за верный ответ» не
///   существует. Восходящий порядок кругов пережил фазу и проверяется в
///   группе «план»: гребёнка была ещё и туториалом.
/// * Группа «подтверждение границы», семь тестов: «три подтверждения
///   объявляют ярус», «одного верного круга мало», «верный ответ обнуляет
///   счётчик промахов», «одна осечка прощается», «вторая осечка опускает
///   ярус», «ниже A0 некуда», «верный ответ снимает потолок, поставленный
///   случайной осечкой». Они охраняли `borderConfirmations`, счётчики
///   `confirmations`/`confirmFailures` и границы поиска `lowest`/`highest`.
///   Правило, которое всё это защищало, одно: ярус нельзя объявлять по
///   одному кругу, потому что шесть вариантов дают 17 % случайного попадания.
///   Оно живо и стало сильнее — вывод вверх требует
///   [CalibrationBalance.tierPassShare] от целой квоты яруса, а не трёх
///   кругов подряд, — и проверяется в группе «правило вывода яруса». Заодно
///   там же осталась главная находка тех тестов: одна осечка внизу не должна
///   стоить игроку яруса.
/// * «Итог остаётся пустым, пока ярус не измерен» в прежнем виде: он
///   проверял границу «мерящие фазы vs засев», а фаз нет. Правило
///   («`_finish` читает `result ?? Tier.a0`, поэтому незаписанный итог стоит
///   игроку яруса») переехало в группу «длина теста».
/// * «Засев обходит выданный ярус и все, что ниже» и «ярус в засеве не
///   двигают ни верные ответы, ни промахи». Они охраняли хвост из 13–20
///   кругов, который шёл по ярусам сверху вниз и намеренно не был
///   адаптивным. Хвоста нет: засевает каждый из двадцати кругов, а ярусы
///   обходит план. Что от них осталось охранять — «засеять можно только
///   выданный ярус и ниже» — проверяется в группе «засев памяти».
/// * Группа «финальные фразы» и пять тестов про созвучные варианты удалены
///   раньше; их записи лежат в истории этого файла и в
///   `CalibrationStep.isRepeat`.
void main() {
  group('план', () {
    test('состав задан квотой владельца: 6/5/4/3/2, всего двадцать', () {
      // **Решение владельца проекта:** «по онбоардингу давай сделаем 20 фраз,
      // только для слабее уровней будем ставить большее количество слов
      // A0 - 6, A1 - 5, A2 - 4, B1 - 3, B2 - 2». Проверяется здесь потому,
      // что это не производное число, а решение: изменить его можно, но
      // молча — нельзя.
      expect(
        [for (final tier in Tier.values) CalibrationBalance.quotaFor(tier)],
        [6, 5, 4, 3, 2],
      );
      expect(CalibrationBalance.testCircles, 20);
      expect(Calibration.plan.length, CalibrationBalance.testCircles);
      for (final tier in Tier.values) {
        expect(
          Calibration.plan.where((t) => t == tier).length,
          CalibrationBalance.quotaFor(tier),
          reason: 'ярус ${tier.label} получил не свою квоту',
        );
      }
    });

    test('порядок восходящий: онбординг — это ещё и туториал', () {
      // Первое, что человек видит в игре, — круг. На A0 фраза длиной
      // восемнадцать знаков, на B2 — до ста восемнадцати: тест, начавшийся с
      // B2, учит новичка не жесту, а тому, что он ничего не понимает. Ровно
      // этим была хороша удалённая гребёнка, и её свойство сохранено здесь.
      //
      // Проверяется монотонность, а не конкретный список: она и есть
      // решение. Перемешанный план дал бы те же двадцать кругов и ту же
      // квоту — и сломал бы только туториал, то есть молча.
      for (var i = 1; i < Calibration.plan.length; i++) {
        expect(
          Calibration.plan[i].index,
          greaterThanOrEqualTo(Calibration.plan[i - 1].index),
          reason: 'круг $i идёт ниже предыдущего',
        );
      }
      expect(Calibration.plan.first, Tier.a0);
      expect(Calibration.plan.last, Tier.b2);
    });

    test('круги идут по плану, а не по ответам', () {
      // Тест перестал быть адаптивным, и это его главное свойство: ни
      // верный ответ, ни промах не двигают ярус проверки. Пока это не
      // проверено, «стратифицированная выборка» — просто слово в докстроке.
      final seen = <Tier>[];
      var state = CalibrationState.start(ceiling: Tier.b2);
      var correct = false;
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        if (!state.step.isRepeat) seen.add(state.step.tier);
        state = Calibration.answer(state,
            correct: correct, latency: const Duration(seconds: 2));
        correct = !correct;
      }
      expect(seen, Calibration.plan);
    });
  });

  group('шаг', () {
    test('весь тест мерит одной механикой, и она продуктивная', () {
      // Ярус нельзя мерить узнаванием: выбрать перевод из шести проще, чем
      // назвать фразу на изучаемом, и игрок, который «всё понимает», получил
      // бы ярус, на котором не может сказать ничего. Отсюда единственная
      // механика на весь тест — самая требовательная из трёх.
      //
      // Это же место занимала проверка вида дистракторов: механик в тесте
      // было две, обычный круг и тесный, и различить их можно было только по
      // ним. Различать больше нечего, и осталось правило про механику.
      final modes = <GameMode>{};
      final tiers = <Tier>{};

      var state = CalibrationState.start(ceiling: Tier.b2);
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        modes.add(state.step.mode);
        tiers.add(state.step.tier);
        state = Calibration.answer(
          state,
          correct: state.step.tier.index <= Tier.a2.index,
          latency: const Duration(seconds: 2),
        );
      }

      expect(modes, {GameMode.pickTarget});
      expect(modes.single.isProductive, isTrue,
          reason: 'ярус измерен узнаванием, а не производством');
      // Иначе множество режимов набралось бы с одного яруса, и проверка выше
      // говорила бы только про начало теста.
      expect(tiers, Tier.values.toSet());
    });
  });

  group('длина теста', () {
    test('двадцать зачётных кругов, сколько бы игрок ни отвечал', () {
      // Длина — сумма квот, а не свободное число: спросить меньше значит
      // недобрать проб на каком-то ярусе, а на B2 их и так две.
      //
      // Находка владельца, из-за которой у теста вообще появилась длина: он
      // кончался, когда сходился алгоритм, и забег, ответивший верно пять
      // раз, укладывался в пять кругов — «Кіл у тесті 5, Тест показав B2».
      final random = Random(2026);
      for (final tier in Tier.values) {
        for (var i = 0; i < 40; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          expect(state.asked, CalibrationBalance.testCircles,
              reason: 'ярус $tier, прогон $i');
        }
      }
    });

    test('итог объявляется последним зачётным кругом, а не раньше', () {
      // Цена расхождения: `_finish` в контроллере читает `result ?? Tier.a0`,
      // поэтому объявленный не вовремя итог — это ярус A0 у игрока,
      // ответившего на B1, либо ярус, назначенный до последних проб.
      var state = CalibrationState.start(ceiling: Tier.b2);
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        expect(state.result, isNull,
            reason: 'ярус объявлен на круге ${state.asked} из '
                '${CalibrationBalance.testCircles}');
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
      }
      expect(state.asked, CalibrationBalance.testCircles);
      expect(state.result, isNotNull);
      expect(state.isDone, isTrue);
    });

    test('переспрос идёт сверх двадцати, а не вместо пробы', () {
      // **Решение и запись о нём.** Прежде переспрос входил в длину теста:
      // длина была обещанием игроку, а он считает экраны. С квотой это
      // перестало работать — проба, отданная переспросу, оставила бы ярус с
      // меньшим числом проб, чем задано, и на B2 замер сократился бы вдвое.
      // Поэтому переспросы вынесены за квоту: игрок видит от двадцати до
      // двадцати четырёх кругов, а квоту получает целиком.
      var state = CalibrationState.start(ceiling: Tier.b2);
      final perTier = <Tier, int>{};
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        final step = state.step;
        if (!step.isRepeat) {
          perTier[step.tier] = (perTier[step.tier] ?? 0) + 1;
        }
        state = Calibration.answer(state,
            correct: true, latency: const Duration(milliseconds: 200));
      }

      expect(state.repeats, greaterThan(0),
          reason: 'ни один быстрый ответ не переспросили — мерить нечего');
      expect(state.asked, CalibrationBalance.testCircles);
      expect(state.circles, CalibrationBalance.testCircles + state.repeats,
          reason: 'переспросы посчитались дважды или не посчитались вовсе');
      expect(state.circles,
          lessThanOrEqualTo(
              CalibrationBalance.testCircles + CalibrationBalance.maxRepeats));
      for (final tier in Tier.values) {
        expect(perTier[tier], CalibrationBalance.quotaFor(tier),
            reason: 'переспрос съел пробу яруса ${tier.label}');
      }
    });

    test('последняя проба тоже может уйти в переспрос', () {
      // Обратная сторона того же решения, и запись об удалённом правиле.
      // Здесь стояло условие «до конца теста осталось не меньше двух кругов»:
      // переспрос стоил двух кругов из тридцати, и у самого края теста он
      // съел бы последний круг вместе с единственным ответом, который в него
      // попал. Переспросы вынесены за квоту — охранять стало нечего, и
      // последняя проба переспрашивается наравне с первой.
      var state = CalibrationState.start(ceiling: Tier.b2);
      var guard = 0;
      // Доводим до последней пробы промахами: игрок, не взявший ни одного
      // яруса, — единственный, у кого последняя проба ещё «выше
      // подтверждённого». Ответь он верно на первой фразе B2, ярус стал бы
      // взятым, и быстрый ответ на второй перестал бы быть подозрительным.
      while (state.asked < CalibrationBalance.testCircles - 1 && guard++ < 60) {
        state = Calibration.answer(state,
            correct: false, latency: const Duration(seconds: 3));
      }
      expect(state.asked, CalibrationBalance.testCircles - 1);
      expect(state.isDone, isFalse);
      expect(state.confirmed, isEmpty);

      // Последний круг — быстрый верный ответ на B2, где игрок не взял
      // ничего: ровно тот случай, ради которого переспрос существует.
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 200));

      expect(state.step.isRepeat, isTrue, reason: 'последнюю пробу не проверили');
      expect(state.isDone, isFalse, reason: 'тест кончился на переспросе');
      expect(state.asked, CalibrationBalance.testCircles - 1);

      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 200));
      expect(state.isDone, isTrue);
      expect(state.pendingRepeat, isFalse,
          reason: 'тест кончился с назначенным, но не показанным переспросом');
    });
  });

  group('правило вывода яруса', () {
    test('полная квота ярусов снизу вверх даёт ровно этот ярус', () {
      for (final tier in Tier.values) {
        expect(Calibration.measure(_allCorrectUpTo(tier)), tier,
            reason: 'ожидался ${tier.label}');
      }
    });

    test('пустые ответы дают A0: ниже дна шкалы яруса нет', () {
      expect(Calibration.measure(const {}), Tier.a0);
      expect(Calibration.measure({Tier.a0: 1}), Tier.a0,
          reason: 'один верный из шести — это не взятый ярус');
    });

    test('одна осечка внизу не роняет игрока', () {
      // Главная находка удалённой фазы поиска, перенесённая на новое
      // правило: игрок B2, промахнувшийся на одном круге A1, обязан остаться
      // B2. Правило «самый высокий взятый ярус, ниже которого нет провалов»
      // выдало бы здесь A0 — и это ошибка на четыре яруса из-за одного
      // промаха пальцем.
      final answers = _allCorrectUpTo(Tier.b2)..[Tier.a1] = 4;
      expect(Calibration.measure(answers), Tier.b2);

      // Терпимость шире, чем одна осечка, и это стоит зафиксировать: игрок,
      // проваливший **весь** ярус A1 (один верный из пяти), остаётся B1.
      // Ярус отнимает 1,86, а лежащие выше A2 и B1 прибавляют 3,00 — сумма
      // проходит просадку и берёт новый максимум наверху. Так и задумано:
      // непройденный ярус посередине бывает у человека, который учил язык не
      // по учебнику, и наказывать за это результатом нечестно.
      expect(
        Calibration.measure(_allCorrectUpTo(Tier.b1)..[Tier.a1] = 1),
        Tier.b1,
      );
      // А вот два проваленных яруса подряд — это уже не осечка: сумма не
      // выбирается из просадки, и максимум остаётся внизу. Знать B1, не зная
      // ни A1, ни A2, значит противоречить самой шкале, и тест в таком
      // случае обязан верить нижнему краю.
      expect(
        Calibration.measure(
            _allCorrectUpTo(Tier.b1)..addAll({Tier.a1: 1, Tier.a2: 1})),
        Tier.a0,
      );
    });

    test('одна удача вверху не поднимает', () {
      // Новичок угадал две фразы B1 из трёх — это 7 % таких забегов. Правило
      // «самый высокий взятый ярус» выдало бы B1, то есть ошибку на три
      // яруса; накопленный перевес остаётся на A0, потому что A1 и A2 отняли
      // больше, чем прибавил B1.
      expect(
        Calibration.measure({Tier.a0: 6, Tier.a1: 1, Tier.a2: 1, Tier.b1: 2}),
        Tier.a0,
      );
      // Даже две удачи подряд наверху не перебивают двух проваленных ярусов
      // под ними.
      expect(
        Calibration.measure(
            {Tier.a0: 6, Tier.a1: 1, Tier.a2: 1, Tier.b1: 2, Tier.b2: 2}),
        Tier.a0,
      );
    });

    test('на квоте два вывод вверх требует обоих верных', () {
      // Осторожность вверху — свойство доли [CalibrationBalance.tierPassShare]
      // на маленькой квоте, а не отдельное правило: на B2 проб две, и одна
      // осечка — это половина яруса. Игрок, знающий B2 и промахнувшийся один
      // раз, получает B1: ошибка на ярус вниз, та, которую проект выбирает
      // сознательно.
      expect(Calibration.measure(_allCorrectUpTo(Tier.b2)), Tier.b2);
      expect(
        Calibration.measure(_allCorrectUpTo(Tier.b2)..[Tier.b2] = 1),
        Tier.b1,
      );
      // На квоте шесть та же доля прощает две осечки из шести.
      expect(Calibration.measure({Tier.a0: 4}), Tier.a0);
      expect(Calibration.measure({Tier.a0: 3}), Tier.a0,
          reason: 'ниже A0 всё равно некуда, но перевеса тут уже нет');
    });

    test('правило не зависит от порядка ответов', () {
      // Тест читает только счёт верных по ярусам, и это то, что позволяет
      // выбрать восходящий порядок кругов без оглядки на замер.
      final ascending = _runKnowing(Tier.a2);
      expect(ascending.result, Calibration.measure(ascending.correct));
    });
  });

  group('защита от угадывания', () {
    test('подозрительно быстрый верный ответ переспрашивается', () {
      var state = CalibrationState.start(ceiling: Tier.b2);
      // Поднимаемся выше подтверждённого, чтобы ярус стал незнакомым.
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      while (state.step.tier == Tier.a0) {
        state = Calibration.answer(state,
            correct: true, latency: const Duration(seconds: 2));
      }

      final before = state.asked;
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 300));

      // Круг не засчитан, вместо него будет переспрос — на том же ярусе.
      expect(state.asked, before);
      expect(state.step.isRepeat, isTrue);
      expect(state.step.tier, Tier.a1);
      expect(state.repeats, 1);
    });

    test('переспрос засчитывается как обычный круг', () {
      var state = CalibrationState.start(ceiling: Tier.b2);
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 300));
      expect(state.step.isRepeat, isTrue,
          reason: 'быстрый верный ответ на первом же круге не переспросили');

      final before = state.asked;
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 300));

      expect(state.asked, before + 1, reason: 'переспрос не засчитан');
      expect(state.step.isRepeat, isFalse,
          reason: 'переспрос переспросили ещё раз');
    });

    test('переспросы не бесконечны', () {
      var state = CalibrationState.start(ceiling: Tier.b2);
      var repeats = 0;
      for (var i = 0; i < 60 && !state.isDone; i++) {
        if (state.step.isRepeat) repeats++;
        state = Calibration.answer(state,
            correct: true, latency: const Duration(milliseconds: 200));
      }
      expect(repeats, lessThanOrEqualTo(CalibrationBalance.maxRepeats));
      expect(repeats, greaterThan(0),
          reason: 'ни один быстрый ответ не переспросили — мерить нечего');
    });

    test('медленный верный ответ не переспрашивается', () {
      var state = CalibrationState.start(ceiling: Tier.b2);
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 3));
      expect(state.step.isRepeat, isFalse);
      expect(state.asked, 1);
    });

    test('на взятом ярусе быстрый ответ подозрений не вызывает', () {
      // Быстро отвечать на том, что знаешь, — норма, а не признак
      // угадывания. Правило держится на `_isAboveKnown`, и без него игрок,
      // который просто быстро играет, тратил бы переспросы на каждом круге.
      //
      // При восходящем порядке из этого же следует предел переспросов: по
      // одному на переход между ярусами, четыре за тест — ровно
      // [CalibrationBalance.maxRepeats].
      var state = CalibrationState.start(ceiling: Tier.b2);
      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      expect(state.confirmed, {Tier.a0}, reason: 'ярус не стал взятым');
      expect(state.step.tier, Tier.a0, reason: 'квота A0 не исчерпана');

      final before = state.asked;
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 200));

      expect(state.step.isRepeat, isFalse);
      expect(state.asked, before + 1, reason: 'круг ушёл в переспрос');
      expect(state.repeats, 0);
    });
  });

  group('«я с нуля»', () {
    test('ставит A0 без единого круга', () {
      final state = Calibration.fromScratch();
      expect(state.isDone, isTrue);
      expect(state.result, Tier.a0);
      expect(state.asked, 0);
      expect(state.circles, 0);
    });
  });

  group('сходимость на синтетических игроках', () {
    test('тест всегда заканчивается и не зацикливается', () {
      final random = Random(2026);
      for (final tier in Tier.values) {
        for (var i = 0; i < 50; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          expect(state.isDone, isTrue, reason: 'ярус $tier, прогон $i');
          expect(state.result, isNotNull);
        }
      }
    });

    test('ошибка не больше одного яруса в 90 % случаев', () {
      // Критерий приёмки M3. Прогон на 1000 «игроков» — по 200 на ярус.
      // Измеренное значение — 99,0 % против 99,1 % у прежней адаптивной
      // схемы на том же семени: двадцать кругов с квотой определяют ярус не
      // хуже поиска, который тратил на замер до 23 кругов
      // (`calibration_diagnostic_test.dart` печатает разбивку по ярусам).
      final random = Random(7);
      var within = 0;
      var total = 0;

      for (final tier in Tier.values) {
        for (var i = 0; i < 200; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          final error = (state.result!.index - tier.index).abs();
          if (error <= 1) within++;
          total++;
        }
      }

      final share = within / total;
      expect(share, greaterThanOrEqualTo(0.9),
          reason: 'ошибка больше яруса в ${((1 - share) * 100).round()} % '
              'случаев');
    });

    test('система систематически не завышает ярус', () {
      // Завышенный ярус отпугивает сильнее, чем заниженный утомляет,
      // поэтому смещение допустимо только вниз.
      final random = Random(11);
      var sum = 0;
      var total = 0;

      for (final tier in Tier.values) {
        for (var i = 0; i < 200; i++) {
          final state = _run(_Player(trueTier: tier, random: random));
          sum += state.result!.index - tier.index;
          total++;
        }
      }

      expect(sum / total, lessThanOrEqualTo(0.2));
    });

    test('чистый угадыватель не получает высокий ярус', () {
      // Игрок, который не знает ничего и тычет наугад, должен оказаться
      // внизу — иначе порог [CalibrationBalance.tierPassShare] не работает.
      final random = Random(3);
      var high = 0;

      for (var i = 0; i < 200; i++) {
        final state = _run(_Player(
          trueTier: Tier.a0,
          random: random,
          slip: 0.5,
          guessRate: 1 / ScoreBalance.optionsPerCircle,
        ));
        if (state.result!.index >= Tier.a2.index) high++;
      }

      expect(high / 200, lessThan(0.1));
    });

    test('повторный прогон на том же профиле даёт тот же ярус', () {
      // Критерий приёмки M3: воспроизводимость на безошибочном игроке.
      for (final tier in Tier.values) {
        final first = _run(
          _Player(trueTier: tier, random: Random(1), slip: 0, guessRate: 0),
        );
        final second = _run(
          _Player(trueTier: tier, random: Random(1), slip: 0, guessRate: 0),
        );
        expect(first.result, second.result, reason: '$tier');
      }
    });

    test('идеальный игрок получает свой ярус точно', () {
      for (final tier in Tier.values) {
        final state = _run(
          _Player(trueTier: tier, random: Random(9), slip: 0, guessRate: 0),
        );
        expect(state.result, tier, reason: 'ожидался $tier');
      }
    });
  });

  group('засев памяти', () {
    test('взятые ярусы копятся по ходу теста', () {
      final state = _run(
        _Player(trueTier: Tier.a2, random: Random(4), slip: 0, guessRate: 0),
      );
      expect(state.confirmed, {Tier.a0, Tier.a1, Tier.a2});
    });

    test('промах ярус не подтверждает', () {
      // Ярусы для засева копит `confirmed`, и брать в него ярус за промах
      // значило бы засеять фразу, которую игрок не узнал.
      var state = CalibrationState.start(ceiling: Tier.a0);
      state = Calibration.answer(state,
          correct: false, latency: const Duration(seconds: 3));
      expect(state.confirmed, isEmpty, reason: 'игрок не узнал ничего');
      expect(state.correct, isEmpty);

      state = Calibration.answer(state,
          correct: true, latency: const Duration(seconds: 2));
      expect(state.confirmed, {Tier.a0});
      expect(state.correct[Tier.a0], 1);
    });

    test('на запущенном A0 засеять можно только квоту нижнего яруса', () {
      // Числа засева целиком лежат в квоте, и это главное следствие
      // двадцати кругов. Играть можно только по вычитанному, вычитан один A0
      // (`content/launch.yaml`), значит засевается только верно отвеченное на
      // A0 — не больше [CalibrationBalance.quotaFor] шести фраз, сколько бы
      // ярусов игрок ни взял выше.
      //
      // Знакомству исключением нужно пять
      // ([ScoreBalance.optionsPerCircle] минус верный ответ), то есть запас
      // здесь — одна фраза. Тест держит именно это неравенство: квота
      // нижнего яруса не имеет права опуститься до знакомства.
      final state = _runKnowing(Tier.b2, ceiling: Tier.a0);
      expect(state.result, Tier.b2, reason: 'измеренный ярус урезали');
      expect(state.granted, Tier.a0);

      final seedable = state.correct.entries
          .where((e) => e.key.index <= state.granted!.index)
          .fold<int>(0, (sum, e) => sum + e.value);
      expect(seedable, CalibrationBalance.quotaFor(Tier.a0));
      expect(seedable, greaterThanOrEqualTo(ScoreBalance.optionsPerCircle - 1),
          reason: 'из засева не собрать даже одного знакомства исключением');
    });

    test('одна фраза дважды за тест не выпадет', () {
      // Проверка про контент, выраженная в числах домена: контроллер
      // вычёркивает спрошенное (`_asked`) и берёт следующую фразу из
      // отобранного набора, а в наборе на каждый ярус тридцать позиций
      // (`tool/make_calibration.dart`, `_phrasesPerTier`). Значит повтор
      // невозможен, пока с одного яруса спрашивается не больше тридцати
      // кругов — а больше `квота + переспросы` не бывает по построению.
      const curatedPerTier = 30;
      var state = CalibrationState.start(ceiling: Tier.b2);
      final perTier = <Tier, int>{};
      var guard = 0;
      while (!state.isDone && guard++ < 200) {
        final tier = state.step.tier;
        perTier[tier] = (perTier[tier] ?? 0) + 1;
        // Отвечает верно и очень быстро: максимум переспросов.
        state = Calibration.answer(state,
            correct: true, latency: const Duration(milliseconds: 100));
      }

      for (final tier in Tier.values) {
        expect(
          perTier[tier],
          lessThanOrEqualTo(
              CalibrationBalance.quotaFor(tier) + CalibrationBalance.maxRepeats),
          reason: 'ярус ${tier.label} спрошен чаще, чем квота с переспросами',
        );
        expect(perTier[tier], lessThanOrEqualTo(curatedPerTier),
            reason: 'ярус ${tier.label} вычерпал отобранный набор');
      }
    });
  });

  group('потолок', () {
    test('измеренный ярус остаётся, выданный урезается', () {
      // Экран итога показывает оба числа, и это единственное, что отвечает
      // игроку на «я ответил почти всё, а получил A0». Раньше зажим стоял в
      // контроллере поверх провайдера и не проверялся ничем — а не срабатывал
      // он ровно потому, что `maxTierProvider` до чтения метаданных отдавал
      // все ярусы, и первым его читателем была та самая строка зажима.
      for (final ceiling in Tier.values) {
        final state = _run(
          _Player(trueTier: Tier.b2, random: Random(13), slip: 0, guessRate: 0),
          ceiling: ceiling,
        );
        expect(state.result, Tier.b2, reason: 'потолок $ceiling съел замер');
        expect(state.granted, ceiling, reason: 'потолок $ceiling не сработал');
      }
    });

    test('потолок выше измеренного ничего не меняет', () {
      final state = _run(
        _Player(trueTier: Tier.a1, random: Random(17), slip: 0, guessRate: 0),
      );
      expect(state.result, Tier.a1);
      expect(state.granted, Tier.a1);
    });

    test('потолок не двигает план: мерить надо выше того, что выдадут', () {
      // Иначе тест не измерил бы ничего выше A0 и не смог бы сказать «показал
      // B2, а даёт A0» — то самое, чем экран итога отвечает на «я ответил
      // почти всё».
      final state = _runKnowing(Tier.b2, ceiling: Tier.a0);
      expect(state.correct.keys.toSet(), Tier.values.toSet());
    });

    test('«я с нуля» не ждёт метаданных: ноль разрешён всегда', () {
      // Сборки без запущенного A0 не существует — по такой играть было бы
      // нечем, — поэтому кнопке не нужен ни потолок, ни провайдер.
      final state = Calibration.fromScratch();
      expect(state.granted, Tier.a0);
    });
  });

  group('прогресс', () {
    test('полоса считает пробы из двадцати и не идёт назад', () {
      // Полоса уже дважды мерила чужую длину: сперва складывалась из долей
      // фаз (0,25 гребёнке, 0,45 поиску, 0,3 подтверждению) и доходила до
      // конца к двадцатому кругу из тридцати, потом считала показанные круги
      // из тридцати. Тест стал двадцатью пробами — и полоса приведена к нему.
      var state = CalibrationState.start(ceiling: Tier.b2);
      expect(state.progress, 0);

      final player = _Player(trueTier: Tier.a2, random: Random(6));
      var previous = state.progress;
      var guard = 0;
      while (!state.isDone && guard++ < 100) {
        state = Calibration.answer(
          state,
          correct: player.answer(state.step),
          latency: player.latency(state.step),
        );
        expect(state.progress, inInclusiveRange(0, 1));
        expect(state.progress, greaterThanOrEqualTo(previous),
            reason: 'полоса пошла назад после круга ${state.circles}');
        if (!state.isDone) {
          expect(
            state.progress,
            closeTo(state.asked / CalibrationBalance.testCircles, 1e-9),
            reason: 'полоса мерит не пробы',
          );
        }
        previous = state.progress;
      }
      expect(state.progress, 1);
    });

    test('на переспросе полоса стоит, а не врёт', () {
      // Переспрос идёт сверх квоты и теста не продвигает: круг показан, а
      // проб израсходовано столько же. Стоящая полоса — честный ответ; любая
      // другая означала бы либо шаг назад, либо длину, которая ещё не
      // известна (переспросов может быть от нуля до
      // [CalibrationBalance.maxRepeats]).
      var state = CalibrationState.start(ceiling: Tier.b2);
      state = Calibration.answer(state,
          correct: true, latency: const Duration(milliseconds: 200));
      expect(state.step.isRepeat, isTrue);
      expect(state.progress, 0, reason: 'полоса ушла вперёд на переспросе');
      expect(state.circles, 1, reason: 'круг игроку показан');
    });
  });
}
