import 'package:flutter/material.dart';

import '../../domain/scoring/balance.dart';

/// Палитра Lumen. Основное состояние приложения — ночь: тёмная тема не
/// «альтернативная», а рабочая, светлая нужна для дневного использования и
/// доступности.
///
/// Цвета звёзд заданы по полосам яркости из [LumenBand]: пороги живут в
/// `domain/scoring/balance.dart`, здесь только их визуальное выражение.
abstract final class LumenPalette {
  // ── Ночь ────────────────────────────────────────────────────────────────
  /// Фон неба у зенита — почти чёрный с синим уклоном.
  static const Color skyZenith = Color(0xFF05070F);

  /// Фон неба у горизонта: к нему уходит вертикальный градиент карты.
  static const Color skyHorizon = Color(0xFF0E1630);

  /// Основной акцент — свет звезды, тёплый, а не синий: он должен читаться
  /// как источник, а не как подсветка интерфейса.
  static const Color starlight = Color(0xFFFFD79A);

  /// Линия-фраза между звёздами.
  static const Color constellationLine = Color(0xFF5A7FB8);

  // ── День ────────────────────────────────────────────────────────────────
  static const Color daySurface = Color(0xFFF7F8FC);
  static const Color dayInk = Color(0xFF101526);

  /// Затравка Material 3: глубокая синь ночного неба.
  static const Color seed = Color(0xFF2A4A8F);

  /// Цвет звезды по полосе яркости. Горящая — почти белая с тёплым ядром,
  /// гаснущая — едва отличима от фона.
  static Color star(LumenBand band) => switch (band) {
        LumenBand.burning => const Color(0xFFFFF3DC),
        LumenBand.steady => const Color(0xFFFFD79A),
        LumenBand.flickering => const Color(0xFFC9A97E),
        LumenBand.dimming => const Color(0xFF7B7590),
        LumenBand.fading => const Color(0xFF3A3F55),
      };

  /// Цвет звезды по яркости в люменах.
  static Color starByLumens(Lumens lm) => star(LumenBand.of(lm));

  /// Радиус звезды на карте: горящие крупнее не для красоты, а чтобы
  /// состояние неба считывалось без зума.
  static double starRadius(LumenBand band) => switch (band) {
        LumenBand.burning => 3.4,
        LumenBand.steady => 2.8,
        LumenBand.flickering => 2.2,
        LumenBand.dimming => 1.8,
        LumenBand.fading => 1.4,
      };

  /// Непрозрачность звезды: гаснущая почти не видна, но её место на карте
  /// остаётся — небо не переписывается, оно тускнеет.
  static double starOpacity(LumenBand band) => switch (band) {
        LumenBand.burning => 1.0,
        LumenBand.steady => 0.9,
        LumenBand.flickering => 0.75,
        LumenBand.dimming => 0.55,
        LumenBand.fading => 0.35,
      };

  /// Верный ответ в круге.
  static const Color correct = Color(0xFF6BD6A0);

  /// Неверный ответ: заметно, но без агрессии — ошибка стоит очков, а не
  /// доступа.
  static const Color wrong = Color(0xFFE2856E);
}
