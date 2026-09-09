import 'dart:math';

import '../../../data/content/content_database.dart';
import '../../../domain/entities/circle_question.dart';
import '../../../domain/entities/game_mode.dart';
import '../../../domain/entities/prompt_tag.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scheduler/session_planner.dart';
import '../../../domain/scoring/balance.dart';

/// Собирает вопрос из контентной базы: что в центре, какие варианты вокруг.
///
/// Качество вопроса целиком определяется вариантами — случайные слова
/// превращают игру в угадайку. Поэтому дистракторы берутся из контента, где
/// их подобрал человек, и только при их нехватке добираются соседями по
/// созвездию.
///
/// **Что решает сборщик, а что нет.** Раньше здесь решалось всё: и сколько
/// вариантов, и какого они вида, — по механике, а сверху сборщик прибавлял
/// надбавку захода. Теперь всё это приходит в [PlannedCircle]: вариантность
/// есть шкала сложности, и распоряжаться ею должен тот, кто отвечает за
/// сложность. Сборщик знает только, где взять слова.
///
/// Про заход он не знает ничего, и это не изящество, а починка. Пока надбавка
/// была здесь, она прибавлялась к каждому кругу — включая тот, которому
/// планировщик намеренно поставил один вариант, чтобы знакомство с новым
/// словом было показом, а не проверкой.
class QuestionBuilder {
  QuestionBuilder({
    required this.content,
    required this.targetLang,
    required this.nativeLang,
    Random? random,
  }) : _random = random ?? Random();

  final ContentDatabase content;

  /// Язык изучения.
  final String targetLang;

  /// Язык подсказок.
  final String nativeLang;

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
      // Варианты на родном: центр — изучаемый язык или звук.
      GameMode.pickNative =>
        _pick(circle, concept, target, native, toTarget: false, audio: false),
      GameMode.listenNative =>
        _pick(circle, concept, target, native, toTarget: false, audio: true),

      // Варианты на изучаемом: центр — родной язык или звук.
      GameMode.pickTarget =>
        _pick(circle, concept, target, native, toTarget: true, audio: false),
      GameMode.listenTarget =>
        _pick(circle, concept, target, native, toTarget: true, audio: true),

      // Фразовые механики собираются отдельно: у них другой источник центра.
      // Ветка достижима только если этап поставил их на круг по концепту, —
      // тогда собрать нечего, и это честнее, чем показать слово под видом
      // фразы.
      GameMode.fillGaps || GameMode.buildPhrase => null,
    };
  }

  /// Круг с выбором: механики a, b, c, d.
  ///
  /// Одна функция на четыре механики, потому что различий между ними ровно
  /// два: на каком языке варианты и что в центре — текст или звук. Держать
  /// четыре почти одинаковые функции значило бы четыре раза повторить
  /// подстановку артикля и сборку вариантов.
  Future<CircleQuestion?> _pick(
    PlannedCircle circle,
    ConceptRow concept,
    LexemeRow target,
    LexemeRow native, {
    required bool toTarget,
    required bool audio,
  }) async {
    final lang = toTarget ? targetLang : nativeLang;
    final answer = toTarget ? target.form : native.form;

    final distractors = await _distractors(
      concept: concept,
      lang: lang,
      // Созвучные дистракторы существуют только на языке изучения: их
      // подбирают по фонетике, и на родном языке их писать не стали
      // намеренно. Просить их там — значит гарантированно получить пустоту и
      // добор соседями.
      kind: toTarget ? circle.distractorKind : DistractorKind.far,
      itemId: circle.itemId,
    );

    final options = _assembleOptions(
      answer: answer,
      distractors: distractors,
      count: circle.options,
    );
    if (options == null) return null;

    return CircleQuestion.single(
      itemId: circle.itemId,
      tier: Tier.fromCode(concept.tier),
      mode: circle.mode,
      // В механиках на слух центр пуст: его занимает динамик.
      prompt: audio ? '' : (toTarget ? native.form : _withArticle(target)),
      // Пометка описывает **центр**, а не ответ: в круге «родное слово →
      // варианты на изучаемом» подсказка идёт от родной лексемы, в обратном
      // — от изучаемой.
      //
      // Свободный текст берётся только с родной стороны: там язык файла и
      // есть язык игрока. Пометка изучаемой лексемы — всегда код, потому что
      // правильного языка у неё нет: немецкий файл читает автор контента, и
      // написанное в нём «неисчисляемое» показывалось украинцу как есть.
      promptHint: audio ? null : _freeText(toTarget ? native.note : target.note),
      promptTag: audio ? null : _tag(toTarget ? native.note : target.note),
      options: options.forms,
      answerIndex: options.answerIndex,
      lumens: circle.lumens,
      isNew: circle.isNew,
      promptSpeech: audio ? target.form : null,
      answerSpeech: target.form,
      answerArticle: target.article,
    );
  }

  /// Фраза: заполнить пропуски (**e**) или собрать предложение (**f**).
  ///
  /// Слова игрок знает, а предложение из них собрать не может — ровно эту
  /// границу фразовые механики и проверяют.
  ///
  /// Варианты для пропуска берутся, в порядке предпочтения: собственные
  /// неверные слова слота, потом `far` опорного концепта, потом соседи по
  /// созвездию. Своих неверных слов у большинства фраз пока нет, и добор —
  /// не запасной путь, а основной; но когда они появятся, они вытеснят
  /// добор, потому что подобранное под пропуск всегда лучше подобранного под
  /// тему.
  ///
  /// `far`, а не `near`, и это не мелочь. `near` — созвучные слова, а
  /// созвучное составное существительное почти всегда имеет ту же вершину:
  /// Stadtplan / Bauplan / Zeitplan, Kindeswohl / Gemeinwohl. Общая вершина
  /// означает общий род, общее склонение и общую сочетаемость — то есть
  /// такой «неверный» вариант встаёт в пропуск ничуть не хуже ответа, и
  /// фраза перестаёт иметь единственное решение.
  Future<CircleQuestion?> buildPhrase({
    required String constellation,
    required Tier tier,
    required Lumens lumens,
    GameMode mode = GameMode.fillGaps,
    int options = ScoreBalance.optionsMax,
  }) async {
    final phrase = await pickPhrase(constellation: constellation, tier: tier);
    if (phrase == null) return null;
    return buildPhraseQuestion(
      phrase: phrase,
      mode: mode,
      constellation: constellation,
      lumens: lumens,
      options: options,
    );
  }

  /// Тянет случайную фразу созвездия.
  ///
  /// Отдельный шаг нужен затем, чтобы две фразовые механики можно было
  /// построить на **одном** предложении. Пока выбор был внутри сборки, вызов
  /// её дважды давал два независимых предложения, и обещание «сначала
  /// заполни пропуски, потом собери то же самое» выполнялось только когда
  /// случайность совпадала.
  Future<PhraseRow?> pickPhrase({
    required String constellation,
    required Tier tier,
  }) async {
    final phrases =
        await content.phrasesFor(constellation, tier, lang: targetLang);
    if (phrases.isEmpty) return null;
    return phrases[_random.nextInt(phrases.length)];
  }

  /// Собирает вопрос по уже выбранной фразе.
  Future<CircleQuestion?> buildPhraseQuestion({
    required PhraseRow phrase,
    required GameMode mode,
    required String constellation,
    required Lumens lumens,
    int options = ScoreBalance.optionsMax,
  }) async {
    final answers = await content.phraseAnswers(phrase.id);
    if (answers.isEmpty) return null;

    final conceptIds = await content.phraseConceptIds(phrase.id);
    final anchor = conceptIds.isEmpty ? null : conceptIds.first;
    final translation =
        await content.phraseTranslation(phrase.id, nativeLang);

    return mode == GameMode.buildPhrase
        ? _buildFromWords(phrase, answers, anchor, lumens, translation)
        : _fillGaps(
            phrase,
            answers,
            anchor,
            constellation,
            lumens,
            translation,
            options,
          );
  }

  /// **e.** Шаблон с пропусками, слова-кандидаты вокруг.
  Future<CircleQuestion?> _fillGaps(
    PhraseRow phrase,
    List<String> answers,
    String? anchor,
    String constellation,
    Lumens lumens,
    String? translation,
    int options,
  ) async {
    final own = await content.phraseOptionsFor(phrase.id);

    // Пул общий на все пропуски: игрок видит слова сверху и снизу и тянет
    // каждое к своему месту. Поэтому в пуле обязаны быть все ответы, и
    // неверные слова к ним добавляются сверх.
    final pool = <String>[...answers];
    final seen = {for (final a in answers) a.toLowerCase()};

    Future<void> addAll(Iterable<String> forms) async {
      for (final form in forms) {
        if (pool.length >= options + answers.length - 1) return;
        if (form.isEmpty || !seen.add(form.toLowerCase())) continue;
        pool.add(form);
      }
    }

    for (var slot = 0; slot < answers.length; slot++) {
      // Перемешивается до обрезки, а не после.
      //
      // База отдаёт варианты по первичному ключу, то есть по алфавиту и
      // заглавными вперёд, а в пул влезают не все — только первые
      // `options - 1`. Без перемешивания обрезка систематически предпочитала
      // существительные прилагательным, и в двух фразах A0 ответ оставался
      // единственным строчным словом на экране. Порядок автора при этом всё
      // равно потерян: он не доезжает из YAML до базы.
      await addAll((own[slot] ?? const <String>[]).toList()..shuffle(_random));
    }
    if (anchor != null) {
      await addAll((await content.distractorsFor(anchor, targetLang, 'far'))
          .map((d) => d.form));
    }
    await addAll(await content.siblingForms(
      constellation: constellation,
      tier: phrase.tier,
      lang: targetLang,
      excludeConceptId: anchor ?? '',
    ));

    // Меньше одного лишнего слова — это не задание, а подстановка.
    if (pool.length <= answers.length) return null;

    final shuffled = pool.toList()..shuffle(_random);

    // Индексы ищутся по неиспользованным вхождениям, а не через `indexOf`.
    //
    // Одно и то же слово может отвечать на два пропуска («Ich {gehe} und du
    // {gehe}»), и тогда `indexOf` вернул бы оба раза первый индекс: два слота
    // спорили бы за один вариант, а второе такое же слово в пуле осталось бы
    // недостижимым. Рядом, в `_buildFromWords`, от этого стоит защита — а
    // здесь её не было, и два сборщика фраз расходились друг с другом.
    final used = <int>{};
    final bySlot = <int>[];
    for (final answer in answers) {
      final index = _firstUnused(shuffled, answer, used);
      if (index < 0) return null;
      used.add(index);
      bySlot.add(index);
    }

    return CircleQuestion(
      itemId: anchor ?? phrase.id,
      tier: Tier.fromCode(phrase.tier),
      mode: GameMode.fillGaps,
      prompt: _withGaps(phrase.template),
      promptTag: phrase.register,
      options: shuffled,
      answers: bySlot,
      lumens: lumens,
      answerSpeech: _withAnswers(phrase.template, answers),
      translation: translation,
    );
  }

  /// **f.** Слова врассыпную, пустые места по их числу.
  ///
  /// Слова берутся из самого предложения, а не подбираются: цель — порядок, а
  /// не выбор. Лишние слова здесь были бы другой задачей.
  CircleQuestion? _buildFromWords(
    PhraseRow phrase,
    List<String> answers,
    String? anchor,
    Lumens lumens,
    String? translation,
  ) {
    final sentence = _withAnswers(phrase.template, answers);
    final words = sentence
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Короткое предложение собирается наугад: из трёх слов порядок угадать
    // проще, чем вспомнить. Порог — в балансе.
    if (words.length < SessionBalance.buildPhraseMinWords) return null;

    final pool = words.toList()..shuffle(_random);
    // Индексы ищутся по вхождениям, а не по `indexOf`: слово в предложении
    // может повторяться («Ich habe ... und ich ...»), и тогда второй слот
    // получил бы индекс первого, а один из вариантов остался бы висеть.
    final used = <int>{};
    final answersBySlot = <int>[];
    for (final word in words) {
      final index = _firstUnused(pool, word, used);
      if (index < 0) return null;
      used.add(index);
      answersBySlot.add(index);
    }

    return CircleQuestion(
      itemId: anchor ?? phrase.id,
      tier: Tier.fromCode(phrase.tier),
      mode: GameMode.buildPhrase,
      // Центр пуст: его занимают пустые места по числу слов.
      prompt: '',
      promptTag: phrase.register,
      options: pool,
      answers: answersBySlot,
      lumens: lumens,
      answerSpeech: sentence,
      translation: translation,
    );
  }

  static int _firstUnused(List<String> pool, String word, Set<int> used) {
    for (var i = 0; i < pool.length; i++) {
      if (!used.contains(i) && pool[i] == word) return i;
    }
    return -1;
  }

  // ── Варианты ────────────────────────────────────────────────────────────

  /// Дистракторы нужного вида плюс резерв из соседей по созвездию.
  Future<List<String>> _distractors({
    required ConceptRow concept,
    required String lang,
    required DistractorKind kind,
    required String itemId,
  }) async {
    final picked = (await content.distractorsFor(itemId, lang, kind.code))
        .map((d) => d.form)
        .toList();

    // На родном языке дистракторы есть только у горстки концептов, и это
    // решение, а не пробел: варианты на родном берутся из соседей по
    // созвездию — из слов, которые уже написаны и проверены. Придумать
    // несуществующее слово при этом структурно невозможно, а 31 000 единиц
    // ручной работы не появляется. Заданные руками имеют приоритет.
    //
    // Соседи перемешиваются, и это не украшение. `siblingForms` не задаёт
    // порядок вовсе, а в созвездии ровно двенадцать концептов при лимите
    // двенадцать — то есть база отдаёт один и тот же список в одном и том же
    // порядке всегда. Дальше `_assembleOptions` берёт из него первые
    // `wanted - 1`, и на родном языке, где своих дистракторов почти ни у кого
    // нет, восемь концептов из двенадцати получали одну и ту же четвёрку
    // неверных вариантов **каждый раз**. Игрок при этом учил не слово, а то,
    // что «эти четыре никогда не верны».
    //
    // Ровно та же ошибка, что была у `phrase_options`: список без порядка
    // плюс обрезка. Финальный `shuffle` в `_assembleOptions` её не лечит — он
    // тасует показанное, а не выбранное.
    final siblings = await content.siblingForms(
      constellation: concept.constellation,
      tier: concept.tier,
      lang: lang,
      excludeConceptId: itemId,
    );
    picked.addAll(siblings..shuffle(_random));
    return picked;
  }

  /// Перемешивает ответ с дистракторами.
  ///
  /// Дубли и совпадения с ответом отсеиваются: два одинаковых варианта в
  /// круге — это не сложность, а поломка.
  ///
  /// Один вариант — законный случай, а не вырождение: так устроено
  /// знакомство с новым словом. Раньше сборщик возвращал `null`, если не
  /// набралось двух дистракторов, и такой круг молча исчезал из уровня.
  ({List<String> forms, int answerIndex})? _assembleOptions({
    required String answer,
    required List<String> distractors,
    required int count,
  }) {
    final wanted = count.clamp(ScoreBalance.optionsMin, 64);
    if (wanted <= 1) return (forms: [answer], answerIndex: 0);

    final seen = {answer.toLowerCase()};
    final picked = <String>[];
    for (final form in distractors) {
      if (picked.length >= wanted - 1) break;
      if (form.isEmpty || !seen.add(form.toLowerCase())) continue;
      picked.add(form);
    }

    // Ни одного варианта не нашлось: показать один и назвать это выбором
    // хуже, чем не показать. Но круг из двух — уже вопрос, и монетка честнее
    // пропуска слова.
    if (picked.isEmpty) return null;

    final forms = [...picked, answer]..shuffle(_random);
    return (forms: forms, answerIndex: forms.indexOf(answer));
  }

  String _withArticle(LexemeRow lexeme) => lexeme.article == null
      ? lexeme.form
      : '${lexeme.article} ${lexeme.form}';

  /// Пометка кодом — её переведёт локализация.
  String? _tag(String? note) =>
      note != null && isPromptTag(note) ? note : null;

  /// Пометка свободным текстом — её покажут как есть.
  ///
  /// Две функции на одно поле, а не разбор в вызывающем: пометка приходит из
  /// контента одной строкой, и решать, код это или подсказка, должно одно
  /// место. Иначе третий вызывающий покажет код игроку — как показывал
  /// `register: casual` под каждой из 432 фраз.
  String? _freeText(String? note) =>
      note != null && !isPromptTag(note) ? note : null;

  /// Заменяет слоты шаблона на пропуски:
  /// `Ich brauche {help}.` → `Ich brauche _____.`
  String _withGaps(String template) =>
      template.replaceAll(RegExp(r'\{[^}]*\}'), '_____');

  /// Заполняет слоты ответами: `Ich brauche {help}.` → `Ich brauche Hilfe.`
  ///
  /// Нужно для озвучки фразы. Пока озвучка была файлами, произносилось одно
  /// слово из пропуска — записывать четыреста тридцать два предложения было
  /// незачем. Синтез произносит их бесплатно, и игрок слышит фразу целиком,
  /// ради которой её и учит.
  ///
  /// Порядок [answers] — это порядок слотов в шаблоне слева направо.
  String _withAnswers(String template, List<String> answers) {
    var i = 0;
    return template.replaceAllMapped(
      RegExp(r'\{[^}]*\}'),
      (_) => i < answers.length ? answers[i++] : '',
    );
  }
}
