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
    this.promptTag,
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
    this.promptTag,
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

  /// Пояснение под центром **на родном языке игрока**: «банковская», «мать
  /// супруга». Свободный текст, и он законен ровно потому, что взят из файла
  /// родного языка — там язык файла и есть язык читателя.
  final String? promptHint;

  /// Пометка под центром кодом: часть речи, исчисляемость, регистр фразы.
  /// Строку к коду даёт локализация, на языке интерфейса.
  ///
  /// Отдельно от [promptHint] потому, что раньше это было одно поле — и в
  /// него уезжали то немецкая пометка, написанная по-русски, то внутренний
  /// код `casual`. Под каждой из 432 фраз стояло английское служебное слово,
  /// а под немецким словом — русский грамматический ярлык, независимо от
  /// того, какой язык игрок выбрал. Набор кодов — `promptTags`.
  final String? promptTag;

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

  /// Тот же вопрос, но другой объект.
  ///
  /// Нужен затем, чтобы промах можно было показать заново. Арена сбрасывает
  /// своё состояние, когда `widget.question` перестаёт быть **тем же
  /// объектом** — сравнения по значению у вопроса нет и не надо: два круга по
  /// одному слову это два разных вопроса, и путать их нельзя.
  ///
  /// Но забег возвращал промах в конец очереди тем же экземпляром. Пока за
  /// ним стояли другие круги, разница не проявлялась. А когда промах —
  /// последний круг забега, следующим показывается он же: объект тот, арена
  /// не сбрасывается, заполненные слоты и выбранный вариант остаются на
  /// месте, и она больше не принимает ответов. Забег ждёт вечно.
  ///
  /// Закрывающий уровень фразовый заход — ровно два круга на одном
  /// предложении, так что промах на втором вешал уровень целиком.
  CircleQuestion again() => CircleQuestion(
        itemId: itemId,
        tier: tier,
        mode: mode,
        prompt: prompt,
        options: options,
        answers: answers,
        lumens: lumens,
        isNew: isNew,
        promptSpeech: promptSpeech,
        answerSpeech: answerSpeech,
        promptHint: promptHint,
        promptTag: promptTag,
        answerArticle: answerArticle,
        translation: translation,
      );

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
  ///
  /// Сравнивается **текст**, а не только номер варианта, и это починка, а не
  /// вольность. В пуле фразы лежат слова самого предложения, поэтому два
  /// одинаковых слова — обычное дело: «Das ist ein guter Preis für so ein
  /// Auto» несёт `ein` дважды, и это запущенный ярус A0. Игрок видит две
  /// неотличимые плитки, за каждой стоит свой номер, и слот принимал только
  /// один из двух. Поставил наоборот — «неверно» на предложении, которое
  /// читается буква в букву как правильное.
  ///
  /// Такое есть у четырёх фраз из 432 точным совпадением слова и у
  /// девятнадцати — совпадением без учёта регистра.
  ///
  /// Номера при этом остаются разными у разных слотов (`_firstUnused` в
  /// сборщике): иначе два слота заняли бы одну плитку, а вторая осталась бы
  /// висеть в пуле незакрываемой.
  bool isCorrectFor(int slot, int optionIndex) {
    if (slot < 0 || slot >= slotCount) return false;
    if (answers[slot] == optionIndex) return true;
    if (optionIndex < 0 || optionIndex >= options.length) return false;
    return options[optionIndex] == answerFor(slot);
  }

  /// Верен ли выбор, когда слот один.
  bool isCorrectOption(int index) => isCorrectFor(0, index);

  /// Пропуск в шаблоне: `_____`.
  static final _gap = RegExp('_____');
}
