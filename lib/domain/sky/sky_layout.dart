/// Раскладка неба: где на карте стоит созвездие и где внутри него —
/// каждая звезда.
///
/// Главное свойство: **раскладка детерминирована**. Позиция считается из
/// идентификатора, а не из случайного числа и не из порядка строк в базе.
/// Иначе небо перестраивалось бы при каждом запуске, и метафора «моё небо»
/// не работала бы вовсе — узнавать было бы нечего.
///
/// Чистый Dart: ни Flutter, ни `dart:ui`. Координаты нормированы в [0, 1],
/// перевод в пиксели — дело виджета.
library;

import 'dart:math' as math;

/// Точка в нормированных координатах карты.
class SkyPoint {
  const SkyPoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(SkyPoint other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));

  @override
  String toString() =>
      '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// Звезда на карте.
class StarPlacement {
  const StarPlacement({
    required this.itemId,
    required this.position,
    required this.lumens,
  });

  final String itemId;

  /// Позиция в координатах всей карты.
  final SkyPoint position;

  final int lumens;
}

/// Созвездие на карте: центр, звёзды и линии между ними.
class ConstellationPlacement {
  const ConstellationPlacement({
    required this.name,
    required this.center,
    required this.radius,
    required this.stars,
    required this.lines,
    this.total = 0,
  });

  final String name;
  final SkyPoint center;

  /// Радиус, в котором лежат **отдельные** звёзды.
  ///
  /// Ограничен сверху так, чтобы соседние созвездия не налезали друг на
  /// друга. Свечение Млечного Пути может выходить за него: размытому пятну
  /// пересечение с соседним не мешает, а отдельным звёздам мешает — две
  /// звезды из разных созвездий на одном месте это не плотное небо, а
  /// сломанная карта.
  final double radius;

  /// Звёзды с отдельными координатами — те, которые игрок уже учил.
  final List<StarPlacement> stars;

  /// Сколько звёзд у созвездия на этом ярусе всего, включая невыученные.
  ///
  /// Разница между [total] и `stars.length` — это масса, которая рисуется
  /// свечением. Именно она делает карту масштабируемой: координаты нужны
  /// только выученным звёздам, и небо растёт вместе с прогрессом, а не
  /// вместе с объёмом контента.
  final int total;

  /// Линии-фразы: пары индексов в [stars].
  final List<(int, int)> lines;

  /// Доля созвездия, которую игрок уже трогал. Ноль — чистый Млечный Путь.
  double get worked =>
      total == 0 ? (stars.isEmpty ? 0 : 1) : (stars.length / total).clamp(0, 1);

  /// Радиус свечения: он покрывает всё созвездие, включая невыученное.
  ///
  /// Растёт от числа звёзд яруса, а не от числа выученных: пятно должно
  /// обещать объём темы сразу, иначе непроработанное созвездие выглядит
  /// маленьким и незначительным — ровно наоборот тому, что есть.
  double get glowRadius => SkyLayout.glowRadiusFor(total == 0 ? stars.length : total);
}

abstract final class SkyLayout {
  /// Раскладывает созвездия по карте.
  ///
  /// Созвездия садятся на «золотую спираль»: она даёт равномерное заполнение
  /// без сетки и без наложений, а главное — позиция зависит только от номера
  /// в отсортированном списке, то есть стабильна при добавлении нового
  /// созвездия в конец.
  static List<ConstellationPlacement> place({
    required Map<String, List<StarInput>> constellations,
    Map<String, int> totals = const {},
    double spread = 0.42,
  }) {
    final names = constellations.keys.toList()..sort();
    final result = <ConstellationPlacement>[];

    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final stars = constellations[name] ?? const <StarInput>[];
      final center = _spiralPoint(i, names.length, spread);

      result.add(ConstellationPlacement(
        name: name,
        center: center,
        radius: starRadiusFor(stars.length),
        total: totals[name] ?? stars.length,
        stars: _placeStars(name, stars, center, starRadiusFor(stars.length)),
        lines: _lines(stars.length, name),
      ));
    }
    return result;
  }

  /// Радиус, в котором лежат отдельные звёзды.
  ///
  /// Плотные созвездия занимают больше места, но не пропорционально: иначе
  /// созвездие из 250 звёзд перекрыло бы половину карты. И **не больше
  /// половины расстояния между центрами** — иначе соседние созвездия
  /// налезают друг на друга.
  ///
  /// Потолок появился не из осторожности, а по измерению. Расстояние между
  /// ближайшими центрами на спирали — постоянные [_minCenterDistance] при
  /// любом числе созвездий от девяти до пятидесяти: оно зависит только от
  /// [spread] и [_referenceCount]. А прежняя формула давала уже на A0, при
  /// двенадцати звёздах, радиус 0.100 — то есть двум соседям требовалось
  /// 0.200 при доступных 0.119. Созвездия перекрывались на 41 % **всегда**,
  /// с первого дня. Тест на это назывался «созвездия не налезают друг на
  /// друга» и проверял, что расстояние между центрами больше нуля.
  static double starRadiusFor(int stars) {
    final wanted = 0.045 + 0.055 * math.sqrt(stars / 12.0);
    return math.min(wanted, _minCenterDistance / 2);
  }

  /// Радиус свечения. Ему налезать можно: Млечный Путь и в небе непрерывен.
  static double glowRadiusFor(int stars) =>
      0.05 + 0.06 * math.sqrt(stars / 12.0);

  /// Звёзды внутри созвездия: по кольцам, с детерминированным разбросом.
  ///
  /// Ровное кольцо выглядит как циферблат, чистый рандом — как рассыпанная
  /// крупа. Кольца плюс сдвиг по хешу дают то, что читается как созвездие.
  ///
  /// **Позиция считается только из идентификатора звезды, а не из её номера
  /// в списке.** Раньше и кольцо, и угол брались из индекса и длины списка,
  /// и это работало, пока в списке лежали все звёзды яруса. Как только в
  /// него попадают только выученные, каждое новое выученное слово меняет и
  /// длину, и все индексы — то есть перекладывает созвездие целиком. Небо
  /// «моё» ровно потому, что его можно узнать; переставляющееся при каждом
  /// слове узнать нельзя.
  static List<StarPlacement> _placeStars(
    String constellation,
    List<StarInput> stars,
    SkyPoint center,
    double radius,
  ) {
    final result = <StarPlacement>[];

    for (final star in stars) {
      final seed = _hash('$constellation/${star.itemId}');

      // Кольцо: корень из равномерного числа даёт равномерную плотность по
      // площади, а не сгущение к центру.
      final ring = math.sqrt(_unit(seed));
      final angle = _unit(seed >> 11) * 2 * math.pi;
      // Разброс только внутрь: наружу звезда вылезла бы за границу
      // созвездия и налезла на соседнее.
      final jitter = 0.72 + _unit(seed >> 21) * 0.28;

      result.add(StarPlacement(
        itemId: star.itemId,
        position: SkyPoint(
          center.x + math.cos(angle) * radius * ring * jitter,
          center.y + math.sin(angle) * radius * ring * jitter,
        ),
        lumens: star.lumens,
      ));
    }
    return result;
  }

  /// Линии между звёздами. Их немного и они не пересекаются со всеми
  /// подряд: линия — это фраза, а не сетка.
  static List<(int, int)> _lines(int count, String constellation) {
    if (count < 2) return const [];
    final seed = _hash(constellation);
    final lines = <(int, int)>[];
    // Примерно одна линия на три звезды — столько же, сколько фраз на ярусе.
    final target = math.max(1, count ~/ 3);

    for (var i = 0; i < target; i++) {
      final a = (_hash('$constellation/line/$i') % count).abs();
      var b = (_hash('$constellation/line/$i/b') % count).abs();
      if (a == b) b = (b + 1 + (seed % 2).abs()) % count;
      lines.add((a, b));
    }
    return lines;
  }

  /// Точка на золотой спирали — равномерное заполнение диска.
  ///
  /// Радиус считается от **постоянного** [_referenceCount], а не от числа
  /// созвездий в базе. Это принципиально: иначе добавление одного созвездия
  /// сдвигало бы все остальные, и небо переписывалось бы при каждом
  /// обновлении контента. С константой новые созвездия просто дорастают
  /// наружу, а знакомые остаются на своих местах.
  static SkyPoint _spiralPoint(int index, int total, double spread) {
    if (total == 1) return const SkyPoint(0.5, 0.5);
    final radius = spread * math.sqrt((index + 0.5) / _referenceCount);
    final angle = index * _goldenAngle;
    return SkyPoint(
      0.5 + math.cos(angle) * radius,
      0.5 + math.sin(angle) * radius,
    );
  }

  /// Расчётный объём курса: 50 созвездий — пятьдесят тем разговорника, по
  /// десять на ярус. Число точное, а не с запасом: темы приходят одним
  /// источником, и пятьдесят первой не будет, пока не появится новый ярус.
  ///
  /// Раньше здесь стояло 30 — расчёт на словник, который давал 24 темы.
  /// Разговорник принёс пятьдесят, и спираль, посчитанная на тридцать,
  /// уводила двенадцать созвездий за край карты: у семи звёзды выходили за
  /// границу, у двух за ней оказывался сам центр. Карта их не рисует и
  /// доехать до них нельзя — то есть седьмая часть курса была игроку не
  /// видна. Проверяется тестом «ни одна звезда не уезжает за край карты».
  ///
  /// **Смена этого числа перекладывает небо целиком** — ровно то, от чего
  /// оно и защищает. Сделано это здесь потому, что корпус в этом же заходе
  /// заменён целиком: у всех фраз новые идентификаторы, ни одно созвездие не
  /// сохранило прежнего имени, и переносить было нечего. Второй раз такой
  /// случай не подвернётся, поэтому число взято по факту, а не «на вырост».
  static const int _referenceCount = 50;

  /// Минимальное расстояние между центрами ближайших созвездий.
  ///
  /// Величина постоянная при любом числе созвездий от одного до
  /// [_referenceCount]: радиус на спирали считается от [_referenceCount], а
  /// не от фактического числа, — именно затем, чтобы добавление созвездия не
  /// сдвигало остальные. Отсюда и то, что потолок радиуса звёзд можно
  /// задать константой, а не считать от числа созвездий.
  ///
  /// Число изменилось вместе с [_referenceCount]: пятьдесят созвездий на том
  /// же диске стоят теснее тридцати, и расстояние между ближайшими центрами
  /// упало с 0.1185517 до нынешнего. Потолок радиуса звёзд — половина от
  /// него, то есть созвездия стали компактнее. Это плата за то, что все
  /// пятьдесят помещаются на карту.
  ///
  /// Проверяется тестом: если `spread` или [_referenceCount] изменят, тест
  /// упадёт с настоящей цифрой, а не промолчит.
  /// Значение округлено **вниз**: потолок радиуса равен половине этого
  /// числа, и округление вверх дало бы перекрытие в пятый знак — то есть
  /// падающий тест вместо работающего правила.
  static const double minCenterDistance = _minCenterDistance;
  static const double _minCenterDistance = 0.0918297;

  /// Золотой угол: то, чем природа раскладывает семечки в подсолнухе, и
  /// ровно то, что нужно для «случайной, но равномерной» карты.
  static const double _goldenAngle = 2.399963229728653;

  /// Стабильный хеш строки (FNV-1a). `String.hashCode` не годится: он не
  /// гарантирован между запусками и версиями Dart, а небо обязано быть
  /// одинаковым всегда.
  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Число из хеша в диапазоне [0, 1).
  static double _unit(int seed) => (seed.abs() % 10007) / 10007;
}

/// Вход для раскладки: что известно о звезде.
class StarInput {
  const StarInput({required this.itemId, required this.lumens});

  final String itemId;
  final int lumens;
}
