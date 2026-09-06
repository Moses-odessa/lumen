// Проверки полноты и качества контента. Запускается в CI, падение блокирует
// мерж (docs/CONTENT_PIPELINE.md).
//
//   dart run tool/validate_content.dart --lang de

import 'dart:convert';
import 'dart:io';

import 'content_schema.dart';
import 'content_sources.dart';
import 'morphology.dart';
import 'phonetics.dart';

Future<void> main(List<String> args) async {
  final lang = _argValue(args, '--lang') ?? targetLang;
  final root = Directory.current;

  final ContentSources sources;
  try {
    sources = ContentSources.load(
      Directory('${root.path}/content'),
      lang: lang,
    );
  } on ContentSourceException catch (e) {
    stderr.writeln('✗ исходники: ${e.message}');
    exitCode = 1;
    return;
  }

  final report = _Report();

  final launched = sources.launch.launched;
  if (launched.isEmpty) {
    report.pending(
      'в content/launch.yaml не объявлен ни один запущенный ярус для $lang — '
      'проверяется только структура',
    );
  } else {
    stdout.writeln('Запущенные ярусы $lang: ${launched.join(', ')}');
  }

  _checkLaunchPolicy(sources, report);
  _checkLexemeCoverage(sources, report);
  _checkOrphanLexemes(sources, report);
  _checkDistractors(sources, lang, report);
  _checkNearSoundalike(sources, lang, report);
  _checkConstellationSizes(sources, report);
  _checkDuplicateForms(sources, lang, report);
  _checkPhraseAnswers(sources, lang, report);
  _checkArticleGender(sources, lang, report);
  _checkPluralMorphology(sources, lang, report);
  _checkPluraleTantum(sources, lang, report);
  _checkDistractorCase(sources, lang, report);
  _checkPhraseAmbiguity(sources, lang, report);
  _checkDistractorVariety(sources, lang, report);
  _checkPhrases(sources, report);
  _checkCalibration(sources, lang, report);
  _checkAudio(sources, lang, root, report);

  report.print(lang);
  if (report.errors.isNotEmpty) exitCode = 1;
}

/// У каждого концепта есть лексема на каждом языке проекта.
void _checkLexemeCoverage(ContentSources sources, _Report report) {
  for (final lang in projectLangs) {
    final byConcept = sources.lexemes[lang];
    if (byConcept == null) {
      report.error('нет файла content/lang/$lang.yaml');
      continue;
    }
    final missing = sources.concepts.keys
        .where((id) => !byConcept.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      report.error(
        'язык $lang: нет лексем для ${missing.length} концептов '
        '(${_head(missing)})',
      );
    }
  }
}

/// Лексема без концепта — обычно опечатка в id после переименования.
void _checkOrphanLexemes(ContentSources sources, _Report report) {
  for (final entry in sources.lexemes.entries) {
    final orphans = entry.value.keys
        .where((id) => !sources.concepts.containsKey(id))
        .toList();
    if (orphans.isNotEmpty) {
      report.error(
        'язык ${entry.key}: лексемы без концепта — ${_head(orphans)}',
      );
    }
  }
}

/// У каждого концепта минимум 2 дистрактора `far` и 3 `near` на языке
/// изучения, и ни один не совпадает с ответом.
///
/// Полнота требуется только от запущенных ярусов — как и везде: дистракторы
/// пишутся вместе с вычиткой, и требовать их от чернового яруса значит
/// блокировать мерж за незаконченную работу, которая и не объявлена
/// законченной.
void _checkDistractors(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  var draftGaps = 0;

  for (final lex in byConcept.values) {
    final tier = sources.concepts[lex.conceptId]?.tier;
    final launched = tier != null && sources.launch.isLaunched(tier);

    final short = lex.farDistractors.length < minFarDistractors ||
        lex.nearDistractors.length < minNearDistractors;

    if (short && !launched) {
      draftGaps++;
      continue;
    }

    if (lex.farDistractors.length < minFarDistractors) {
      report.error(
        '${lex.conceptId}: дистракторов far ${lex.farDistractors.length}, '
        'нужно $minFarDistractors',
      );
    }
    if (lex.nearDistractors.length < minNearDistractors) {
      report.error(
        '${lex.conceptId}: дистракторов near ${lex.nearDistractors.length}, '
        'нужно $minNearDistractors',
      );
    }

    final all = [...lex.farDistractors, ...lex.nearDistractors];
    // Сравнение нормализованное: «Grösse» — это швейцарское написание
    // «Größe», а не другое слово. Вариант написания в роли неверного ответа
    // учит считать ошибкой правильную форму.
    final answer = foldSpelling(lex.form);
    final answerPlural = lex.plural == null ? null : foldSpelling(lex.plural!);
    for (final d in all) {
      final folded = foldSpelling(d);
      if (folded != answer && folded != answerPlural) continue;
      report.error(
        '${lex.conceptId}: дистрактор "$d" — это сам ответ '
        '"${lex.form}" в другом написании',
      );
    }

    if (all.toSet().length != all.length) {
      report.error('${lex.conceptId}: дистракторы дублируются');
    }
  }

  if (draftGaps > 0) {
    report.pending(
      'дистракторы не дописаны у $draftGaps концептов незапущенных ярусов',
    );
  }
}

/// `near`-дистракторы обязаны быть созвучны. Эвристика грубая и смотрит на
/// три вещи: общее начало, общее окончание и расстояние Левенштейна — но не
/// в написании, а в приблизительной звуковой записи (`tool/phonetics.dart`).
///
/// Окончание здесь не менее важно, чем начало: в немецком созвучие часто идёт
/// по суффиксу — и по короткому. Три буквы, а не четыре, потому что рифму
/// дают именно трёхбуквенные окончания: Diagnose / Narkose, Temperatur /
/// Struktur, Impfung / Umformung. Всё сомнительное выводится списком на ручную проверку,
/// а не молча пропускается.
void _checkNearSoundalike(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    for (final d in lex.nearDistractors) {
      if (soundsAlike(lex.form, d)) continue;
      report.review(
        '${lex.conceptId}: "$d" не выглядит созвучным с "${lex.form}" '
        '(${soundalikeReport(lex.form, d)})',
      );
    }
  }
}

/// Размеры созвездий соответствуют ярусам. Размер накопительный: на A2 в
/// созвездии 48 звёзд, включая 24 с A1.
void _checkConstellationSizes(ContentSources sources, _Report report) {
  for (final name in sources.constellations) {
    final byTier = <String, int>{};
    for (final c in sources.concepts.values) {
      if (c.constellation != name) continue;
      byTier[c.tier] = (byTier[c.tier] ?? 0) + 1;
    }
    if (byTier.isEmpty) {
      report.error('созвездие $name: ни одного концепта');
      continue;
    }

    var cumulative = 0;
    for (final tier in tiers) {
      final added = byTier[tier];
      if (added == null) {
        // Ярус ещё не написан — это нормально, пока язык не запущен.
        continue;
      }
      cumulative += added;
      final expected = starsPerTier[tier]!;
      if (cumulative == expected) continue;

      final message =
          'созвездие $name, ярус $tier: $cumulative звёзд, ожидается $expected';
      // С незапущенного яруса полноты не требуем: он пишется постепенно и
      // блокировать им мерж бессмысленно.
      if (sources.launch.isLaunched(tier)) {
        report.error(message);
      } else {
        report.pending('$message (ярус не запущен)');
      }
    }
  }
}

/// Нет дублей форм внутри одного созвездия и яруса — иначе в круге появятся
/// два одинаковых варианта.
void _checkDuplicateForms(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  final seen = <String, String>{};
  for (final concept in sources.concepts.values) {
    final lex = byConcept[concept.id];
    if (lex == null) continue;
    final key = '${concept.constellation}/${concept.tier}/'
        '${lex.form.toLowerCase()}';
    final previous = seen[key];
    if (previous != null) {
      report.error(
        'форма "${lex.form}" повторяется в ${concept.constellation}/'
        '${concept.tier}: $previous и ${concept.id}',
      );
    }
    seen[key] = concept.id;
  }
}

/// Ответ фразы — это форма того слова, к которому фраза привязана.
///
/// Круг собирается из дистракторов концепта, а верным считается `answer`.
/// Если это разные слова, игрок видит варианты к одному слову, а угадать
/// должен другое — пройти такой круг честно нельзя. Склонение при этом
/// нормально: «Schmerzen» при лексеме «Schmerz» — та же лексема в
/// множественном, и допуск по длине это учитывает.
void _checkPhraseAnswers(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final phrase in sources.phrases) {
    for (final conceptId in phrase.conceptIds) {
      final lex = byConcept[conceptId];
      if (lex == null) continue;
      final form = lex.form;
      final answer = phrase.answer;
      if (answer == form) continue;

      final a = form.toLowerCase();
      final b = answer.toLowerCase();
      final shared = commonPrefix(a, b);
      final drift = (a.length - b.length).abs();
      // Словоформа сохраняет основу и меняет хвост: Kartoffel / Kartoffeln.
      // Другое слово либо теряет основу, либо резко меняет длину.
      if (shared >= a.length - 2 && drift <= 3) continue;

      report.error(
        'фраза ${phrase.id}: ответ "$answer" не форма слова "$form" '
        '(концепт $conceptId)',
      );
    }
  }
}

/// Немецкое множественное образуется от самого слова: суффикс, иногда умлаут,
/// иногда ничего. Оно не может быть множественным другого, более длинного
/// слова.
///
/// Проверка существует потому, что этот класс ошибок уже случался дважды и
/// оба раза был найден человеком, а не машиной. Само правило живёт в
/// `tool/morphology.dart` и покрыто тестом.
void _checkPluralMorphology(
  ContentSources sources,
  String lang,
  _Report report,
) {
  // Правило описывает немецкую морфологию и только её: в английском
  // множественное бывает внутри словосочетания («contract for work» →
  // «contracts for work»), и закрытый список суффиксов там неприменим.
  if (lang != 'de') return;

  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    final plural = lex.plural;
    if (plural == null) continue;
    if (isGermanPlural(lex.form, plural)) continue;

    // Частный и узнаваемый случай: субстантивированное прилагательное
    // записано в сильной форме, хотя рядом стоит определённый артикль.
    // «der Vorgesetzter» — так игра и покажет его на экране.
    if (isMisdeclinedAdjectivalNoun(lex.form, plural)) {
      report.error(
        '${lex.conceptId}: "${lex.article} ${lex.form}" — субстантивированное '
        'прилагательное склоняется слабо, нужна форма "$plural"',
      );
      continue;
    }

    report.error(
      '${lex.conceptId}: "$plural" не образуется от "${lex.form}" — '
      'это множественное другой лексемы; либо уберите поле, либо дайте '
      'настоящую форму',
    );
  }
}

/// У слова, которое бывает только во множественном, нет рода.
///
/// Артикль `die` во множественном одинаков для всех трёх родов, поэтому
/// соблазн записать `gender: f` велик — и он учит неправде: «Treuepunkte» это
/// множественное от «der Treuepunkt».
void _checkPluraleTantum(ContentSources sources, String lang, _Report report) {
  // Артикль `die` — немецкий признак; в языках без рода проверять нечего.
  if (lang != 'de') return;

  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    if (lex.plural != lex.form || lex.article != 'die') continue;
    if (lex.gender == null) continue;
    report.error(
      '${lex.conceptId}: "${lex.form}" — только множественное, '
      'род "${lex.gender}" здесь означает артикль, а не род леммы',
    );
  }
}

/// Дистрактор с заглавной буквы обязан быть существительным.
///
/// Проверяется по концовкам, которые в немецком бывают только у прилагательных
/// и наречий. Список короткий намеренно: `-schaft` содержит `-haft`, `-wert`
/// и `-bar` бывают у существительных (Nährwert, Nachbar), и широкий набор
/// давал бы полсотни ложных срабатываний вместо трёх настоящих.
void _checkDistractorCase(ContentSources sources, String lang, _Report report) {
  // Заглавная буква несёт смысл только там, где с неё пишут существительные.
  if (lang != 'de') return;

  const adjectiveEndings = ['los', 'weit', 'frei', 'sam', 'mäßig', 'voll'];
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    for (final d in [...lex.farDistractors, ...lex.nearDistractors]) {
      if (d.isEmpty || d[0].toLowerCase() == d[0]) continue;
      if (d.length <= 6) continue;
      final lower = d.toLowerCase();
      if (!adjectiveEndings.any(lower.endsWith)) continue;
      report.error(
        '${lex.conceptId}: дистрактор "$d" оканчивается как прилагательное, '
        'а записан с заглавной — такого существительного нет',
      );
    }
  }
}

/// Артикль и род не противоречат друг другу.
///
/// Ошибка тихая и дорогая: игрок заучивает род вместе со словом, и неверная
/// пара «die / n» учит его неправильно, ничем себя не выдавая. Проверяется
/// только там, где заданы оба поля.
void _checkArticleGender(ContentSources sources, String lang, _Report report) {
  const byArticle = <String, String>{'der': 'm', 'die': 'f', 'das': 'n'};
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  for (final lex in byConcept.values) {
    final article = lex.article;
    final gender = lex.gender;
    if (article == null || gender == null) continue;
    final expected = byArticle[article];
    if (expected == null || expected == gender) continue;
    report.error(
      '${lex.conceptId}: артикль "$article" не сходится с родом "$gender" '
      '(ожидается "$expected")',
    );
  }
}

/// Один и тот же дистрактор не повторяется в ярусе слишком часто.
///
/// Это не ошибка данных, а вопрос игры: слово, которое стоит вариантом у
/// пяти разных вопросов, игрок запоминает как «тот, который всегда неверный»,
/// и перестаёт читать варианты вообще.
void _checkDistractorVariety(
  ContentSources sources,
  String lang,
  _Report report,
) {
  const limit = 2;
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  final byTier = <String, Map<String, List<String>>>{};
  for (final concept in sources.concepts.values) {
    final lex = byConcept[concept.id];
    if (lex == null) continue;
    final tier = byTier.putIfAbsent(concept.tier, () => {});
    for (final d in [...lex.farDistractors, ...lex.nearDistractors]) {
      tier.putIfAbsent(d.toLowerCase(), () => []).add(concept.id);
    }
  }

  for (final entry in byTier.entries) {
    for (final d in entry.value.entries) {
      if (d.value.length <= limit) continue;
      report.review(
        'ярус ${entry.key}: дистрактор "${d.key}" встречается '
        '${d.value.length} раз (${d.value.take(3).join(", ")}…)',
      );
    }
  }
}

/// У фразы должен быть ровно один верный ответ.
///
/// Проверить это в общем виде нельзя — нужен смысл. Но один и притом самый
/// частый источник вторых верных ответов машина видит: варианты, у которых с
/// ответом общая вершина сложного слова. Stadtplan / Bauplan / Zeitplan,
/// Kindeswohl / Gemeinwohl, Projektphase / Testphase — общая вершина даёт
/// общий род, общее склонение и общую сочетаемость, поэтому такой вариант
/// встаёт в пропуск наравне с ответом.
///
/// Считается ровно тот набор, который соберёт `QuestionBuilder.buildBoss`:
/// `far` опорного концепта плюс соседи по созвездию и ярусу. Проверять другой
/// набор бессмысленно — игрок увидит этот.
void _checkPhraseAmbiguity(
  ContentSources sources,
  String lang,
  _Report report,
) {
  // Четыре буквы: -plan, -wohl, -zeit, -kosten. Три давали бы -ung и -ion,
  // то есть половину немецких отглагольных существительных.
  const headLength = 4;

  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  var drafted = 0;
  final byTier = <String, Map<String, List<String>>>{};
  for (final concept in sources.concepts.values) {
    final form = byConcept[concept.id]?.form;
    if (form == null) continue;
    byTier
        .putIfAbsent(concept.tier, () => {})
        .putIfAbsent(concept.constellation, () => [])
        .add(form);
  }

  for (final phrase in sources.phrases) {
    final anchor =
        phrase.conceptIds.isEmpty ? null : byConcept[phrase.conceptIds.first];
    final options = <String>[
      ...?anchor?.farDistractors,
      ...?byTier[phrase.tier]?[phrase.constellation],
    ];

    final answer = foldSpelling(phrase.answer);
    final clashing = options
        .map(foldSpelling)
        .where((o) => o != answer && commonSuffix(answer, o) >= headLength)
        .toSet();
    if (clashing.isEmpty) continue;

    final message =
        'фраза ${phrase.id}: вариант ${clashing.join(", ")} имеет ту же '
        'вершину, что ответ "${phrase.answer}", и может встать в тот же '
        'пропуск';
    // Как и с полнотой дистракторов: с запущенного яруса спрос полный, с
    // невычитанного — список на потом. Иначе проверка блокировала бы мерж за
    // работу, которая и не объявлена законченной.
    if (sources.launch.isLaunched(phrase.tier)) {
      report.error(message);
    } else {
      drafted++;
    }
  }

  if (drafted > 0) {
    report.pending(
      'у $drafted фраз незапущенных ярусов вариант делит вершину с ответом — '
      'разбирать при вычитке яруса',
    );
  }
}

/// Фразы ссылаются на существующие концепты, и ответ действительно
/// подставляется в шаблон.
void _checkPhrases(ContentSources sources, _Report report) {
  final ids = <String>{};
  for (final p in sources.phrases) {
    if (!ids.add(p.id)) report.error('фраза ${p.id}: дублирующийся id');

    for (final conceptId in p.conceptIds) {
      if (!sources.concepts.containsKey(conceptId)) {
        report.error('фраза ${p.id}: нет концепта $conceptId');
      }
    }
    if (!p.template.contains('{')) {
      report.error('фраза ${p.id}: в шаблоне нет слота {…}');
    }
  }
}

/// Набор калибровки покрывает все пять ярусов минимум по 30 позиций.
void _checkCalibration(ContentSources sources, String lang, _Report report) {
  final items = sources.calibration[lang];
  if (items == null || items.isEmpty) {
    // Считаем, из чего вообще можно собрать набор: 30 позиций на ярус
    // требуют примерно трёх созвездий, одного не хватает физически.
    final possible = <String, int>{};
    for (final c in sources.concepts.values) {
      possible[c.tier] = (possible[c.tier] ?? 0) + 1;
    }
    final shortage = sources.launch.launched
        .where((t) => (possible[t] ?? 0) < 30)
        .map((t) => '$t: ${possible[t] ?? 0} концептов')
        .toList();

    report.pending(
      shortage.isEmpty
          ? 'набор калибровки для $lang не написан'
          : 'набор калибровки для $lang не написан: на запущенных ярусах '
              'не хватает материала (${shortage.join(', ')}) — нужно '
              'минимум три созвездия на ярус',
    );
    return;
  }

  for (final tier in tiers) {
    final count = items.where((i) => i.tier == tier).length;
    if (count >= 30) continue;

    final message = 'калибровка $lang, ярус $tier: $count позиций из 30';
    if (sources.launch.isLaunched(tier)) {
      report.error(message);
    } else {
      report.pending('$message (ярус не запущен)');
    }
  }
  for (final item in items) {
    if (item.conceptId != null &&
        !sources.concepts.containsKey(item.conceptId)) {
      report.error('калибровка ${item.id}: нет концепта ${item.conceptId}');
    }
  }
}

/// У каждой лексемы и фразы языка изучения есть файл озвучки: концепт без
/// аудио не проходит валидацию, потому что звук верного ответа — часть ядра
/// игры.
///
/// Пока каталога озвучки нет вообще (до M4), проверка честно объявляется
/// пропущенной — а не тихо проходит.
void _checkAudio(
  ContentSources sources,
  String lang,
  Directory root,
  _Report report,
) {
  final audioDir = Directory('${root.path}/assets/audio/$lang');
  final manifestFile = File('${audioDir.path}/manifest.json');
  if (!manifestFile.existsSync()) {
    report.pending(
      'нет assets/audio/$lang/manifest.json — запустите '
      'dart run tool/synthesize_audio.dart --lang $lang',
    );
    return;
  }

  final Map<String, Object?> files;
  try {
    final json = jsonDecode(manifestFile.readAsStringSync())
        as Map<String, Object?>;
    files = json['files'] as Map<String, Object?>? ?? const {};
  } catch (e) {
    report.error('манифест озвучки не читается: $e');
    return;
  }

  /// Файл должен быть и в манифесте, и на диске: манифест из чужой ветки
  /// без файлов — ровно та ситуация, которую эта проверка ловит.
  bool present(String audioId) {
    final entry = files[audioId] as Map<String, Object?>?;
    if (entry == null) return false;
    final name = entry['file'] as String?;
    return name != null && File('${audioDir.path}/$name').existsSync();
  }

  final missing = <String>[];
  final missingDraft = <String>[];

  for (final lex in sources.lexemes[lang]?.values ?? const <LexemeSource>[]) {
    if (present(audioIdFor(lang, lex.form))) continue;
    final tier = sources.concepts[lex.conceptId]?.tier;
    (tier != null && sources.launch.isLaunched(tier) ? missing : missingDraft)
        .add(lex.form);
  }
  for (final phrase in sources.phrases) {
    if (present(audioIdForPhrase(lang, phrase.id))) continue;
    (sources.launch.isLaunched(phrase.tier) ? missing : missingDraft)
        .add(phrase.id);
  }

  if (missing.isNotEmpty) {
    // Концепт без озвучки не проходит валидацию: звук верного ответа — часть
    // ядра игры, а не украшение.
    report.error(
      'нет озвучки для ${missing.length} позиций запущенных ярусов '
      '(${_head(missing)})',
    );
  }
  if (missingDraft.isNotEmpty) {
    report.pending(
      'нет озвучки для ${missingDraft.length} позиций незапущенных ярусов',
    );
  }
}

/// Ярус не может быть одновременно запущенным и черновым, а запущенный
/// обязан иметь хоть какой-то контент.
void _checkLaunchPolicy(ContentSources sources, _Report report) {
  final both = sources.launch.launched.intersection(sources.launch.drafted);
  if (both.isNotEmpty) {
    report.error(
      'ярусы ${both.join(', ')} помечены и запущенными, и черновыми',
    );
  }

  for (final tier in sources.launch.launched) {
    if (!tiers.contains(tier)) {
      report.error('в launch.yaml неизвестный ярус "$tier"');
      continue;
    }
    final onTier = sources.concepts.values.where((c) => c.tier == tier);
    if (onTier.isEmpty) {
      report.error('ярус $tier запущен, но контента на нём нет');
      continue;
    }

    // Вычитка обязана покрывать ярус целиком.
    //
    // Именно здесь правило и протекало: `reviewers` был свободным текстом,
    // созвездий стало девять вместо пяти, а запись осталась прежней. Ярус
    // считался запущенным, потому что так было написано, — а не потому, что
    // его прочитали.
    final review = sources.launch.reviews[tier];
    if (review == null || review.by.isEmpty) {
      report.error('ярус $tier запущен, но в launch.yaml нет записи о вычитке');
      continue;
    }

    final present = {for (final c in onTier) c.constellation};
    final missing = present.difference(review.constellations).toList()..sort();
    if (missing.isNotEmpty) {
      report.error(
        'ярус $tier запущен, но вычитка не покрывает созвездия '
        '${missing.join(', ')} — либо вычитать, либо снять ярус с запуска',
      );
    }

    final extra = review.constellations.difference(present).toList()..sort();
    if (extra.isNotEmpty) {
      report.error(
        'ярус $tier: в вычитке значатся созвездия ${extra.join(', ')}, '
        'которых на ярусе нет',
      );
    }
  }
}

class _Report {
  final List<String> errors = [];

  /// Сомнительное, но не блокирующее — на ручную вычитку.
  final List<String> reviews = [];

  /// Осознанно не сделанное: приходит с будущей вехой.
  final List<String> pendings = [];

  void error(String message) => errors.add(message);
  void review(String message) => reviews.add(message);
  void pending(String message) => pendings.add(message);

  void print(String lang) {
    for (final p in pendings) {
      stdout.writeln('… $p');
    }
    for (final r in reviews) {
      stdout.writeln('? $r');
    }
    for (final e in errors) {
      stderr.writeln('✗ $e');
    }
    if (errors.isEmpty) {
      stdout.writeln(
        '✓ контент $lang валиден'
        '${reviews.isEmpty ? '' : ' (${reviews.length} на ручную проверку)'}',
      );
    } else {
      stderr.writeln('✗ ошибок: ${errors.length}');
    }
  }
}




String _head(List<String> items, [int limit = 5]) {
  final shown = items.take(limit).join(', ');
  return items.length > limit ? '$shown, …' : shown;
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  final prefixed = args.firstWhere(
    (a) => a.startsWith('$name='),
    orElse: () => '',
  );
  return prefixed.isEmpty ? null : prefixed.substring(name.length + 1);
}
