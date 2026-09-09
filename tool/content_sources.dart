/// Чтение YAML-исходников контента. Формат описан в
/// docs/CONTENT_PIPELINE.md.
///
/// Два вида файлов, и деление между ними принципиальное:
///
/// * `content/phrases/<код>/<тема>.yaml` — фразы на языке изучения. Фраза и
///   есть единица изучения: у неё ярус, созвездие и порядок внутри них.
///   Немецкое предложение не может лежать в язык-нейтральном файле, и раньше
///   лежало.
/// * `content/lang/<код>.yaml` (или каталог `content/lang/<код>/*.yaml`) —
///   то, что добавляет язык: заголовок, которым он объявляет о себе, и
///   переводы фраз.
///
/// Рядом читаются `content/launch.yaml` — какие ярусы запущены и кто их
/// вычитал — и `content/calibration/<код>.yaml`, набор онбординга.
///
/// Языки находятся перебором каталога, а не списком в коде. Разница не
/// косметическая: она отделяет «добавить язык значит создать файл» от
/// «добавить язык значит найти четыре места в Dart и ни одного не забыть».
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'content_schema.dart';

/// Ошибка в исходниках: сообщение адресовано человеку, который правит YAML,
/// а не разработчику инструмента.
class ContentSourceException implements Exception {
  ContentSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Язык проекта: что он о себе объявил и что принёс.
class LanguageSource {
  LanguageSource({
    required this.code,
    required this.role,
    required this.status,
    required this.name,
    required this.phraseTranslations,
  });

  final String code;

  /// `native`, `target` или `both`.
  final String role;

  /// `draft` или `launched`. Полноты валидатор требует только от `launched`.
  final String status;

  /// Самоназвание: «Українська», «Deutsch». Живёт здесь, а не в коде, потому
  /// что иначе добавление языка снова потребовало бы правки Dart.
  final String name;

  /// phrase_id → перевод фразы целиком. Всё, что язык добавляет к контенту:
  /// со словарным слоем ушли и лексемы, которые язык приносил раньше.
  final Map<String, String> phraseTranslations;

  bool get isTarget => role == 'target' || role == 'both';
  bool get isNative => role == 'native' || role == 'both';
  bool get isLaunched => status == 'launched';
}

class PhraseSource {
  PhraseSource({
    required this.id,
    required this.lang,
    required this.tier,
    required this.constellation,
    required this.idx,
    required this.text,
    this.register,
  });

  final String id;
  final String lang;
  final String tier;
  final String constellation;

  /// Порядок внутри созвездия и яруса — тот, в котором фразы написаны в файле.
  ///
  /// Последовательность знакомства раньше задавала частотность слова
  /// (`concepts.freq_rank`), а у фразы частотности нет и быть не может:
  /// «Zum Frühstück esse ich Brot» не встречается в корпусе ни разу. Порядок
  /// поэтому решает автор, и решает он его порядком строк в файле — то есть
  /// там же, где пишет фразы, а не в отдельном поле, которое разошлось бы с
  /// файлом при первой вставке в середину.
  final int idx;

  /// Готовая к показу строка: подстановка ответов сделана при чтении.
  final String text;

  final String? register;
}

class CalibrationItemSource {
  CalibrationItemSource({
    required this.id,
    required this.tier,
    required this.kind,
    required this.phraseId,
  });

  final String id;
  final String tier;

  /// Чем спрашивают. Сегодня всегда `phrase`: другой единицы у калибровки
  /// нет. Поле остаётся, потому что видов вопроса о фразе больше одного
  /// (узнать перевод, узнать на слух), и различать их придётся.
  final String kind;

  final String phraseId;
}

/// Кто вычитал ярус и что именно он прочитал.
///
/// Второе поле появилось не сразу, и его отсутствие стоило дорого. Раньше
/// `reviewers` был свободным текстом «автор проекта; созвездия doctor, food,
/// transport, home, shop», и когда созвездий стало девять, строчку никто не
/// обновил. Ярус A0 остался запущенным, а его содержимое уезжало игроку не
/// прочитанным никем. Правило было записано, но не проверялось — то есть не
/// работало.
class TierReview {
  const TierReview({
    required this.by,
    this.constellations = const {},
    this.passes = const [],
  });

  /// Кто читал. Строка человеческая: важно не имя, а то, чем читали.
  final String by;

  /// Какие созвездия прочитаны. Сверяется с составом яруса.
  final Set<String> constellations;

  /// Проходы вычитки: чем читали, когда и что именно было прочитано.
  final List<ReviewPass> passes;

  /// Сколько разных моделей читали ярус **целиком**.
  ///
  /// Разных, а не проходов: два прогона одной моделью — это один взгляд,
  /// повторённый дважды, и от согласованной ошибки он не страхует. И только
  /// полные: два частичных прохода не складываются в один полный, даже если
  /// вместе покрывают весь текст, — покрытие не то же самое, что прочтение
  /// в одном контексте.
  int get distinctModels =>
      {for (final p in passes.where((p) => p.isFull)) p.model}.length;
}

/// Один проход вычитки.
///
/// [contentHash] — отпечаток содержимого яруса на момент проверки. Он и есть
/// смысл этой записи: проверка описывает конкретный текст, и если текст
/// изменили, проверка устарела. Без отпечатка это невидимо — запись
/// выглядит рабочей.
///
/// В этом проекте на такое уже наступали: аудит был снят с ревизии
/// `88acb03`, применялся к HEAD, и половина находок оказалась давно
/// исправленной. Разбирать пришлось руками, написав для этого отдельный
/// классификатор.
class ReviewPass {
  const ReviewPass({
    required this.model,
    required this.at,
    required this.contentHash,
    this.scope = 'full',
    this.findings = 0,
    this.note = '',
  });

  /// Чем читали: имя модели или человека.
  final String model;

  /// Когда. Строкой, как записано: сравнивать даты машинно незачем, а
  /// читающему важно видеть, насколько запись свежая.
  final String at;

  /// Отпечаток содержимого яруса на момент прохода.
  final String contentHash;

  /// Что именно прочитано: `full` — ярус целиком, иначе часть (`phrases`,
  /// `translations`…).
  ///
  /// Поле появилось потому, что без него частичный проход неотличим от
  /// полного, и два частичных закрывали бы требование «две модели прочитали
  /// ярус», ничего такого не сделав. Записывать частичные проходы всё равно
  /// стоит: они говорят, что с ярусом делали. К порогу идут только полные.
  final String scope;

  bool get isFull => scope == 'full';

  /// Сколько находок дал проход. Ноль — законный результат, но говорящий:
  /// проход, не нашедший ничего, либо подтверждает ярус, либо не читал его.
  final int findings;

  final String note;
}

/// Какие ярусы языка запущены, а какие только написаны.
///
/// Машинная форма правила «ярус не запускается без вычитки»: валидатор
/// требует полноты только от запущенных ярусов и не даёт объявить запущенным
/// ярус, вычитанный наполовину.
class LaunchPolicy {
  const LaunchPolicy({
    this.launched = const {},
    this.drafted = const {},
    this.reviews = const {},
  });

  final Set<String> launched;
  final Set<String> drafted;

  /// Ярус → что о его вычитке известно.
  final Map<String, TierReview> reviews;

  bool isLaunched(String tier) => launched.contains(tier);

  /// Ярус написан, но не вычитан: структуру проверяем, полноту — нет.
  bool isDrafted(String tier) => drafted.contains(tier);

  static LaunchPolicy read(File file, String lang) {
    if (!file.existsSync()) return const LaunchPolicy();
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) return const LaunchPolicy();
    final byLang = doc[lang];
    if (byLang is! YamlMap) return const LaunchPolicy();

    Set<String> read(String key) {
      final node = byLang[key];
      return node is YamlList ? {for (final e in node) '$e'} : <String>{};
    }

    final reviews = <String, TierReview>{};
    final node = byLang['reviewers'];
    if (node is YamlMap) {
      for (final entry in node.entries) {
        final body = entry.value;
        if (body is! YamlMap) {
          throw ContentSourceException(
            'launch.yaml, $lang/${entry.key}: вычитка записана строкой. '
            'Нужны поля by и constellations — иначе покрытие не проверить, '
            'а непроверяемая запись рано или поздно разойдётся с контентом.',
          );
        }
        final covered = body['constellations'];
        final passNode = body['passes'];
        final passes = <ReviewPass>[];
        if (passNode is YamlList) {
          for (final raw in passNode) {
            if (raw is! YamlMap) {
              throw ContentSourceException(
                'launch.yaml, $lang/${entry.key}: проход вычитки записан не '
                'картой. Нужны model, at и content_hash — без отпечатка '
                'проверка не привязана к тексту, который проверяли.',
              );
            }
            passes.add(ReviewPass(
              model: '${raw['model'] ?? ''}',
              at: '${raw['at'] ?? ''}',
              contentHash: '${raw['content_hash'] ?? ''}',
              scope: '${raw['scope'] ?? 'full'}',
              findings: raw['findings'] is int ? raw['findings'] as int : 0,
              note: '${raw['note'] ?? ''}',
            ));
          }
        }

        reviews['${entry.key}'] = TierReview(
          by: '${body['by'] ?? ''}',
          constellations:
              covered is YamlList ? {for (final e in covered) '$e'} : const {},
          passes: passes,
        );
      }
    }

    return LaunchPolicy(
      launched: read('launched'),
      drafted: read('drafted'),
      reviews: reviews,
    );
  }
}

/// Всё, что прочитано из `content/`.
///
/// **Чего здесь больше нет и почему файлы всё равно на диске.** Пайплайн
/// перестал читать `content/concepts/*.yaml` (концепты) и секции `lexemes:`
/// языковых файлов, включая двадцать пять файлов `content/lang/de/`. Это не
/// потеря и не забытая уборка: единицей изучения стала фраза, и словарной
/// записи в игре нет — ни звездой, ни вариантом в круге (см. v5 в
/// `content_schema.dart`).
///
/// Файлы намеренно оставлены на месте. Шесть тысяч немецких лемм с уровнем,
/// темой, артиклем и родом — это материал, по которому пишутся короткие
/// фразы: словник отвечает на вопрос «какие слова должен закрыть ярус A1», и
/// другого источника этого ответа у проекта нет. Удалить их значило бы
/// выбросить редакторскую работу ради того, чтобы каталог соответствовал
/// коду.
///
/// Из `content/lang/<код>.yaml` читаются только заголовок языка (`lang`,
/// `role`, `status`, `name`) и раздел `phrases:` — переводы фраз. Раздел
/// `lexemes:` игнорируется: он описывает слово, а слова у игры больше нет.
/// Из файла фраз по той же причине не читаются `concepts:` (к какому слову
/// привязана фраза) и `orders:` (какие сборки принимаются верными сверх
/// шаблона) — вставки слов в предложение больше нет, значит нет и сборок.
class ContentSources {
  ContentSources({
    required this.constellations,
    required this.languages,
    required this.phrases,
    required this.calibration,
    required this.hash,
    required this.targetLang,
    this.launch = const LaunchPolicy(),
  });

  /// Политика запуска ярусов языка изучения.
  final LaunchPolicy launch;

  /// Хеш всех прочитанных файлов: попадает в `content_meta.source_hash` и
  /// позволяет по собранному ассету понять, из чего он собран, не полагаясь
  /// на метку времени.
  final String hash;

  /// Язык изучения, под который собирается эта база.
  final String targetLang;

  /// Имена созвездий в порядке файлов.
  ///
  /// Берутся из файлов фраз: созвездие есть тогда, когда в нём есть звёзды, а
  /// звезда — это фраза. Раньше список приходил из `content/concepts/`, и
  /// поэтому в нём значились темы, у которых не написано ни одной фразы, —
  /// то есть темы, которых в игре нет.
  final List<String> constellations;

  /// Языки по коду — со всем, что каждый принёс.
  final Map<String, LanguageSource> languages;

  final List<PhraseSource> phrases;

  /// Набор калибровки по языку изучения.
  final Map<String, List<CalibrationItemSource>> calibration;

  /// Отпечаток содержимого яруса на языке изучения.
  ///
  /// Считается по тому, что видит вычитывающий: тексты фраз яруса, их
  /// пометки регистра и их переводы на все языки, которые их дали. Порядок
  /// нормализован сортировкой — переставленные строки YAML не должны означать
  /// «текст изменился».
  ///
  /// Не по хешу файлов: файл содержит все ярусы, и правка B2 объявляла бы
  /// устаревшей вычитку A0.
  ///
  /// Раньше сюда входили формы, множественные числа, пометки лексем и
  /// дистракторы — вычитка занималась в основном ими. Со словарным слоем это
  /// ушло, а переводы, наоборот, вошли: перевод — половина того, что читает
  /// вычитывающий, и правка перевода обязана устаревить запись о прочтении.
  String tierHash(String tier) {
    final parts = <String>[];
    final codes = languages.keys.toList()..sort();

    for (final phrase in phrases) {
      if (phrase.tier != tier) continue;
      final translations = <String>[];
      for (final code in codes) {
        final text = languages[code]!.phraseTranslations[phrase.id];
        if (text == null) continue;
        translations.add('$code=$text');
      }
      parts.add([
        phrase.id,
        phrase.text,
        phrase.register ?? '',
        translations.join('|'),
      ].join(''));
    }

    parts.sort();
    return sha256
        .convert(utf8.encode(parts.join('')))
        .toString()
        .substring(0, 12);
  }

  /// Читает исходники под язык изучения [lang].
  ///
  /// [withCalibration] выключается ровно одним вызывающим — генератором
  /// набора калибровки. Он этот файл пишет, и читать его перед записью значит
  /// упасть на нём: набор, собранный по прежним правилам, чтением
  /// отвергается, а починить его можно только генератором. Проверка набора от
  /// этого не слабеет — её делают валидатор и сборка, а они читают всё.
  static ContentSources load(
    Directory root, {
    String lang = defaultTargetLang,
    bool withCalibration = true,
  }) {
    if (!root.existsSync()) {
      throw ContentSourceException(
        'нет каталога исходников ${root.path} — см. docs/CONTENT_PIPELINE.md',
      );
    }

    // Порядок файлов фиксирован сортировкой: он определяет порядок вставки
    // в базу, а значит и байты собранного ассета.
    final phraseFiles = _yamlFiles(Directory('${root.path}/phrases/$lang'));
    if (phraseFiles.isEmpty) {
      throw ContentSourceException(
        'в ${root.path}/phrases/$lang нет ни одного .yaml — фраза это '
        'единица изучения, и без файла фраз собирать нечего',
      );
    }
    final constellations = <String>[];
    final phrases = <PhraseSource>[];
    for (final file in phraseFiles) {
      _readPhraseFile(file, lang, constellations, phrases);
    }

    final languages = <String, LanguageSource>{};
    final langFiles = <File>[];
    for (final entry in _languageEntries(Directory('${root.path}/lang'))) {
      langFiles.addAll(entry.files);
      languages[entry.code] = _readLanguage(entry);
    }
    if (languages.isEmpty) {
      throw ContentSourceException(
        'в ${root.path}/lang нет ни одного языка. Язык — это файл '
        '<код>.yaml или каталог <код>/ с файлами по темам.',
      );
    }

    // Читается набор только того языка изучения, под который собирается база
    // — по той же причине, что и фразы: калибровка меряет ярус на фразах, а
    // фразы принадлежат языку изучения. Раньше читались все файлы каталога, и
    // набор языка, который языком изучения быть перестал (английский, см.
    // историю в шапке валидатора), ронял бы сборку немецкого.
    final calibration = <String, List<CalibrationItemSource>>{};
    final calibrationFiles = <File>[];
    final calibrationFile = File('${root.path}/calibration/$lang.yaml');
    if (withCalibration && calibrationFile.existsSync()) {
      calibrationFiles.add(calibrationFile);
      calibration[lang] = _readCalibration(calibrationFile);
    }

    return ContentSources(
      constellations: constellations,
      languages: languages,
      phrases: phrases,
      calibration: calibration,
      targetLang: lang,
      launch: LaunchPolicy.read(File('${root.path}/launch.yaml'), lang),
      hash: _hashOf([
        ...phraseFiles,
        ...langFiles,
        ...calibrationFiles,
        File('${root.path}/launch.yaml'),
      ]),
    );
  }

  /// Языки, найденные в `content/lang/`.
  ///
  /// Язык — это либо файл `<код>.yaml`, либо каталог `<код>/` с файлами по
  /// темам. Второй вид остался от словарного слоя: шесть тысяч лексем в одном
  /// YAML — это сорок тысяч строк, которые нельзя ни читать, ни править по
  /// частям. Переводы фраз столько места не занимают, но вид файлов сохранён:
  /// каталоги на диске лежат, и читать их надо.
  static List<_LanguageEntry> _languageEntries(Directory dir) {
    if (!dir.existsSync()) return const [];
    final result = <_LanguageEntry>[];

    for (final entity in dir.listSync()..sort(_byPath)) {
      if (entity is File && entity.path.endsWith('.yaml')) {
        final code = entity.uri.pathSegments.last.replaceAll('.yaml', '');
        result.add(_LanguageEntry(code, [entity]));
      } else if (entity is Directory) {
        final code = entity.uri.pathSegments
            .lastWhere((s) => s.isNotEmpty);
        final files = _yamlFiles(entity);
        if (files.isEmpty) {
          throw ContentSourceException(
            '${entity.path}: каталог языка пуст — либо положите файлы по '
            'темам, либо уберите каталог',
          );
        }
        result.add(_LanguageEntry(code, files));
      }
    }

    final seen = <String>{};
    for (final entry in result) {
      if (!seen.add(entry.code)) {
        throw ContentSourceException(
          'язык ${entry.code} объявлен и файлом, и каталогом — '
          'останьтесь на одном виде',
        );
      }
    }
    return result;
  }

  static int _byPath(FileSystemEntity a, FileSystemEntity b) =>
      a.path.compareTo(b.path);

  /// YAML-файлы каталога в стабильном порядке.
  static List<File> _yamlFiles(Directory dir) {
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Хеш содержимого исходников. Имя файла входит в хеш, чтобы переименование
  /// созвездия тоже считалось изменением контента.
  static String _hashOf(List<File> files) {
    // Исходники — текстовые YAML на сотни килобайт, поэтому склеить их в
    // памяти дешевле, чем возиться с потоковым хешированием.
    final buffer = BytesBuilder(copy: false);
    for (final file in files) {
      if (!file.existsSync()) continue;
      buffer.add(utf8.encode(file.uri.pathSegments.last));
      buffer.add(file.readAsBytesSync());
    }
    return sha256.convert(buffer.takeBytes()).toString().substring(0, 16);
  }

  static void _readPhraseFile(
    File file,
    String lang,
    List<String> constellations,
    List<PhraseSource> phrases,
  ) {
    final doc = _loadMap(file);
    final declared = doc['lang'];
    if (declared != lang) {
      throw ContentSourceException(
        '${file.path}: внутри указан язык "$declared", а файл лежит в '
        'phrases/$lang/',
      );
    }
    final name = _requireString(doc, 'constellation', file);
    constellations.add(name);

    final tierMap = doc['tiers'];
    if (tierMap is! YamlMap) {
      throw ContentSourceException('${file.path}: нет секции tiers');
    }

    for (final tier in tiers) {
      final node = tierMap[tier];
      if (node == null) continue;
      if (node is! YamlList) {
        throw ContentSourceException(
          '${file.path}: tiers.$tier должен быть списком фраз',
        );
      }
      // Порядок внутри созвездия и яруса — это порядок строк в файле, и
      // считается он здесь, а не в поле YAML: поле пришлось бы править у всех
      // фраз ниже при каждой вставке в середину.
      var idx = 0;
      for (final raw in node) {
        if (raw is! YamlMap) {
          throw ContentSourceException(
            '${file.path}: tiers.$tier содержит не карту',
          );
        }
        phrases.add(_readPhrase(raw, lang, tier, name, idx++, file));
      }
    }
  }

  static PhraseSource _readPhrase(
    YamlMap raw,
    String lang,
    String tier,
    String constellation,
    int idx,
    File file,
  ) {
    final id = _requireString(raw, 'id', file);

    // Фраза в файле — готовая строка, и это разница с прежней записью.
    //
    // Раньше здесь читались `template` с пропуском `{…}` и `answer` к нему:
    // фразу собирала механика вставки слов, и в файле она хранилась
    // разобранной. Механики нет, разбирать нечего — у фразы есть текст.
    final text = _requireString(raw, 'text', file);
    if (text.contains('{')) {
      throw ContentSourceException(
        '${file.path}: фраза $id несёт `{` — пропусков в фразе больше не '
        'бывает, вставки слов в предложение в игре нет',
      );
    }

    return PhraseSource(
      id: id,
      lang: lang,
      tier: tier,
      constellation: constellation,
      idx: idx,
      text: text,
      register: raw['register'] as String?,
    );
  }

  static LanguageSource _readLanguage(_LanguageEntry entry) {
    final translations = <String, String>{};
    String? role;
    String? status;
    String? name;

    for (final file in entry.files) {
      final doc = _loadMap(file);
      final declared = doc['lang'];
      if (declared != entry.code) {
        throw ContentSourceException(
          '${file.path}: внутри указан язык "$declared", а файл лежит под '
          '"${entry.code}"',
        );
      }

      // Заголовок обязателен ровно один раз: у файла-языка — в нём самом, у
      // каталога-языка — в любом из файлов, но одинаковый во всех.
      for (final field in const ['role', 'status', 'name']) {
        final value = doc[field];
        if (value == null) continue;
        final current = switch (field) {
          'role' => role,
          'status' => status,
          _ => name,
        };
        if (current != null && current != '$value') {
          throw ContentSourceException(
            '${file.path}: $field="$value" расходится с "$current" в другом '
            'файле того же языка',
          );
        }
        switch (field) {
          case 'role':
            role = '$value';
          case 'status':
            status = '$value';
          default:
            name = '$value';
        }
      }

      // Раздел `lexemes:` не читается совсем, и молчание здесь намеренное.
      // Слово перестало быть единицей изучения, поэтому лексема не попадает
      // ни в базу, ни в проверки. Ошибкой её присутствие тоже не считается:
      // шесть тысяч немецких лемм с уровнем и темой — материал для будущих
      // фраз, и требовать их удаления значило бы требовать выбросить его.
      final phraseNode = doc['phrases'];
      if (phraseNode is YamlMap) {
        for (final e in phraseNode.entries) {
          translations['${e.key}'] = '${e.value}';
        }
      }
    }

    final head = entry.files.first.path;
    if (role == null || !languageRoles.contains(role)) {
      throw ContentSourceException(
        '$head: язык ${entry.code} не объявил role. Нужно одно из '
        '${languageRoles.join(", ")} — иначе непонятно, учат на нём или '
        'подсказывают им.',
      );
    }
    if (status == null || !languageStatuses.contains(status)) {
      throw ContentSourceException(
        '$head: язык ${entry.code} не объявил status. Нужно одно из '
        '${languageStatuses.join(", ")} — от этого зависит, требовать ли '
        'полноты.',
      );
    }
    if (name == null || name.isEmpty) {
      throw ContentSourceException(
        '$head: язык ${entry.code} не объявил name. Самоназвание живёт в '
        'файле языка, а не в коде: иначе добавление языка снова потребует '
        'правки Dart.',
      );
    }

    return LanguageSource(
      code: entry.code,
      role: role,
      status: status,
      name: name,
      phraseTranslations: translations,
    );
  }

  static List<CalibrationItemSource> _readCalibration(File file) {
    final doc = _loadMap(file);
    final node = doc['items'];
    if (node is! YamlList) {
      throw ContentSourceException('${file.path}: нет секции items');
    }

    final result = <CalibrationItemSource>[];
    for (final raw in node) {
      if (raw is! YamlMap) {
        throw ContentSourceException('${file.path}: items содержит не карту');
      }
      final phraseId = raw['phrase'] as String?;
      if (phraseId == null) {
        // Позиция со `concept:` — набор, собранный до разговорника. Молча
        // пропустить её нельзя: калибровка меряет ярус, и набор, потерявший
        // четыре пятых позиций, объявил бы игроку A0 при владении A2.
        throw ContentSourceException(
          '${file.path}: у позиции калибровки ${raw['id']} нет поля phrase. '
          'Слово перестало быть единицей изучения, спрашивать можно только '
          'фразу — пересоберите набор: '
          'dart run tool/make_calibration.dart --lang ${doc['lang']}',
        );
      }
      result.add(CalibrationItemSource(
        id: _requireString(raw, 'id', file),
        tier: _requireString(raw, 'tier', file),
        kind: 'phrase',
        phraseId: phraseId,
      ));
    }
    return result;
  }

  static YamlMap _loadMap(File file) {
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) {
      throw ContentSourceException(
          '${file.path}: ожидалась карта на верхнем уровне');
    }
    return doc;
  }

  static String _requireString(YamlMap map, String key, File file) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw ContentSourceException('${file.path}: нет обязательного поля "$key"');
  }

  /// Список строк. Пустой элемент — ошибка, а не пустая строка.
  ///
  /// Ловушка YAML, на которую уже наступили: `Null`, `No`, `On`, `~` он
  /// разбирает не как слова, а как значения. Слово `Null` — настоящее
  /// немецкое существительное (die Null, ноль) — превращалось в null, а
  /// интерполяция `'$e'` делала из него строку «null», и в контент уезжало
  /// слово, написанное словом «null». Такие слова нужно брать в кавычки, и
  /// проверка об этом прямо говорит.
}

/// Язык и файлы, из которых он собран.
class _LanguageEntry {
  _LanguageEntry(this.code, this.files);

  final String code;
  final List<File> files;
}
