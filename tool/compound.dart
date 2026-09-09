/// Разбор немецких составных слов.
///
/// Немецкий строит существительные склеиванием, и это не редкость, а норма:
/// `Wohnungsgenossenschaft`, `Katastrophenschutz`, `Flächennutzungsplan`. Ни
/// один словарь не содержит их все, поэтому проверка существования формы без
/// разбора на части бесполезна — она объявит сомнительным каждое второе
/// слово.
///
/// **Чего этот файл не делает.** Он не доказывает, что слово существует. Он
/// отвечает на более узкий вопрос: раскладывается ли форма на части, каждая
/// из которых известна. Ответ «да» означает «правдоподобно», а не «есть в
/// языке»; ответ «нет» означает «нужен человек», а не «выдумка».
///
/// Разница важна, потому что искушение прочитать первое как второе очень
/// велико. Измерено на этом проекте: 6000 лемм словника плюс все формы
/// контента объясняют 654 дистрактора из 1227, а остальные 573 — почти
/// сплошь настоящие немецкие слова (Abbildung, Achtung, Aktion, Ambulanz).
/// Проверка, построенная на таком множестве, дала бы 573 ложных
/// срабатывания, то есть список, который никто не читает.
library;

/// Соединительные элементы между частями составного слова.
///
/// Порядок значим: длинные проверяются раньше коротких, иначе `-es-` никогда
/// не будет найден — его перекроет `-e-`.
const List<String> linkingElements = ['ens', 'ens', 'es', 'en', 'er', 'ns', 's', 'n', 'e', ''];

/// Минимальная длина части.
///
/// Четыре буквы. С тремя разбор начинает находить «части» в середине любого
/// слова: `der`, `ein`, `aus` встречаются как подстроки повсюду, и любая
/// выдумка раскладывается.
const int minCompoundPart = 4;

/// Раскладывается ли [word] на части из [known].
///
/// [known] — множество слов в нижнем регистре. Регистр здесь не значим: в
/// составном слове вторая часть пишется со строчной, а как лемма — с
/// заглавной.
bool splitsIntoKnown(
  String word,
  Set<String> known, {
  int maxParts = 3,
}) =>
    _split(word.toLowerCase(), known, maxParts) != null;

/// Части, на которые разложилось слово; `null`, если не разложилось.
///
/// Нужно не для проверки, а для сообщения человеку: «Nährwerttabelle =
/// nährwert + tabelle» объясняет, почему форма считается правдоподобной,
/// куда лучше, чем «да».
List<String>? compoundParts(
  String word,
  Set<String> known, {
  int maxParts = 3,
}) =>
    _split(word.toLowerCase(), known, maxParts);

List<String>? _split(String word, Set<String> known, int budget) {
  if (known.contains(word)) return [word];
  if (budget <= 1 || word.length < minCompoundPart * 2) return null;

  for (var cut = word.length - minCompoundPart; cut >= minCompoundPart; cut--) {
    final head = word.substring(0, cut);
    if (!known.contains(head)) continue;

    for (final link in linkingElements) {
      var rest = word.substring(cut);
      if (link.isNotEmpty) {
        if (!rest.startsWith(link)) continue;
        rest = rest.substring(link.length);
      }
      if (rest.length < minCompoundPart) continue;

      final tail = _split(rest, known, budget - 1);
      if (tail != null) return [head, ...tail];
    }
  }
  return null;
}
