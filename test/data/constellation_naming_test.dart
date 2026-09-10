import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/content/constellation_naming.dart';

/// Правило показа имени созвездия проверяется здесь, а не в тесте схемы:
/// схема отвечает за то, что имена доедут из ассета, а это — за то, что
/// доехавшего не хватило и подпись всё равно не пустая.
///
/// Все четыре случая проверяются отдельно намеренно: откат — это цепочка, и
/// сломанное звено видно только по своему случаю. Проверка «есть имя на языке
/// интерфейса» зелена при любом устройстве отката.
void main() {
  test('язык интерфейса важнее языка подсказок', () {
    const naming = ConstellationNaming(
      interfaceNames: {'first_contact': 'Erster Kontakt'},
      nativeNames: {'first_contact': 'Перший контакт'},
    );

    expect(naming.nameOf('first_contact'), 'Erster Kontakt');
  });

  test('нет имени на языке интерфейса — берётся язык подсказок', () {
    // Так живёт француз: интерфейс на французском, а французского контента
    // нет вовсе. Имён пять языков, интерфейсов шесть — этот случай не
    // экзотика, а один из шести.
    const naming = ConstellationNaming(
      interfaceNames: {},
      nativeNames: {'first_contact': 'First Contact'},
    );

    expect(naming.nameOf('first_contact'), 'First Contact');
  });

  test('нет имени ни на одном языке — показывается slug, а не пустота', () {
    const naming = ConstellationNaming(
      interfaceNames: {'about_me': 'Про себя'},
      nativeNames: {'about_me': 'Про себе'},
    );

    // Тема, которой имя ещё не написали. Латиница на карте некрасива, но это
    // не падение и не подпись из воздуха.
    expect(naming.nameOf('first_contact'), 'first_contact');
    expect(const ConstellationNaming.slugsOnly().nameOf('about_me'),
        'about_me');
  });

  test('пустое имя — это отсутствие имени, а не имя', () {
    // Ключ есть, значения нет: `??` по ключу такой ряд принял бы за имя и
    // съел подпись, причём молча и без отката на язык подсказок.
    const naming = ConstellationNaming(
      interfaceNames: {'first_contact': '   ', 'about_me': ''},
      nativeNames: {'first_contact': 'Перший контакт'},
    );

    expect(naming.nameOf('first_contact'), 'Перший контакт');
    expect(naming.nameOf('about_me'), 'about_me');
  });
}
