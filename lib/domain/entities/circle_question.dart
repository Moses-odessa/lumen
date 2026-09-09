import 'game_mode.dart';
import 'tier.dart';
import '../scoring/balance.dart';

/// Один вопрос: что в центре, что вокруг и что считается верным.
///
/// Геометрия экрана одна и та же во всех механиках — меняется только
/// содержимое этой структуры. Поэтому виджет не знает про механики ничего,
/// кроме того, что здесь написано.
///
/// **Один слот или несколько.** Механики a–d ставят один вопрос: выбрать
/// вариант. Механики e и f ставят несколько: заполнить пропуски или собрать
/// предложение. Раньше на это завели бы вторую структуру и второй виджет, но
/// разница между ними ровно одна — число слотов. Круг это фраза с одним
/// слотом, у которой нет видимого шаблона; поэтому [answers] список, а не
/// одно число, и `answers.length == 1` покрывает четыре механики из шести.
class CircleQuestion {
  const CircleQuestion({
    required this.itemId,
    required this.tier,
    required this.mode,
    required this.prompt,
    required this.options,
    required this.answers,
    required this.lumens,
    this.isNew = false,
    this.promptSpeech,
    this.answerSpeech,
    this.promptHint,
    this.answerArticle,
    this.translation,
  });

  /// Круг с одним слотом — самый частый случай.
  CircleQuestion.single({
    required this.itemId,
    required this.tier,
    required this.mode,
    required this.prompt,
    required this.options,
    required int answerIndex,
    required this.lumens,
    this.isNew = false,
    this.promptSpeech,
    this.answerSpeech,
    this.promptHint,
    this.answerArticle,
    this.translation,
  }) : answers = [answerIndex];

  final String itemId;

  /// Ярус слова из `content.db`. Нужен при первом показе: строки состояния
  /// у слова ещё нет, и ярус взять больше неоткуда.
  final Tier tier;

  final GameMode mode;

  /// Что в центре: слово, фраза с пропусками или пустая строка, когда центр
  /// занимает звук либо слоты.
  final String prompt;

  /// Пояснение под центром: артикль, часть речи, регистр фразы.
  final String? promptHint;

  /// Пул вариантов. В механиках a–d это варианты вокруг центра; в e и f —
  /// слова, которые нужно расставить по слотам.
  final List<String> options;

  /// Для каждого слота — индекс верного варианта в [options].
  /// Длина списка равна числу слотов.
  final List<int> answers;

  /// Перевод фразы целиком на родной язык: проявляется, когда все пропуски
  /// заполнены. Пропуск, заполненный верно, но так и не объяснённый, учит
  /// подбирать форму и ничему больше.
  final String? translation;

  /// Яркость слова **до** этого ответа: от неё зависят очки.
  final Lumens lumens;

  /// Первый показ нового слова: таймера нет.
  final bool isNew;

  /// Что произносится в центре — нужно механикам на слух.
  final String? promptSpeech;

  /// Что произносится при верном соединении. Звучит в каждой механике: за
  /// пять минут игрок слышит полсотни образцов произношения, ничего для
  /// этого не делая.
  ///
  /// Это текст, а не идентификатор записи. Разница не техническая: у фразы
  /// здесь стоит всё предложение целиком, а не одно слово из пропуска, —
  /// записывать столько файлов было незачем, а произнести их можно.
  final String? answerSpeech;

  /// Артикль верного ответа: показывается вместе с ответом.
  final String? answerArticle;

  /// Сколько слотов нужно заполнить.
  int get slotCount => answers.length;

  /// Один слот — четыре механики из шести.
  bool get isSingleSlot => slotCount == 1;

  /// Индекс верного варианта, когда слот один.
  int get answerIndex => answers.first;

  /// Текст верного варианта единственного слота.
  String get answer => answerFor(0);

  /// Текст верного варианта для слота.
  String answerFor(int slot) {
    if (slot < 0 || slot >= slotCount) return '';
    final index = answers[slot];
    return index >= 0 && index < options.length ? options[index] : '';
  }

  /// Собранное предложение: все слоты заполнены верно.
  ///
  /// Для механики f это и есть цель; для e — то, что проигрывается в конце.
  String get assembled {
    if (mode == GameMode.buildPhrase) {
      return [for (var i = 0; i < slotCount; i++) answerFor(i)].join(' ');
    }
    var slot = 0;
    return prompt.replaceAllMapped(
      _gap,
      (_) => slot < slotCount ? answerFor(slot++) : '',
    );
  }

  /// Верен ли выбор варианта для слота.
  bool isCorrectFor(int slot, int optionIndex) =>
      slot >= 0 && slot < slotCount && answers[slot] == optionIndex;

  /// Верен ли выбор, когда слот один.
  bool isCorrectOption(int index) => isCorrectFor(0, index);

  /// Пропуск в шаблоне: `_____`.
  static final _gap = RegExp('_____');
}
