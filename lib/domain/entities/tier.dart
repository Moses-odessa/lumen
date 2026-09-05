/// Ярус игрока по CEFR. Одно и то же созвездие существует на всех пяти ярусах
/// и растёт вместе с игроком (docs/CONCEPT.md «Прогрессия»).
///
/// Порядок значений значим: он задаёт направление подъёма и спуска в
/// калибровке, поэтому сравнивать ярусы нужно через [index].
enum Tier {
  a0,
  a1,
  a2,
  b1,
  b2;

  /// Код яруса в `content.db` (`concepts.tier`).
  String get code => name;

  /// Человекочитаемая метка CEFR — одинаковая на всех языках интерфейса,
  /// поэтому не идёт в ARB.
  String get label => name.toUpperCase();

  /// Следующий ярус вверх или `null`, если это уже B2.
  Tier? get up => index + 1 < values.length ? values[index + 1] : null;

  /// Следующий ярус вниз или `null`, если это уже A0.
  Tier? get down => index > 0 ? values[index - 1] : null;

  /// Разбор кода из БД. Неизвестный код — данные битые, но игру ломать
  /// не должен: считаем такой концепт самым простым.
  static Tier fromCode(String code) {
    for (final t in values) {
      if (t.name == code) return t;
    }
    return Tier.a0;
  }
}
