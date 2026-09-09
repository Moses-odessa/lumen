/// Списки слов для проверки форм: положительный и отрицательный.
///
/// **Положительного списка в проекте пока нет, и это названо, а не скрыто.**
/// Проверка «форма существует в языке» требует словаря языка. Ни один
/// доступный офлайн материал им не является: 6000 лемм редакторского
/// словника плюс все формы контента объясняют 654 дистрактора из 1227, а
/// остальные 573 — почти сплошь настоящие немецкие слова. Проверка на такой
/// основе выдала бы 573 ложных срабатывания.
///
/// Сгенерировать словарь моделью нельзя, и это не осторожность. Список из
/// ста тысяч лемм, произведённый тем же способом, что произвёл контент,
/// будет содержать те же выдумки — и тогда проверка начнёт **подтверждать**
/// несуществующие слова. Это хуже отсутствия проверки: она превратит
/// открытый вопрос в закрытый и неверный.
///
/// Поэтому здесь два списка, и они разной природы.
///
/// * `de.txt` — **положительный**: формы, существование которых
///   подтверждено. Файла нет; когда появится, проверка включится сама, и
///   ничего кроме него для этого не нужно.
/// * `de-nonwords.txt` — **отрицательный**: формы, про которые установлено,
///   что их не существует. Он не может доказать существование, но делает
///   невозможным возврат: найденная однажды выдумка не вернётся в контент
///   никогда. Такой список у проекта есть чем наполнить — вычитка уже
///   находила несуществующие слова, и до сих пор эта работа никуда не
///   складывалась.
library;

import 'dart:io';

/// Каталог со списками слов.
Directory wordListDirectory(String root) =>
    Directory('$root/dictionaries');

/// Читает список слов: по одному на строку, `#` — комментарий.
///
/// После слова может стоять причина, отделённая двумя пробелами: она нужна
/// человеку, а не проверке, и здесь отбрасывается.
///
/// Возвращается в нижнем регистре: в составном слове вторая часть пишется со
/// строчной, а как лемма — с заглавной, и различать их при проверке нечем.
Set<String> readWordList(File file) {
  if (!file.existsSync()) return const {};
  final result = <String>{};
  for (final line in file.readAsLinesSync()) {
    var word = line.trim();
    if (word.isEmpty || word.startsWith('#')) continue;
    final reason = word.indexOf('  ');
    if (reason > 0) word = word.substring(0, reason).trim();
    result.add(word.toLowerCase());
  }
  return result;
}

/// Слово и причина запрета, как записано в отрицательном списке.
Map<String, String> readNonWordReasons(File file) {
  if (!file.existsSync()) return const {};
  final result = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final at = trimmed.indexOf('  ');
    if (at <= 0) {
      result[trimmed.toLowerCase()] = '';
      continue;
    }
    result[trimmed.substring(0, at).trim().toLowerCase()] =
        trimmed.substring(at).trim();
  }
  return result;
}

/// Положительный список языка: формы, существование которых подтверждено.
/// Пустое множество означает «списка нет», а не «слов нет».
Set<String> readDictionary(String root, String lang) =>
    readWordList(File('${wordListDirectory(root).path}/$lang.txt'));

/// Отрицательный список: формы, про которые установлено, что их нет.
Set<String> readNonWords(String root, String lang) =>
    readWordList(File('${wordListDirectory(root).path}/$lang-nonwords.txt'));

/// Записывает отрицательный список.
///
/// Порядок — по алфавиту, чтобы файл не шумел в diff. Пометка о происхождении
/// обязательна: список запрещает слово навсегда, и через год должно быть
/// видно, кто и на каком основании это решил.
void writeNonWords(
  File file,
  String lang,
  Map<String, String> wordsWithReason,
) {
  final words = wordsWithReason.keys.toList()..sort();
  final out = StringBuffer()
    ..writeln('# Формы, про которые установлено, что в $lang их не существует.')
    ..writeln('#')
    ..writeln('# Список не доказывает существование — он запрещает возврат.')
    ..writeln('# Найденная однажды выдумка не вернётся в контент никогда:')
    ..writeln('# валидатор считает ошибкой любую форму из этого файла.')
    ..writeln('#')
    ..writeln('# Строка: слово, потом причина после двух пробелов. Причина')
    ..writeln('# обязательна: запрет навсегда, и через год должно быть видно,')
    ..writeln('# на каком основании он поставлен.');
  for (final word in words) {
    out.writeln('$word  ${wordsWithReason[word]}');
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(out.toString());
}
