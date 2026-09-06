/// Немецкая морфология в объёме, который нужен валидатору контента.
///
/// Отдельный модуль по той же причине, что и `phonetics.dart`: правило,
/// живущее внутри скрипта, проверяется один раз глазами, а вынесенное —
/// тестом на каждом прогоне.
library;

/// Написание, приведённое к сравнимому виду: регистр и ß/ss.
///
/// Умлаут сюда не входит, и это не упущение: в немецком он различает слова —
/// «Küche» и «Kuchen», «Schränke» и «Schranke» — тогда как «Grösse» и «Größe»
/// это одно слово в двух допустимых написаниях.
String foldSpelling(String word) => word.toLowerCase().replaceAll('ß', 'ss');

/// То же плюс развёртка умлаута — нужна там, где умлаут появляется как часть
/// самого образования формы: Arzt / Ärzte, Hand / Hände.
String foldUmlaut(String word) => foldSpelling(word)
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u');

/// Полный список немецких показателей множественного. Он закрытый — в этом
/// вся сила проверки: всё, что не сводится к нему, разбирается вручную.
const _pluralSuffixes = ['', 'e', 'er', 'n', 'en', 'nen', 's', 'se', 'ien', 'a'];

/// Заимствования меняют конец основы: Dosis/Dosen, Firma/Firmen,
/// Konto/Konten, Klima/Klimata, Museum/Museen.
const _loanStemEndings = ['e', 'us', 'um', 'on', 'is', 'a', 'o'];
const _loanSuffixes = [..._pluralSuffixes, 'en', 'ata'];

/// Образуется ли [plural] от [form] по правилам немецкого множественного.
///
/// Проверка нужна потому, что поле `plural` есть в схеме, и заполнить его
/// хочется всегда — даже у неисчисляемых. Тогда вместо формы туда попадает
/// выдуманное составное: «Milch» → «Milchsorten», «Zeitdruck» → «Zeitzwänge».
/// Игрок учит слово, которого в его словаре нет.
bool isGermanPlural(String form, String plural) {
  final stem = foldUmlaut(form);
  final made = foldUmlaut(plural);
  if (stem.isEmpty) return false;

  if (_pluralSuffixes.any((s) => made == stem + s)) return true;
  // Удвоение конечной согласной: Bus / Busse.
  if (_pluralSuffixes.any((s) => made == stem + stem[stem.length - 1] + s)) {
    return true;
  }
  return _loanStemEndings.any(
    (e) =>
        stem.endsWith(e) &&
        _loanSuffixes.any(
          (s) => made == stem.substring(0, stem.length - e.length) + s,
        ),
  );
}

/// Субстантивированное прилагательное, записанное в сильной форме, хотя рядом
/// стоит определённый артикль: «der Vorgesetzter» вместо «der Vorgesetzte».
///
/// Узнаётся по тому, что «множественное» короче формы ровно на конечное -r —
/// у обычного существительного такого не бывает.
bool isMisdeclinedAdjectivalNoun(String form, String plural) =>
    form.endsWith('er') && plural == form.substring(0, form.length - 1);
