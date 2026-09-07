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
  void speak(String text);

  /// Прерывает текущее произнесение: игрок ответил раньше, чем оно кончилось.
  void stop();

  /// Тактильный отклик вместо звука — беззвучный режим и отсутствие голоса.
  void haptic();

  Future<void> dispose();
}

/// Реализация на `flutter_tts`.
class DeviceSpeechService implements SpeechService {
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
    // Не ждём окончания: забег не должен упираться в длину слова.
    await _tts.awaitSpeakCompletion(false);
  }

  /// Скорость речи. У платформ разная шкала: на Android 1.0 — это «в два
  /// раза быстрее нормы», на iOS нормой считается около 0.5.
  static double get speechRate =>
      defaultTargetPlatform == TargetPlatform.iOS ? 0.45 : 0.5;

  @override
  void speak(String text) {
    if (!enabled || text.isEmpty) {
      haptic();
      return;
    }
    // Намеренно не await: забег не ждёт звука.
    unawaited(_speak(text));
  }

  Future<void> _speak(String text) async {
    final started = DateTime.now();
    try {
      if (!(await status()).canSpeak) {
        haptic();
        return;
      }
      await _configure();
      await _tts.speak(text);
      probe.record(DateTime.now().difference(started));
    } catch (e) {
      if (kDebugMode) debugPrint('[speech] speak "$text": $e');
      haptic();
    }
  }

  @override
  void stop() {
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
class SilentSpeechService implements SpeechService {
  SilentSpeechService({this.reported = SpeechStatus.ready});

  /// Что отвечать на [status] — тестам удобно подменять.
  final SpeechStatus reported;

  /// Что просили произнести.
  final List<String> spoken = [];

  /// Сколько раз отдавали вибрацию вместо звука.
  int hapticCount = 0;

  int stopCount = 0;

  @override
  Future<SpeechStatus> status({bool refresh = false}) async => reported;

  @override
  void speak(String text) => spoken.add(text);

  @override
  void stop() => stopCount++;

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
