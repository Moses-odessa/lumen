import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/content_database.dart';
import 'package:lumen/domain/entities/tier.dart';

/// Одна фраза корпуса: текст на изучаемом, перевод на родной, ярус.
typedef CorpusPhrase = ({String id, Tier tier, String target, String native});

/// Крайние строки корпуса, **прочитанные из ассета**.
///
/// Читаются, а не вписаны, и это не педантизм. Корпус уже менялся дважды: была
/// тысяча фраз с многоточиями, стало полторы тысячи без них. Вписанный в тест
/// худший случай был 90 знаков — нынешний 118, а украинский перевод дорос с 66
/// до 97. Тест на вписанных строках продолжал бы зеленеть ровно в тот момент,
/// когда на телефоне появилась бы обрезка: он проверял бы прошлый корпус.
///
/// Ассет — `assets/content/de.db`, тот самый файл, который открывает
/// приложение. Читается он тем же кодом (`ContentDatabase.forLanguage`), то
/// есть тест ошибается вместе с игрой, а не отдельно от неё.
///
/// Грузить это надо из `setUpAll` или другого места **вне** `testWidgets`:
/// внутри теста живут поддельные часы, и настоящий файловый ввод-вывод под
/// ними не завершается никогда.
class CorpusExtremes {
  const CorpusExtremes(this.phrases);

  static Future<CorpusExtremes> load({
    String target = 'de',
    String native = 'uk',
  }) async {
    // Ассет читается через `rootBundle`, а копия базы кладётся в
    // support-директорию: так же, как на устройстве. Обе вещи требуют
    // поднятого биндинга и подложенного `path_provider`.
    TestWidgetsFlutterBinding.ensureInitialized();
    final support = Directory.systemTemp.createTempSync('lumen_corpus');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationSupportDirectory'
          ? support.path
          : null,
    );

    final content = ContentDatabase.forLanguage(target);
    try {
      final rows = await content.phrasesUpTo(Tier.values.last);
      // Переводы берутся пачками: один запрос на полторы тысячи
      // идентификаторов упирается в предел числа параметров SQLite.
      final translations = <String, String>{};
      for (var i = 0; i < rows.length; i += 400) {
        final chunk = rows.skip(i).take(400).map((r) => r.id);
        translations.addAll(await content.translationsFor(chunk, native));
      }
      return CorpusExtremes([
        for (final row in rows)
          (
            id: row.id,
            tier: Tier.fromCode(row.tier),
            target: row.sentence,
            native: translations[row.id] ?? '',
          ),
      ]);
    } finally {
      await content.close();
    }
  }

  /// Все фразы корпуса в авторском порядке.
  final List<CorpusPhrase> phrases;

  /// [count] самых длинных фраз на изучаемом языке; [on] — только этот ярус.
  ///
  /// Длина считается в знаках, а не в отрисованной ширине, и для худшего
  /// случая этого достаточно: шрифт один на все шесть вариантов, и самая
  /// длинная строка занимает больше всех строк в капсуле.
  List<String> longestTarget(int count, {Tier? on}) =>
      _longest(count, on: on, pick: (p) => p.target);

  /// [count] самых длинных переводов на родной язык.
  List<String> longestNative(int count, {Tier? on}) =>
      _longest(count, on: on, pick: (p) => p.native);

  /// [count] самых коротких фраз на изучаемом языке.
  ///
  /// Другой конец той же шкалы: раскладка обязана быть хороша и здесь, иначе
  /// «Danke!» получит капсулу во всю ширину полосы, и круг превратится в
  /// список одинаковых плит.
  List<String> shortestTarget(int count, {Tier? on}) =>
      _longest(count, on: on, pick: (p) => p.target, longestFirst: false);

  /// [count] самых коротких переводов на родной язык.
  List<String> shortestNative(int count, {Tier? on}) =>
      _longest(count, on: on, pick: (p) => p.native, longestFirst: false);

  List<String> _longest(
    int count, {
    required Tier? on,
    required String Function(CorpusPhrase) pick,
    bool longestFirst = true,
  }) {
    final texts = [
      for (final phrase in phrases)
        if (on == null || phrase.tier == on)
          if (pick(phrase).isNotEmpty) pick(phrase),
    ]..sort((a, b) => longestFirst
        ? b.length.compareTo(a.length)
        : a.length.compareTo(b.length));
    return texts.take(count).toList();
  }
}
