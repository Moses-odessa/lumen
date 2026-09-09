// Проверки полноты и качества контента. Запускается в CI, падение блокирует
// мерж (docs/CONTENT_PIPELINE.md).
//
//   dart run tool/validate_content.dart            # все языки изучения
//   dart run tool/validate_content.dart --lang de  # только немецкий
//
// Без флага проверяются **все** языки, объявившие себя языками изучения.
// Так и должно быть, и это исправление конкретной дыры: CI вызывал валидатор
// с жёстко прописанным `--lang de`, а в репозитории лежал второй язык
// изучения — английский, — который никто никогда не проверял. В
// assets/content/en.db из-за этого уехали немецкие фразы с пометкой
// lang="en": 397 ошибок, которые валидатор находил сразу, как только его об
// этом спрашивали. Спросить было некому.

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'content_schema.dart';
import 'compound.dart';
import 'content_sources.dart';
import 'morphology.dart';
import 'phonetics.dart';
import 'translation_lock.dart';
import 'word_lists.dart';

Future<void> main(List<String> args) async {
  final requested = _argValue(args, '--lang');
  final root = Directory('${Directory.current.path}/content');

  final langs = requested != null ? [requested] : _targetLanguages(root);
  if (langs.isEmpty) {
    stderr.writeln('✗ в content/lang/ нет ни одного языка изучения');
    exitCode = 1;
    return;
  }

  var failed = false;
  for (final lang in langs) {
    if (langs.length > 1) stdout.writeln('── $lang ──');
    if (!_validate(root, lang)) failed = true;
  }
  if (failed) exitCode = 1;
}

/// Языки, объявившие `role: target`. Читаются из каталога, а не из списка:
/// список в CI и был тем местом, где потерялся второй язык изучения.
List<String> _targetLanguages(Directory root) {
  try {
    final sources = ContentSources.load(root, lang: defaultTargetLang);
    final targets = sources.languages.values
        .where((l) => l.isTarget)
        .map((l) => l.code)
        .toList()
      ..sort();
    return targets;
  } on ContentSourceException catch (e) {
    stderr.writeln('✗ исходники: ${e.message}');
    return const [];
  }
}

/// Прогон всех проверок для одного языка изучения. `true` — ошибок нет.
bool _validate(Directory root, String lang) {
  final ContentSources sources;
  try {
    sources = ContentSources.load(root, lang: lang);
  } on ContentSourceException catch (e) {
    stderr.writeln('✗ исходники: ${e.message}');
    return false;
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
  _checkDraftedConcepts(sources, report);
  _checkWordExistence(sources, lang, report);
  _checkLanguages(sources, report);
  _checkLexemeCoverage(sources, report);
  _checkPhraseTranslations(sources, report);
  _checkFunctionWords(sources, report);
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
  _checkPhraseRegister(sources, report);
  _checkDistractorVariety(sources, lang, report);
  _checkPhrases(sources, report);
  _checkCalibration(sources, lang, report);

  report.print(lang);
  return report.errors.isEmpty;
}

/// Черновые концепты: сколько их и где.
///
/// Печатается всегда, потому что это главное число про готовность контента, и
/// оно не должно требовать запроса. Черновой концепт лежит в базе, но в игру
/// не идёт — и разница между «916 концептов» и «916 концептов, из них 52
/// вычитано» слишком велика, чтобы её приходилось вычислять.
void _checkDraftedConcepts(ContentSources sources, _Report report) {
  final total = sources.concepts.length;
  final drafted = sources.concepts.values.where((c) => c.draft).length;
  if (drafted == 0) return;

  report.note(
    'концептов $total, из них черновых $drafted '
    '(${(100 * drafted / total).round()} %) — в игру не идут',
  );

  for (final tier in tiers) {
    final onTier = sources.draftedOn(tier);
    if (onTier == 0) continue;
    if (!sources.launch.isLaunched(tier)) continue;
    // Черновое на запущенном ярусе — законно и ожидаемо: словник кладёт
    // слова на ярусы независимо от того, что уже запущено. Но видеть это
    // нужно: именно здесь измеряется, сколько осталось вычитать.
    report.note('ярус $tier запущен, и на нём $onTier черновых концептов');
  }
}

/// Существование форм: положительный список и отрицательный.
///
/// **Ни одна форма из отрицательного списка не проходит.** Это единственная
/// часть проверки, которая работает без словаря языка: доказать
/// существование она не может, но делает невозможным возврат — найденная
/// однажды выдумка не вернётся в контент никогда.
///
/// Положительный список включает вторую половину проверки: каждая форма
/// обязана либо лежать в нём, либо раскладываться на его слова. Файла в
/// проекте пока нет, и проверка честно об этом сообщает, а не молчит.
///
/// Почему не сгенерировать словарь моделью: список лемм, произведённый тем
/// же способом, что произвёл контент, содержит те же выдумки — и проверка
/// начнёт **подтверждать** несуществующие слова. Это хуже отсутствия
/// проверки: открытый вопрос превращается в закрытый и неверный.
void _checkWordExistence(
  ContentSources sources,
  String lang,
  _Report report,
) {
  final root = '${Directory.current.path}/content';
  final banned = readNonWordReasons(
    File('${wordListDirectory(root).path}/$lang-nonwords.txt'),
  );
  final dictionary = readDictionary(root, lang);

  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  // Все формы языка, которые игрок может увидеть: леммы, множественные
  // числа, дистракторы и ответы фраз.
  final forms = <String, String>{};
  void note(String form, String where) {
    if (form.trim().isEmpty) return;
    forms.putIfAbsent(form, () => where);
  }

  for (final lex in byConcept.values) {
    note(lex.form, lex.conceptId);
    if (lex.plural != null) note(lex.plural!, '${lex.conceptId} (мн. ч.)');
    for (final d in lex.farDistractors) {
      note(d, '${lex.conceptId} (far)');
    }
    for (final d in lex.nearDistractors) {
      note(d, '${lex.conceptId} (near)');
    }
  }
  for (final phrase in sources.phrases) {
    for (final answer in phrase.answers) {
      note(answer, phrase.id);
    }
  }

  // ── отрицательный список: работает всегда ───────────────────────────────
  for (final entry in forms.entries) {
    final reason = banned[entry.key.toLowerCase()];
    if (reason == null) continue;
    report.error(
      '${entry.value}: форма "${entry.key}" в отрицательном списке — '
      '${reason.isEmpty ? "установлено, что её не существует" : reason}',
    );
  }

  // ── положительный список: работает, когда он есть ───────────────────────
  if (dictionary.isEmpty) {
    report.pending(
      'словаря $lang нет (content/dictionaries/$lang.txt) — существование '
      '${forms.length} форм не проверено. Отрицательный список работает: '
      '${banned.length} запрещённых форм.',
    );
    return;
  }

  final unknown = <String>[];
  for (final entry in forms.entries) {
    if (splitsIntoKnown(entry.key, dictionary)) continue;
    unknown.add('${entry.key} (${entry.value})');
  }
  if (unknown.isEmpty) {
    report.note('все ${forms.length} форм $lang есть в словаре или '
        'раскладываются на его слова');
    return;
  }

  // Незнакомая форма — вопрос человеку, а не приговор: словарь не содержит
  // всех составных слов немецкого, и разбор их не всегда находит.
  report.review(
    'формы $lang не найдены в словаре (${unknown.length} из '
    '${forms.length}): ${_head(unknown, 10)}',
  );
}

/// Языки объявили о себе непротиворечиво, и играть вообще есть чем.
///
/// Список языков больше не константа в коде — он равен содержимому
/// `content/lang/`. Поэтому проверять приходится то, что раньше гарантировала
/// компиляция: что язык изучения существует, что хоть один родной язык
/// запущен и что собираемая база собирается для языка изучения, а не для
/// языка подсказок.
void _checkLanguages(ContentSources sources, _Report report) {
  final target = sources.languages[sources.targetLang];
  if (target == null) {
    report.error(
      'нет языка "${sources.targetLang}" в content/lang/ — собирать нечего',
    );
    return;
  }
  if (!target.isTarget) {
    report.error(
      'язык ${target.code} объявлен role="${target.role}", а база собирается '
      'для него как для языка изучения',
    );
  }

  // Роль языка и запись о запуске обязаны говорить одно и то же.
  //
  // Расхождение здесь стоило проекту отгруженного бага. Английский был
  // объявлен в launch.yaml языком изучения с запущенным A0, и сборщик
  // штамповал `--lang en` на строки фраз — а фразы немецкие. В
  // assets/content/en.db лежали немецкие шаблоны с пометкой lang="en", и
  // валидатор находил 397 ошибок ровно в тот момент, когда его об этом
  // спрашивали. Никто не спрашивал: CI собирал только de.
  final launchFile = File('${Directory.current.path}/content/launch.yaml');
  if (launchFile.existsSync()) {
    final declared = _languagesInLaunchFile(launchFile);
    for (final code in declared) {
      final language = sources.languages[code];
      if (language == null) {
        report.error(
          'launch.yaml объявляет ярусы языка "$code", которого нет в '
          'content/lang/',
        );
      } else if (!language.isTarget) {
        report.error(
          'launch.yaml объявляет ярусы языка "$code", а сам он объявлен '
          'role="${language.role}". Ярусы бывают только у языка изучения: '
          'либо уберите секцию, либо поменяйте роль.',
        );
      }
    }
    for (final language in sources.languages.values) {
      if (!language.isTarget || declared.contains(language.code)) continue;
      report.error(
        'язык ${language.code} объявлен языком изучения, но секции в '
        'launch.yaml у него нет — значит ни одна проверка запуска на него не '
        'действует, и это молча',
      );
    }
  }

  final natives = sources.languages.values.where((l) => l.isNative).toList();
  if (natives.isEmpty) {
    report.error(
      'ни один язык не объявлен role="native" — подсказывать будет нечем',
    );
  }
  if (natives.isNotEmpty && !natives.any((l) => l.isLaunched)) {
    report.pending(
      'ни один родной язык не объявлен launched: играть можно, но ни одна '
      'пара не считается готовой',
    );
  }
}

/// Полнота лексем.
///
/// Требуется от `launched`, у `draft` только считается и печатается. Это и
/// есть механизм добавления языка: файл ложится в каталог со `status: draft`,
/// валидатор говорит, сколько он покрывает, и ничего не блокирует. Концепт
/// без лексемы в одном из языков пары планировщик просто не возьмёт — игрок
/// увидит меньше слов, а не чужое слово вместо своего.
void _checkLexemeCoverage(ContentSources sources, _Report report) {
  final total = sources.concepts.length;

  for (final language in sources.languages.values) {
    final missing = sources.concepts.keys
        .where((id) => !language.lexemes.containsKey(id))
        .toList();
    if (missing.isEmpty) continue;

    if (!language.isLaunched) {
      report.pending(
        'язык ${language.code} (draft): лексем '
        '${language.lexemes.length}/$total, не хватает ${missing.length}',
      );
      continue;
    }

    // У запущенного языка изучения спрос по ярусам: черновой ярус не обязан
    // быть полным, а запущенный обязан.
    final blocking = missing
        .where((id) => !sources.concepts[id]!.draft)
        .where((id) =>
            !language.isTarget ||
            sources.launch.isLaunched(sources.concepts[id]!.tier))
        .toList();

    if (blocking.isEmpty) {
      report.pending(
        'язык ${language.code}: лексем ${language.lexemes.length}/$total — '
        'не хватает только на незапущенных ярусах',
      );
      continue;
    }

    report.error(
      'язык ${language.code} объявлен launched, но нет лексем для '
      '${blocking.length} концептов (${_head(blocking)})',
    );
  }
}

/// Переводы фраз: без них механика «заполни пропуски» нечем закончить.
///
/// Фраза заполняется, проигрывается — и под ней должен проявиться перевод.
/// Это не украшение: пропуск, заполненный верно, но так и не объяснённый, не
/// учит ничему, кроме подбора формы.
void _checkPhraseTranslations(ContentSources sources, _Report report) {
  final launchedPhrases = sources.phrases
      .where((p) => sources.launch.isLaunched(p.tier))
      .map((p) => p.id)
      .toSet();
  final all = {for (final p in sources.phrases) p.id};

  for (final language in sources.languages.values) {
    if (!language.isNative) continue;

    final unknown = language.phraseTranslations.keys
        .where((id) => !all.contains(id))
        .toList();
    if (unknown.isNotEmpty) {
      report.error(
        'язык ${language.code}: перевод фразы, которой нет — '
        '${_head(unknown)}',
      );
    }

    _checkTranslationFreshness(sources, language, report);

    final missing = launchedPhrases
        .where((id) => !language.phraseTranslations.containsKey(id))
        .toList()
      ..sort();
    if (missing.isEmpty) continue;

    final message = 'язык ${language.code}: нет перевода у ${missing.length} '
        'фраз запущенных ярусов (${_head(missing)})';
    if (language.isLaunched) {
      report.error(message);
    } else {
      report.pending('$message — язык draft');
    }
  }
}

/// Перевод сделан с того текста, который лежит сейчас.
///
/// Отсутствующий перевод виден: его нет. Устаревший не виден никак — он на
/// месте и выглядит рабочим. Поэтому рядом с переводами лежит замок
/// `content/lang/<код>.lock` с отпечатком немецкого предложения на момент
/// перевода, и расхождение означает, что фразу правили после.
///
/// Ошибка не гипотетическая. В этом проекте 432 украинских перевода были
/// сделаны, а следующим действием изменились двадцать семь немецких фраз, и
/// одна из них — «Die Rechnungsadresse steht auf der Rechnung» → «… kann von
/// der Lieferadresse abweichen» — сменила смысл целиком. Перевод остался
/// прежним, и ни одна проверка на это не указала.
void _checkTranslationFreshness(
  ContentSources sources,
  LanguageSource language,
  _Report report,
) {
  final lock = readTranslationLock(
    translationLockFile('${Directory.current.path}/content', language.code),
  );
  if (lock.isEmpty) {
    if (language.phraseTranslations.isNotEmpty) {
      report.pending(
        'язык ${language.code}: замка переводов нет — '
        'dart run tool/lock_translations.dart --lang ${language.code}',
      );
    }
    return;
  }

  final byId = {for (final p in sources.phrases) p.id: p};
  final stale = <String>[];
  final unlocked = <String>[];

  for (final id in language.phraseTranslations.keys) {
    final phrase = byId[id];
    if (phrase == null) continue;
    final locked = lock[id];
    if (locked == null) {
      unlocked.add(id);
    } else if (locked != phraseFingerprint(phrase)) {
      stale.add(id);
    }
  }

  if (unlocked.isNotEmpty) {
    report.pending(
      'язык ${language.code}: ${unlocked.length} переводов без записи в '
      'замке (${_head(unlocked..sort())})',
    );
  }
  if (stale.isEmpty) return;

  final message = 'язык ${language.code}: у ${stale.length} фраз немецкий '
      'текст изменился после перевода — перевод описывает не тот текст '
      '(${_head(stale..sort())})';
  if (language.isLaunched) {
    report.error(message);
  } else {
    report.pending('$message — язык draft');
  }
}

/// Служебное слово живёт только во фразе.
///
/// У `sich` нет ни перевода одним словом, ни осмысленного набора вариантов:
/// круг из него собрать нельзя. Поэтому с таких концептов не требуется
/// дистракторов — но требуется другое: если служебное слово не входит ни в
/// одну фразу, оно недостижимо. Это не звезда и не задание, а строка в базе,
/// которая никогда не покажется игроку.
void _checkFunctionWords(ContentSources sources, _Report report) {
  final inPhrases = <String>{
    for (final p in sources.phrases) ...p.conceptIds,
  };

  final unreachable = <String>[];
  for (final concept in sources.concepts.values) {
    if (!concept.isFunctionWord) continue;
    if (inPhrases.contains(concept.id)) continue;
    unreachable.add(concept.id);
  }
  if (unreachable.isEmpty) return;

  final blocking = unreachable
      .where((id) => !sources.concepts[id]!.draft)
      .where((id) => sources.launch.isLaunched(sources.concepts[id]!.tier))
      .toList();
  if (blocking.isNotEmpty) {
    report.error(
      'служебные слова запущенного яруса не входят ни в одну фразу и потому '
      'недостижимы: ${_head(blocking)}',
    );
  }
  final drafted = unreachable.length - blocking.length;
  if (drafted > 0) {
    report.pending(
      '$drafted служебных слов незапущенных ярусов пока не входят ни в одну '
      'фразу — им нужна фраза, а не дистракторы',
    );
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
    final concept = sources.concepts[lex.conceptId];
    // Со служебного слова дистракторов не требуется: круга из него нет, а
    // выдумывать «неверные варианты» к `sich` — занятие без смысла и без
    // конца. Достижимость служебных слов проверяет _checkFunctionWords.
    if (concept != null && concept.isFunctionWord) continue;

    final tier = concept?.tier;
    // Черновой концепт в игру не идёт, и требовать от него полноты незачем —
    // даже если ярус, на который он лёг, запущен.
    final launched = tier != null &&
        sources.launch.isLaunched(tier) &&
        !(concept?.draft ?? false);

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

/// Созвездие, появившееся на карте, обязано быть созвездием, а не точкой.
///
/// Раньше здесь требовалось точное совпадение с накопительными 12/24/48/72/96.
/// Это правило годилось для девяти тем, написанных под него, и провалилось бы
/// на словнике из 6000 лемм: у «денег» и «общества» на A0 по одному слову, и
/// дотягивать их до двенадцати значило бы придумывать A0-лексику там, где её
/// нет, — то есть портить содержание ради формы.
///
/// Порог вместо равенства. Тема ждёт того яруса, на котором ей есть что
/// показать, и прогрессия из этого получается сама. Ошибка теперь одна и
/// осмысленная: созвездие показано игроку, а звёзд в нём меньше порога.
void _checkConstellationSizes(ContentSources sources, _Report report) {
  final opensAt = <String, String>{};

  for (final name in sources.constellations) {
    final byTier = <String, int>{};
    for (final c in sources.playableConcepts) {
      if (c.constellation != name) continue;
      byTier[c.tier] = (byTier[c.tier] ?? 0) + 1;
    }
    if (byTier.isEmpty) {
      // Тема, написанная целиком в черновике, — законное промежуточное
      // состояние: ровно его и означает `draft`. Ошибкой это было бы, если
      // бы файл темы был пуст, — тогда её действительно нет.
      final written =
          sources.concepts.values.where((c) => c.constellation == name).length;
      if (written == 0) {
        report.error('созвездие $name: файл темы есть, а концептов в нём нет');
      } else {
        report.pending(
          'созвездие $name: все $written концептов черновые — тема написана, '
          'но не вычитана',
        );
      }
      continue;
    }

    var cumulative = 0;
    String? opened;
    for (final tier in tiers) {
      cumulative += byTier[tier] ?? 0;
      if (opened == null && cumulative >= minStarsForConstellation) {
        opened = tier;
        opensAt[name] = tier;
      }
      if (opened == null) continue;
      // Ярус, на котором созвездие уже видно, а звёзд стало меньше порога,
      // невозможен: накопительный размер только растёт. Проверять тут нечего
      // — важно другое, ниже.
    }

    if (opened == null) {
      final message = 'созвездие $name: за все ярусы набралось $cumulative '
          'звёзд, порог появления — $minStarsForConstellation';
      // Созвездие, которое не открывается никогда, — это либо недописанная
      // тема, либо тема, которой в курсе не место. Ошибка только если её
      // ярусы объявлены запущенными.
      final launched = tiers
          .where((t) => (byTier[t] ?? 0) > 0)
          .any(sources.launch.isLaunched);
      if (launched) {
        report.error(message);
      } else {
        report.pending('$message (ярусы не запущены)');
      }
    }
  }

  // Что открывается на каком ярусе — печатается всегда: это форма курса, и
  // видеть её при каждой сборке полезнее, чем считать вручную.
  final byTier = <String, List<String>>{};
  for (final e in opensAt.entries) {
    byTier.putIfAbsent(e.value, () => []).add(e.key);
  }
  for (final tier in tiers) {
    final names = byTier[tier];
    if (names == null) continue;
    names.sort();
    report.note('ярус $tier открывает созвездия: ${names.join(', ')}');
  }
}

/// Нет дублей форм внутри одного созвездия и яруса — иначе в круге появятся
/// два одинаковых варианта.
///
/// Регистр не различается, и это не небрежность. Соседи по созвездию и ярусу
/// — резервный источник вариантов круга, а «essen» и «Essen» звучат
/// одинаково: в механике «прослушай и выбери» такой круг не проходится
/// честно, сколько бы заглавных букв в нём ни было.
///
/// У черновых слов это замечание, а не ошибка: пара «глагол и
/// существительное от него» — обычное немецкое явление, и решать, какое из
/// двух слов остаётся звездой, должна вычитка. В отгруженном контенте — уже
/// ошибка: там решение принято.
void _checkDuplicateForms(ContentSources sources, String lang, _Report report) {
  final byConcept = sources.lexemes[lang];
  if (byConcept == null) return;

  final seen = <String, ConceptSource>{};
  for (final concept in sources.concepts.values) {
    final lex = byConcept[concept.id];
    if (lex == null) continue;
    final key = '${concept.constellation}/${concept.tier}/'
        '${lex.form.toLowerCase()}';
    final previous = seen[key];
    if (previous != null) {
      final message = 'форма "${lex.form}" повторяется в '
          '${concept.constellation}/${concept.tier}: '
          '${previous.id} и ${concept.id}';
      if (previous.draft || concept.draft) {
        report.review('$message (черновик — решает вычитка)');
      } else {
        report.error(message);
      }
    }
    seen[key] = concept;
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
    final forms = <String, String>{
      for (final id in phrase.conceptIds)
        if (byConcept[id] != null) id: byConcept[id]!.form,
    };
    if (forms.isEmpty) continue;

    // Когда пропусков и концептов одинаково, они соответствуют друг другу по
    // порядку, и это можно проверить точно. Когда нет — проверяем слабее:
    // каждый ответ обязан быть формой хоть одного из привязанных слов.
    final pairwise = phrase.answers.length == phrase.conceptIds.length;

    for (var i = 0; i < phrase.answers.length; i++) {
      final answer = phrase.answers[i];
      final candidates = pairwise
          ? <String, String>{
              phrase.conceptIds[i]:
                  forms[phrase.conceptIds[i]] ?? phrase.conceptIds[i],
            }
          : forms;

      if (candidates.values.any((form) => _isFormOf(answer, form))) continue;

      report.error(
        'фраза ${phrase.id}, пропуск ${i + 1}: ответ "$answer" не форма '
        'слова ${candidates.values.map((f) => '"$f"').join(" / ")} '
        '(${candidates.keys.join(", ")})',
      );
    }

    if (!pairwise && phrase.answers.length > 1) {
      report.review(
        'фраза ${phrase.id}: ${phrase.answers.length} пропусков и '
        '${phrase.conceptIds.length} концептов — соответствие по порядку не '
        'проверить, перечислите концепты в порядке пропусков',
      );
    }
  }
}

/// Ответ — словоформа этого слова, а не другое слово.
///
/// Словоформа сохраняет основу и меняет хвост: Kartoffel / Kartoffeln. Другое
/// слово либо теряет основу, либо резко меняет длину.
bool _isFormOf(String answer, String form) {
  if (answer == form) return true;
  final a = form.toLowerCase();
  final b = answer.toLowerCase();
  return commonPrefix(a, b) >= a.length - 2 && (a.length - b.length).abs() <= 3;
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

/// Немецкие суффиксы образования существительных.
///
/// Их приходится снимать перед сравнением окончаний, иначе проверка на общую
/// вершину сложного слова превращается в проверку на «оба слова абстрактные».
/// На конкретной лексике A0–A2 это было незаметно, на B1 стало очевидно:
/// `Zuständigkeit` и `Öffentlichkeit` делят `keit`, `Infektion` и `Operation`
/// делят `tion` — и ни в одном случае это не общая вершина, а всего лишь
/// один и тот же способ сделать из слова существительное.
const _derivationalEndings = [
  'ierung', 'schaft', 'igkeit', 'lichkeit', 'ismus', 'ität', 'keit', 'heit',
  'ung', 'tion', 'sion', 'nis', 'tum', 'anz', 'enz', 'ling', 'chen', 'lein',
];

/// Слово без суффикса образования: `Überweisung` → `überweis`.
String _withoutDerivation(String word) {
  final folded = foldSpelling(word);
  for (final ending in _derivationalEndings) {
    // Оставляем не меньше трёх букв основы: иначе от короткого слова вроде
    // «Union» не останется ничего и оно совпадёт со всем подряд.
    if (folded.endsWith(ending) && folded.length - ending.length >= 3) {
      return folded.substring(0, folded.length - ending.length);
    }
  }
  return folded;
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
  // Четыре буквы: -plan, -wohl, -zeit, -kosten.
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

    // Свои варианты слота вытесняют добор соседями: когда для пропуска
    // выписаны неверные слова, игрок увидит именно их, и проверять надо их.
    final clashing = <String>{};
    for (var slot = 0; slot < phrase.answers.length; slot++) {
      final own = phrase.optionsFor(slot);
      final options = own.isNotEmpty
          ? own
          : <String>[
              ...?anchor?.farDistractors,
              ...?byTier[phrase.tier]?[phrase.constellation],
            ];

      final expected = phrase.answers[slot];
      final stem = _withoutDerivation(expected);
      clashing.addAll(options
          .where((o) => foldSpelling(o) != foldSpelling(expected))
          .where((o) => commonSuffix(stem, _withoutDerivation(o)) >= headLength)
          .map(foldSpelling));
    }

    if (clashing.isEmpty) {
      // Отметка осталась от прежней редакции фразы: она больше ничего не
      // прикрывает и вводит в заблуждение следующего читающего.
      if (phrase.ambiguityReviewed) {
        report.review(
          'фраза ${phrase.id}: пометка «ambiguity: reviewed» лишняя — '
          'вариантов с той же вершиной больше нет',
        );
      }
      continue;
    }
    if (phrase.ambiguityReviewed) continue;

    final message =
        'фраза ${phrase.id}: вариант ${clashing.join(", ")} имеет ту же '
        'вершину, что ответ ${phrase.answers.map((a) => '"$a"').join(" / ")}, '
        'и может встать в тот же пропуск';
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

/// `register: formal` означает обращение на Sie — и ничего больше.
///
/// Определение нужно было выбрать: в docs/CONTENT_PIPELINE.md поле значилось
/// как «необязательно: formal | casual», без объяснения, и данные разошлись.
/// «Nehmen Sie die Treppe» стояло casual, «Die Frist ist am Freitag» —
/// formal, хотя вежливой формы там нет вовсе.
///
/// Выбрано грамматическое значение, потому что игрок видит эту пометку как
/// подсказку и должен по ней что-то уметь. Отличить Sie от du он умеет
/// проверяемо; угадать, насколько ситуация «официальная», — нет.
void _checkPhraseRegister(ContentSources sources, _Report report) {
  // Вежливая форма узнаётся по местоимению: Sie, Ihnen, Ihr/Ihre/Ihren…
  final polite = RegExp(r'\b(Sie|Ihnen|Ihr|Ihre|Ihrem|Ihren|Ihrer|Ihres)\b');
  var drafted = 0;

  for (final phrase in sources.phrases) {
    final register = phrase.register;
    if (register == null) continue;
    if (register != 'formal' && register != 'casual') {
      report.error('фраза ${phrase.id}: регистр "$register" — нужен '
          'formal или casual');
      continue;
    }

    final hasPolite = polite.hasMatch(phrase.template);
    if (hasPolite == (register == 'formal')) continue;

    final message = hasPolite
        ? 'фраза ${phrase.id}: обращение на Sie, а помечена casual'
        : 'фраза ${phrase.id}: помечена formal, но вежливой формы в ней нет';
    if (sources.launch.isLaunched(phrase.tier)) {
      report.error(message);
    } else {
      drafted++;
    }
  }

  if (drafted > 0) {
    report.pending(
      'у $drafted фраз незапущенных ярусов пометка регистра не сходится с '
      'формой обращения',
    );
  }
}

/// Фразы ссылаются на существующие концепты, шаблон имеет пропуски, и ответ
/// в самом шаблоне не подсказан.
void _checkPhrases(ContentSources sources, _Report report) {
  final ids = <String>{};
  for (final p in sources.phrases) {
    if (!ids.add(p.id)) report.error('фраза ${p.id}: дублирующийся id');

    for (final conceptId in p.conceptIds) {
      if (!sources.concepts.containsKey(conceptId)) {
        report.error('фраза ${p.id}: нет концепта $conceptId');
      }
    }
    if (p.conceptIds.isEmpty) {
      report.error(
        'фраза ${p.id}: не привязана ни к одному концепту — такая фраза не '
        'зажигает ни одной звезды и не попадает ни в один уровень',
      );
    }
    if (phraseSlotCount(p.template) == 0) {
      report.error('фраза ${p.id}: в шаблоне нет слота {…}');
    }

    // Ответ, стоящий в шаблоне открытым текстом, превращает пропуск в
    // упражнение на списывание. Проверяется без учёта регистра, но целыми
    // словами: «Ich habe Hunger und {hunger}» — ошибка, а «Handy» внутри
    // «Handynummer» — нет.
    for (final answer in p.answers) {
      if (answer.length < 4) continue;
      final visible = phraseWithGaps(p.template);
      final word = RegExp(
        r'(?<![\p{L}])' + RegExp.escape(answer) + r'(?![\p{L}])',
        caseSensitive: false,
        unicode: true,
      );
      if (!word.hasMatch(visible)) continue;
      report.error(
        'фраза ${p.id}: ответ "$answer" стоит в шаблоне открытым текстом',
      );
    }

    // Пустой слот в собранном предложении означает, что шаблон и ответы
    // разошлись, а это игрок увидит как «…» посреди фразы.
    if (phraseSpeech(p.template, p.answers).contains('…')) {
      report.error(
        'фраза ${p.id}: пропусков в шаблоне больше, чем ответов',
      );
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
    // Черновые концепты в состав яруса не входят.
    //
    // Ярус запущен — значит, прочитан. Импортированное и невычитанное слово
    // в игру не идёт (сборка его не отгружает), поэтому требовать вычитки от
    // него нельзя: иначе импорт словника снимал бы с запуска уже прочитанный
    // A0 за то, что рядом с ним положили черновик.
    final onTier =
        sources.concepts.values.where((c) => c.tier == tier && !c.draft);
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

    _checkReviewPasses(sources, tier, review, report);
  }
}

/// Проходы вычитки: сколько их, чем читали и тот ли текст читали.
///
/// Правило записано в PLAN.md, «Вычитка»: не меньше двух проходов **разными**
/// моделями, и запись несёт отпечаток содержимого яруса. Второе важнее
/// первого. Отсутствующую проверку видно — её нет; устаревшая выглядит
/// рабочей, и отличить её от свежей без отпечатка нечем.
///
/// Ограничение названо там же и здесь не забыто: две модели обучены на
/// пересекающихся данных и ошибаются согласованно. От этого страхует не
/// второй проход, а словарь языка, которого у проекта пока нет.
void _checkReviewPasses(
  ContentSources sources,
  String tier,
  TierReview review,
  _Report report,
) {
  const requiredModels = 2;
  final actual = sources.tierHash(tier);

  if (review.passes.isEmpty) {
    // Ярусы, вычитанные до появления этого правила, записей о проходах не
    // имеют. Требовать их задним числом значило бы снять с запуска то, что
    // прочитано, — поэтому это отложенное, а не ошибка.
    report.pending(
      'ярус $tier запущен без записей о проходах вычитки — добавить passes '
      'с model, at и content_hash: $actual',
    );
    return;
  }

  if (review.distinctModels < requiredModels) {
    report.error(
      'ярус $tier: проходов вычитки ${review.passes.length}, но разных '
      'моделей ${review.distinctModels} — нужно $requiredModels. Два прогона '
      'одной моделью это один взгляд, повторённый дважды.',
    );
  }

  final stale = review.passes
      .where((p) => p.contentHash.isNotEmpty && p.contentHash != actual)
      .toList();
  if (stale.isNotEmpty) {
    report.error(
      'ярус $tier: ${stale.length} из ${review.passes.length} проходов '
      'описывают другой текст (в записи '
      '${stale.map((p) => p.contentHash).join(", ")}, сейчас $actual) — '
      'ярус правили после вычитки',
    );
  }

  final noHash = review.passes.where((p) => p.contentHash.isEmpty).length;
  if (noHash > 0) {
    report.error(
      'ярус $tier: у $noHash проходов нет content_hash — такая запись не '
      'привязана к тексту и не отличима от устаревшей',
    );
  }
}

class _Report {
  final List<String> errors = [];

  /// Сомнительное, но не блокирующее — на ручную вычитку.
  final List<String> reviews = [];

  /// Осознанно не сделанное: приходит с будущей вехой.
  final List<String> pendings = [];

  /// Не проблема, а форма контента: что открывается на каком ярусе, сколько
  /// покрывает язык. Печатается затем, чтобы это было видно при каждой
  /// сборке, а не считалось руками.
  final List<String> notes = [];

  void error(String message) => errors.add(message);
  void review(String message) => reviews.add(message);
  void pending(String message) => pendings.add(message);
  void note(String message) => notes.add(message);

  void print(String lang) {
    for (final n in notes) {
      stdout.writeln('· $n');
    }
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




/// Языки, у которых в `launch.yaml` есть секция.
///
/// Читается отдельным разбором: `LaunchPolicy.read` берёт один язык за раз и
/// про остальные ничего не знает — а именно это и надо проверить.
Set<String> _languagesInLaunchFile(File file) {
  final doc = loadYaml(file.readAsStringSync());
  if (doc is! YamlMap) return const {};
  return {
    for (final key in doc.keys)
      if (doc[key] is YamlMap) '$key',
  };
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
