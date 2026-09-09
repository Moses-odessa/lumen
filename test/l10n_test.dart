import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';

/// Локализация ломается тихо: недостающий ключ просто откатывается к
/// английскому, и англоязычный разработчик этого не замечает никогда.
/// Поэтому полнота проверяется тестом, а не вниманием.
void main() {
  final arbDir = Directory('lib/core/l10n/arb');

  Map<String, Object?> read(String lang) {
    final file = File('${arbDir.path}/app_$lang.arb');
    if (!file.existsSync()) {
      // Читается и вне теста (при сборке шаблона), поэтому не expect:
      // matcher за пределами теста бросает OutsideTestException.
      throw StateError('нет ${file.path}');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  }

  /// Ключи без метаданных (`@key`) и без служебных полей.
  Set<String> keysOf(Map<String, Object?> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final template = read('en');
  final templateKeys = keysOf(template);

  test('шаблон непустой и содержит все экраны', () {
    expect(templateKeys.length, greaterThan(100));
    // Проверка на «забыли добавить экран целиком».
    //
    // Префикса `dictionary` в списке больше нет: экран словаря удалён вместе
    // со словарным слоем — единицей изучения стала фраза, и списка слов у
    // игрока не существует.
    for (final prefix in [
      'onboarding',
      'calibration',
      'ritual',
      'run',
      'sky',
      'profile',
      'customWords',
      'settings',
      'about',
    ]) {
      expect(
        templateKeys.any((k) => k.startsWith(prefix)),
        isTrue,
        reason: 'нет ни одного ключа с префиксом $prefix',
      );
    }
  });

  test('во всех локалях те же ключи, что в шаблоне', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final lang = locale.languageCode;
      if (lang == 'en') continue;

      final keys = keysOf(read(lang));
      final missing = templateKeys.difference(keys);
      final extra = keys.difference(templateKeys);

      expect(missing, isEmpty,
          reason: '$lang: не хватает ключей — ${missing.take(5).join(', ')}');
      expect(extra, isEmpty,
          reason: '$lang: лишние ключи — ${extra.take(5).join(', ')}');
    }
  });

  test('плейсхолдеры совпадают со строкой шаблона', () {
    final placeholder = RegExp(r'\{(\w+)\}');

    Set<String> placeholdersOf(String value) =>
        placeholder.allMatches(value).map((m) => m.group(1)!).toSet();

    for (final locale in AppLocalizations.supportedLocales) {
      final lang = locale.languageCode;
      if (lang == 'en') continue;
      final arb = read(lang);

      for (final key in templateKeys) {
        final expected = placeholdersOf(template[key]! as String);
        final actual = placeholdersOf(arb[key]! as String);
        expect(actual, expected,
            reason: '$lang/$key: плейсхолдеры разошлись с шаблоном');
      }
    }
  });

  test('нет пустых переводов', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final arb = read(locale.languageCode);
      for (final key in keysOf(arb)) {
        expect((arb[key]! as String).trim(), isNotEmpty,
            reason: '${locale.languageCode}/$key пустой');
      }
    }
  });

  test('поддерживаются все шесть языков интерфейса', () {
    final langs =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(langs, {'en', 'ru', 'uk', 'de', 'it', 'fr'});
  });

  test('перевод не оставлен английским по недосмотру', () {
    // Грубая проверка на копипасту: если больше четверти строк локали
    // дословно совпадают с английскими, её, скорее всего, не переводили.
    // Исключение — короткие интернационализмы вроде «combo» и «E-mail».
    for (final locale in AppLocalizations.supportedLocales) {
      final lang = locale.languageCode;
      if (lang == 'en') continue;
      final arb = read(lang);

      var identical = 0;
      for (final key in templateKeys) {
        if (arb[key] == template[key]) identical++;
      }

      final share = identical / templateKeys.length;
      expect(share, lessThan(0.25),
          reason: '$lang: ${(share * 100).round()} % строк совпадают с '
              'английскими — похоже, локаль не переведена');
    }
  });
}
