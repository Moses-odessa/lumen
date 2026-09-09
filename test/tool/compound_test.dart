@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/compound.dart';
import '../../tool/word_lists.dart';

/// Тесты разбора немецких составных слов.
///
/// Разбор не доказывает существование слова: он отвечает на вопрос
/// «раскладывается ли форма на известные части». Тесты ниже про то, что
/// ответ «да» не даётся слишком легко: разбор, который раскладывает любую
/// строку, бесполезен точно так же, как разбор, который не раскладывает
/// ничего.
void main() {
  // Небольшое множество, где всё известно наперёд, — иначе тест проверял бы
  // содержимое словаря, а не алгоритм.
  const known = {
    'haus',
    'tür',
    'wohnung',
    'genossenschaft',
    'nähr',
    'wert',
    'tabelle',
    'arzt',
    'termin',
    'kind',
    'garten',
    'zeit',
    'plan',
    'stadt',
  };

  group('простые случаи', () {
    test('известное слово раскладывается в себя', () {
      expect(splitsIntoKnown('Haus', known), isTrue);
      expect(compoundParts('Haus', known), ['haus']);
    });

    test('регистр не значим', () {
      // В составном слове вторая часть пишется со строчной, а как лемма —
      // с заглавной, и различать их при проверке нечем.
      expect(splitsIntoKnown('HAUS', known), isTrue);
      expect(splitsIntoKnown('haus', known), isTrue);
    });

    test('незнакомое слово не раскладывается', () {
      expect(splitsIntoKnown('Xylophon', known), isFalse);
      expect(compoundParts('Xylophon', known), isNull);
    });
  });

  group('склейка из двух частей', () {
    test('без соединительного элемента', () {
      expect(compoundParts('Stadtplan', known), ['stadt', 'plan']);
      expect(compoundParts('Hauswert', known), ['haus', 'wert']);
    });

    test('с соединительным -s-', () {
      expect(compoundParts('Wohnungsgenossenschaft', known),
          ['wohnung', 'genossenschaft']);
    });

    test('с соединительным -er-', () {
      expect(compoundParts('Kindergarten', known), ['kind', 'garten']);
    });

    test('три части', () {
      expect(compoundParts('Nährwerttabelle', known),
          ['nähr', 'wert', 'tabelle']);
    });

    test('глубина ограничена', () {
      // Без ограничения разбор находит «части» в любой достаточно длинной
      // строке: чем больше склеек допускается, тем меньше значит успех.
      expect(
        splitsIntoKnown('Nährwerttabelle', known, maxParts: 2),
        isFalse,
        reason: 'три части прошли при бюджете на две',
      );
    });
  });

  group('чего разбор не должен делать', () {
    test('не находит части короче порога', () {
      // С тремя буквами разбор начинает находить «части» в середине любого
      // слова: der, ein, aus встречаются как подстроки повсюду, и любая
      // выдумка раскладывается.
      expect(minCompoundPart, greaterThanOrEqualTo(4));
      expect(splitsIntoKnown('Hauszeit', {'haus', 'zei'}), isFalse);
    });

    test('не раскладывает выдумку из известных обрывков', () {
      // «Beschwerlichkeitn» — настоящая порча из истории этого проекта:
      // на месте «Beschwerden» стояла форма с обрубленным окончанием. Разбор
      // не должен объявить её правдоподобной только потому, что «beschwer»
      // где-то встречается.
      expect(splitsIntoKnown('Beschwerlichkeitn', known), isFalse);
    });

    test('не считает остаток слишком коротким за часть', () {
      expect(splitsIntoKnown('Hausx', known), isFalse);
      expect(splitsIntoKnown('Hausei', known), isFalse);
    });

    test('пустая строка не раскладывается', () {
      expect(splitsIntoKnown('', known), isFalse);
    });

    test('пустой словарь не раскладывает ничего', () {
      // Отсутствие словаря обязано означать «не знаю», а не «всё плохо» и
      // не «всё хорошо». В валидаторе этот случай отдельно объявлен
      // непроверенным.
      expect(splitsIntoKnown('Stadtplan', const {}), isFalse);
    });

    test('трёхбуквенная часть не находится — это названное ограничение', () {
      // «Haustür» = Haus + Tür, и разбор её не найдёт: «tür» короче порога.
      // Порог стоит на четырёх намеренно — с тремя буквами частями
      // становятся `der`, `ein`, `aus`, которые встречаются в середине чего
      // угодно, и раскладывается любая выдумка.
      //
      // Цена названа: составные слова с короткой второй частью (Tür, Bad,
      // Uhr, Hof, Weg, Öl) уходят в канал ручной проверки. Это верное место
      // для них — там их прочитает человек, а не там, где их молча
      // подтвердит алгоритм.
      expect(splitsIntoKnown('Haustür', {...known, 'tür'}), isFalse);
    });
  });

  group('списки слов', () {
    test('строка с причиной читается как одно слово', () {
      final file = _tempFile('''
# комментарий
beschwerlichkeitn  обрубленное окончание, нужно Beschwerden
xylophonx
''');
      addTearDown(() => file.deleteSync());

      expect(readWordList(file), {'beschwerlichkeitn', 'xylophonx'});
      final reasons = readNonWordReasons(file);
      expect(reasons['beschwerlichkeitn'],
          'обрубленное окончание, нужно Beschwerden');
      expect(reasons['xylophonx'], '');
    });

    test('отсутствующий файл даёт пустое множество, а не падение', () {
      expect(readDictionary(r'C:\нет\такого\пути', 'de'), isEmpty);
      expect(readNonWords(r'C:\нет\такого\пути', 'de'), isEmpty);
    });
  });
}

File _tempFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/lumen_words_'
    '${content.hashCode.toUnsigned(32)}.txt',
  );
  file.writeAsStringSync(content);
  return file;
}
