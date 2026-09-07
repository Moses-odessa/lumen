import 'dart:math';

import '../../../data/content/content_database.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/game_mode.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scheduler/session_planner.dart';
import '../../../domain/scoring/balance.dart';

/// Собирает круг из контентной базы: что в центре, какие варианты вокруг.
///
/// Качество круга целиком определяется вариантами вокруг — случайные слова
/// превращают игру в угадайку. Поэтому дистракторы берутся из контента, где
/// их подобрал человек, и только при их нехватке добираются соседями по
/// созвездию.
class QuestionBuilder {
  QuestionBuilder({
    required this.content,
    required this.targetLang,
    required this.nativeLang,
    this.extraOptions = 0,
    Random? random,
  }) : _random = random ?? Random();

  final ContentDatabase content;

  /// Язык изучения — на нём варианты в продуктивных режимах.
  final String targetLang;

  /// Язык подсказок — на нём центр круга.
  final String nativeLang;

  /// Сколько лишних вариантов добавляет уровень захода: чем выше, тем меньше
  /// шанс угадать.
  final int extraOptions;

  final Random _random;

  /// Собирает вопрос по запланированному кругу.
  ///
  /// Возвращает `null`, если контента не хватает: у концепта нет лексемы на
  /// одном из языков или совсем нет вариантов. Молча показывать сломанный
  /// круг хуже, чем пропустить слово.
  Future<CircleQuestion?> build(PlannedCircle circle) async {
    final concept = await content.concept(circle.itemId);
    if (concept == null) return null;

    final target = await content.lexeme(circle.itemId, targetLang);
    final native = await content.lexeme(circle.itemId, nativeLang);
    if (target == null || native == null) return null;

    return switch (circle.mode) {
      GameMode.recognition => _recognition(circle, concept, target, native),
      GameMode.typing => _typing(circle, concept, target, native),
      GameMode.audio => _audio(circle, concept, target),
      GameMode.circle => _productive(circle, concept, target, native, 'far'),
      GameMode.tight => _productive(circle, concept, target, native, 'near'),
      // Фраза-босс собирается отдельно, через buildBoss: у неё другой
      // источник центра. Ветка достижима только через круг, запланированный
      // по концепту, — и `far` здесь по той же причине, что и там.
      GameMode.phrase => _productive(circle, concept, target, native, 'far'),
    };
  }

  /// Босс уровня: предложение с пропуском, вокруг слова той же темы.
  ///
  /// Слова игрок знает, а предложение из них собрать не может — ровно эту
  /// границу босс и проверяет.
  ///
  /// Варианты берутся из `far`, а не из `near`, и это не мелочь. `near` — это
  /// созвучные слова, а созвучное составное существительное почти всегда имеет
  /// ту же вершину: Stadtplan / Bauplan / Zeitplan, Kindeswohl / Gemeinwohl.
  /// Общая вершина означает общий род, общее склонение и общую сочетаемость —
  /// то есть такой «неверный» вариант встаёт в пропуск ничуть не хуже ответа,
  /// и круг перестаёт иметь единственное решение. `far` — слова той же темы с
  /// другим значением; они в пропуск обычно не встают, а когда встают, разница
  /// именно смысловая, и её проверять честно.
  Future<CircleQuestion?> buildBoss({
    required String constellation,
    required Tier tier,
    required Lumens lumens,
  }) async {
    final phrases = await content.phrasesFor(constellation, tier);
    if (phrases.isEmpty) return null;
    final phrase = phrases[_random.nextInt(phrases.length)];

    final conceptIds = await content.phraseConceptIds(phrase.id);
    final anchor = conceptIds.isEmpty ? null : conceptIds.first;

    final distractors = <String>[];
    if (anchor != null) {
      distractors.addAll(
        (await content.distractorsFor(anchor, targetLang, 'far'))
            .map((d) => d.form),
      );
    }
    distractors.addAll(await content.siblingForms(
      constellation: constellation,
      tier: phrase.tier,
      lang: targetLang,
      excludeConceptId: anchor ?? '',
    ));

    final options = _assembleOptions(
      answer: phrase.answer,
      distractors: distractors,
      count: ScoreBalance.optionsFor(GameMode.phrase,
          extra: extraOptions),
    );
    if (options == null) return null;

    return CircleQuestion(
      itemId: anchor ?? phrase.id,
      tier: Tier.fromCode(phrase.tier),
      mode: GameMode.phrase,
      prompt: _withGap(phrase.template),
      promptHint: phrase.register,
      options: options.forms,
      answerIndex: options.answerIndex,
      lumens: lumens,
      answerSpeech: _withAnswer(phrase.template, phrase.answer),
    );
  }

  // ── Режимы ──────────────────────────────────────────────────────────────

  /// Узнавание: в центре изучаемый язык, вокруг варианты на родном.
  Future<CircleQuestion?> _recognition(
    PlannedCircle circle,
    ConceptRow concept,
    LexemeRow target,
    LexemeRow native,
  ) async {
    final distractors = await _distractors(
      concept: concept,
      lang: nativeLang,
      kind: 'far',
      itemId: circle.itemId,
    );

    final options = _assembleOptions(
      answer: native.form,
      distractors: distractors,
      count: ScoreBalance.optionsFor(GameMode.recognition,
          extra: extraOptions),
    );
    if (options == null) return null;

    return CircleQuestion(
      itemId: circle.itemId,
      tier: Tier.fromCode(concept.tier),
      mode: GameMode.recognition,
      prompt: _withArticle(target),
      promptHint: target.note,
      options: options.forms,
      answerIndex: options.answerIndex,
      lumens: circle.lumens,
      isNew: circle.isNew,
      answerSpeech: target.form,
      answerArticle: target.article,
    );
  }

  /// Круг и тесный круг: в центре родной язык, вокруг изучаемый.
  /// Отличаются только видом дистракторов — тематические или созвучные.
  Future<CircleQuestion?> _productive(
    PlannedCircle circle,
    ConceptRow concept,
    LexemeRow target,
    LexemeRow native,
    String kind,
  ) async {
    final distractors = await _distractors(
      concept: concept,
      lang: targetLang,
      kind: kind,
      itemId: circle.itemId,
    );

    final options = _assembleOptions(
      answer: target.form,
      distractors: distractors,
      count: ScoreBalance.optionsFor(circle.mode,
          extra: extraOptions),
    );
    if (options == null) return null;

    return CircleQuestion(
      itemId: circle.itemId,
      tier: Tier.fromCode(concept.tier),
      mode: circle.mode,
      prompt: native.form,
      promptHint: native.note,
      options: options.forms,
      answerIndex: options.answerIndex,
      lumens: circle.lumens,
      isNew: circle.isNew,
      answerSpeech: target.form,
      answerArticle: target.article,
    );
  }

  /// Слух: в центре только звук.
  Future<CircleQuestion?> _audio(
    PlannedCircle circle,
    ConceptRow concept,
    LexemeRow target,
  ) async {
    final distractors = await _distractors(
      concept: concept,
      lang: targetLang,
      kind: 'near',
      itemId: circle.itemId,
    );

    final options = _assembleOptions(
      answer: target.form,
      distractors: distractors,
      count: ScoreBalance.optionsFor(GameMode.audio,
          extra: extraOptions),
    );
    if (options == null) return null;

    return CircleQuestion(
      itemId: circle.itemId,
      tier: Tier.fromCode(concept.tier),
      mode: GameMode.audio,
      prompt: '',
      options: options.forms,
      answerIndex: options.answerIndex,
      lumens: circle.lumens,
      promptSpeech: target.form,
      answerSpeech: target.form,
      answerArticle: target.article,
    );
  }

  /// Набор: поле ввода, вариантов нет.
  CircleQuestion _typing(
    PlannedCircle circle,
    ConceptRow concept,
    LexemeRow target,
    LexemeRow native,
  ) =>
      CircleQuestion(
        itemId: circle.itemId,
        tier: Tier.fromCode(concept.tier),
        mode: GameMode.typing,
        prompt: native.form,
        promptHint: target.gender,
        options: [target.form],
        answerIndex: 0,
        lumens: circle.lumens,
        answerSpeech: target.form,
        answerArticle: target.article,
      );

  // ── Варианты ────────────────────────────────────────────────────────────

  /// Дистракторы нужного вида плюс резерв из соседей по созвездию.
  Future<List<String>> _distractors({
    required ConceptRow concept,
    required String lang,
    required String kind,
    required String itemId,
  }) async {
    final picked = (await content.distractorsFor(itemId, lang, kind))
        .map((d) => d.form)
        .toList();

    // На родном языке дистракторы есть не всегда — их пишут прежде всего
    // для языка изучения. Соседи по созвездию закрывают дыру.
    picked.addAll(await content.siblingForms(
      constellation: concept.constellation,
      tier: concept.tier,
      lang: lang,
      excludeConceptId: itemId,
    ));
    return picked;
  }

  /// Перемешивает ответ с дистракторами.
  ///
  /// Дубли и совпадения с ответом отсеиваются: два одинаковых варианта в
  /// круге — это не сложность, а поломка.
  ({List<String> forms, int answerIndex})? _assembleOptions({
    required String answer,
    required List<String> distractors,
    required int count,
  }) {
    if (count <= 0) return (forms: [answer], answerIndex: 0);

    final seen = {answer.toLowerCase()};
    final picked = <String>[];
    for (final form in distractors) {
      if (picked.length >= count - 1) break;
      if (form.isEmpty || !seen.add(form.toLowerCase())) continue;
      picked.add(form);
    }

    // Меньше двух вариантов — это не круг, а подсказка.
    if (picked.length < 2) return null;

    final forms = [...picked, answer]..shuffle(_random);
    return (forms: forms, answerIndex: forms.indexOf(answer));
  }

  String _withArticle(LexemeRow lexeme) => lexeme.article == null
      ? lexeme.form
      : '${lexeme.article} ${lexeme.form}';

  /// Заменяет слот шаблона на пропуск:
  /// `Ich brauche {help}.` → `Ich brauche _____.`
  String _withGap(String template) =>
      template.replaceAll(RegExp(r'\{[^}]*\}'), '_____');

  /// Заполняет слот ответом: `Ich brauche {help}.` → `Ich brauche Hilfe.`
  ///
  /// Нужно для озвучки фразы. Пока озвучка была файлами, произносилось одно
  /// слово из пропуска — записывать четыреста тридцать два предложения было
  /// незачем. Синтез произносит их бесплатно, и игрок слышит фразу целиком,
  /// ради которой её и учит.
  String _withAnswer(String template, String answer) =>
      template.replaceAll(RegExp(r'\{[^}]*\}'), answer);
}
