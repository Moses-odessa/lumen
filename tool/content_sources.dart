/// Чтение YAML-исходников контента. Формат описан в
/// docs/CONTENT_PIPELINE.md.
///
/// Три вида файлов, и деление между ними принципиальное:
///
/// * `content/concepts/<тема>.yaml` — **язык-нейтральное**: какой концепт
///   появляется на каком ярусе. Ни одной немецкой буквы.
/// * `content/lang/<код>.yaml` (или каталог `content/lang/<код>/*.yaml`) —
///   всё, что язык добавляет: формы, дистракторы, переводы фраз. Плюс
///   заголовок, которым язык объявляет о себе.
/// * `content/phrases/<код>/<тема>.yaml` — фразы на языке изучения. Немецкое
///   предложение не может лежать в язык-нейтральном файле, и раньше лежало.
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

class ConceptSource {
  ConceptSource({
    required this.id,
    required this.tier,
    required this.constellation,
    required this.pos,
    this.freqRank,
  });

  final String id;
  final String tier;
  final String constellation;
  final String pos;
  final int? freqRank;

  /// Служебное слово: круг из него не собрать.
  ///
  /// У `sich` нет ни перевода одним словом, ни осмысленного набора вариантов.
  /// Но пропуск во фразе — ровно та форма, в которой предлоги и проверяют,
  /// поэтому служебные слова живут только в механиках «заполни пропуски» и
  /// «собери предложение», а звёздами на карте не становятся.
  bool get isFunctionWord => functionWordPos.contains(pos);
}

/// Части речи, которые не годятся для круга с вариантами.
///
/// Дублируется с `lib/domain/entities/part_of_speech.dart`: `tool/` —
/// отдельная программа и не тянет за собой `lib/`. Совпадение наборов
/// проверяется тестом.
const Set<String> functionWordPos = {
  'pronoun',
  'article',
  'determiner',
  'preposition',
  'conjunction',
  'particle',
  'interjection',
  'number',
};

class LexemeSource {
  LexemeSource({
    required this.conceptId,
    required this.form,
    this.article,
    this.gender,
    this.plural,
    this.note,
    this.farDistractors = const [],
    this.nearDistractors = const [],
  });

  final String conceptId;
  final String form;
  final String? article;
  final String? gender;
  final String? plural;
  final String? note;

  /// Дистракторы из той же темы, но с другим значением.
  final List<String> farDistractors;

  /// Созвучные и однокоренные — самая дорогая для подбора часть круга.
  final List<String> nearDistractors;
}

/// Язык проекта: что он о себе объявил и что принёс.
class LanguageSource {
  LanguageSource({
    required this.code,
    required this.role,
    required this.status,
    required this.name,
    required this.lexemes,
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

  /// concept_id → лексема.
  final Map<String, LexemeSource> lexemes;

  /// phrase_id → перевод фразы целиком.
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
    required this.template,
    required this.answers,
    required this.conceptIds,
    this.optionsBySlot = const [],
    this.register,
    this.ambiguityReviewed = false,
  });

  final String id;
  final String lang;
  final String tier;
  final String constellation;
  final String template;

  /// Ответы по слотам в порядке слева направо. Длина обязана совпадать с
  /// числом `{…}` в шаблоне.
  final List<String> answers;

  /// Неверные слова по слоту. Необязательны: когда их нет, варианты
  /// добираются соседями по созвездию.
  final List<List<String>> optionsBySlot;

  final List<String> conceptIds;
  final String? register;

  /// `ambiguity: reviewed` — человек посмотрел на варианты с той же вершиной
  /// и решил, что смысл предложения их отсекает.
  ///
  /// Отметка нужна потому, что машина этого решить не может. Она видит, что
  /// «Eingang» встаёт в тот же пропуск, что «Ausgang», и правильно на это
  /// указывает; понять, что «Wir gehen durch den ___ hinaus» допускает только
  /// выход, она не в силах. Без отметки проверка ругалась бы на исправленную
  /// фразу вечно — а проверка, которую нельзя закрыть, отключается целиком.
  final bool ambiguityReviewed;

  /// Одно слово в пропуске — частный случай, но самый частый.
  String get answer => answers.isEmpty ? '' : answers.first;

  int get slotCount => answers.length;

  List<String> optionsFor(int slot) =>
      slot < optionsBySlot.length ? optionsBySlot[slot] : const [];
}

class CalibrationItemSource {
  CalibrationItemSource({
    required this.id,
    required this.tier,
    required this.kind,
    this.conceptId,
    this.phraseId,
  });

  final String id;
  final String tier;
  final String kind;
  final String? conceptId;
  final String? phraseId;
}

/// Кто вычитал ярус и что именно он прочитал.
///
/// Второе поле появилось не сразу, и его отсутствие стоило дорого. Раньше
/// `reviewers` был свободным текстом «автор проекта; созвездия doctor, food,
/// transport, home, shop», и когда созвездий стало девять, строчку никто не
/// обновил. Ярус A0 остался запущенным, а 48 его концептов и 16 фраз уезжали
/// игроку не прочитанными никем. Правило было записано, но не проверялось —
/// то есть не работало.
class TierReview {
  const TierReview({required this.by, this.constellations = const {}});

  /// Кто читал. Строка человеческая: важно не имя, а то, чем читали.
  final String by;

  /// Какие созвездия прочитаны. Сверяется с составом яруса.
  final Set<String> constellations;
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
        reviews['${entry.key}'] = TierReview(
          by: '${body['by'] ?? ''}',
          constellations:
              covered is YamlList ? {for (final e in covered) '$e'} : const {},
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
class ContentSources {
  ContentSources({
    required this.constellations,
    required this.concepts,
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
  final List<String> constellations;

  /// Концепты по id.
  final Map<String, ConceptSource> concepts;

  /// Языки по коду — со всем, что каждый принёс.
  final Map<String, LanguageSource> languages;

  final List<PhraseSource> phrases;

  /// Набор калибровки по языку изучения.
  final Map<String, List<CalibrationItemSource>> calibration;

  /// Лексемы: язык → concept_id → лексема. Вид, в котором их ждут проверки.
  Map<String, Map<String, LexemeSource>> get lexemes =>
      {for (final l in languages.values) l.code: l.lexemes};

  /// Концепты, годные для круга с вариантами: без служебных слов.
  Iterable<ConceptSource> get playableConcepts =>
      concepts.values.where((c) => !c.isFunctionWord);

  /// Сколько концептов покрывает язык. Считается, а не объявляется.
  int coverageOf(String lang) => languages[lang]?.lexemes.length ?? 0;

  static ContentSources load(
    Directory root, {
    String lang = defaultTargetLang,
  }) {
    if (!root.existsSync()) {
      throw ContentSourceException(
        'нет каталога исходников ${root.path} — см. docs/CONTENT_PIPELINE.md',
      );
    }

    final constellations = <String>[];
    final concepts = <String, ConceptSource>{};

    // Порядок файлов фиксирован сортировкой: он определяет порядок вставки
    // в базу, а значит и байты собранного ассета.
    final conceptFiles = _yamlFiles(Directory('${root.path}/concepts'));
    if (conceptFiles.isEmpty) {
      throw ContentSourceException(
        'в ${root.path}/concepts нет ни одного .yaml',
      );
    }
    for (final file in conceptFiles) {
      _readConceptFile(file, constellations, concepts);
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

    final phraseFiles = _yamlFiles(Directory('${root.path}/phrases/$lang'));
    final phrases = <PhraseSource>[];
    for (final file in phraseFiles) {
      _readPhraseFile(file, lang, phrases);
    }

    final calibration = <String, List<CalibrationItemSource>>{};
    final calibrationFiles = _yamlFiles(
      Directory('${root.path}/calibration'),
    );
    for (final file in calibrationFiles) {
      final code = file.uri.pathSegments.last.replaceAll('.yaml', '');
      calibration[code] = _readCalibration(file);
    }

    return ContentSources(
      constellations: constellations,
      concepts: concepts,
      languages: languages,
      phrases: phrases,
      calibration: calibration,
      targetLang: lang,
      launch: LaunchPolicy.read(File('${root.path}/launch.yaml'), lang),
      hash: _hashOf([
        ...conceptFiles,
        ...langFiles,
        ...phraseFiles,
        ...calibrationFiles,
        File('${root.path}/launch.yaml'),
      ]),
    );
  }

  /// Языки, найденные в `content/lang/`.
  ///
  /// Язык — это либо файл `<код>.yaml`, либо каталог `<код>/` с файлами по
  /// темам. Второй вид нужен потому, что 6299 концептов в одном YAML — это
  /// сорок тысяч строк, которые нельзя ни читать, ни править по частям. Но
  /// начинается язык всё равно с одного файла, и это важнее удобства.
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

  static void _readConceptFile(
    File file,
    List<String> constellations,
    Map<String, ConceptSource> concepts,
  ) {
    final doc = _loadMap(file);
    final name = _requireString(doc, 'constellation', file);
    constellations.add(name);

    final tierMap = doc['tiers'];
    if (tierMap is! YamlMap) {
      throw ContentSourceException('${file.path}: нет секции tiers');
    }

    if (doc.containsKey('phrases')) {
      throw ContentSourceException(
        '${file.path}: фразы больше не живут рядом с концептами. Немецкое '
        'предложение — это язык изучения, ему место в '
        'content/phrases/<код>/<тема>.yaml',
      );
    }

    for (final tier in tiers) {
      final node = tierMap[tier];
      if (node == null) continue;
      if (node is! YamlMap) {
        throw ContentSourceException('${file.path}: tiers.$tier не карта');
      }
      if (node.containsKey('phrases')) {
        throw ContentSourceException(
          '${file.path}: tiers.$tier.phrases — фразы переехали в '
          'content/phrases/<код>/<тема>.yaml',
        );
      }

      final conceptList = node['concepts'];
      if (conceptList is YamlList) {
        for (final raw in conceptList) {
          final concept = _readConcept(raw, name, tier, file);
          if (concepts.containsKey(concept.id)) {
            throw ContentSourceException(
              '${file.path}: концепт ${concept.id} объявлен дважды — '
              'id должен быть уникален глобально, а не в пределах созвездия',
            );
          }
          concepts[concept.id] = concept;
        }
      }
    }
  }

  /// Концепт задаётся либо строкой-идентификатором, либо картой с частью речи
  /// и частотным рангом. Короткая форма нужна, чтобы файл созвездия читался
  /// как список, а не как таблица.
  static ConceptSource _readConcept(
    Object? raw,
    String constellation,
    String tier,
    File file,
  ) {
    if (raw is String) {
      return ConceptSource(
        id: raw,
        tier: tier,
        constellation: constellation,
        pos: 'noun',
      );
    }
    if (raw is YamlMap) {
      return ConceptSource(
        id: _requireString(raw, 'id', file),
        tier: tier,
        constellation: constellation,
        pos: (raw['pos'] as String?) ?? 'noun',
        freqRank: raw['freq_rank'] as int?,
      );
    }
    throw ContentSourceException(
      '${file.path}: tiers.$tier.concepts содержит ни строку, ни карту',
    );
  }

  static void _readPhraseFile(
    File file,
    String lang,
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
      for (final raw in node) {
        if (raw is! YamlMap) {
          throw ContentSourceException(
            '${file.path}: tiers.$tier содержит не карту',
          );
        }
        phrases.add(_readPhrase(raw, lang, tier, name, file));
      }
    }
  }

  static PhraseSource _readPhrase(
    YamlMap raw,
    String lang,
    String tier,
    String constellation,
    File file,
  ) {
    final id = _requireString(raw, 'id', file);
    final template = _requireString(raw, 'template', file);

    // Ответ пишется либо одним словом, либо списком по слотам. Оба вида
    // нужны: один пропуск — самый частый случай, и заставлять писать его
    // списком значит утяжелять четыреста тридцать две строки ради двадцати.
    final single = raw['answer'];
    final many = raw['answers'];
    if ((single == null) == (many == null)) {
      throw ContentSourceException(
        '${file.path}: фраза $id — нужен ровно один из answer / answers',
      );
    }
    final answers = single != null ? ['$single'] : _stringList(many);
    if (answers.isEmpty) {
      throw ContentSourceException(
        '${file.path}: фраза $id — пустой список answers',
      );
    }

    final slots = phraseSlotCount(template);
    if (slots != answers.length) {
      throw ContentSourceException(
        '${file.path}: фраза $id — в шаблоне $slots пропусков, '
        'а ответов ${answers.length}',
      );
    }

    return PhraseSource(
      id: id,
      lang: lang,
      tier: tier,
      constellation: constellation,
      template: template,
      answers: answers,
      optionsBySlot: _optionsBySlot(raw['options'], answers.length, id, file),
      conceptIds: _stringList(raw['concepts']),
      register: raw['register'] as String?,
      ambiguityReviewed: raw['ambiguity'] == 'reviewed',
    );
  }

  /// Неверные слова по слоту.
  ///
  /// `options: [Milch, Wasser]` — плоский список для единственного слота.
  /// `options: [[…], […]]` — по списку на слот. Первый вид годится только
  /// когда пропуск один: иначе непонятно, к какому слоту он относится.
  static List<List<String>> _optionsBySlot(
    Object? node,
    int slots,
    String phraseId,
    File file,
  ) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw ContentSourceException(
        '${file.path}: фраза $phraseId — options должен быть списком',
      );
    }
    if (node.isEmpty) return const [];

    final nested = node.first is YamlList;
    if (!nested) {
      if (slots != 1) {
        throw ContentSourceException(
          '${file.path}: фраза $phraseId — пропусков $slots, поэтому options '
          'нужен списком на слот: [[…], […]]',
        );
      }
      return [_stringList(node)];
    }

    final result = <List<String>>[];
    for (final entry in node) {
      result.add(_stringList(entry));
    }
    if (result.length != slots) {
      throw ContentSourceException(
        '${file.path}: фраза $phraseId — в options ${result.length} групп, '
        'а пропусков $slots',
      );
    }
    return result;
  }

  static LanguageSource _readLanguage(_LanguageEntry entry) {
    final lexemes = <String, LexemeSource>{};
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

      final node = doc['lexemes'];
      if (node is YamlMap) {
        for (final e in node.entries) {
          final conceptId = e.key as String;
          if (lexemes.containsKey(conceptId)) {
            throw ContentSourceException(
              '${file.path}: лексема $conceptId у языка ${entry.code} '
              'объявлена дважды',
            );
          }
          lexemes[conceptId] = _readLexeme(conceptId, e.value, file);
        }
      }

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
      lexemes: lexemes,
      phraseTranslations: translations,
    );
  }

  static LexemeSource _readLexeme(String conceptId, Object? value, File file) {
    if (value is! YamlMap) {
      throw ContentSourceException('${file.path}: lexemes.$conceptId не карта');
    }
    final distractors = value['distractors'];
    return LexemeSource(
      conceptId: conceptId,
      form: _requireString(value, 'form', file),
      article: value['article'] as String?,
      gender: value['gender'] as String?,
      plural: value['plural'] as String?,
      note: value['note'] as String?,
      farDistractors:
          distractors is YamlMap ? _stringList(distractors['far']) : const [],
      nearDistractors:
          distractors is YamlMap ? _stringList(distractors['near']) : const [],
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
      final conceptId = raw['concept'] as String?;
      final phraseId = raw['phrase'] as String?;
      if ((conceptId == null) == (phraseId == null)) {
        throw ContentSourceException(
          '${file.path}: у позиции калибровки должен быть ровно один из '
          'concept / phrase',
        );
      }
      result.add(CalibrationItemSource(
        id: _requireString(raw, 'id', file),
        tier: _requireString(raw, 'tier', file),
        kind: conceptId != null ? 'word' : 'phrase',
        conceptId: conceptId,
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
  /// разбирает не как слова, а как значения. Дистрактор `Null` — настоящее
  /// немецкое существительное (die Null, ноль) — превращался в null, а
  /// интерполяция `'$e'` делала из него строку «null». В круге у слова Müll
  /// стоял вариант, написанный словом «null». Такие слова нужно брать в
  /// кавычки, и проверка об этом прямо говорит.
  static List<String> _stringList(Object? node) {
    if (node is YamlList) {
      return [
        for (final e in node)
          if (e == null)
            throw ContentSourceException(
              'в списке пустое значение — YAML разобрал слово как null. '
              'Слова Null, No, On, Off, Yes и ~ надо брать в кавычки: "Null"',
            )
          else
            '$e',
      ];
    }
    return const [];
  }
}

/// Язык и файлы, из которых он собран.
class _LanguageEntry {
  _LanguageEntry(this.code, this.files);

  final String code;
  final List<File> files;
}
