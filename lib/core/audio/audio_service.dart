import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/repositories/player_repository.dart';
import 'audio_manifest.dart';

/// Озвучка верного ответа.
///
/// Инвариант из README: **каждое верное соединение озвучивается**, и звук не
/// блокирует переход к следующему кругу — он играет поверх анимации
/// разворачивания. Отсюда два требования, которые и определяют устройство
/// сервиса:
///
/// 1. [play] возвращает управление немедленно и никогда не бросает. Ошибка
///    звука не имеет права остановить забег.
/// 2. Задержка от касания до звука должна быть незаметной. Один плеер этого
///    не даёт: пока он закрывает предыдущий файл и открывает следующий,
///    проходят десятки миллисекунд. Поэтому пул и предзагрузка.
abstract class AudioService {
  /// Готовит файл к мгновенному воспроизведению. Вызывается заранее — на
  /// разворачивании круга, а не в момент ответа.
  Future<void> preload(String audioId);

  /// Проигрывает файл. Не ждёт окончания и не бросает исключений.
  void play(String audioId);

  /// Тактильный отклик вместо звука — беззвучный режим.
  void haptic();

  Future<void> dispose();
}

/// Реализация на `just_audio` с пулом плееров.
///
/// Плееры чередуются по кругу: пока один играет, следующий уже держит
/// открытым свой файл. Размер пула — три: двух не хватает, когда игрок
/// отвечает быстрее, чем заканчивается предыдущее слово, а больше трёх
/// не даёт выигрыша и просто держит ресурсы.
class PooledAudioService implements AudioService {
  PooledAudioService({
    required this.lang,
    int poolSize = 3,
    this.enabled = true,
  }) : _players = List.generate(poolSize, (_) => AudioPlayer());

  /// Язык изучения: у каждого свой каталог озвучки и свой манифест.
  final String lang;

  final List<AudioPlayer> _players;
  int _next = 0;

  /// Звук выключен настройкой: вместо него вибрация.
  bool enabled;

  AudioManifest? _manifest;
  Future<AudioManifest>? _loading;

  /// Какой файл сейчас заряжен в каком плеере — чтобы не открывать заново.
  final Map<int, String> _loaded = {};

  /// Файлы, которые не открылись. Жалуемся один раз, а не каждый круг.
  final Set<String> _broken = {};

  /// Последние измеренные задержки — для спайка на реальном устройстве.
  final AudioLatencyProbe probe = AudioLatencyProbe();

  Future<AudioManifest> _ensureManifest() =>
      _loading ??= AudioManifest.load(lang).then((m) => _manifest = m);

  @override
  Future<void> preload(String audioId) async {
    if (!enabled || _broken.contains(audioId)) return;
    final path = (await _ensureManifest()).pathFor(audioId);
    if (path == null) return;

    final index = _next;
    if (_loaded[index] == audioId) return;
    try {
      await _players[index].setAsset(path);
      _loaded[index] = audioId;
    } catch (e) {
      _reportBroken(audioId, e);
    }
  }

  @override
  void play(String audioId) {
    if (!enabled || _broken.contains(audioId)) {
      haptic();
      return;
    }
    // Намеренно не await: забег не ждёт звука.
    unawaited(_play(audioId));
  }

  Future<void> _play(String audioId) async {
    final started = DateTime.now();
    final manifest = _manifest ?? await _ensureManifest();
    final path = manifest.pathFor(audioId);
    if (path == null) {
      // Озвучки нет — беззвучный отклик вместо тишины.
      _reportBroken(audioId, 'нет в манифесте');
      haptic();
      return;
    }

    final index = _next;
    _next = (_next + 1) % _players.length;
    final player = _players[index];

    try {
      if (_loaded[index] != audioId) {
        await player.setAsset(path);
        _loaded[index] = audioId;
      } else {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
      probe.record(DateTime.now().difference(started));
    } catch (e) {
      _reportBroken(audioId, e);
      haptic();
    }
  }

  @override
  void haptic() {
    // Тоже best-effort: на устройстве без вибромотора это не ошибка.
    HapticFeedback.selectionClick().catchError((_) {});
  }

  void _reportBroken(String audioId, Object error) {
    if (_broken.add(audioId) && kDebugMode) {
      debugPrint('[audio] нет озвучки $audioId: $error');
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
  }
}

/// Сервис-заглушка: ничего не играет. Используется в тестах и на платформах
/// без звука, чтобы игровой код не ветвился на «а есть ли звук».
class SilentAudioService implements AudioService {
  SilentAudioService();

  /// Что просили проиграть — удобно проверять в тестах.
  final List<String> played = [];

  /// Сколько раз отдавали вибрацию вместо звука.
  int hapticCount = 0;

  @override
  Future<void> preload(String audioId) async {}

  @override
  void play(String audioId) => played.add(audioId);

  @override
  void haptic() => hapticCount++;

  @override
  Future<void> dispose() async {}
}

/// Замер задержки от вызова [AudioService.play] до фактического старта
/// воспроизведения.
///
/// Существует ради спайка из PLAN.md M1: если медиана выше
/// [acceptableMedian], звук приходит после следующего круга и ломает темп
/// игры — тогда меняем библиотеку или момент озвучки, а не подкручиваем
/// анимации.
class AudioLatencyProbe {
  AudioLatencyProbe({this.capacity = 100});

  final int capacity;
  final List<Duration> _samples = [];

  /// Порог приемлемости из PLAN.md.
  static const Duration acceptableMedian = Duration(milliseconds: 80);

  List<Duration> get samples => List.unmodifiable(_samples);

  int get count => _samples.length;

  void record(Duration latency) {
    _samples.add(latency);
    if (_samples.length > capacity) _samples.removeAt(0);
  }

  void clear() => _samples.clear();

  Duration? get median {
    if (_samples.isEmpty) return null;
    final sorted = [..._samples]..sort();
    return sorted[sorted.length ~/ 2];
  }

  Duration? get worst =>
      _samples.isEmpty ? null : _samples.reduce((a, b) => a > b ? a : b);

  /// Укладывается ли замер в порог. `null` — данных ещё нет.
  bool? get isAcceptable {
    final m = median;
    return m == null ? null : m <= acceptableMedian;
  }
}

/// Единственный экземпляр на приложение: плееры — ресурс, их не создают на
/// каждый экран.
final audioServiceProvider = Provider<AudioService>((ref) {
  final player = ref.watch(playerControllerProvider);
  final service = PooledAudioService(
    lang: player?.targetLang ?? defaultTargetLang,
    enabled: player?.soundEnabled ?? true,
  );
  ref.onDispose(service.dispose);
  return service;
});
