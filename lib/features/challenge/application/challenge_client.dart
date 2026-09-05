import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'challenge_transport.dart';

/// Одна пара ночного вызова.
class ChallengePair {
  const ChallengePair({
    required this.conceptId,
    required this.target,
    this.article,
    this.audioId,
  });

  final String conceptId;
  final String target;
  final String? article;
  final String? audioId;

  static ChallengePair fromJson(Map<String, Object?> json) => ChallengePair(
        conceptId: json['concept']! as String,
        target: json['target']! as String,
        article: json['article'] as String?,
        audioId: json['audio'] as String?,
      );
}

/// Ночной вызов на день.
class DailyChallenge {
  const DailyChallenge({
    required this.day,
    required this.lang,
    required this.pairs,
    required this.seconds,
  });

  final String day;
  final String lang;
  final List<ChallengePair> pairs;
  final int seconds;

  Duration get duration => Duration(seconds: seconds);

  static DailyChallenge fromJson(Map<String, Object?> json) => DailyChallenge(
        day: json['day']! as String,
        lang: json['lang']! as String,
        seconds: (json['seconds'] as num?)?.toInt() ?? 60,
        pairs: [
          for (final p in (json['pairs'] as List? ?? const []))
            ChallengePair.fromJson(p as Map<String, Object?>),
        ],
      );
}

/// Загрузка ночного вызова.
///
/// **Единственное сетевое место во всей игре.** Отсюда три следствия,
/// заложенные в устройство:
///
/// 1. Никакого пакета HTTP-клиента: один GET статического файла делается
///    платформенными средствами. Инвариант из AGENT.md — `http` и `archive`
///    не появляются в проекте раньше M8.
/// 2. Отсутствие сети — не ошибка. Играется всё, кроме вызова, и приложение
///    об этом говорит спокойно.
/// 3. Файл один на язык и день, поэтому его можно закешировать навсегда:
///    вчерашний вызов не меняется.
class ChallengeClient {
  ChallengeClient({required this.baseUrl, ChallengeTransport? transport})
      : _transport = transport ?? createTransport();

  /// База CDN, задаётся при сборке: `--dart-define=CHALLENGE_BASE_URL=...`.
  /// Пусто — вызов просто недоступен, и это нормальное состояние до M7.
  final String baseUrl;

  final ChallengeTransport _transport;

  final Map<String, DailyChallenge> _cache = {};

  bool get isConfigured => baseUrl.isNotEmpty;

  /// Вызов на день; `null` — нет сети, нет файла или CDN не настроен.
  Future<DailyChallenge?> load(String lang, DateTime day) async {
    if (!isConfigured) return null;

    final key = dayKey(day);
    final cached = _cache['$lang/$key'];
    if (cached != null) return cached;

    try {
      final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/$lang/$key.json';
      final body = await _transport.get(url);
      if (body == null) return null;

      final json = jsonDecode(body) as Map<String, Object?>;
      final challenge = DailyChallenge.fromJson(json);
      _cache['$lang/$key'] = challenge;
      return challenge;
    } catch (e) {
      if (kDebugMode) debugPrint('[challenge] $e');
      return null;
    }
  }

  /// Ключ дня в UTC: вызов общий для всех часовых поясов, иначе «один и тот
  /// же набор для всех» перестал бы быть одним и тем же.
  static String dayKey(DateTime day) {
    final utc = day.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }
}
