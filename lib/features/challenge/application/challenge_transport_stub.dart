import 'challenge_transport.dart';

/// На web ночной вызов не загружается: web-сборка существует как проверка
/// компиляции, игра целится в Android и iOS.
class UnavailableChallengeTransport implements ChallengeTransport {
  const UnavailableChallengeTransport();

  @override
  Future<String?> get(String url) async => null;
}

ChallengeTransport createTransport() => const UnavailableChallengeTransport();
