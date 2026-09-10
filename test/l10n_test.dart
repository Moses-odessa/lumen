import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:yaml/yaml.dart';

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
    //
    // Префикса `customWords` тоже нет: экран «Свои слова» удалён вместе с
    // таблицей `custom_concepts` (миграция v7). Таблица держала личные пары
    // игрока «слово → перевод», и не читала их ни одна механика — ни
    // планировщик, ни сборщик вопросов, ни небо. Форма, которая молча
    // съедает работу человека, хуже отсутствующей формы, а в разговорнике
    // она к тому же просила слово там, где единица изучения — фраза.
    //
    // Префикса `band` нет по третьей причине. Пять ключей (`bandBurning`,
    // `bandSteady`, `bandFlickering`, `bandDimming`, `bandFading`) переводили
    // имена полос яркости из `LumenBand` — и не читал их ни один экран, ни
    // один виджет, ни один тест. Тридцать переведённых строк удалены не за
    // неиспользуемость: они были **вторым набором слов** для тех же пяти
    // полос, и именно так одно слово стало значить четыре разных порога —
    // «світять» стояло и над 15 lm в сводке неба, и над 70 на карточке
    // созвездия, и над 85 в строке профиля, и над флагом скорости. Пока
    // лишний словарь лежит рядом непоказанным, следующее расхождение
    // заводится в нём молча. Понадобится подписывать полосы — ключи
    // заводятся заново и сразу с читателем; разбор порогов записан у
    // `SkySnapshot.litStars`.
    //
    // Префикс `reminder` в списке **есть**, и он единственный не про экран.
    // Текст напоминания — единственное, что приходит к игроку само, и до
    // этих ключей он приходил русскими литералами из
    // `notification_service.dart` при любом языке интерфейса. Пустой список
    // ключей `reminder*` означал бы, что литералы вернулись на место.
    for (final prefix in [
      'onboarding',
      'calibration',
      'ritual',
      'run',
      'sky',
      'profile',
      'settings',
      'about',
      'reminder',
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

  test('плюрал не теряется при переводе', () {
    // «1 фраз із тесту вже світять» — так это выглядело на экране. Число
    // подставлялось в строку с существительным в одной готовой форме, и на
    // единице фраза ломалась сразу во всех шести локалях. Формы ICU были
    // ровно у одного сообщения из шести, которым они нужны
    // (`reminderDimmingTitle`), — у остальных пяти стояла голая подстановка.
    //
    // Формы живут в ARB, а не в склейке на Dart, по той же причине, по
    // которой здесь вообще есть тест: склейка требует, чтобы каждое место
    // показа знало правила своего языка, а правил шесть разных — русский и
    // украинский различают one/few/many, остальные четыре языка one/other.
    // Одно место показа, забывшее об этом, возвращает «1 фраз».
    //
    // Шаблон здесь — объявление: `plural` у ключа в `app_en.arb` значит
    // «число в этом сообщении управляет согласованием», и тогда формы
    // обязаны быть во всех локалях. Английские ветки `profileBrightOf`
    // поэтому одинаковы («1 of 30 bright» и «3 of 30 bright» по-английски
    // не различаются) — они и есть объявление, а не забытая правка;
    // gen-l10n сам принял бы плюрал в одной локали и без шаблона.
    final declaration = RegExp(r'\{(\w+), plural,');
    final branch = RegExp(r'(?:^|[\s{])(zero|one|two|few|many|other)\{');

    // Формы, без которых язык врёт на каком-нибудь числе. `other` нужен
    // везде: на него ICU падает, когда подходящей ветки нет.
    const required = {
      'en': {'one', 'other'},
      'de': {'one', 'other'},
      'fr': {'one', 'other'},
      'it': {'one', 'other'},
      'ru': {'one', 'few', 'many', 'other'},
      'uk': {'one', 'few', 'many', 'other'},
    };

    // Ключ → по какому числу считается плюрал. Число именно одно: в
    // `ritualDoneBody` их два, но склоняется только счёт фраз, а `lm` —
    // символ единицы, который не изменяется ни в одном из шести языков.
    final plural = {
      for (final key in templateKeys)
        if (declaration.firstMatch(template[key]! as String) case final m?)
          key: m.group(1)!,
    };
    expect(plural, isNotEmpty,
        reason: 'в шаблоне не осталось ни одного плюрала — либо ключи '
            'переименованы, либо формы потеряли, и тест сторожит пустоту');

    for (final locale in AppLocalizations.supportedLocales) {
      final lang = locale.languageCode;
      final arb = read(lang);

      for (final entry in plural.entries) {
        final value = arb[entry.key]! as String;
        final match = declaration.firstMatch(value);
        expect(match, isNotNull,
            reason: '$lang/${entry.key}: число подставлено без плюрала — '
                'на единице получится «1 фраз»');
        expect(match!.group(1), entry.value,
            reason: '$lang/${entry.key}: плюрал считается по «${match.group(1)}», '
                'а согласование в шаблоне ведёт «${entry.value}»');

        final forms = branch.allMatches(value).map((m) => m.group(1)!).toSet();
        final missing = required[lang]!.difference(forms);
        expect(missing, isEmpty,
            reason: '$lang/${entry.key}: не хватает форм — '
                '${missing.join(', ')}');
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

  test('локаль не сбивается с «вы» на «ты» посреди себя', () {
    // Форма обращения — свойство локали целиком, и держать её вниманием не
    // получилось: украинский и русский были на «ви»/«вы» в тринадцати
    // строках и на «ти»/«ты» в двух («Твої рекорди», «Зіграй рівень»), причём
    // обе стояли рядом с «Ваше небо». Во французском то же расхождение было
    // в тех же двух ключах, в немецком — одно «Ihnen» на всю локаль,
    // выбранную на «du». Игрок читает это как двух разных авторов.
    //
    // Выбор в каждой локали — за большинством уже написанного, а не за
    // вкусом: uk/ru/fr на вежливом обращении, de/it на «ты». Правило не
    // выведено из языка (в немецком приложении вежливое «Sie» так же
    // законно) — оно выведено из того, что уже переведено, и менять его
    // теперь значит переписывать локаль целиком, а не одну строку.
    //
    // Проверка узкая намеренно. В формальных локалях ищутся однозначные
    // «ты»-формы; в de/it — только те вежливые, которые не путаются с
    // третьим лицом: немецкое `sie` («они») и итальянское `sue` («её»)
    // отличаются от вежливых лишь заглавной буквой, и широкий шаблон дал бы
    // ложные срабатывания на «Alte Sterne bleiben, wo sie sind». То есть
    // тест ловит возврат прежнего расхождения, а не любое мыслимое.
    const informal = {
      'uk': ['ти', 'тебе', 'тобі', 'твій', 'твоя', 'твоє', 'твої', 'зіграй',
        'грай', 'візьми', 'почни'],
      'ru': ['ты', 'тебя', 'тебе', 'твой', 'твоя', 'твоё', 'твои', 'сыграй',
        'играй', 'возьми', 'начни'],
      'fr': ['tu', 'toi', 'ton', 'tes', 'joue'],
    };
    const formal = {
      'de': ['Ihnen', 'Ihrem', 'Ihren', 'Ihrer'],
      'it': ['Lei', 'Suo', 'Sua', 'Suoi'],
    };

    /// Границы слова с учётом диакритики и кириллицы.
    ///
    /// `\b` в Dart считает словом только ASCII, поэтому `\btes\b` совпадало с
    /// французским «êtes»: между «ê» и «t» для него граница слова. Ровно так
    /// проверка и покраснела в первый раз — на строке без единого «ты».
    const letter = r'[A-Za-zÀ-ɏЀ-ӿ]';
    RegExp asWords(List<String> forms, {required bool ignoreCase}) => RegExp(
          '(?<!$letter)(?:${forms.join('|')})(?!$letter)',
          caseSensitive: !ignoreCase,
        );

    List<String> slipsIn(String lang, RegExp pattern) {
      final arb = read(lang);
      return keysOf(arb).where((k) => pattern.hasMatch(arb[k]! as String)).toList()
        ..sort();
    }

    for (final entry in informal.entries) {
      final slips = slipsIn(entry.key, asWords(entry.value, ignoreCase: true));
      expect(slips, isEmpty,
          reason: '${entry.key}: локаль на вежливом обращении, а здесь «ты» '
              '— ${slips.join(', ')}');
    }

    for (final entry in formal.entries) {
      final slips = slipsIn(entry.key, asWords(entry.value, ignoreCase: false));
      expect(slips, isEmpty,
          reason: '${entry.key}: локаль на «ты», а здесь вежливое обращение '
              '— ${slips.join(', ')}');
    }
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

  test('текст о контенте опирается на ноль проходов вычитки', () {
    // Экран «О приложении» говорит игроку: фразы написала языковая модель, и
    // после неё их не читал никто. Это утверждение о качестве того, по чему
    // человек учит язык, и держится оно на одном факте — `passes` в
    // `content/launch.yaml` пусты у всех ярусов.
    //
    // Раньше там стояло обратное («перекрёстно проверены второй моделью»), и
    // ничего не покраснело, когда это перестало быть правдой: текст не был
    // связан ни с чем. Связать его с данными честно нельзя и сейчас —
    // единственное, что доезжает до приложения, это
    // `content_meta.launched_tiers`, а launched не значит «прочитан»: A0
    // запущен решением автора при `passes: []`. Поэтому сторожем стоит тест,
    // и сторожит он не формулировку (отрицание словами не проверить: у
    // немецкого «niemand gegengelesen» те же слова, что у обещания), а тот
    // самый факт, на который формулировка опирается.
    //
    // Ходить приходится по YAML напрямую, а не через `LaunchPolicy.read`:
    // тот читает один язык по имени, а обещание на экране — про весь корпус,
    // включая язык, которого в файле ещё нет.
    final file = File('content/launch.yaml');
    expect(file.existsSync(), isTrue,
        reason: 'нет content/launch.yaml — подтвердить, что вычитки не '
            'было, стало нечем, а текст на экране это утверждает');

    final doc = loadYaml(file.readAsStringSync());
    final found = <String>[];
    if (doc is YamlMap) {
      for (final lang in doc.entries) {
        final reviewers = (lang.value as YamlMap?)?['reviewers'];
        if (reviewers is! YamlMap) continue;
        for (final tier in reviewers.entries) {
          final passes = (tier.value as YamlMap?)?['passes'];
          if (passes is YamlList && passes.isNotEmpty) {
            found.add('${lang.key}/${tier.key}: ${passes.length}');
          }
        }
      }
    }

    expect(found, isEmpty,
        reason: 'в launch.yaml появились проходы вычитки (${found.join('; ')}) '
            '— значит «после неё их не вычитывал никто» на экране «О '
            'приложении» больше не правда. Переписать в шести локалях '
            'aboutReviewTitle, aboutReviewBody и aboutReviewLimit, а этот '
            'тест — на то, что там теперь сказано');
  });
}
