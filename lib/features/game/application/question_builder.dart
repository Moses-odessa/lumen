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
      // Варианты на родном: центр — изучаемое слово или звук.
      GameMode.pickNative =>
        _pick(circle, concept, target, native, toTarget: false, audio: false),
      GameMode.listenNative =>
        _pick(circle, concept, target, native, toTarget: false, audio: true),

      // Варианты на изучаемом: центр — родное слово. Звука в этой половине
      // нет: вопрос на слух всегда даёт варианты на родном.
      GameMode.pickTarget =>
        _pick(circle, concept, target, native, toTarget: true, audio: false),

      // Фразовые механики собираются отдельно: у них другой источник центра.
      // Ветка достижима только если этап поставил их на круг по концепту, —
      // тогда собрать нечего, и это честнее, чем показать слово под видом
      // фразы.
      GameMode.fillGaps || GameMode.buildPhrase => null,
    };
  }

  /// Круг с выбором: механики a, b, c.
  ///
  /// Одна функция на три механики, потому что различий между ними ровно два:
  /// на каком языке варианты и что в центре — текст или звук. Держать три
  /// почти одинаковые функции значило бы трижды повторить подстановку
  /// артикля и сборку вариантов.
  ///
  /// Четвёртой комбинации — звук в центре и варианты на изучаемом — больше
  /// нет, и функция от этого не упростилась: `audio` и `toTarget` остались
  /// независимыми, потому что запрет живёт в наборе механик, а не здесь.
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

  /// Фраза целиком: выбрать предложение и вынуть из него слова.
  ///
  /// Число пропусков приходит извне — это шкала сложности, и распоряжаться
  /// ею должен тот, кто отвечает за сложность. Сборщик знает только, где
  /// взять предложение и как из него вынуть слова.
  Future<CircleQuestion?> buildPhrase({
    required String constellation,
    required Tier tier,
    required Lumens lumens,
    int gaps = SessionBalance.phraseGapsMin,
  }) async {
    final phrase = await pickPhrase(constellation: constellation, tier: tier);
    if (phrase == null) return null;
    return buildPhraseQuestion(phrase: phrase, lumens: lumens, gaps: gaps);
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

    // Слишком короткое предложение отбрасывается здесь, а не в сборке.
    //
    // Раньше его отбрасывал `_place`, возвращая `null`, а загрузчик молча
    // пропускал такой круг — и уровень заканчивался без обеих закрывающих
    // фраз. «Ich trinke Wasser.» это три слова при пороге четыре, то есть
    // каждый четвёртый уровень «Еды» терял фразовый заход целиком, и заметить
    // это было нельзя: ошибки нет, просто кругов меньше.
    //
    // Порог держится не на угадывании перебором, а на том, что при
    // закреплённых начале и конце у предложения из n слов внутренних
    // расстановок ровно (n − 2)!: три слова дают одну, то есть задания нет
    // вовсе.
    final long = <PhraseRow>[];
    for (final phrase in phrases) {
      final answers = await content.phraseAnswers(phrase.id);
      final words = _tokenise(phrase.template, answers).words.length;
      if (words >= SessionBalance.phraseMinWords) long.add(phrase);
    }
    if (long.isEmpty) return null;
    return long[_random.nextInt(long.length)];
  }

  /// Собирает вопрос по уже выбранной фразе.
  Future<CircleQuestion?> buildPhraseQuestion({
    required PhraseRow phrase,
    required Lumens lumens,
    int gaps = SessionBalance.phraseGapsMin,
  }) async {
    final answers = await content.phraseAnswers(phrase.id);
    if (answers.isEmpty) return null;

    final conceptIds = await content.phraseConceptIds(phrase.id);
    final anchor = conceptIds.isEmpty ? null : conceptIds.first;
    final translation =
        await content.phraseTranslation(phrase.id, nativeLang);

    return _place(
      phrase,
      answers,
      anchor,
      lumens,
      translation,
      gaps,
      partial: gaps != SessionBalance.phraseGapsAll,
    );
  }

  /// **e и f — одна механика.** Предложение с пропусками, вокруг ровно
  /// вынутые из него слова.
  ///
  /// Пропусков от двух до всех слов, и сколько именно — шкала сложности, как
  /// число вариантов в круге. «Собери предложение» это она же на максимуме:
  /// вынуто всё, скелета не осталось. Двух реализаций поэтому больше нет —
  /// они расходились (одна искала индекс через `indexOf`, другая через
  /// `_firstUnused`), и разошлись бы снова.
  ///
  /// Посторонних слов в пуле нет вовсе, и это главное изменение. Шесть
  /// раундов вычитки ушло на списки неверных вариантов, и каждый находил в
  /// них слово, дающее правильное немецкое предложение: в рамку, куда влезает
  /// одно, влезает и второе. Слова самого предложения такого вопроса не
  /// ставят — спрашивается порядок, а не выбор.
  ///
  /// Минимум два пропуска не из осторожности. Один пропуск и есть та самая
  /// рамка с выбором: вокруг лежало бы одно слово, и задание вырождалось бы
  /// в подстановку.
  Future<CircleQuestion?> _place(
    PhraseRow phrase,
    List<String> answers,
    String? anchor,
    Lumens lumens,
    String? translation,
    int gaps, {
    required bool partial,
  }) async {
    final tokens = _tokenise(phrase.template, answers);
    if (tokens.words.length < SessionBalance.phraseMinWords) return null;

    // Знаки препинания снимаются со слов заранее: плитка несёт слово, а знак
    // остаётся в предложении.
    final bare = [for (final word in tokens.words) _bare(word)];
    final gappable = [
      for (var i = 0; i < bare.length; i++)
        if (bare[i].core.isNotEmpty) i
    ];

    final chosen = _pickGaps(tokens, gaps, partial: partial, gappable: gappable);
    if (chosen.length < SessionBalance.phraseGapsMin) return null;

    // Пул — ровно вынутые слова, перемешанные. Порядок в пуле случаен, но
    // состав задан: игрок видит то, что вынуто, и ничего больше.
    final pool = [for (final i in chosen) bare[i].core]..shuffle(_random);

    // Индексы ищутся по неиспользованным вхождениям, а не через `indexOf`:
    // слово в предложении может повторяться («Das ist ein guter Preis für so
    // ein Auto»), и тогда два слота получили бы один индекс, а вторая плитка
    // осталась бы недостижимой. Взаимозаменяемость одинаковых плиток при
    // ответе обеспечивает `CircleQuestion.isCorrectFor` — она сравнивает
    // текст, а не только номер.
    final used = <int>{};
    final bySlot = <int>[];
    for (final i in chosen) {
      final index = _firstUnused(pool, bare[i].core, used);
      if (index < 0) return null;
      used.add(index);
      bySlot.add(index);
    }

    // Скелет: слова на месте, вынутые — пропусками, а знаки препинания
    // остаются там, где стояли. При максимуме пропусков это строка из одних
    // пропусков со знаками, и отдельного вида центра для неё не нужно: тот же
    // виджет рисует и её.
    final skeleton = [
      for (var i = 0; i < tokens.words.length; i++)
        if (chosen.contains(i))
          '${bare[i].prefix}_____${bare[i].suffix}'
        else
          tokens.words[i]
    ].join(' ');

    return CircleQuestion(
      itemId: anchor ?? phrase.id,
      tier: Tier.fromCode(phrase.tier),
      // Имя механики — от того, всё ли вынуто: игрок видит разные задания,
      // и статистика с этапами их различают.
      mode: chosen.length == gappable.length
          ? GameMode.buildPhrase
          : GameMode.fillGaps,
      prompt: skeleton,
      promptTag: phrase.register,
      options: pool,
      answers: bySlot,
      lumens: lumens,
      answerSpeech: tokens.words.join(' '),
      accepted: await content.phraseOrdersFor(phrase.id),
      translation: translation,
    );
  }

  /// Слова предложения и позиции тех, что несут пропуск шаблона.
  ///
  /// Режется **шаблон**, а не готовое предложение: только так известно, какое
  /// слово фраза учит. Слово при этом остаётся со своим знаком препинания
  /// (`"{water}."` → `"Wasser."`) — разделяет их [_bare], и только для тех
  /// слов, которые вынимаются в пул.
  static ({List<String> words, Set<int> taught}) _tokenise(
    String template,
    List<String> answers,
  ) {
    final words = <String>[];
    final taught = <int>{};
    var next = 0;

    for (final chunk in template.split(RegExp(r'\s+'))) {
      if (chunk.isEmpty) continue;
      if (chunk.contains('{')) {
        final answer = next < answers.length ? answers[next++] : '';
        words.add(chunk.replaceAll(RegExp(r'\{[^}]*\}'), answer));
        taught.add(words.length - 1);
      } else {
        words.add(chunk);
      }
    }
    return (words: words, taught: taught);
  }

  /// Какие слова вынуть: сперва те, что фраза учит, потом остальные.
  ///
  /// Слово из пропуска шаблона вынимается всегда. Иначе круг перестаёт
  /// проверять то слово, ради которого существует, — а память всё равно
  /// запишется против него.
  ///
  /// Остальные добираются случайно, а не по части речи: части речи в рантайме
  /// нет. Она есть у концепта, а слова скелета концептами не являются —
  /// «Buchstabieren» и «bitte» это текст шаблона. Правило «вынимать только
  /// значимые слова» поэтому нереализуемо там, где выбираются пропуски, и
  /// придумывать его на глаз хуже, чем честная случайность.
  List<int> _pickGaps(
    ({List<String> words, Set<int> taught}) tokens,
    int gaps, {
    required bool partial,
    required List<int> gappable,
  }) {
    final total = gappable.length;
    // Ноль означает «все слова», а не «ноль пропусков»: это максимум шкалы,
    // то самое «собери предложение». Прогонять его через `clamp` нельзя —
    // ноль превратился бы в минимум, и самая трудная настройка стала бы самой
    // лёгкой. Молча: пропусков два вместо всех, круг проходится, ошибку видно
    // только по числу слотов.
    // Частичный круг обязан оставить хоть одно слово на месте, иначе он
    // совпадает с полным. Уровень закрывается двумя кругами на одном
    // предложении — сперва часть слов, потом всё, — и на коротких фразах при
    // заходе от четвёртого уровня оба вынимали всё: обещанное «сперва часть,
    // потом целиком» молча превращалось в «целиком, целиком».
    final ceiling = partial && total > SessionBalance.phraseGapsMin
        ? total - 1
        : total;
    final wanted = gaps == SessionBalance.phraseGapsAll
        ? total
        : gaps.clamp(SessionBalance.phraseGapsMin, ceiling);

    final gaps0 = gappable.toSet();
    final chosen = <int>{...tokens.taught.where(gaps0.contains)};
    if (chosen.length < wanted) {
      final rest = [
        for (final i in gappable)
          if (!chosen.contains(i)) i
      ]..shuffle(_random);
      for (final i in rest) {
        if (chosen.length >= wanted) break;
        chosen.add(i);
      }
    }
    return chosen.toList()..sort();
  }

  /// Слово и знаки препинания вокруг него.
  ///
  /// Плитка несёт **слово**, а знак остаётся в предложении. Плитка
  /// «Penicillin.» — с точкой — читалась как ответ вместе с концом
  /// предложения: игрок видел, куда её надо ставить, ещё не решив задание.
  /// Это же и обещание неверное: точка принадлежит предложению, как и запятая
  /// с вопросительным знаком, а не слову.
  ///
  /// Снимаются только те знаки, которые в корпусе действительно стоят по
  /// краям слова: `. ? , :` — и на всякий случай кавычки со скобками. Дефис
  /// НЕ снимается: «Renten-, Kranken- und Pflegekasse» — там он часть слова,
  /// а не знак при нём, и запятую с него снять надо, а дефис оставить.
  /// Апостроф тоже: «geht's» несёт его внутри, и слово без него — не слово.
  static ({String prefix, String core, String suffix}) _bare(String token) {
    var start = 0;
    var end = token.length;
    while (start < end && _edgeMarks.contains(token[start])) {
      start++;
    }
    while (end > start && _edgeMarks.contains(token[end - 1])) {
      end--;
    }
    return (
      prefix: token.substring(0, start),
      core: token.substring(start, end),
      suffix: token.substring(end),
    );
  }

  /// Знаки, которые считаются знаками **при** слове, а не его частью.
  static const _edgeMarks = '.,!?;:…«»„“”()[]';

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

}
