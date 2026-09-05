import 'package:flutter/material.dart';

import 'palette.dart';

/// Темы приложения. Тёмная — по умолчанию (небо), светлая — альтернатива.
abstract final class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: LumenPalette.seed,
      brightness: brightness,
    ).copyWith(
      // Небо, а не серый Material-фон: карта созвездий занимает весь экран.
      surface: isDark ? LumenPalette.skyZenith : LumenPalette.daySurface,
      primary: isDark ? LumenPalette.starlight : LumenPalette.seed,
      onPrimary: isDark ? LumenPalette.skyZenith : Colors.white,
      error: LumenPalette.wrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? LumenPalette.skyHorizon
            : LumenPalette.daySurface,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
      // Цифры счёта и таймера — с табличными цифрами: иначе счёт «дёргается»
      // на каждом круге, когда меняется ширина знака.
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        displayMedium: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        headlineLarge: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
