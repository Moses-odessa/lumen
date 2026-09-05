/// Искры: внутренняя валюта, которую нельзя купить.
///
/// Ограничение из docs/CONCEPT.md: **ничего, что ограничивает обучение, за
/// искры не продаётся**. Они тратятся на паузу орбиты, внеочередное
/// созвездие и косметику неба — то есть на удобство и вид, но никогда на
/// доступ к материалу и никогда на преимущество.
library;

/// На что можно потратить искры.
enum SparkPurchase {
  /// Затмение: пауза орбиты на несколько дней.
  eclipse,

  /// Внеочередное созвездие — открыть тему, до которой курс ещё не дошёл.
  /// Это не «пропустить обучение», а «выбрать порядок».
  constellation,

  /// Косметика неба.
  cosmetic;

  /// Цена. TODO(balance)
  int get cost => switch (this) {
        SparkPurchase.eclipse => 120,
        SparkPurchase.constellation => 250,
        SparkPurchase.cosmetic => 400,
      };
}

abstract final class Sparks {
  /// Начисление за уровень.
  ///
  /// Считается от прироста яркости, а не от очков: очки можно нафармить
  /// повтором лёгкого, а люмены у горящих слов почти не растут.
  /// TODO(balance)
  static int forLevel({required int lumensGained, required int newWords}) =>
      lumensGained + newWords * 5;

  /// Хватает ли на покупку.
  static bool canAfford(int balance, SparkPurchase purchase) =>
      balance >= purchase.cost;

  /// Остаток после покупки; `null` — не хватает.
  static int? spend(int balance, SparkPurchase purchase) =>
      canAfford(balance, purchase) ? balance - purchase.cost : null;
}
