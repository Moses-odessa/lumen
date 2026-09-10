import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/repositories/player_repository.dart';
import 'speech_locale.dart';

/// Что известно про синтез речи для языка изучения.
///
/// Различать «движка нет» и «языка нет» обязательно, потому что игроку нужно
/// сказать разное. В первом случае предлагать нечего, во втором — есть куда
/// пойти и что установить.
enum SpeechStatus {
  /// Голос есть и работает без сети.
  ready,

  /// Синтез в системе есть, но данных нужного языка нет. Это самый частый
  /// случай на Android: движок Google предустановлен, а языки докачиваются.
  languageMissing,

  /// Синтеза нет вовсе или он не отвечает.
  unavailable;

  bool get canSpeak => this == SpeechStatus.ready;
}

/// Чем кончилось произнесение — для того, кто его ждал.
///
/// Ждущий в игре один — круг на слух: пока фраза звучит, отвечать физически
/// не на что, и окно на ответ открывается по концу озвучки. Различать ему нужно
/// не «прозвучало или нет», а «наступила ли после моего произнесения тишина»:
/// окно, открытое на **чужом** произнесении, — это те же часы, идущие сквозь
/// звук, ради которых окно и стали ждать.
///
/// Сторож, который проверял вместо этого круг («тот же вопрос, что был?»),
/// пропускал ровно два пути: переслушивание и повтор после возвращения на
/// экран. Круг там тот же, а звучит уже второе чтение — окно открывалось под
/// голос.
enum SpeechOutcome {
  /// Произнесение кончилось, и после него тишина: говорить больше нечего.
  ///
  /// Сюда же попадает «говорить было нечем» — голоса нет, звук выключен,
  /// текст пуст. Для ждущего это то же самое: тишина уже наступила, и повиснуть
  /// он из-за этого не должен. Круг со слухом на телефоне без синтеза
  /// непроходим, но открыться обязан.
  done,

  /// Произнесение не последнее: его вытеснил новый запрос (переслушивание,
  /// повтор после возвращения), оборвал [SpeechService.stop] или служба
  /// замолчала. Окно откроет тот, кто вытеснил, — этот сигнал молчит.
  displaced,
}

/// Озвучка верного ответа — теперь синтезом устройства, а не файлами.
///
/// Инвариант из README остаётся: **каждое верное соединение озвучивается**,
/// и звук не блокирует переход к следующему кругу. Отсюда те же два
/// требования: [speak] возвращает управление немедленно и никогда не
/// бросает.
///
/// Что изменилось вместе с переходом: озвучивать можно любой текст, а не
/// только заранее записанные позиции. Поэтому фраза теперь звучит целиком,
/// а не одним словом из пропуска, и новый контент говорит с первого дня —
/// без прогона синтеза и без мегабайтов в установке.
///
/// Чем за это платим — тем, что голос принадлежит устройству. Его нельзя
/// вычитать, он разный на разных телефонах, и его может не оказаться. Первое
/// и второе — цена решения; третье проверяется до начала игры ([status]).
abstract class SpeechService {
  /// Состояние синтеза для языка изучения. Считается один раз и кэшируется:
  /// это платформенный вызов, а спрашивать его в горячем пути забега нельзя.
  Future<SpeechStatus> status({bool refresh = false});

  /// Произносит текст. Не ждёт окончания и не бросает исключений.
  ///
  /// Начатое произнесение **договаривается**. Пока говорится слово, новый
  /// запрос не обрывает его, а ждёт своей очереди — и очередь эта длиной в
  /// один: если за время произнесения запросов пришло несколько, прозвучит
  /// последний. См. [SpeechQueue].
  void speak(String text);

  /// То же произнесение, но с сигналом окончания — и с ответом на вопрос
  /// «кончилось ли **моё**».
  ///
  /// Нужно ровно одному месту — кругу на слух: там фраза существует только как
  /// звук, и пока она звучит, отвечать физически не на что. Окно на ответ
  /// поэтому открывается по этому сигналу, а не вместе с озвучкой (см.
  /// `RunController`); без него от пяти секунд на ответ игроку оставалось две.
  ///
  /// Правило «забег не ждёт звука» цело, и охраняет его подпись [speak]:
  /// она по-прежнему ничего не возвращает, то есть ждать её нельзя даже
  /// случайно. Ждать или нет решает тот, кто позвал; все остальные вызывающие
  /// зовут [speak] и не ждут.
  ///
  /// Будущее завершается, когда кончилось **это** произнесение, и говорит,
  /// осталась ли после него тишина ([SpeechOutcome]). Своего сигнала на запрос
  /// не было вовсе: служба отдавала всем ждущим одну общую цепочку, и
  /// «дозвучало» означало «дозвучало что-нибудь». Исключений не бросает:
  /// молчание не повод останавливать круг.
  Future<SpeechOutcome> speakAndWait(String text);

  /// Прерывает текущее произнесение: игрок ответил раньше, чем оно кончилось.
  ///
  /// Ждущие при этом получают [SpeechOutcome.displaced] — не повисают. Ждать
  /// сигнала, которого уже не будет, значило бы для круга на слух никогда не
  /// открыть окно.
  void stop();

  /// Замолчать и **молчать, пока не разрешат** ([allowSpeech]).
  ///
  /// Тишина вне экрана — состояние службы, а не поведение одного вызывающего,
  /// и это решение, а не удобство. Пока она была разовым `stop()` в корне,
  /// обещание «вне экрана тишина» держалось на двух несвязанных
  /// случайностях: забег проверял экран сам, а калибровка молчала потому, что
  /// у её единственной механики нет звучащего центра. Первый же экран, который
  /// заговорит, ничего из этого не наследует — и жалоба владельца («закрыл
  /// окно, а она продолжает говорить») вернулась бы.
  ///
  /// Что делается с уже начатым — обрывается: доигранная в закрытом окне фраза
  /// и есть та самая жалоба. Что делается с пришедшим, пока молчим, — не
  /// копится: отложенная фраза, прозвучавшая через минуту после возвращения, —
  /// тот же голос из закрытого окна, только с опозданием.
  void silence();

  /// Снова можно говорить. Сама речь при этом не начинается: что произносить,
  /// решает тот, кто ведёт круг, а не тот, кто следит за экраном.
  void allowSpeech();

  /// Молчит ли служба принудительно прямо сейчас.
  bool get silenced;

  /// Тактильный отклик вместо звука — беззвучный режим и отсутствие голоса.
  void haptic();

  Future<void> dispose();
}

/// Одна цепочка произнесений, очередь длиной в один и тишина как состояние.
///
/// Здесь живёт вся семантика одновременных произнесений, и живёт она **один
/// раз на обе службы**. Прежде её знало только устройство, а заглушка отдавала
/// на каждый вызов независимую задержку и на `stop()` никого не разрешала.
/// Расходились они ровно там, где идёт проверка: группа «окно ждёт озвучку»
/// зеленела против дубля, у которого второй запрос во время произнесения не
/// ждёт очереди, а звучит сам по себе. Контракт теперь общий по построению, а
/// не по совпадению, и `speech_service_test.dart` прогоняет его по обеим
/// службам — чтобы третья реализация не начала с той же ошибки.
///
/// Реализациям остаётся то, чем они и отличаются: чем произносить ([utter]),
/// чем оборвать ([abort]) и есть ли чем говорить вообще ([voiced]).
abstract class SpeechQueue implements SpeechService {
  /// Что звучит прямо сейчас; `null` — тишина.
  _Utterance? _current;

  /// Что прозвучит после текущего. Ровно одно, а не очередь.
  ///
  /// Очередь любой длины означала бы, что звук отстаёт от экрана на весь
  /// хвост: игрок ушёл на три круга вперёд, а телефон дочитывает прошлые.
  /// Поэтому ждёт своей очереди только **последний** запрос, а всё, что он
  /// вытеснил, не звучит вовсе.
  _Utterance? _queued;

  bool _silenced = false;

  @override
  bool get silenced => _silenced;

  /// Начинает произнесение. Будущее завершается, когда движок договорил.
  ///
  /// Исключений бросать не должно: цепочка, повисшая на одном произнесении,
  /// означала бы игру, замолчавшую до конца сессии.
  @protected
  Future<void> utter(String text);

  /// Обрывает платформенное произнесение. Зовётся и тогда, когда цепочка уже
  /// пуста: остаточный звук на платформе цепочке не виден.
  @protected
  void abort();

  /// Есть ли чем говорить. `false` — вместо звука вибрация: звук выключен
  /// настройкой игрока.
  @protected
  bool get voiced => true;

  /// Запрос взят в работу. Крючок для заглушки: ей надо помнить, о чём
  /// просили, даже если очередь это потом вытеснит.
  @protected
  void accepted(String text) {}

  @override
  void speak(String text) {
    // Намеренно теряем будущее: забег не ждёт звука, и подпись `void` — это
    // единственное, чем это правило можно охранять от случайного `await`.
    unawaited(speakAndWait(text));
  }

  @override
  Future<SpeechOutcome> speakAndWait(String text) {
    if (_silenced) {
      // Вне экрана — молчим и не копим. Ждущий получает отказ, а не тишину
      // без ответа: повиснуть он не должен даже здесь.
      return Future<SpeechOutcome>.value(SpeechOutcome.displaced);
    }
    if (text.isEmpty || !voiced) {
      haptic();
      // Тишина уже кончилась: ждать нечего, и ждущий не должен из-за этого
      // повиснуть. Круг со слухом без голоса открывает окно сразу — иначе он
      // не открыл бы его никогда.
      return Future<SpeechOutcome>.value(SpeechOutcome.done);
    }
    accepted(text);
    final utterance = _Utterance(text);
    final speaking = _current;
    if (speaking == null) {
      _current = utterance;
      _start(utterance);
      return utterance.outcome;
    }
    // Начатое договаривается — но тишины после него уже не наступит: следом
    // встало новое. Для ждущего это вытеснение, и окно откроет тот, кто
    // вытеснил, а не тот, кого договорили.
    speaking.settle(SpeechOutcome.displaced);
    _queued?.settle(SpeechOutcome.displaced);
    _queued = utterance;
    return utterance.outcome;
  }

  void _start(_Utterance utterance) {
    utter(utterance.text).then(
      (_) => _finished(utterance),
      // Ошибку произнесения ловит сама реализация; ловим и здесь, чтобы
      // цепочка не осталась стоять на упавшем движке.
      onError: (Object _) => _finished(utterance),
    );
  }

  void _finished(_Utterance utterance) {
    // Оборванное или вытесненное произнесение цепочку больше не двигает:
    // платформа может договорить в пустоту (`stop()` не обязан доводить
    // произнесение до сигнала, а у ожидания есть потолок), и её опоздавший
    // сигнал не должен запускать чужую очередь.
    if (!identical(_current, utterance)) return;
    final queued = _queued;
    _current = queued;
    _queued = null;
    // Если произнесение уже вытеснено, ответ ему давно дан — `settle`
    // повторного не отдаёт.
    utterance.settle(SpeechOutcome.done);
    if (queued != null) _start(queued);
  }

  @override
  void stop() {
    // Ждавшее своей очереди отменяется вместе с текущим: «остановить» значит
    // тишину, а не «домолчать до следующего слова».
    final speaking = _current;
    final queued = _queued;
    _current = null;
    _queued = null;
    queued?.settle(SpeechOutcome.displaced);
    speaking?.settle(SpeechOutcome.displaced);
    abort();
  }

  @override
  void silence() {
    _silenced = true;
    stop();
  }

  @override
  void allowSpeech() => _silenced = false;
}

/// Одно произнесение: текст и обещание тому, кто его ждёт.
class _Utterance {
  _Utterance(this.text);

  final String text;
  final Completer<SpeechOutcome> _completer = Completer<SpeechOutcome>();

  Future<SpeechOutcome> get outcome => _completer.future;

  /// Ответ ждущему. Первый ответ и окончательный: вытесненное произнесение
  /// потом ещё договаривает на платформе, и второй сигнал означал бы «после
  /// меня тишина» уже после того, как заговорило следующее.
  void settle(SpeechOutcome outcome) {
    if (!_completer.isCompleted) _completer.complete(outcome);
  }
}

/// Реализация на `flutter_tts`.
class DeviceSpeechService extends SpeechQueue {
  DeviceSpeechService({
    required this.lang,
    this.enabled = true,
    FlutterTts Function()? engine,
  }) : _engine = engine ?? FlutterTts.new;

  /// Язык изучения в виде кода проекта: `de`, `en`.
  final String lang;

  /// Звук выключен настройкой: вместо него вибрация.
  bool enabled;

  /// Движок создаётся лениво, и это не оптимизация.
  ///
  /// Конструктор `FlutterTts` сразу ставит обработчик канала, а для этого
  /// нужен инициализированный биндинг. Провайдер создаётся раньше — и
  /// доменные тесты, которым синтез не нужен вовсе, падали бы на попытке
  /// его собрать. Платформу трогаем тогда, когда действительно говорим.
  final FlutterTts Function() _engine;
  FlutterTts? _instance;

  FlutterTts get _tts => _instance ??= _engine();

  SpeechStatus? _status;
  Future<SpeechStatus>? _checking;
  bool _configured = false;

  /// Последние измеренные задержки — для замера на реальном устройстве.
  final SpeechLatencyProbe probe = SpeechLatencyProbe();

  @override
  Future<SpeechStatus> status({bool refresh = false}) {
    if (refresh) {
      _status = null;
      _checking = null;
    }
    final known = _status;
    if (known != null) return Future.value(known);
    return _checking ??= _check();
  }

  Future<SpeechStatus> _check() async {
    final tag = speechLocaleFor(lang);
    try {
      // Порядок проверок важен. `isLanguageInstalled` на Android требует
      // голоса, который работает без сети и не помечен «не установлен», —
      // это ровно то, что нужно офлайн-игре. На iOS этого метода нет, и
      // тогда остаётся `isLanguageAvailable` по списку системных голосов.
      final installed = await _tts.isLanguageInstalled(tag);
      if (installed is bool) {
        _status = installed
            ? SpeechStatus.ready
            : await _availableButNotInstalled(tag);
        return _status!;
      }
    } on MissingPluginException {
      // Метода нет на этой платформе — спрашиваем то, что есть.
    } catch (e) {
      if (kDebugMode) debugPrint('[speech] isLanguageInstalled: $e');
    }

    try {
      final available = await _tts.isLanguageAvailable(tag);
      _status = available == true
          ? SpeechStatus.ready
          : SpeechStatus.languageMissing;
    } catch (e) {
      if (kDebugMode) debugPrint('[speech] isLanguageAvailable: $e');
      _status = SpeechStatus.unavailable;
    }
    return _status!;
  }

  /// Языка нет. Осталось понять, есть ли вообще синтез: если движок не
  /// отвечает даже списком языков, предлагать установку бессмысленно.
  Future<SpeechStatus> _availableButNotInstalled(String tag) async {
    try {
      final languages = await _tts.getLanguages;
      if (languages is List && languages.isEmpty) {
        return SpeechStatus.unavailable;
      }
    } catch (_) {
      return SpeechStatus.unavailable;
    }
    return SpeechStatus.languageMissing;
  }

  /// Настройка движка. Делается один раз, лениво: до первого произнесения
  /// платформенные вызовы не нужны.
  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.setLanguage(speechLocaleFor(lang));
    // Чуть медленнее обычного: это образец произношения, а не диктовка.
    await _tts.setSpeechRate(speechRate);
    // Ждём окончания — но ждёт **сервис**, а не забег.
    //
    // Было `false`, и тогда `speak` возвращался сразу, а следующий запрос
    // рубил начатое: на Android новое произнесение по умолчанию идёт с
    // `QUEUE_FLUSH`. Слышно это было так — игрок верно соединяет слово, оно
    // начинает звучать и обрывается на середине, потому что следующий круг
    // оказался кругом на слух и его центр заиграл поверх.
    //
    // Забег от этого не замедлился: `speak` по-прежнему возвращает
    // управление немедленно, ожидание живёт внутри цепочки ([SpeechQueue]).
    await _tts.awaitSpeakCompletion(true);
  }

  /// Скорость речи. У платформ разная шкала: на Android 1.0 — это «в два
  /// раза быстрее нормы», на iOS нормой считается около 0.5.
  static double get speechRate =>
      defaultTargetPlatform == TargetPlatform.iOS ? 0.45 : 0.5;

  /// Потолок ожидания одного произнесения.
  ///
  /// Страховка от движка, который не сообщает об окончании: без неё цепочка
  /// осталась бы висеть, и игра замолчала бы до конца сессии. Слово читается
  /// меньше двух секунд, предложение — меньше четырёх.
  static const _speakCeiling = Duration(seconds: 6);

  /// Звук выключен настройкой — говорить нечем, но вибрация остаётся.
  @override
  bool get voiced => enabled;

  @override
  Future<void> utter(String text) async {
    final started = DateTime.now();
    try {
      if (!(await status()).canSpeak) {
        haptic();
        return;
      }
      await _configure();
      await _tts.speak(text).timeout(_speakCeiling, onTimeout: () => null);
      probe.record(DateTime.now().difference(started));
    } catch (e) {
      if (kDebugMode) debugPrint('[speech] speak "$text": $e');
      haptic();
    }
  }

  @override
  void abort() {
    // Движка ещё нет — останавливать нечего, и создавать его ради этого
    // тоже нечего.
    if (_instance == null) return;
    unawaited(_tts.stop().catchError((_) => null));
  }

  @override
  void haptic() {
    // Best-effort: на устройстве без вибромотора это не ошибка.
    HapticFeedback.selectionClick().catchError((_) {});
  }

  @override
  Future<void> dispose() async => stop();
}

/// Сервис-заглушка: ничего не произносит.
///
/// Нужен тестам и беззвучному режиму, чтобы игровой код не ветвился на
/// «а есть ли голос».
///
/// Очередь, вытеснение и тишину она берёт у [SpeechQueue] — то есть у той же
/// цепочки, что работает на устройстве, — и своей семантики одновременных
/// произнесений у неё больше нет. Была: независимая задержка на каждый вызов и
/// `stop()`, который никого не разрешал. Заглушка вела себя обратно настоящей
/// службе ровно в том месте, которое ею и проверяют, — «окно ждёт озвучку», —
/// и группа зеленела на семантике, которой в игре не существует.
class SilentSpeechService extends SpeechQueue {
  SilentSpeechService({
    this.reported = SpeechStatus.ready,
    this.sounds = Duration.zero,
  });

  /// Что отвечать на [status] — тестам удобно подменять.
  final SpeechStatus reported;

  /// Сколько «длится» произнесение. Меняется на ходу, как [enabled] у
  /// устройства: круг на слух и круг на чтение живут в одном тесте.
  ///
  /// Ноль по умолчанию, и это не лень: заглушка нужна большинству тестов
  /// именно мгновенной. Но правило «окно открывается, когда фраза дозвучала»
  /// на мгновенном голосе не проверить — с ним «до» и «после» приходятся на
  /// один и тот же миг. Тесты круга на слух ставят здесь настоящую длину
  /// предложения (две-три секунды), и тогда видно, тикали ли часы сквозь
  /// озвучку.
  Duration sounds;

  /// Что просили произнести и служба взяла в работу.
  ///
  /// «Взяла в работу» — не то же, что «прозвучало», и разделены они нарочно.
  /// Взятое может быть вытеснено следующим запросом и не прозвучать вовсе
  /// ([uttered]); а вот отказ службы — молчание вне экрана или выключенный
  /// звук — здесь не появляется. Большинство тестов спрашивает именно
  /// «попросили ли»: им довольно того, что игра сказала своё слово.
  final List<String> spoken = [];

  /// Что действительно прозвучало: без вытесненного и без оборванного.
  ///
  /// Нужен тому, кто проверяет саму службу, — очередь, вытеснение, тишину.
  /// На устройстве это видно по вызовам канала, здесь — по этому списку.
  final List<String> uttered = [];

  /// Сколько раз отдавали вибрацию вместо звука.
  int hapticCount = 0;

  int stopCount = 0;

  @override
  Future<SpeechStatus> status({bool refresh = false}) async => reported;

  @override
  void accepted(String text) => spoken.add(text);

  @override
  Future<void> utter(String text) {
    if (!reported.canSpeak) {
      // Устройство без голоса отвечает вибрацией и мгновенной тишиной:
      // заглушка, «произносящая» две секунды там, где синтеза нет, показывала
      // бы кругу на слух окно, которого на таком телефоне не бывает.
      haptic();
      return Future<void>.value();
    }
    uttered.add(text);
    // Мгновенный голос отвечает мгновенно, а не через микрозадачу: лишняя
    // микрозадача сдвинула бы порядок событий в десятках тестов, которые про
    // звук не знают ничего.
    return sounds == Duration.zero
        ? Future<void>.value()
        : Future<void>.delayed(sounds);
  }

  @override
  void abort() {
    // Обрывать нечего: `Future.delayed` не отменяется. И не нужно — цепочка
    // сверяет опоздавший сигнал с текущим произнесением, а не верит ему на
    // слово, поэтому «договорившая в пустоту» задержка её не двигает.
  }

  @override
  void stop() {
    stopCount++;
    super.stop();
  }

  @override
  void haptic() => hapticCount++;

  @override
  Future<void> dispose() async {}
}

/// Замер задержки от вызова [SpeechService.speak] до старта произнесения.
///
/// С файлами задержку давало открытие плеера, и её лечили предзагрузкой.
/// У синтеза предзагрузки нет: движок инициализируется на первом вызове, и
/// первое слово в сессии заведомо медленнее остальных. Поэтому замер стал
/// нужнее, а не менее нужен — и медиана здесь честнее среднего.
class SpeechLatencyProbe {
  SpeechLatencyProbe({this.capacity = 100});

  final int capacity;
  final List<Duration> _samples = [];

  /// Порог приемлемости из PLAN.md: выше — звук приходит после следующего
  /// круга и ломает темп игры.
  static const Duration acceptableMedian = Duration(milliseconds: 80);

  List<Duration> get samples => List.unmodifiable(_samples);

  void record(Duration value) {
    _samples.add(value);
    if (_samples.length > capacity) _samples.removeAt(0);
  }

  void clear() => _samples.clear();

  Duration? get median {
    if (_samples.isEmpty) return null;
    final sorted = [..._samples]..sort();
    return sorted[sorted.length ~/ 2];
  }

  bool get isAcceptable {
    final value = median;
    return value != null && value <= acceptableMedian;
  }
}

/// Сервис синтеза для текущего языка изучения.
final speechServiceProvider = Provider<SpeechService>((ref) {
  final player = ref.watch(playerControllerProvider);
  final service = DeviceSpeechService(
    lang: player?.targetLang ?? defaultTargetLang,
    enabled: player?.soundEnabled ?? true,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Состояние синтеза для языка изучения.
///
/// Отдельный провайдер, потому что состояние спрашивают экраны, а не
/// игровой цикл: онбординг — чтобы предупредить до начала, настройки —
/// чтобы показать, почему тихо.
final speechStatusProvider = FutureProvider<SpeechStatus>(
  (ref) => ref.watch(speechServiceProvider).status(),
);
