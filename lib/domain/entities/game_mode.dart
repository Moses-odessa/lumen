/// Шесть режимов круга поверх одной геометрии (docs/CONCEPT.md «Шесть степеней
/// сложности»). Меняется только то, что в центре, сколько вариантов и насколько
/// они похожи друг на друга.
///
/// Множители и диапазоны яркости для каждого режима — в
/// `domain/scoring/balance.dart`, здесь только идентичность режима.
enum GameMode {
  /// В центре изучаемый язык, вокруг варианты на родном. Без таймера.
  recognition,

  /// В центре родной язык, вокруг изучаемый; дистракторы из того же созвездия.
  circle,

  /// То же, но дистракторы однокоренные и созвучные.
  tight,

  /// В центре только звук.
  audio,

  /// Поле ввода вместо круга, с артиклем.
  typing,

  /// Босс: предложение с пропуском, вокруг шесть форм одного слова.
  phrase;

  /// Код режима в `Reviews.mode`.
  String get code => name;

  /// Режим производит слово (игрок вспоминает сам), а не только узнаёт его.
  /// Отсюда растёт правило «горящего слова»: оно считается только здесь.
  bool get isProductive => switch (this) {
        GameMode.recognition => false,
        GameMode.circle ||
        GameMode.tight ||
        GameMode.audio ||
        GameMode.typing ||
        GameMode.phrase =>
          true,
      };

  static GameMode fromCode(String code) {
    for (final m in values) {
      if (m.name == code) return m;
    }
    return GameMode.circle;
  }
}
