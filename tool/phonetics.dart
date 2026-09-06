// Грубая фонетика немецкого — для проверки созвучности дистракторов.
//
// Зачем отдельный файл: исходная эвристика сравнивала написание, и на
// немецком это давало поток ложных срабатываний. `Tour` и `Uhr` рифмуются,
// `Fleiß` и `Preis` рифмуются, `Karaffe` и `Kaffee` звучат почти одинаково —
// но общих букв у них мало, и валидатор выносил их на ручную проверку.
// Список из сотни таких «сомнительных» бесполезен: настоящие проблемы в нём
// не видно.
//
// Это не транскрипция и не претендует на неё. Задача одна: привести
// написание к виду, где одинаково звучащие куски выглядят одинаково.

/// Приблизительная звуковая запись немецкого слова.
///
/// Порядок замен значим: составные графемы разбираются раньше одиночных
/// букв, иначе `sch` успеет превратиться в `s` + `ch`.
String germanSoundalike(String word) {
  var s = word.toLowerCase().trim();

  const digraphs = <String, String>{
    // Шипящие и аффрикаты.
    'sch': 'S',
    'chs': 'ks',
    'ch': 'x',
    'ph': 'f',
    'th': 't',
    'ck': 'k',
    'qu': 'kv',
    'tz': 'ts',
    'dt': 't',
    // Дифтонги. `ie` — это долгое «и», а не дифтонг.
    'ie': 'i',
    'ei': 'aj',
    'ai': 'aj',
    'eu': 'oj',
    'äu': 'oj',
  };
  for (final entry in digraphs.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }

  const singles = <String, String>{
    'ß': 's',
    'z': 'ts',
    'x': 'ks',
    'v': 'f',
    'w': 'f',
    'ä': 'e',
    'ö': 'o',
    'ü': 'u',
    'y': 'i',
  };
  for (final entry in singles.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }

  // Растяжное `h` не звучит: Uhr → ur, Zahn → tsan.
  s = s.replaceAllMapped(RegExp('([aeiou])h'), (m) => m[1]!);

  // Конечное `-er` в немецком — гласный, а не согласный: Vater ≈ «фата».
  if (s.endsWith('er')) s = '${s.substring(0, s.length - 2)}a';

  // Удвоения ничего не добавляют к звучанию.
  s = s.replaceAllMapped(RegExp(r'(.)\1'), (m) => m[1]!);

  return s;
}

/// Похоже ли `distractor` на `answer` на слух.
///
/// Порог по окончанию снижен для коротких слов: рифма `Uhr` / `Tour` — это
/// два звука, и требовать от неё трёх значит не увидеть её вовсе.
bool soundsAlike(String answer, String distractor) {
  final a = germanSoundalike(answer);
  final b = germanSoundalike(distractor);
  if (a.isEmpty || b.isEmpty) return false;

  final shortest = a.length < b.length ? a.length : b.length;
  final prefix = commonPrefix(a, b);
  final suffix = commonSuffix(a, b);
  final distance = levenshtein(a, b);

  return prefix >= 3 ||
      suffix >= 3 ||
      (suffix >= 2 && shortest <= 4) ||
      distance <= 2 ||
      distance <= (a.length / 3).ceil();
}

/// Отчёт для списка ручной проверки: по каким числам решение принято.
String soundalikeReport(String answer, String distractor) {
  final a = germanSoundalike(answer);
  final b = germanSoundalike(distractor);
  return 'звучание "$b" против "$a": общее начало ${commonPrefix(a, b)}, '
      'окончание ${commonSuffix(a, b)}, расстояние ${levenshtein(a, b)}';
}

int commonPrefix(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  return i;
}

int commonSuffix(String a, String b) {
  var i = 0;
  while (i < a.length &&
      i < b.length &&
      a[a.length - 1 - i] == b[b.length - 1 - i]) {
    i++;
  }
  return i;
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = <int>[i + 1];
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      final insert = current[j] + 1;
      final delete = previous[j + 1] + 1;
      final replace = previous[j] + cost;
      var best = insert < delete ? insert : delete;
      if (replace < best) best = replace;
      current.add(best);
    }
    previous = current;
  }
  return previous.last;
}
