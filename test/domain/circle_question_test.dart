import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/circle_question.dart';
import 'package:lumen/domain/entities/game_mode.dart';
import 'package:lumen/domain/entities/tier.dart';

void main() {
  CircleQuestion question({
    GameMode mode = GameMode.pickTarget,
    List<String> options = const ['Arzt', 'Art', 'Arm'],
    int answerIndex = 0,
    String? article,
  }) =>
      CircleQuestion.single(
        itemId: 'doctor_person',
        tier: Tier.a0,
        mode: mode,
        prompt: 'врач',
        options: options,
        answerIndex: answerIndex,
        lumens: 50,
        answerArticle: article,
      );

  group('выбор варианта', () {
    test('верен только ответ', () {
      final q = question(answerIndex: 1);
      expect(q.isCorrectOption(1), isTrue);
      expect(q.isCorrectOption(0), isFalse);
      expect(q.answer, 'Art');
    });

    test('индекс вне списка не считается верным', () {
      final q = question();
      expect(q.isCorrectOption(-1), isFalse);
      expect(q.isCorrectOption(99), isFalse);
    });

    test('круг с одним вариантом — законный вопрос', () {
      // Знакомство с новым словом: выбирать не из чего, но соединение обязано
      // засчитаться — иначе первый показ слова непроходим. Раньше такой круг
      // был недостижим: сборщик возвращал null, не набрав двух дистракторов,
      // и слово молча исчезало из уровня.
      final q = question(mode: GameMode.pickNative, options: const ['врач']);
      expect(q.slotCount, 1);
      expect(q.isCorrectOption(0), isTrue);
      expect(q.isCorrectOption(1), isFalse);
      expect(q.answer, 'врач');
    });

    test('у всех механик выбора ответ занимает ровно один слот', () {
      // Виджет про механики не знает: одна геометрия обязана давать одну и ту
      // же форму ответа, иначе экран пришлось бы ветвить по режиму.
      for (final mode in const [
        GameMode.pickNative,
        GameMode.pickTarget,
        GameMode.listenNative,
      ]) {
        final q = question(mode: mode, answerIndex: 2);
        expect(q.isSingleSlot, isTrue, reason: mode.name);
        expect(q.answerIndex, 2, reason: mode.name);
        expect(q.isCorrectFor(0, 2), isTrue, reason: mode.name);
        // Второго слота нет — обращение к нему не должно оказаться верным.
        expect(q.isCorrectFor(1, 2), isFalse, reason: mode.name);
      }
    });
  });

  group('несколько слотов', () {
    // Пул вариантов один на все пропуски: игрок тянет слова из общего набора.
    // Поэтому верность — это пара «слот + вариант», а не один индекс.
    const gaps = CircleQuestion(
      itemId: 'doctor_person',
      tier: Tier.a1,
      mode: GameMode.fillGaps,
      prompt: 'Ich _____ einen _____.',
      options: ['brauche', 'Arzt', 'Termin', 'kaufe'],
      answers: [0, 1],
      lumens: 60,
      translation: 'Мне нужен врач.',
    );

    test('у каждого слота свой верный вариант', () {
      expect(gaps.slotCount, 2);
      expect(gaps.isSingleSlot, isFalse);
      expect(gaps.isCorrectFor(0, 0), isTrue);
      expect(gaps.isCorrectFor(1, 1), isTrue);
      expect(gaps.answerFor(0), 'brauche');
      expect(gaps.answerFor(1), 'Arzt');
    });

    test('верное слово в чужом пропуске — ошибка', () {
      // Иначе задание проходится перебором пула: любое слово подошло бы
      // куда угодно, и проверялся бы состав набора, а не форма и порядок.
      expect(gaps.isCorrectFor(1, 0), isFalse);
      expect(gaps.isCorrectFor(0, 1), isFalse);
    });

    test('слот вне шаблона не считается верным', () {
      expect(gaps.isCorrectFor(-1, 0), isFalse);
      expect(gaps.isCorrectFor(2, 0), isFalse);
      expect(gaps.answerFor(2), isEmpty);
      expect(gaps.answerFor(-1), isEmpty);
    });

    test('заполненные пропуски дают фразу целиком', () {
      // Ради неё пропуски и заполняются: озвучка и перевод относятся к
      // предложению, а не к одному слову из пропуска.
      expect(gaps.assembled, 'Ich brauche einen Arzt.');
    });

    test('на максимуме пропусков скелет — строка из одних пропусков', () {
      // «Собери предложение» это не отдельная механика, а максимум одной
      // шкалы: вынуто всё, скелета не осталось. Отдельной ветки в
      // `assembled` поэтому больше нет — раньше их было две ровно потому,
      // что было две реализации механики.
      const built = CircleQuestion(
        itemId: 'doctor_person',
        tier: Tier.a1,
        mode: GameMode.buildPhrase,
        prompt: '_____ _____ _____ _____',
        options: ['Arzt', 'Ich', 'einen', 'brauche'],
        answers: [1, 3, 2, 0],
        lumens: 60,
      );
      expect(built.assembled, 'Ich brauche einen Arzt');
      expect(built.isCorrectFor(0, 1), isTrue);
      expect(built.isCorrectFor(0, 0), isFalse);
    });

    test('часть слов вынута, остальные видны как скелет', () {
      // Самая лёгкая настройка: два пропуска, прочее на месте. Собранное
      // предложение читается целиком, а не только из вынутых слов.
      const built = CircleQuestion(
        itemId: 'doctor_person',
        tier: Tier.a1,
        mode: GameMode.fillGaps,
        prompt: 'Ich brauche _____ _____',
        options: ['Arzt', 'einen'],
        answers: [1, 0],
        lumens: 60,
      );
      expect(built.assembled, 'Ich brauche einen Arzt');
      expect(built.slotCount, 2);
    });

    test('принимается и другой верный порядок слов', () {
      // Немецкий позволяет вынести в начало почти любой член предложения:
      // «Heute habe ich Zeit» и «Ich habe heute Zeit» верны оба и означают
      // одно. Механика даёт игроку слова предложения, значит собрать законный
      // другой порядок он может — и объявлять это ошибкой нельзя.
      const built = CircleQuestion(
        itemId: 'time_noun',
        tier: Tier.a1,
        mode: GameMode.buildPhrase,
        prompt: '_____ _____ _____ _____',
        options: ['Zeit', 'Heute', 'habe', 'ich'],
        answers: [1, 2, 3, 0],
        lumens: 60,
        accepted: ['Heute habe ich Zeit', 'Ich habe heute Zeit'],
      );
      expect(built.acceptsAssembly('Heute habe ich Zeit'), isTrue);
      expect(built.acceptsAssembly('Ich habe heute Zeit'), isTrue);
      expect(built.acceptsAssembly('Zeit habe ich heute'), isFalse);
    });

    test('без списка принимается только заданный шаблоном порядок', () {
      const built = CircleQuestion(
        itemId: 'doctor_person',
        tier: Tier.a1,
        mode: GameMode.buildPhrase,
        prompt: '_____ _____ _____ _____',
        options: ['Arzt', 'Ich', 'einen', 'brauche'],
        answers: [1, 3, 2, 0],
        lumens: 60,
      );
      expect(built.acceptsAssembly('Ich brauche einen Arzt'), isTrue);
      expect(built.acceptsAssembly('Einen Arzt brauche ich'), isFalse);
    });

    test('одинаковые плитки взаимозаменяемы, а номера — нет', () {
      // «ich» в предложении дважды, и это не редкость: в пуле фразы лежат
      // слова самого предложения. Четыре фразы из 432 несут точно повторённое
      // слово, девятнадцать — повторённое без учёта регистра, и одна из
      // четырёх («Das ist ein guter Preis für so ein Auto») стоит на
      // запущенном ярусе.
      //
      // Раньше здесь стояло обратное требование: «слоты не взаимозаменяемы».
      // Оно верно про **номера** и неверно про игрока. Игрок видит две
      // неотличимые плитки; за каждой свой номер; слот принимал только один
      // из двух. Поставил наоборот — «неверно» на предложении, которое
      // читается буква в букву как правильное. Это ровно тот дефект, за
      // которым шесть раундов вычитки гонялись в вариантах фраз, только
      // сидел он в коде.
      const built = CircleQuestion(
        itemId: 'doctor_person',
        tier: Tier.a1,
        mode: GameMode.buildPhrase,
        prompt: '_____ _____ _____ _____ _____',
        options: ['ich', 'ich', 'komme', 'und', 'gehe'],
        answers: [0, 2, 3, 1, 4],
        lumens: 60,
      );
      expect(built.assembled, 'ich komme und ich gehe');
      expect(built.isCorrectFor(0, 0), isTrue);
      expect(built.isCorrectFor(3, 1), isTrue);

      // Тот же текст, другой экземпляр — принимается: собранное предложение
      // от этого не меняется.
      expect(built.isCorrectFor(0, 1), isTrue);
      expect(built.isCorrectFor(3, 0), isTrue);

      // А слово другое — по-прежнему неверно.
      expect(built.isCorrectFor(0, 2), isFalse);

      // Номера у разных слотов всё равно разные: иначе два слота заняли бы
      // одну плитку, а вторая осталась бы незакрываемой.
      expect(built.answers.toSet().length, built.answers.length);
    });
  });

  // ── Что здесь было и почему больше нет ──────────────────────────────────
  //
  // 1. Тест «у «Набора» ответ есть, но выбирать нечего» проверял
  //    `CircleQuestion.isTyped`. Флага нет: механика «Набор» удалена, вопрос
  //    без выбора теперь означает другое — знакомство с новым словом, — и эту
  //    часть смысла унаследовал тест «круг с одним вариантом — законный
  //    вопрос» выше.
  //
  // 2. Группа «ввод текста» проверяла `isCorrectInput`: точный ответ, любой
  //    регистр и пробелы по краям, форма с артиклем и без, опечатка в одну
  //    букву засчитывается, две — уже нет, в коротком слове не прощается
  //    ничего («Bad» и «Bar» — разные слова), лишние слова не проходят.
  //
  //    Ни одной из этих гарантий не существует, потому что нет поля ввода:
  //    текст в игре больше нигде не набирается. Терпимость к опечатке была
  //    нужна затем, чтобы игра проверяла знание слова, а не меткость на
  //    телефонной клавиатуре, — вместе с клавиатурой исчез и повод. Ближайшая
  //    из оставшихся механик, `GameMode.buildPhrase`, требует восстановить
  //    порядок слов, а не написать их, так что написание не тренируется
  //    ничем. Это осознанный размен, а не пробел: возвращать эти тесты имеет
  //    смысл только вместе с полем ввода.
}
