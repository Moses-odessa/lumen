/// Чтение YAML-исходников контента. Формат описан в
/// docs/CONTENT_PIPELINE.md: файл на созвездие задаёт, какие концепты
/// добавляются на каком ярусе, файл на язык — формы и дистракторы.
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
}

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

class PhraseSource {
  PhraseSource({
    required this.id,
    required this.tier,
    required this.constellation,
    required this.template,
    required this.answer,
    required this.conceptIds,
    this.register,
  });

  final String id;
  final String tier;
  final String constellation;
  final String template;
  final String answer;
  final List<String> conceptIds;
  final String? register;
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

  /// Кто читал. Строка человеческая: важно не имя, а то, носитель или нет.
  final String by;

  /// Какие созвездия прочитаны. Сверяется с составом яруса.
  final Set<String> constellations;
}

/// Какие ярусы языка запущены, а какие только написаны.
///
/// Машинная форма правила «язык не запускается, пока его ярусы не вычитаны
/// человеком»: валидатор требует полноты только от запущенных ярусов и не
/// даёт объявить запущенным ярус, вычитанный наполовину.
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
    required this.lexemes,
    required this.phrases,
    required this.calibration,
    required this.hash,
    this.launch = const LaunchPolicy(),
  });

  /// Политика запуска ярусов.
  final LaunchPolicy launch;

  /// Хеш всех прочитанных файлов: попадает в `content_meta.source_hash` и
  /// позволяет по собранному ассету понять, из чего он собран, не полагаясь
  /// на метку времени.
  final String hash;

  /// Имена созвездий в порядке файлов.
  final List<String> constellations;

  /// Концепты по id.
  final Map<String, ConceptSource> concepts;

  /// Лексемы: язык → concept_id → лексема.
  final Map<String, Map<String, LexemeSource>> lexemes;

  final List<PhraseSource> phrases;

  /// Набор калибровки по языку изучения.
  final Map<String, List<CalibrationItemSource>> calibration;

  static ContentSources load(Directory root, {String lang = targetLang}) {
    if (!root.existsSync()) {
      throw ContentSourceException(
        'нет каталога исходников ${root.path} — см. docs/CONTENT_PIPELINE.md',
      );
    }

    final constellations = <String>[];
    final concepts = <String, ConceptSource>{};
    final phrases = <PhraseSource>[];

    // Порядок файлов фиксирован сортировкой: он определяет порядок вставки
    // в базу, а значит и байты собранного ассета.
    final constellationFiles = _yamlFiles(
      Directory('${root.path}/constellations'),
    );
    if (constellationFiles.isEmpty) {
      throw ContentSourceException(
        'в ${root.path}/constellations нет ни одного .yaml',
      );
    }
    for (final file in constellationFiles) {
      _readConstellation(file, constellations, concepts, phrases);
    }

    final lexemes = <String, Map<String, LexemeSource>>{};
    final langFiles = <File>[];
    for (final lang in projectLangs) {
      final file = File('${root.path}/lang/$lang.yaml');
      if (!file.existsSync()) continue;
      langFiles.add(file);
      lexemes[lang] = _readLexemes(file, lang);
    }
    if (lexemes.isEmpty) {
      throw ContentSourceException('нет ни одного файла content/lang/*.yaml');
    }

    final calibration = <String, List<CalibrationItemSource>>{};
    final calibrationFiles = _yamlFiles(
      Directory('${root.path}/calibration'),
    );
    for (final file in calibrationFiles) {
      final lang = file.uri.pathSegments.last.replaceAll('.yaml', '');
      calibration[lang] = _readCalibration(file);
    }

    return ContentSources(
      constellations: constellations,
      concepts: concepts,
      lexemes: lexemes,
      phrases: phrases,
      calibration: calibration,
      launch: LaunchPolicy.read(File('${root.path}/launch.yaml'), lang),
      hash: _hashOf([
        ...constellationFiles,
        ...langFiles,
        ...calibrationFiles,
        File('${root.path}/launch.yaml'),
      ]),
    );
  }

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
    // Исходники — текстовые YAML на десятки килобайт, поэтому склеить их в
    // памяти дешевле, чем возиться с потоковым хешированием.
    final buffer = BytesBuilder(copy: false);
    for (final file in files) {
      if (!file.existsSync()) continue;
      buffer.add(utf8.encode(file.uri.pathSegments.last));
      buffer.add(file.readAsBytesSync());
    }
    return sha256.convert(buffer.takeBytes()).toString().substring(0, 16);
  }

  static void _readConstellation(
    File file,
    List<String> constellations,
    Map<String, ConceptSource> concepts,
    List<PhraseSource> phrases,
  ) {
    final doc = _loadMap(file);
    final name = _requireString(doc, 'constellation', file);
    constellations.add(name);

    final tierMap = doc['tiers'];
    if (tierMap is! YamlMap) {
      throw ContentSourceException('${file.path}: нет секции tiers');
    }

    for (final tier in tiers) {
      final node = tierMap[tier];
      if (node == null) continue;
      if (node is! YamlMap) {
        throw ContentSourceException('${file.path}: tiers.$tier не карта');
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

      final phraseList = node['phrases'];
      if (phraseList is YamlList) {
        for (final raw in phraseList) {
          if (raw is! YamlMap) {
            throw ContentSourceException(
              '${file.path}: tiers.$tier.phrases содержит не карту',
            );
          }
          phrases.add(PhraseSource(
            id: _requireString(raw, 'id', file),
            tier: tier,
            constellation: name,
            template: _requireString(raw, 'template', file),
            answer: _requireString(raw, 'answer', file),
            conceptIds: _stringList(raw['concepts']),
            register: raw['register'] as String?,
          ));
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

  static Map<String, LexemeSource> _readLexemes(File file, String lang) {
    final doc = _loadMap(file);
    final declared = doc['lang'];
    if (declared != lang) {
      throw ContentSourceException(
        '${file.path}: внутри указан язык "$declared", а файл называется '
        '"$lang.yaml"',
      );
    }

    final node = doc['lexemes'];
    if (node is! YamlMap) {
      throw ContentSourceException('${file.path}: нет секции lexemes');
    }

    final result = <String, LexemeSource>{};
    for (final entry in node.entries) {
      final conceptId = entry.key as String;
      final value = entry.value;
      if (value is! YamlMap) {
        throw ContentSourceException(
          '${file.path}: lexemes.$conceptId не карта',
        );
      }
      final distractors = value['distractors'];
      result[conceptId] = LexemeSource(
        conceptId: conceptId,
        form: _requireString(value, 'form', file),
        article: value['article'] as String?,
        gender: value['gender'] as String?,
        plural: value['plural'] as String?,
        note: value['note'] as String?,
        farDistractors: distractors is YamlMap
            ? _stringList(distractors['far'])
            : const [],
        nearDistractors: distractors is YamlMap
            ? _stringList(distractors['near'])
            : const [],
      );
    }
    return result;
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
      throw ContentSourceException('${file.path}: ожидалась карта на верхнем уровне');
    }
    return doc;
  }

  static String _requireString(YamlMap map, String key, File file) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw ContentSourceException('${file.path}: нет обязательного поля "$key"');
  }

  static List<String> _stringList(Object? node) {
    if (node is YamlList) return node.map((e) => '$e').toList();
    return const [];
  }
}
