/// Снимок пользовательских данных: кодирование, разбор и слияние.
///
/// Чистый Dart и никакой сети. Это принципиально: слияние двух состояний —
/// самая опасная операция во всём проекте, потому что её ошибка стирает
/// прогресс молча и навсегда. Такую вещь нужно уметь прогонять тестами без
/// сервера, аккаунта и интернета.
///
/// Формат совпадает с тем, что отдаёт экспорт данных: одно и то же должно
/// описываться одинаково, иначе одна из двух веток сломается незаметно.
library;

/// Состояние одного слова в снимке.
class WordSnapshot {
  const WordSnapshot({
    required this.conceptId,
    required this.tier,
    required this.difficulty,
    required this.stability,
    this.lastReview,
    this.due,
    this.reps = 0,
    this.lapses = 0,
    this.burning = false,
  });

  final String conceptId;
  final String tier;
  final double difficulty;
  final double stability;
  final DateTime? lastReview;
  final DateTime? due;
  final int reps;
  final int lapses;
  final bool burning;

  Map<String, Object?> toJson() => {
        'conceptId': conceptId,
        'tier': tier,
        'difficulty': difficulty,
        'stability': stability,
        'lastReview': lastReview?.toIso8601String(),
        'due': due?.toIso8601String(),
        'reps': reps,
        'lapses': lapses,
        'burning': burning,
      };

  static WordSnapshot fromJson(Map<String, Object?> json) => WordSnapshot(
        conceptId: json['conceptId']! as String,
        tier: json['tier'] as String? ?? 'a0',
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5,
        stability: (json['stability'] as num?)?.toDouble() ?? 0,
        lastReview: _date(json['lastReview']),
        due: _date(json['due']),
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        lapses: (json['lapses'] as num?)?.toInt() ?? 0,
        burning: json['burning'] as bool? ?? false,
      );
}

/// Сессия в снимке — агрегат, а не строка журнала.
class SessionSnapshot {
  const SessionSnapshot({
    required this.startedAt,
    required this.durationMs,
    required this.lmGained,
    required this.score,
    required this.newWords,
  });

  final DateTime startedAt;
  final int durationMs;
  final int lmGained;
  final int score;
  final int newWords;

  Map<String, Object?> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'durationMs': durationMs,
        'lmGained': lmGained,
        'score': score,
        'newWords': newWords,
      };

  static SessionSnapshot fromJson(Map<String, Object?> json) =>
      SessionSnapshot(
        startedAt: _date(json['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        lmGained: (json['lmGained'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toInt() ?? 0,
        newWords: (json['newWords'] as num?)?.toInt() ?? 0,
      );
}

/// Профиль игрока в снимке.
class PlayerSnapshot {
  const PlayerSnapshot({
    required this.targetLang,
    required this.nativeLang,
    required this.tier,
    this.uiLang,
    this.calibrated = false,
    this.orbit = 0,
    this.sparks = 0,
    this.lastPlayedAt,
    this.missedInRow = 0,
    this.freePace = false,
    this.soundEnabled = true,
  });

  final String targetLang;
  final String nativeLang;
  final String? uiLang;
  final String tier;
  final bool calibrated;
  final int orbit;
  final int sparks;
  final DateTime? lastPlayedAt;
  final int missedInRow;
  final bool freePace;
  final bool soundEnabled;

  Map<String, Object?> toJson() => {
        'targetLang': targetLang,
        'nativeLang': nativeLang,
        'uiLang': uiLang,
        'tier': tier,
        'calibrated': calibrated,
        'orbit': orbit,
        'sparks': sparks,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'missedInRow': missedInRow,
        'freePace': freePace,
        'soundEnabled': soundEnabled,
      };

  static PlayerSnapshot fromJson(Map<String, Object?> json) => PlayerSnapshot(
        targetLang: json['targetLang'] as String? ?? 'de',
        nativeLang: json['nativeLang'] as String? ?? 'ru',
        uiLang: json['uiLang'] as String?,
        tier: json['tier'] as String? ?? 'a0',
        calibrated: json['calibrated'] as bool? ?? false,
        orbit: (json['orbit'] as num?)?.toInt() ?? 0,
        sparks: (json['sparks'] as num?)?.toInt() ?? 0,
        lastPlayedAt: _date(json['lastPlayedAt']),
        missedInRow: (json['missedInRow'] as num?)?.toInt() ?? 0,
        freePace: json['freePace'] as bool? ?? false,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
      );
}

/// Свои слова в снимке.
class CustomWordSnapshot {
  const CustomWordSnapshot({
    required this.id,
    required this.target,
    required this.native,
    required this.deck,
  });

  final String id;
  final String target;
  final String native;
  final String deck;

  Map<String, Object?> toJson() =>
      {'id': id, 'target': target, 'native': native, 'deck': deck};

  static CustomWordSnapshot fromJson(Map<String, Object?> json) =>
      CustomWordSnapshot(
        id: json['id']! as String,
        target: json['target'] as String? ?? '',
        native: json['native'] as String? ?? '',
        deck: json['deck'] as String? ?? 'custom',
      );
}

/// Полный снимок.
class UserData {
  const UserData({
    this.player,
    this.words = const [],
    this.sessions = const [],
    this.customWords = const [],
  });

  /// Версия формата. Растёт вместе со схемой снимка.
  static const int version = 1;

  final PlayerSnapshot? player;
  final List<WordSnapshot> words;
  final List<SessionSnapshot> sessions;
  final List<CustomWordSnapshot> customWords;

  bool get isEmpty =>
      player == null &&
      words.isEmpty &&
      sessions.isEmpty &&
      customWords.isEmpty;
}

/// Снимок → JSON.
Map<String, Object?> encodeUserData(UserData data) => {
      'version': UserData.version,
      'player': data.player?.toJson(),
      'wordStates': [for (final w in data.words) w.toJson()],
      'sessions': [for (final s in data.sessions) s.toJson()],
      'customConcepts': [for (final c in data.customWords) c.toJson()],
      // `Reviews` в облако не уходят: журнал большой, нужен только локально
      // для дообучения FSRS и на другом устройстве бесполезен
      // (docs/DATA_MODEL.md).
    };

/// JSON → снимок.
///
/// Терпим к мусору: чужая версия, отсутствующие поля, `null` вместо списка.
/// Снимок приходит из сети, и падать на нём — значит терять доступ к своим
/// же данным из-за чужой ошибки.
UserData decodeUserData(Map<String, Object?> json) => UserData(
      player: json['player'] is Map<String, Object?>
          ? PlayerSnapshot.fromJson(json['player']! as Map<String, Object?>)
          : null,
      words: _list(json['wordStates'], WordSnapshot.fromJson),
      sessions: _list(json['sessions'], SessionSnapshot.fromJson),
      customWords: _list(json['customConcepts'], CustomWordSnapshot.fromJson),
    );

/// Объединяет локальное и облачное состояние.
///
/// Правило одно и оно строгое: **данные не пропадают**. Поэтому union по
/// ключу, а не «кто последний, тот и прав» по всему снимку.
///
/// - Слова объединяются по `conceptId`, побеждает запись с более свежим
///   `lastReview`: она содержит больше повторений.
/// - Сессии объединяются по моменту начала, дубли отбрасываются.
/// - Свои слова объединяются по `id`.
/// - Профиль берётся у того, кто играл позже, но орбита и искры — максимум
///   из двух: терять их из-за расхождения часов на устройствах нельзя.
UserData mergeUserData(UserData local, UserData remote) {
  final words = <String, WordSnapshot>{
    for (final word in local.words) word.conceptId: word,
  };
  for (final word in remote.words) {
    final existing = words[word.conceptId];
    if (existing == null || _isNewer(word.lastReview, existing.lastReview)) {
      words[word.conceptId] = word;
    }
  }

  final sessions = <String, SessionSnapshot>{
    for (final s in [...local.sessions, ...remote.sessions])
      s.startedAt.toUtc().toIso8601String(): s,
  };

  final custom = <String, CustomWordSnapshot>{
    for (final c in [...local.customWords, ...remote.customWords]) c.id: c,
  };

  return UserData(
    player: _mergePlayers(local.player, remote.player),
    words: words.values.toList()
      ..sort((a, b) => a.conceptId.compareTo(b.conceptId)),
    sessions: sessions.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
    customWords: custom.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id)),
  );
}

PlayerSnapshot? _mergePlayers(PlayerSnapshot? local, PlayerSnapshot? remote) {
  if (local == null) return remote;
  if (remote == null) return local;

  final localNewer = _isNewer(local.lastPlayedAt, remote.lastPlayedAt);
  final base = localNewer ? local : remote;

  return PlayerSnapshot(
    targetLang: base.targetLang,
    nativeLang: base.nativeLang,
    uiLang: base.uiLang,
    // Ярус берётся выше из двух: понизить его игрок может сам одним тапом,
    // а вот необъяснимое понижение после синхронизации выглядит как потеря.
    tier: _higherTier(local.tier, remote.tier),
    calibrated: local.calibrated || remote.calibrated,
    orbit: local.orbit > remote.orbit ? local.orbit : remote.orbit,
    sparks: local.sparks > remote.sparks ? local.sparks : remote.sparks,
    lastPlayedAt: _later(local.lastPlayedAt, remote.lastPlayedAt),
    missedInRow: base.missedInRow,
    freePace: base.freePace,
    soundEnabled: base.soundEnabled,
  );
}

const List<String> _tierOrder = ['a0', 'a1', 'a2', 'b1', 'b2'];

String _higherTier(String a, String b) =>
    _tierOrder.indexOf(a) >= _tierOrder.indexOf(b) ? a : b;

bool _isNewer(DateTime? candidate, DateTime? current) {
  if (candidate == null) return false;
  if (current == null) return true;
  return candidate.isAfter(current);
}

DateTime? _later(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

List<T> _list<T>(
  Object? node,
  T Function(Map<String, Object?>) parse,
) {
  if (node is! List) return const [];
  final result = <T>[];
  for (final item in node) {
    if (item is Map<String, Object?>) {
      try {
        result.add(parse(item));
      } catch (_) {
        // Одна битая запись не должна ронять весь снимок.
      }
    }
  }
  return result;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
