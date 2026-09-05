import 'dart:convert';
import 'dart:io';

import 'challenge_transport.dart';

/// HTTP поверх `dart:io`: одного GET статического JSON хватает, пакет
/// ради этого в зависимости не тянем.
class IoChallengeTransport implements ChallengeTransport {
  const IoChallengeTransport();

  @override
  Future<String?> get(String url) async {
    // Короткий таймаут: вызов — приятное дополнение, а не то, ради чего
    // игрок ждёт. Не пришёл за пять секунд — играем без него.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode != 200) return null;
      // Читаем внутри try, а не возвращаем Future наружу: иначе ошибка
      // чтения тела улетит мимо catch и уронит вызов вместо тихого null.
      return await response.transform(utf8.decoder).join();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

ChallengeTransport createTransport() => const IoChallengeTransport();
