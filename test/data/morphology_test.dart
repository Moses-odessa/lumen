import 'package:flutter_test/flutter_test.dart';

// `tool/` — отдельная программа и не лежит в `lib/`, поэтому импорт по
// относительному пути.
import '../../tool/morphology.dart';

/// Поле `plural` заполняется не тем, чем должно.
///
/// Тест существует потому, что этот класс ошибок нашли два независимых
/// человека и ни разу не нашла машина: поле есть в схеме, и заполнить его
/// хочется всегда — даже у неисчисляемых. Тогда вместо формы слова туда
/// попадает выдуманное составное: «Milch» → «Milchsorten». Игрок учит слово,
/// которого в его словаре нет.
///
/// Цена ошибки в другую сторону не меньше: правило, которое ругается на
/// «Dosis / Dosen», заставит автора контента отключить проверку целиком.
void main() {
  group('немецкое множественное', () {
    test('суффикс с умлаутом и без', () {
      expect(isGermanPlural('Arzt', 'Ärzte'), isTrue);
      expect(isGermanPlural('Hand', 'Hände'), isTrue);
      expect(isGermanPlural('Kopf', 'Köpfe'), isTrue);
      expect(isGermanPlural('Schmerz', 'Schmerzen'), isTrue);
      expect(isGermanPlural('Auto', 'Autos'), isTrue);
    });

    test('форма без изменения — тоже множественное', () {
      expect(isGermanPlural('Zimmer', 'Zimmer'), isTrue);
      expect(isGermanPlural('Wecker', 'Wecker'), isTrue);
    });

    test('удвоение конечной согласной', () {
      expect(isGermanPlural('Bus', 'Busse'), isTrue);
    });

    test('заимствования меняют конец основы', () {
      expect(isGermanPlural('Dosis', 'Dosen'), isTrue);
      expect(isGermanPlural('Praxis', 'Praxen'), isTrue);
      expect(isGermanPlural('Firma', 'Firmen'), isTrue);
      expect(isGermanPlural('Ära', 'Ären'), isTrue);
      expect(isGermanPlural('Kautionskonto', 'Kautionskonten'), isTrue);
      expect(isGermanPlural('Betriebsklima', 'Betriebsklimata'), isTrue);
    });

    test('множественное другой лексемы не проходит', () {
      // Ровно те находки, которые пришли из независимой вычитки.
      expect(isGermanPlural('Milch', 'Milchsorten'), isFalse);
      expect(isGermanPlural('Hunger', 'Hungersnöte'), isFalse);
      expect(isGermanPlural('Gepäck', 'Gepäckstücke'), isFalse);
      expect(isGermanPlural('Zeitdruck', 'Zeitzwänge'), isFalse);
      expect(isGermanPlural('Erbe', 'Erbschaften'), isFalse);
      expect(isGermanPlural('Verbraucherschutz', 'Verbraucherschutzregeln'),
          isFalse);
    });

    test('слово, начинающееся так же, но другое — не форма', () {
      // Общее начало ничего не доказывает: проверка идёт по суффиксу целиком.
      expect(isGermanPlural('Post', 'Postämter'), isFalse);
      expect(isGermanPlural('Nahverkehr', 'Nahverkehrsnetze'), isFalse);
    });
  });

  group('субстантивированное прилагательное', () {
    test('сильная форма при определённом артикле узнаётся', () {
      expect(
        isMisdeclinedAdjectivalNoun('Vorgesetzter', 'Vorgesetzte'),
        isTrue,
      );
      expect(isMisdeclinedAdjectivalNoun('Angestellter', 'Angestellte'), isTrue);
    });

    test('обычное существительное на -er не путается с ним', () {
      // У «Wecker» множественное совпадает с формой, а не короче её на -r.
      expect(isMisdeclinedAdjectivalNoun('Wecker', 'Wecker'), isFalse);
      expect(isMisdeclinedAdjectivalNoun('Arzt', 'Ärzte'), isFalse);
    });
  });

  group('свёртка написания', () {
    test('ß и ss — одно слово', () {
      expect(foldSpelling('Größe'), foldSpelling('Grösse'));
    });

    test('умлаут различает слова и в свёртку написания не входит', () {
      // Küche и Kuchen — разные слова, и дистрактор «Kuchen» законен.
      expect(foldSpelling('Küche') == foldSpelling('Kuchen'), isFalse);
      expect(foldSpelling('Schränke') == foldSpelling('Schranke'), isFalse);
      // А в образовании формы умлаут снимается: Schrank → Schränke.
      expect(foldUmlaut('Schränke'), 'schranke');
    });
  });
}
