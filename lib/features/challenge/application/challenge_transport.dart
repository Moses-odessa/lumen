/// Транспорт для единственного сетевого запроса в игре.
///
/// Вынесен за условный импорт по двум причинам: на мобильных достаточно
/// `dart:io` без единого пакета (инвариант «сетевого клиента в проекте нет
/// до M8»), а web-сборка с `dart:io` не компилируется вовсе.
library;

export 'challenge_transport_stub.dart'
    if (dart.library.io) 'challenge_transport_io.dart';

/// Один GET статического файла. `null` — не получилось; это не ошибка.
abstract class ChallengeTransport {
  Future<String?> get(String url);
}
