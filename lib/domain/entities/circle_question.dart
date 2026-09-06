import 'game_mode.dart';
import 'tier.dart';
import '../scoring/balance.dart';

/// Один круг: что в центре, что вокруг и что считается верным.
///
/// Геометрия экрана одна и та же во всех режимах — меняется только
/// содержимое этой структуры. Поэтому виджет круга не знает про режимы
/// ничего, кроме того, что здесь написано.
class CircleQuestion {
  const CircleQuestion({
    required this.itemId,
    required this.tier,
    required this.mode,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.lumens,
    this.isNew = false,
    this.promptAudioId,
    this.answerAudioId,
    this.promptHint,
    this.answerArticle,
  });

  final String itemId;

  /// Ярус слова из `content.db`. Нужен при первом показе: строки состояния
  /// у слова ещё нет, и ярус взять больше неоткуда.
  final Tier tier;

  final GameMode mode;

  /// Что в центре: слово на родном языке, слово на изучаемом или фраза с
  /// пропуском. В режиме «Слух» пустая строка — центр занимает звук.
  final String prompt;

  /// Пояснение под центром: артикль, часть речи, регистр фразы.
  final String? promptHint;

  /// Варианты вокруг. Для «Набора» пустой список: там поле ввода.
  final List<String> options;

  /// Индекс верного варианта в [options]; −1 для «Набора».
  final int answerIndex;

  /// Яркость слова **до** этого ответа: от неё зависят очки.
  final Lumens lumens;

  /// Первый показ нового слова: таймера нет.
  final bool isNew;

  /// Озвучка центра — нужна режиму «Слух».
  final String? promptAudioId;

  /// Озвучка верного ответа. Играет при каждом верном соединении, во всех
  /// режимах: за пять минут игрок слышит полсотни живых образцов
  /// произношения, ничего для этого не делая.
  final String? answerAudioId;

  /// Артикль верного ответа: в «Наборе» он обязателен, в остальных режимах
  /// показывается вместе с ответом.
  final String? answerArticle;

  /// Текст верного варианта.
  String get answer =>
      answerIndex >= 0 && answerIndex < options.length
          ? options[answerIndex]
          : '';

  /// Ответ вводится с клавиатуры, а не выбирается.
  bool get isTyped => mode == GameMode.typing;

  /// Верен ли выбор варианта.
  bool isCorrectOption(int index) => index == answerIndex;

  /// Верен ли введённый текст.
  ///
  /// Опечатка в одну букву засчитывается: игра проверяет знание слова, а не
  /// умение попадать по клавишам на телефоне. Артикль, если он есть,
  /// принимается и с ним, и без него.
  bool isCorrectInput(String input) {
    final typed = _normalize(input);
    if (typed.isEmpty) return false;

    for (final variant in _acceptedForms) {
      final expected = _normalize(variant);
      if (typed == expected) return true;
      // Порог опечатки зависит от длины: в слове из трёх букв одна ошибка —
      // это уже другое слово.
      final tolerance = expected.length >= 5 ? 1 : 0;
      if (tolerance > 0 && _editDistance(typed, expected) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  Iterable<String> get _acceptedForms sync* {
    yield answer;
    final article = answerArticle;
    if (article != null && article.isNotEmpty) {
      yield '$article $answer';
    }
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Расстояние Левенштейна с ранним выходом: слова короткие, но считать
  /// на каждый ввод всё равно незачем.
  static int _editDistance(String a, String b) {
    if ((a.length - b.length).abs() > 2) return 3;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }
}
