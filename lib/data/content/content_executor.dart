/// Открытие контентной базы разведено по платформам: на мобильных нужен
/// `dart:io` (копирование ассета в support-директорию), а web собирается в CI
/// и не должен ломаться из-за этого импорта.
library;

export 'content_executor_web.dart'
    if (dart.library.io) 'content_executor_io.dart';
