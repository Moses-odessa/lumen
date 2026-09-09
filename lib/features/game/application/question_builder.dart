import 'dart:math';

import '../../../data/content/content_database.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/game_mode.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scheduler/session_planner.dart';
import '../../../domain/scoring/balance.dart';

/// Собирает круг из контента: что в центре, что вокруг, что верно.
///
/// Единица изучения — фраза, и вариантов в круге всегда шесть: сама фраза и
/// пять других. Откуда взять эти пять — решает не сборщик, а тот, кто знает
/// память игрока: загрузчик сессии передаёт **упорядоченный пул**, в начале
/// которого стоят фразы, которые игрок уже знает.
///
/// Разделение не формальное. Знакомство устроено методом исключения: игрок
/// понимает, какая из шести фраз новая, потому что остальные пять узнаёт.
/// Правило «пять известных» — это правило про память, и жить оно должно там,
/// где память есть. Сборщик берёт первые подходящие из пула и ничего не знает
/// ни про яркость, ни про заход.
///
/// Возвращает `null`, если круг собрать нельзя: у фразы нет перевода на
/// родной язык или в пуле не набралось пяти других фраз. Молча показать
/// сломанный круг хуже, чем пропустить фразу.
class QuestionBuilder {
  QuestionBuilder({
    required this.content,
    required this.targetLang,
    required this.nativeLang,
    Random? random,
  }) : _random = random ?? Random();

  final ContentDatabase content;

  /// Язык изучения — на нём написаны фразы.
  final String targetLang;

  /// Язык подсказок — на нём переводы.
  final String nativeLang;

  final Random _random;

  /// Собирает круг по запланированной фразе.
  ///
  /// [pool] — идентификаторы фраз, из которых берутся пять других вариантов,
  /// в порядке предпочтения: известные игроку первыми. Сама фраза круга из
  /// пула отбрасывается, так что передавать его отфильтрованным не нужно.
  Future<CircleQuestion?> build(
    PlannedCircle circle, {
    required List<String> pool,
  }) async {
    final phrase = await content.phrase(circle.itemId);
    if (phrase == null) return null;

    final others = _pickOthers(circle.itemId, pool);
    if (others.length < ScoreBalance.optionsPerCircle - 1) return null;

    final ids = [circle.itemId, ...others];
    final translations = await content.translationsFor(ids, nativeLang);

    // Перевод нужен каждому варианту, а не только ответу: на родном языке
    // стоят либо варианты, либо центр. Фраза без перевода круг не собирает —
    // ни своим, ни чужим.
    if (translations.length < ids.length) return null;

    final texts = <String, String>{phrase.id: phrase.sentence};
    for (final id in others) {
      final row = await content.phrase(id);
      if (row == null) return null;
      texts[id] = row.sentence;
    }

    final onTarget = circle.mode.optionsInTargetLanguage;
    final options = [
      for (final id in ids) onTarget ? texts[id]! : translations[id]!,
    ];

    // Порядок вариантов перемешивается, иначе верный всегда стоит первым.
    final order = List<int>.generate(options.length, (i) => i)
      ..shuffle(_random);
    final shuffled = [for (final i in order) options[i]];
    final answerIndex = order.indexOf(0);

    final target = texts[circle.itemId]!;
    final native = translations[circle.itemId]!;

    return CircleQuestion(
      itemId: circle.itemId,
      tier: Tier.fromCode(phrase.tier),
      mode: circle.mode,
      // В механике на слух центр пуст: его занимает динамик.
      prompt: switch (circle.mode) {
        GameMode.pickNative => target,
        GameMode.pickTarget => native,
        GameMode.listenNative => '',
      },
      promptTag: phrase.register,
      options: shuffled,
      answerIndex: answerIndex,
      lumens: circle.lumens,
      isNew: circle.isNew,
      promptSpeech: circle.mode.needsAudio ? target : null,
      answerSpeech: target,
      // Перевод показывается вместе с ответом — но только там, где он не
      // является самим ответом. В `pickNative` вокруг стоят переводы, и
      // показать его второй раз значит сказать игроку то, что он и выбрал.
      translation: circle.mode == GameMode.pickNative ? null : native,
    );
  }

  /// Пять других фраз для круга: первые подходящие из пула.
  ///
  /// Пул уже упорядочен — известное впереди, — поэтому здесь только отбор
  /// без повторов и без самой себя. Перемешивать пул не надо: брать из его
  /// начала значит брать самое знакомое, то есть ровно то, на чём работает
  /// исключение.
  List<String> _pickOthers(String itemId, List<String> pool) {
    final picked = <String>[];
    final seen = {itemId};
    for (final id in pool) {
      if (!seen.add(id)) continue;
      picked.add(id);
      if (picked.length == ScoreBalance.optionsPerCircle - 1) break;
    }
    return picked;
  }
}
