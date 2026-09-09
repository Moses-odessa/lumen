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
//
// ── Какие проверки ушли с разговорником и что каждая охраняла ─────────────
//
// Единицей изучения стала фраза, отдельного слова в игре нет (см. v5 в
// `content_schema.dart`). Двадцать одна проверка описывала слово, круг
// вариантов вокруг слова или сборку предложения из слов, и после смены
// единицы проверять стало нечего.
// Список нужен затем, чтобы удалённое правило не выглядело потерянным: на
// эти записи ссылается PLAN.md, и по ним видно, какой класс ошибок больше
// никто не ловит.
//
// Словарный слой:
//
// * существование форм — отрицательный список делал невозможным возврат
//   однажды найденной выдумки, положительный сверял форму со словарём и
//   разбором составных слов;
// * покрытие лексемами — у запущенного языка лексема есть на каждый концепт;
// * лексема-сирота — id, которого нет среди концептов (опечатка после
//   переименования);
// * служебные слова — `sich` без единой фразы недостижим: строка в базе,
//   которую игрок не увидит никогда;
// * пометка лексемы — код из закрытого набора, а не свободный текст: текст
//   уезжал игроку на языке файла, а не на его собственном (для регистра
//   фразы эта проверка осталась);
// * дубли форм внутри созвездия и яруса — иначе в круге два одинаковых
//   варианта; фразового аналога (две фразы с одинаковым текстом) пока нет;
// * артикль против рода — «die / n» учит неправде, ничем себя не выдавая;
// * немецкое множественное — образуется от самого слова, а не от другого;
// * plurale tantum — у слова только во множественном нет рода;
// * дистракторы — минимум 2 far и 3 near, и ни один не равен ответу в другом
//   написании;
// * созвучность near — вариант, не похожий на ответ на слух, круг не
//   усложняет;
// * созвучные на родном языке — 132 написанных и отгруженных дистрактора,
//   которых игрок не увидел бы никогда: круг на родном всегда просил far;
// * заглавная у дистрактора — слово с окончанием прилагательного, записанное
//   существительным, не существует;
// * разнообразие дистракторов — слово, стоящее вариантом у пяти вопросов,
//   запоминается как «всегда неверный».
//
// Фразовая сборка (пропуск, плитки, порядок слов):
//
// * `phrase_orders` — заявленный порядок собран из тех же слов, что и фраза,
//   и не повторяет заданный шаблоном;
// * перестановки — считала фразы со свободным передним полем, у которых
//   второй верный порядок не заявлен: игра объявляла бы его ошибкой;
// * длина фразы — короче четырёх слов фразовая механика не брала, и круг
//   молча терялся;
// * ответ в пропуске — форма того слова, к которому фраза привязана, иначе
//   круг не пройти честно;
// * слот и подсказка — в шаблоне есть `{…}`, ответ не стоит в нём открытым
//   текстом, а число пропусков сходится с числом ответов. Последнее не
//   исчезло: его теперь проверяет чтение исходников, потому что подстановка
//   делается там (`_readPhrase`), и до валидатора такая фраза не доходит;
// * привязка к концепту — фраза без концепта не зажигала ни одной звезды;
// * черновые концепты — сколько написано и не вычитано; у фразы такой
//   пометки в исходниках нет, готовность объявляется ярусом.

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'content_schema.dart';
import 'content_sources.dart';
import 'translation_lock.dart';

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
    final findings = validateContent(root, lang);
    findings.print(lang);
    if (findings.errors.isNotEmpty) failed = true;
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

/// Прогон всех проверок для одного языка изучения.
///
/// Возвращает находки, а не печатает их, и это не косметика: до M13 у
/// валидатора не было ни одного теста — проверить его было нечем, потому что
/// единственным его выходом был `stdout`. Критерий приёмки M13 требует
/// обратного: подсадить в контент дефект и убедиться, что валидатор его
/// находит.
Findings validateContent(Directory root, String lang) {
  final report = Findings();

  final ContentSources sources;
  try {
    sources = ContentSources.load(root, lang: lang);
  } on ContentSourceException catch (e) {
    report.error('исходники: ${e.message}');
    return report;
  }

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
  _checkLanguages(sources, report, root);
  _checkPhraseTranslations(sources, report, root);
  _checkConstellationSizes(sources, report);
  _checkSingleSentence(sources, report);
  _checkPhraseRegister(sources, report);
  _checkPhrases(sources, report);
  _checkCalibration(sources, lang, report);

  return report;
}

/// Языки объявили о себе непротиворечиво, и играть вообще есть чем.
///
/// Список языков больше не константа в коде — он равен содержимому
/// `content/lang/`. Поэтому проверять приходится то, что раньше гарантировала
/// компиляция: что язык изучения существует, что хоть один родной язык
/// запущен и что собираемая база собирается для языка изучения, а не для
/// языка подсказок.
void _checkLanguages(
  ContentSources sources,
  Findings report,
  Directory rootDir,
) {
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
  // assets/content/en.db лежали немецкие фразы с пометкой lang="en", и
  // валидатор находил 397 ошибок ровно в тот момент, когда его об этом
  // спрашивали. Никто не спрашивал: CI собирал только de.
  final launchFile = File('${rootDir.path}/launch.yaml');
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

/// Переводы фраз: без перевода фраза не учит ничему.
///
/// Фраза звучит, читается — и рядом должен стоять перевод. Это не украшение:
/// разобранное на слух предложение, смысл которого никто не назвал, учит
/// только произношению.
///
/// Полнота требуется от `launched`, у `draft` только считается и печатается.
/// Это и есть механизм добавления языка: файл ложится в каталог со
/// `status: draft`, валидатор говорит, сколько он покрывает, и ничего не
/// блокирует.
void _checkPhraseTranslations(
  ContentSources sources,
  Findings report,
  Directory rootDir,
) {
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

    _checkTranslationFreshness(sources, language, report, rootDir);

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
  Findings report,
  Directory rootDir,
) {
  final lock = readTranslationLock(
    translationLockFile(rootDir.path, language.code),
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

/// Созвездие, появившееся на карте, обязано быть созвездием, а не точкой.
///
/// Звезда — это фраза, и порог считается по фразам. Раньше здесь требовалось
/// точное совпадение с накопительными 12/24/48/72/96 концептами. Это правило
/// годилось для девяти тем, написанных под него, и провалилось бы на любой
/// теме, которой на A0 сказать почти нечего: дотягивать её до двенадцати
/// значило бы придумывать A0-содержание там, где его нет.
///
/// Порог вместо равенства. Тема ждёт того яруса, на котором ей есть что
/// показать, и прогрессия из этого получается сама. Ошибка теперь одна и
/// осмысленная: созвездие показано игроку, а звёзд в нём меньше порога.
void _checkConstellationSizes(ContentSources sources, Findings report) {
  final opensAt = <String, String>{};

  for (final name in sources.constellations) {
    final byTier = <String, int>{};
    for (final phrase in sources.phrases) {
      if (phrase.constellation != name) continue;
      byTier[phrase.tier] = (byTier[phrase.tier] ?? 0) + 1;
    }
    if (byTier.isEmpty) {
      // Список созвездий берётся из файлов фраз, поэтому пустое созвездие
      // означает ровно одно: файл темы есть, а фраз в нём нет.
      report.error('созвездие $name: файл темы есть, а фраз в нём нет');
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
///
/// Код, а не свободный текст, и это вторая половина проверки. `register:
/// casual` уезжал на экран как есть, и под каждой из 432 фраз стояло
/// английское служебное слово. Строку к коду даёт локализация — на языке
/// интерфейса, — поэтому набор закрыт (`promptTags`), и пометка вне набора
/// означает строку, которую показать нечем.
void _checkPhraseRegister(ContentSources sources, Findings report) {
  // Вежливая форма узнаётся по местоимению: Sie, Ihnen, Ihr/Ihre/Ihren…
  final polite = RegExp(r'\b(Sie|Ihnen|Ihr|Ihre|Ihrem|Ihren|Ihrer|Ihres)\b');
  var drafted = 0;

  for (final phrase in sources.phrases) {
    final register = phrase.register;
    if (register == null) continue;
    if (!promptTags.contains(register)) {
      report.error(
        'фраза ${phrase.id}: регистр "$register" не код из набора '
        '${promptTags.join(", ")} — свободный текст показался бы игроку на '
        'языке файла, а не на его собственном',
      );
      continue;
    }

    final hasPolite = polite.hasMatch(phrase.text);

    // Проверка осталась односторонней, и это не упрощение.
    //
    // «Есть Sie, а помечена casual» — настоящий дефект: игрок учит вежливое
    // обращение с пометкой «так говорят с друзьями». А вот обратное неверно:
    // вежливость в немецком бывает лексической, без единого местоимения —
    // «Entschuldigung.», «Könnte ich bitte ...». Пока проверка требовала
    // `Sie` от каждой формальной фразы, она отвергала именно такие.
    if (hasPolite && register == 'casual') {
      final message = 'фраза ${phrase.id}: обращение на Sie, а помечена casual';
      if (sources.launch.isLaunched(phrase.tier)) {
        report.error(message);
      } else {
        drafted++;
      }
    }
  }

  if (drafted > 0) {
    report.pending(
      'у $drafted фраз незапущенных ярусов пометка регистра не сходится с '
      'формой обращения',
    );
  }
}

/// Фраза — одно предложение.
///
/// Два предложения в одной фразе — это две единицы изучения, слепленные в
/// одну звезду: их нельзя ни показать по отдельности, ни спросить по
/// отдельности, а перевод у них один на двоих. Проверка появилась при
/// фразовой сборке, где второе предложение давало ещё и ложный отказ
/// («Wo ist die Post? Ich muss einen Brief schicken» собирается в обратном
/// порядке и остаётся верным), и осталась после неё: пять таких фраз
/// появились от правки шаблонов ради смыслового ограничения — придаточное
/// добавить было проще, чем перестроить фразу, — и соблазн вернётся при
/// следующей такой правке.
void _checkSingleSentence(ContentSources sources, Findings report) {
  // Знак конца предложения, за которым ещё что-то есть.
  final inner = RegExp(r'[.!?]\s+\S');

  // Многоточие — не конец предложения, а место для своего слова.
  //
  // В разговорнике 239 фраз написаны с пропуском такого рода: «Ich heiße ...»,
  // «Ich bin ... Jahre alt.». Это одна фраза и одна единица изучения — игрок
  // подставляет своё имя сам, вслух. Пока проверка читала последнюю точку
  // многоточия как конец предложения, она давала 84 ложных отказа на 1000
  // фраз, то есть ровно на том корпусе, для которого игра и делается.
  final ellipsis = RegExp(r'(\.\.\.|…)');

  for (final phrase in sources.phrases) {
    if (!inner.hasMatch(phrase.text.replaceAll(ellipsis, '_'))) continue;
    report.error(
      'фраза ${phrase.id}: два предложения в одной фразе — «${phrase.text}». '
      'Это две единицы изучения под одной звездой и с одним переводом',
    );
  }
}

/// Идентификаторы фраз уникальны.
///
/// Всё, что раньше проверялось здесь же — есть ли в шаблоне слот, не стоит ли
/// ответ в шаблоне открытым текстом, привязана ли фраза к концепту, — ушло
/// вместе с пропуском и словом. Осталась одна проверка, и снять её нельзя:
/// прогресс игрока привязан к id, а `phrases.id` — первичный ключ, поэтому
/// дубль либо уронил бы сборку на вставке, либо (при `INSERT OR IGNORE`)
/// молча потерял бы вторую фразу.
///
/// Расхождение шаблона с ответами до валидатора не доходит: подстановку
/// делает чтение исходников, и фраза, у которой пропусков больше, чем
/// ответов, не читается вовсе.
void _checkPhrases(ContentSources sources, Findings report) {
  final ids = <String>{};
  for (final p in sources.phrases) {
    if (!ids.add(p.id)) report.error('фраза ${p.id}: дублирующийся id');
  }
}

/// Набор калибровки покрывает все пять ярусов минимум по 30 позиций.
void _checkCalibration(ContentSources sources, String lang, Findings report) {
  final items = sources.calibration[lang];
  if (items == null || items.isEmpty) {
    // Считаем, из чего вообще можно собрать набор: 30 позиций на ярус
    // требуют примерно трёх созвездий, одного не хватает физически.
    final possible = <String, int>{};
    for (final p in sources.phrases) {
      possible[p.tier] = (possible[p.tier] ?? 0) + 1;
    }
    final shortage = sources.launch.launched
        .where((t) => (possible[t] ?? 0) < 30)
        .map((t) => '$t: ${possible[t] ?? 0} фраз')
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

  final known = {for (final p in sources.phrases) p.id};
  for (final item in items) {
    if (known.contains(item.phraseId)) continue;
    report.error('калибровка ${item.id}: нет фразы ${item.phraseId}');
  }
}

/// Ярус не может быть одновременно запущенным и черновым, а запущенный
/// обязан иметь хоть какой-то контент.
void _checkLaunchPolicy(ContentSources sources, Findings report) {
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
    final onTier = sources.phrases.where((p) => p.tier == tier);
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

    final present = {for (final p in onTier) p.constellation};
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
/// второй проход, а носитель языка.
void _checkReviewPasses(
  ContentSources sources,
  String tier,
  TierReview review,
  Findings report,
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

  // Требование ставится к **нынешнему** тексту, а не ко всей записи.
  //
  // Раньше здесь стояло «любой устаревший проход — ошибка», и это делало
  // честную историю невозможной: вычитка A0 прошла шесть раундов, каждый
  // нашёл настоящее, каждая правка меняла текст. Записать все шесть значило
  // получить одиннадцать «устаревших» ошибок за то, что история сохранена, —
  // то есть проверка требовала стереть прошлые проходы, чтобы стать зелёной.
  //
  // Спрашивать надо одно: **этот** текст прочитан двумя разными моделями
  // целиком? Остальные записи — история, и они полезны: по ним видно, что
  // ярус читали шесть раз и что находил каждый раз.
  final current = review.passes
      .where((p) => p.isFull && p.contentHash == actual)
      .map((p) => p.model)
      .toSet();

  if (current.length < requiredModels) {
    final stale = review.passes.where((p) => p.contentHash != actual).length;
    report.error(
      'ярус $tier: нынешний текст ($actual) прочитан целиком '
      '${current.length} разными моделями, нужно $requiredModels. '
      '${stale == 0 ? "" : "Ещё $stale проходов описывают более ранние "
          "версии — это история, а не замена. "}'
      'Два прогона одной моделью — один взгляд, повторённый дважды.',
    );
  }

  final stale = review.passes
      .where((p) => p.contentHash.isNotEmpty && p.contentHash != actual)
      .length;
  if (stale > 0) {
    report.note(
      'ярус $tier: проходов вычитки ${review.passes.length}, из них '
      '${review.passes.length - stale} описывают нынешний текст, а $stale — '
      'более ранние версии',
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

class Findings {
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
