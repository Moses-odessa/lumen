import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/remote/cloud_sync.dart';
import '../../../data/remote/supabase_cloud_sync.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/cloud/user_data.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/tier.dart';

/// Какой синхронизацией пользуемся. Без ключей — [DisabledCloudSync], и ни
/// один экран об этом не узнаёт.
final cloudSyncProvider = Provider<CloudSync>((ref) {
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    return const DisabledCloudSync();
  }
  try {
    return SupabaseCloudSync.instance();
  } catch (_) {
    // Supabase не проинициализировался — играем офлайн.
    return const DisabledCloudSync();
  }
});

class CloudState {
  const CloudState({
    this.configured = false,
    this.signedIn = false,
    this.syncing = false,
    this.lastSyncedAt,
    this.error,
  });

  final bool configured;
  final bool signedIn;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final String? error;

  CloudState copyWith({
    bool? configured,
    bool? signedIn,
    bool? syncing,
    DateTime? Function()? lastSyncedAt,
    String? Function()? error,
  }) =>
      CloudState(
        configured: configured ?? this.configured,
        signedIn: signedIn ?? this.signedIn,
        syncing: syncing ?? this.syncing,
        lastSyncedAt:
            lastSyncedAt == null ? this.lastSyncedAt : lastSyncedAt(),
        error: error == null ? this.error : error(),
      );
}

/// Облако: вход, выгрузка, слияние.
///
/// Аккаунт **необязателен**. Игра целиком работает без него, и любая ошибка
/// здесь не имеет права ничего сломать локально — максимум показать текст на
/// экране облака.
class CloudController extends Notifier<CloudState> {
  StreamSubscription<bool>? _auth;
  StreamSubscription<UserData>? _remote;
  Timer? _debounce;

  @override
  CloudState build() {
    final sync = ref.watch(cloudSyncProvider);
    ref.onDispose(() {
      _auth?.cancel();
      _remote?.cancel();
      _debounce?.cancel();
    });

    _auth = sync.authChanges.listen((signedIn) {
      state = state.copyWith(signedIn: signedIn);
      if (signedIn) {
        unawaited(pull());
        _listenRemote();
      } else {
        _remote?.cancel();
      }
    });

    return CloudState(
      configured: sync.isConfigured,
      signedIn: sync.isSignedIn,
    );
  }

  Future<void> signIn(String email, String password) =>
      _guard(() => ref.read(cloudSyncProvider).signIn(
            email: email,
            password: password,
          ));

  Future<void> signUp(String email, String password) =>
      _guard(() => ref.read(cloudSyncProvider).signUp(
            email: email,
            password: password,
          ));

  Future<void> resetPassword(String email) =>
      _guard(() => ref.read(cloudSyncProvider).resetPassword(email));

  Future<void> signOut() async {
    _remote?.cancel();
    await _guard(() => ref.read(cloudSyncProvider).signOut());
  }

  /// Забирает облачный снимок и сливает с локальным.
  Future<void> pull() => _guard(() async {
        final remote = await ref.read(cloudSyncProvider).download();
        if (remote == null) return;
        await _apply(remote);
      });

  /// Выгружает локальное состояние.
  Future<void> push() => _guard(() async {
        final local = await _collect();
        await ref.read(cloudSyncProvider).upload(local);
        state = state.copyWith(lastSyncedAt: () => DateTime.now());
      });

  /// Выгрузка с задержкой: во время забега состояние меняется на каждом
  /// круге, и слать снимок двадцать раз подряд незачем.
  void scheduleUpload() {
    if (!state.signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(push()));
  }

  /// Удаляет облачную копию, не трогая локальные данные.
  Future<void> deleteRemote() =>
      _guard(() => ref.read(cloudSyncProvider).deleteRemote());

  void _listenRemote() {
    _remote?.cancel();
    _remote = ref.read(cloudSyncProvider).watch().listen(
          (data) => unawaited(_apply(data)),
          onError: (_) {},
        );
  }

  /// Сливает облачный снимок с локальным и записывает результат.
  ///
  /// Именно слияние, а не замена: «кто последний, тот и прав» стирает
  /// прогресс второго устройства молча.
  Future<void> _apply(UserData remote) async {
    final local = await _collect();
    final merged = mergeUserData(local, remote);
    final db = ref.read(appDatabaseProvider);

    final player = merged.player;
    if (player != null) {
      ref.read(playerControllerProvider.notifier).replace(
            Player(
              targetLang: player.targetLang,
              nativeLang: player.nativeLang,
              uiLang: player.uiLang,
              tier: Tier.fromCode(player.tier),
              calibrated: player.calibrated,
              orbit: player.orbit,
              sparks: player.sparks,
              lastPlayedAt: player.lastPlayedAt,
              missedInRow: player.missedInRow,
              freePace: player.freePace,
              soundEnabled: player.soundEnabled,
            ),
          );
    }

    for (final word in merged.words) {
      await db.into(db.wordStates).insertOnConflictUpdate(
            WordStatesCompanion(
              conceptId: Value(word.conceptId),
              tier: Value(word.tier),
              difficulty: Value(word.difficulty),
              stability: Value(word.stability),
              lastReview: Value(word.lastReview),
              due: Value(word.due),
              reps: Value(word.reps),
              lapses: Value(word.lapses),
              burning: Value(word.burning),
            ),
          );
    }

    await db.replaceCustomConcepts([
      for (final custom in merged.customWords)
        CustomConceptsCompanion(
          id: Value(custom.id),
          target: Value(custom.target),
          native: Value(custom.native),
          deck: Value(custom.deck),
        ),
    ]);

    state = state.copyWith(lastSyncedAt: () => DateTime.now());
  }

  /// Локальное состояние в виде снимка.
  Future<UserData> _collect() async {
    final db = ref.read(appDatabaseProvider);
    final player = ref.read(playerControllerProvider);

    return UserData(
      player: player == null
          ? null
          : PlayerSnapshot(
              targetLang: player.targetLang,
              nativeLang: player.nativeLang,
              uiLang: player.uiLang,
              tier: player.tier.code,
              calibrated: player.calibrated,
              orbit: player.orbit,
              sparks: player.sparks,
              lastPlayedAt: player.lastPlayedAt,
              missedInRow: player.missedInRow,
              freePace: player.freePace,
              soundEnabled: player.soundEnabled,
            ),
      words: [
        for (final row in await db.loadWordStates())
          WordSnapshot(
            conceptId: row.conceptId,
            tier: row.tier,
            difficulty: row.difficulty,
            stability: row.stability,
            lastReview: row.lastReview,
            due: row.due,
            reps: row.reps,
            lapses: row.lapses,
            burning: row.burning,
          ),
      ],
      sessions: [
        for (final row in await db.loadSessions(limit: 500))
          SessionSnapshot(
            startedAt: row.startedAt,
            durationMs: row.durationMs,
            lmGained: row.lmGained,
            score: row.score,
            newWords: row.newWords,
          ),
      ],
      customWords: [
        for (final row in await db.loadCustomConcepts())
          CustomWordSnapshot(
            id: row.id,
            target: row.target,
            native: row.native,
            deck: row.deck,
          ),
      ],
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    state = state.copyWith(syncing: true, error: () => null);
    try {
      await action();
    } catch (e) {
      state = state.copyWith(error: () => '$e');
    } finally {
      state = state.copyWith(syncing: false);
    }
  }
}

final cloudControllerProvider =
    NotifierProvider<CloudController, CloudState>(CloudController.new);
