import '../../domain/cloud/user_data.dart';

/// Облачная синхронизация.
///
/// Интерфейс отдельно от реализации не ради красоты: игра обязана работать
/// без аккаунта и без сети, поэтому весь остальной код видит только этот
/// контракт и ни строчки Supabase. Когда облако не настроено, подставляется
/// [DisabledCloudSync], и ни один экран об этом не узнаёт.
abstract class CloudSync {
  /// Облако вообще настроено в этой сборке.
  bool get isConfigured;

  /// Игрок вошёл.
  bool get isSignedIn;

  /// Идентификатор пользователя; `null` — не вошёл.
  String? get userId;

  /// Поток состояния входа.
  Stream<bool> get authChanges;

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Письмо для сброса пароля.
  Future<void> resetPassword(String email);

  /// Снимок из облака; `null` — его там нет.
  Future<UserData?> download();

  /// Выгружает снимок.
  Future<void> upload(UserData data);

  /// Изменения своей строки с другого устройства.
  Stream<UserData> watch();

  /// Удаляет облачную копию. Локальные данные не трогает.
  Future<void> deleteRemote();
}

/// Реализация «облака нет».
///
/// Все методы тихо ничего не делают. Это нормальное состояние проекта до
/// M6, а для игрока без аккаунта — навсегда.
class DisabledCloudSync implements CloudSync {
  const DisabledCloudSync();

  @override
  bool get isConfigured => false;

  @override
  bool get isSignedIn => false;

  @override
  String? get userId => null;

  @override
  Stream<bool> get authChanges => const Stream.empty();

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<UserData?> download() async => null;

  @override
  Future<void> upload(UserData data) async {}

  @override
  Stream<UserData> watch() => const Stream.empty();

  @override
  Future<void> deleteRemote() async {}
}
