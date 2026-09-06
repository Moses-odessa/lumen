import 'package:flutter_test/flutter_test.dart';

// `tool/` — отдельная программа и не лежит в `lib/`, поэтому импорт по
// относительному пути.
import '../../tool/phonetics.dart';

/// Созвучность дистракторов проверяется на слух, а не по написанию.
///
/// Тест существует потому, что исходная эвристика сравнивала буквы и на
/// немецком тонула в ложных срабатываниях: `Tour` и `Uhr` рифмуются, но
/// общих букв у них нет. Сотня ложных «сомнительных» делает список
/// бесполезным — настоящие проблемы в нём не разглядеть.
void main() {
  group('звуковая запись', () {
    test('растяжное h не звучит', () {
      expect(germanSoundalike('Uhr'), 'ur');
      expect(germanSoundalike('Zahn'), 'tsan');
    });

    test('дифтонги пишутся одинаково независимо от орфографии', () {
      // ei и ai — один звук, eu и äu — тоже, ß и ss — тоже.
      expect(germanSoundalike('Eis'), germanSoundalike('Ais'));
      expect(germanSoundalike('Eule'), germanSoundalike('Äule'));
      expect(germanSoundalike('Preis').substring(2), 'ajs');
      expect(germanSoundalike('Fleiß').substring(2), 'ajs');
    });

    test('конечное -er — это гласный', () {
      expect(germanSoundalike('Vater'), 'fata');
    });

    test('шипящие и аффрикаты разбираются до одиночных букв', () {
      expect(germanSoundalike('Schule'), 'Sule');
      expect(germanSoundalike('Sechs'), 'seks');
      expect(germanSoundalike('Katze'), 'katse');
    });

    test('удвоения не влияют на звучание', () {
      expect(germanSoundalike('Kaffee'), 'kafe');
    });
  });

  group('созвучность', () {
    test('рифма считается созвучием, даже если пишется иначе', () {
      expect(soundsAlike('Uhr', 'Tour'), isTrue);
      expect(soundsAlike('Uhr', 'Spur'), isTrue);
      expect(soundsAlike('Preis', 'Fleiß'), isTrue);
      expect(soundsAlike('Weg', 'Beleg'), isTrue);
    });

    test('близкое звучание при разном написании', () {
      expect(soundsAlike('Kaffee', 'Karaffe'), isTrue);
      expect(soundsAlike('Vater', 'Watte'), isTrue);
    });

    test('общая тема без общего звучания созвучием не считается', () {
      expect(soundsAlike('Frau', 'Frost'), isFalse);
      expect(soundsAlike('Apotheke', 'Bibliothek'), isFalse);
      expect(soundsAlike('Praxis', 'Achse'), isFalse);
    });

    test('короткому слову хватает двух общих звуков в конце', () {
      // Иначе рифма из двух звуков не находится вовсе, а в немецком
      // односложных слов много.
      expect(soundsAlike('Bus', 'Fluss'), isTrue);
      expect(soundsAlike('Geld', 'Feld'), isTrue);
    });

    test('пустые строки не ломают проверку', () {
      expect(soundsAlike('', 'Uhr'), isFalse);
      expect(soundsAlike('Uhr', ''), isFalse);
    });
  });
}
