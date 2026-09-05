import 'tier.dart';

/// Состояние игрока — одна строка в `user.db`. Родной язык (язык подсказок в
/// игре) и язык интерфейса — разные настройки, поэтому языка интерфейса здесь
/// нет: он живёт отдельно и может отличаться от [nativeLang].
class Player {
  const Player({
    required this.targetLang,
    required this.nativeLang,
    required this.tier,
    this.calibrated = false,
    this.orbit = 0,
    this.sparks = 0,
    this.lastPlayedAt,
    this.missedInRow = 0,
    this.freePace = false,
    this.soundEnabled = true,
    this.uiLang,
  });

  /// Язык изучения: `de`. До M8 в ассетах лежит озвучка ровно одного.
  final String targetLang;

  /// Язык подсказок в игре: `ru`, `uk`, `en`.
  final String nativeLang;

  /// Язык интерфейса; `null` — следовать языку системы.
  final String? uiLang;

  /// Текущий ярус. Результат калибровки — предложение, а не приговор:
  /// ярус меняется вручную в любой момент.
  final Tier tier;

  /// Калибровка пройдена (в том числе кнопкой «я с нуля»). Пока false —
  /// роутер держит игрока в онбординге.
  final bool calibrated;

  /// Орбита вместо стрика: пропуск опускает на один, а не обнуляет.
  final int orbit;

  /// Искры: тратятся на затмения и косметику, но не на обучение.
  final int sparks;

  final DateTime? lastPlayedAt;

  /// Пропусков подряд; полный сброс орбиты — только на третьем.
  final int missedInRow;

  /// «Свой темп»: снимает дидактическое ограничение в один уровень в день.
  final bool freePace;

  /// В беззвучном режиме озвучка заменяется вибрацией и подсветкой
  /// ударного слога — но не отключается как механика.
  final bool soundEnabled;

  Player copyWith({
    String? targetLang,
    String? nativeLang,
    String? Function()? uiLang,
    Tier? tier,
    bool? calibrated,
    int? orbit,
    int? sparks,
    DateTime? Function()? lastPlayedAt,
    int? missedInRow,
    bool? freePace,
    bool? soundEnabled,
  }) =>
      Player(
        targetLang: targetLang ?? this.targetLang,
        nativeLang: nativeLang ?? this.nativeLang,
        uiLang: uiLang == null ? this.uiLang : uiLang(),
        tier: tier ?? this.tier,
        calibrated: calibrated ?? this.calibrated,
        orbit: orbit ?? this.orbit,
        sparks: sparks ?? this.sparks,
        lastPlayedAt:
            lastPlayedAt == null ? this.lastPlayedAt : lastPlayedAt(),
        missedInRow: missedInRow ?? this.missedInRow,
        freePace: freePace ?? this.freePace,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );
}
