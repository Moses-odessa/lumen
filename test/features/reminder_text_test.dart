import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/core/notifications/notification_service.dart';

/// Формулировки напоминаний проверяются тестом, потому что именно они решают,
/// отключит игрок уведомления или нет. «Не забудь позаниматься» отключают
/// после третьего раза.
///
/// **Тест переписан с литералов на свойства, и это не вкусовщина.** Прежний
/// проверял русские строки: `expect(text.title, 'Небо в порядке')`,
/// `expect(text.body, contains('Две минуты'))`. Он был зелёным всё время,
/// пока напоминание приходило по-русски игроку с украинским интерфейсом, —
/// и он же был причиной, по которой вычитка дважды прошла мимо: строка в
/// тесте выглядит как решение, а не как дефект. Литерал в тесте цементирует
/// язык; свойство — нет.
///
/// Свойств два, и оба про то, чем прежнее устройство было плохо:
///
/// 1. **Текст на языке интерфейса целиком.** Проверяется не совпадением со
///    строкой, а тем, что шесть локалей дают шесть разных текстов: локаль,
///    забытая в коде, немедленно совпала бы с чужой. Ветку при этом
///    сверяем с ключом (`l10n.reminderCalmTitle`), а не со строкой — так
///    тест говорит «взята ветка спокойного неба», не называя её слов.
/// 2. **Согласование числа со словом.** «1 звёзд тускнеют» и «21 звёзд
///    тускнеют» получались конкатенацией и никак иначе получиться не могли.
///    Здесь проверяется форма: у русского и украинского форма для 1 не та,
///    что для 5, а форма для 21 — та же, что для 1. Конкатенация это
///    провалит, а перевод, где формы перепутаны, — тоже.
///
/// Созвездие подставляется **именем темы**, как оно лежит в контентной базе
/// («Самочувствие и врач»), а не слагом. Дыры это не закрывает:
/// [ReminderText] — чистая функция, и на `health_doctor` в аргументе она
/// согласится с той же охотой. Но именно так игрок и получал на телефон «В
/// созвездии «place_time_price»» — функция была права, а аргумент ей собирал
/// планировщик, — и фикстура формы слага учила бы, что так и надо. Кто
/// проверяет сам аргумент, написано в `reminder_scheduler_test.dart`: там
/// путь от базы до текста проходится целиком, на настоящем ассете.
void main() {
  /// Строки локали без дерева виджетов — тем же способом, которым их берёт
  /// планировщик: `load` принимает локаль аргументом.
  Future<AppLocalizations> l10nFor(String lang) =>
      AppLocalizations.delegate.load(Locale(lang));

  final langs = [
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  ];

  ({String title, String body}) dimming(AppLocalizations l10n, int stars) =>
      ReminderText.build(
        l10n: l10n,
        dimmingStars: stars,
        constellation: 'Самочувствие и врач',
        orbit: 5,
        missesBeforeReset: 3,
      );

  group('текст напоминания', () {
    test('называет конкретное число звёзд и созвездие', () async {
      final text = dimming(await l10nFor('ru'), 7);

      expect(text.title, contains('7'));
      expect(text.body, contains('Самочувствие и врач'));
    });

    test('обещание двух минут — часть договорённости', () async {
      // Проверяется на шаблоне, то есть на английском: «две минуты, а не
      // занятие» — это утверждение о смысле, и смысл задаёт `app_en.arb`.
      // Остальные пять локалей держит `l10n_test.dart` (паритет ключей и
      // проверка «локаль не оставлена английской»), а не пять литералов
      // здесь: список слов «две минуты» на шести языках — это тот же
      // цемент, от которого тест и переписан.
      final en = await l10nFor('en');
      expect(dimming(en, 7).body.toLowerCase(), contains('two minutes'));
      expect(
        ReminderText.build(
          l10n: en,
          dimmingStars: 40,
          constellation: null,
          orbit: 12,
          missesBeforeReset: 1,
        ).body.toLowerCase(),
        contains('two minutes'),
      );
    });

    test('без созвездия всё равно называет число', () async {
      final text = ReminderText.build(
        l10n: await l10nFor('ru'),
        dimmingStars: 12,
        constellation: null,
        orbit: 3,
        missesBeforeReset: 3,
      );
      expect(text.title, contains('12'));
      expect(text.body, isNotEmpty);
    });

    test('угроза орбите важнее тускнеющих звёзд', () async {
      // Орбиту можно потерять безвозвратно, а звёзды вернутся.
      final l10n = await l10nFor('ru');
      final text = ReminderText.build(
        l10n: l10n,
        dimmingStars: 40,
        constellation: 'Самочувствие и врач',
        orbit: 12,
        missesBeforeReset: 1,
      );
      expect(text.title, l10n.reminderOrbitTitle(12));
      expect(text.body, l10n.reminderOrbitBody);
    });

    test('без орбиты угрозой не пугаем', () async {
      final l10n = await l10nFor('ru');
      final text = ReminderText.build(
        l10n: l10n,
        dimmingStars: 5,
        constellation: 'Жильё и неполадки',
        orbit: 0,
        missesBeforeReset: 1,
      );
      expect(text.title, l10n.reminderDimmingTitle(5));
    });

    test('когда повторять нечего, напоминание не выдумывает повод', () async {
      final l10n = await l10nFor('ru');
      final text = ReminderText.build(
        l10n: l10n,
        dimmingStars: 0,
        constellation: null,
        orbit: 4,
        missesBeforeReset: 3,
      );
      expect(text.title, l10n.reminderCalmTitle);
      expect(text.body, l10n.reminderCalmBody);
    });
  });

  group('язык напоминания', () {
    test('все шесть локалей дают разные тексты', () async {
      // Локаль, забытая в коде (или литерал, вернувшийся на место строки из
      // arb), совпала бы с чужой — и это единственный способ поймать
      // «уведомление приходит по-русски всем шести», не выписывая шесть
      // ожидаемых строк.
      for (final branch in ['dimming', 'orbit', 'calm']) {
        final seen = <String, String>{};
        for (final lang in langs) {
          final l10n = await l10nFor(lang);
          final text = switch (branch) {
            'dimming' => dimming(l10n, 7),
            'orbit' => ReminderText.build(
                l10n: l10n,
                dimmingStars: 0,
                constellation: null,
                orbit: 12,
                missesBeforeReset: 1,
              ),
            _ => ReminderText.build(
                l10n: l10n,
                dimmingStars: 0,
                constellation: null,
                orbit: 4,
                missesBeforeReset: 3,
              ),
          };
          final other = seen[text.title];
          expect(other, isNull,
              reason: '$branch: $lang и $other дают один заголовок '
                  '«${text.title}» — одна из локалей не переведена или '
                  'строка вернулась литералом в код');
          seen[text.title] = lang;
        }
      }
    });

    test('имя созвездия остаётся в обёртке того же языка', () async {
      // Прежняя поломка была не «текст не переведён», а хуже: имя темы
      // приходило уже переведённым (его собирает `ConstellationNaming` по
      // языку интерфейса), а фраза вокруг него была русской. Проверяем, что
      // обёртка и имя из одной локали.
      for (final lang in langs) {
        final l10n = await l10nFor(lang);
        expect(
          dimming(l10n, 7).body,
          l10n.reminderDimmingIn('Самочувствие и врач'),
        );
      }
    });
  });

  group('согласование числа', () {
    /// Форма фразы без самого числа: «Тускнеют 21 звезда» → «Тускнеют #
    /// звезда». Сравнивать формы, а не строки, — единственный способ
    /// проверить согласование, не выписывая его словами.
    String shapeOf(AppLocalizations l10n, int n) =>
        l10n.reminderDimmingTitle(n).replaceAll('$n', '#');

    test('единственное и множественное различаются во всех локалях', () async {
      for (final lang in langs) {
        final l10n = await l10nFor(lang);
        expect(shapeOf(l10n, 1), isNot(shapeOf(l10n, 2)),
            reason: '$lang: одна звезда и две названы одинаково');
        expect(l10n.reminderDimmingTitle(7), contains('7'),
            reason: '$lang: число потерялось из заголовка');
      }
    });

    test('у русского и украинского три формы, и выбраны они верно', () async {
      // Правила CLDR для обоих: one — 1, 21, 101; few — 2..4, 22..24;
      // many — 0, 5..20, 25..30. Здесь не повторяется таблица правил, а
      // проверяется наблюдаемое следствие: числа одной категории дают одну
      // форму, разных — разные. «1 звёзд тускнеют» проваливает первую
      // проверку, потому что форма для 1 совпала бы с формой для 5.
      for (final lang in ['ru', 'uk']) {
        final l10n = await l10nFor(lang);

        final one = shapeOf(l10n, 1);
        final few = shapeOf(l10n, 2);
        final many = shapeOf(l10n, 5);
        expect({one, few, many}, hasLength(3),
            reason: '$lang: три категории склеились в меньшее число форм');

        for (final n in [21, 101]) {
          expect(shapeOf(l10n, n), one, reason: '$lang: $n не как 1');
        }
        for (final n in [3, 4, 22]) {
          expect(shapeOf(l10n, n), few, reason: '$lang: $n не как 2');
        }
        for (final n in [0, 11, 14, 25]) {
          expect(shapeOf(l10n, n), many, reason: '$lang: $n не как 5');
        }
      }
    });

    test('плюрал живёт в arb, а не собирается конкатенацией', () async {
      // Прямая проверка на возврат прежнего устройства: у ключа в каждой
      // локали должна быть ICU-форма. Без неё код снова сможет склеить
      // число со словом и остаться зелёным на всех проверках выше, если
      // переводчик подберёт формы «на глаз».
      for (final lang in langs) {
        final arb = jsonDecode(
          File('lib/core/l10n/arb/app_$lang.arb').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(arb['reminderDimmingTitle'], startsWith('{count, plural,'),
            reason: '$lang: заголовок про тускнеющие звёзды не плюрал');
      }
    });
  });
}
