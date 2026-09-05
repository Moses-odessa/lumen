import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/cloud/user_data.dart';
import 'cloud_sync.dart';

/// Ключи Supabase передаются при сборке и в репозитории их нет.
///
/// Имя `SUPABASE_ANON_KEY` сохранено ради совместимости со сборками
/// athlete_index; в API это теперь `publishableKey`.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Инициализация. Без ключей — тихо ничего не делает: игра офлайн-первая, и
/// отсутствие облака для неё нормально, а не аварийно.
Future<bool> initSupabase() async {
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return false;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    return true;
  } catch (e) {
    if (kDebugMode) debugPrint('[supabase] init: $e');
    return false;
  }
}

/// Синхронизация через Supabase: снимок одной строкой JSONB в `backups`.
///
/// Схема — `supabase/schema.sql`. Здесь нет ни лиг, ни дуэлей: снимок и
/// социальное — разные вещи с разными правами доступа, и мешать их в одном
/// клиенте значит однажды выгрузить чужие данные не туда.
class SupabaseCloudSync implements CloudSync {
  SupabaseCloudSync(this._client);

  factory SupabaseCloudSync.instance() =>
      SupabaseCloudSync(Supabase.instance.client);

  final SupabaseClient _client;

  static const String _table = 'backups';

  @override
  bool get isConfigured => supabaseUrl.isNotEmpty;

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Stream<bool> get authChanges =>
      _client.auth.onAuthStateChange.map((event) => event.session != null);

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<UserData?> download() async {
    final id = userId;
    if (id == null) return null;

    final row = await _client
        .from(_table)
        .select('data')
        .eq('user_id', id)
        .maybeSingle();

    final data = row?['data'];
    return data is Map<String, Object?> ? decodeUserData(data) : null;
  }

  @override
  Future<void> upload(UserData data) async {
    final id = userId;
    if (id == null) return;

    // `updated_at` проставляет сервер триггером: часы на устройстве могут
    // врать, а от этой отметки зависит разрешение конфликтов.
    await _client.from(_table).upsert({
      'user_id': id,
      'data': encodeUserData(data),
    });
  }

  @override
  Stream<UserData> watch() {
    final id = userId;
    if (id == null) return const Stream.empty();

    return _client
        .from(_table)
        .stream(primaryKey: ['user_id'])
        .eq('user_id', id)
        .map((rows) {
          if (rows.isEmpty) return const UserData();
          final data = rows.first['data'];
          return data is Map<String, Object?>
              ? decodeUserData(data)
              : const UserData();
        })
        .where((data) => !data.isEmpty);
  }

  @override
  Future<void> deleteRemote() async {
    final id = userId;
    if (id == null) return;
    await _client.from(_table).delete().eq('user_id', id);
  }
}
