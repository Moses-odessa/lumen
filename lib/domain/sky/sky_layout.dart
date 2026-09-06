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
  });

  final String name;
  final SkyPoint center;

  /// Радиус, который созвездие занимает на карте.
  final double radius;

  final List<StarPlacement> stars;

  /// Линии-фразы: пары индексов в [stars].
  final List<(int, int)> lines;
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
    double spread = 0.42,
  }) {
    final names = constellations.keys.toList()..sort();
    final result = <ConstellationPlacement>[];

    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final stars = constellations[name] ?? const <StarInput>[];
      final center = _spiralPoint(i, names.length, spread);
      // Плотные созвездия занимают больше места, но не пропорционально:
      // иначе B2 с 96 звёздами перекрыло бы половину карты.
      final radius = 0.045 + 0.055 * math.sqrt(stars.length / 12.0);

      result.add(ConstellationPlacement(
        name: name,
        center: center,
        radius: radius,
        stars: _placeStars(name, stars, center, radius),
        lines: _lines(stars.length, name),
      ));
    }
    return result;
  }

  /// Звёзды внутри созвездия: по кольцам, с детерминированным разбросом.
  ///
  /// Ровное кольцо выглядит как циферблат, чистый рандом — как рассыпанная
  /// крупа. Кольца плюс сдвиг по хешу дают то, что читается как созвездие.
  static List<StarPlacement> _placeStars(
    String constellation,
    List<StarInput> stars,
    SkyPoint center,
    double radius,
  ) {
    final result = <StarPlacement>[];

    for (var i = 0; i < stars.length; i++) {
      final star = stars[i];
      final seed = _hash('$constellation/${star.itemId}');

      // Номер кольца: первые звёзды ближе к центру.
      final ring = math.sqrt((i + 0.5) / stars.length);
      final angle = i * _goldenAngle + _unit(seed) * 0.9;
      // Разброс только внутрь: наружу звезда вылезла бы за границу
      // созвездия и налезла на соседнее.
      final jitter = 0.72 + _unit(seed >> 8) * 0.28;

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

  /// Расчётный объём курса: ~30 созвездий (docs/CONCEPT.md «Прогрессия»).
  /// Больше — спираль просто продолжится за пределы единичного круга, и
  /// карту нужно будет отмасштабировать, а не переложить.
  static const int _referenceCount = 30;

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
