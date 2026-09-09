@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Снимок карты «лемма → идентификатор».
///
/// Идентификатор — это ключ, по которому у игрока лежит память о слове.
/// Перенумеровать их значит стереть прогресс всем, кто уже играл, и сделать
/// это молча: приложение не упадёт, оно просто увидит 5435 незнакомых слов
/// вместо выученных.
///
/// Поэтому карта проверяется отпечатком, а не правилами. Правило можно
/// выполнить и всё равно всё переставить; отпечаток ломается от любого
/// сдвига, и тогда о нём приходится думать, а не узнавать от игрока.
void main() {
  late Map<String, String> ids;

  setUpAll(() {
    final doc = loadYaml(File('content/lexicon_ids.yaml').readAsStringSync());
    ids = {
      for (final e in (doc['ids'] as YamlMap).entries)
        '${e.key}': '${e.value}',
    };
  });

  test('карта не переставлена', () {
    final rows = ids.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
    final digest = sha256.convert(utf8.encode(rows.join('\n')));

    expect(ids.length, 5435);
    expect(
      digest.toString().substring(0, 16),
      'ba2961e992516e00',
      reason: 'Карта идентификаторов изменилась. Дописать лемму в конец — '
          'нормально, и тогда снимок обновляется вместе с числом записей. '
          'Но если число то же, а отпечаток другой — значит, id у '
          'существующего слова стал другим, и это потеря прогресса.',
    );
  });

  test('идентификаторы уникальны и одного вида', () {
    // Форма `lx####` выбрана вместо редакторских `deNNNN` намеренно: в
    // словнике номер кодирует уровень (id строго возрастает по A0→B2), и
    // дописать слово на A0 без перенумерации там нельзя.
    for (final e in ids.entries) {
      expect(e.value, matches(RegExp(r'^lx\d{4,}$')),
          reason: 'лемма ${e.key}: идентификатор не того вида');
    }
    expect(ids.values.toSet().length, ids.length,
        reason: 'один id выдан двум леммам');
  });

  test('совпавшие с существующими леммы сохранили свои слуги', () {
    // 565 лемм словника уже были в контенте под осмысленными слугами — вместе
    // с прогрессом, переводами на четыре языка, дистракторами и вычиткой.
    // Их в карте нет и быть не должно: карта раздаёт id только новым словам.
    for (final lemma in ['Brot', 'Arzt', 'Wasser', 'Milch', 'Adresse']) {
      expect(ids.containsKey(lemma), isFalse,
          reason: '$lemma получил новый id, хотя уже был в контенте');
    }

    final concepts = Directory('content/concepts')
        .listSync()
        .whereType<File>()
        .map((f) => f.readAsStringSync())
        .join();
    for (final slug in ['bread_food', 'doctor_person', 'water_drink']) {
      expect(concepts, contains(slug),
          reason: 'слуг $slug исчез — вместе с ним прогресс игрока');
    }
  });

  test('каждый выданный id стоит ровно в одном концепте', () {
    final used = <String, int>{};
    for (final file in Directory('content/concepts')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'))) {
      for (final match in RegExp(r'id: (lx\d+)')
          .allMatches(file.readAsStringSync())) {
        final id = match.group(1)!;
        used[id] = (used[id] ?? 0) + 1;
      }
    }

    final twice = used.entries.where((e) => e.value > 1).map((e) => e.key);
    expect(twice, isEmpty, reason: 'id стоит в двух концептах');
    expect(used.length, ids.length,
        reason: 'в карте ${ids.length} записей, а в темах ${used.length} — '
            'импорт выдал id и не положил слово');
  });
}
