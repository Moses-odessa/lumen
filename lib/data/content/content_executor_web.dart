import 'package:drift/drift.dart';

/// Путь к ассету с собранной контентной базой.
String contentAssetPath(String lang) => 'assets/content/$lang.db';

/// На web контентная база не открывается: для этого нужны wasm-ассеты SQLite,
/// а web-сборка существует только как проверка компиляции в CI (README
/// «CI/CD и сборка»). Игра целится в Android и iOS.
///
/// Экзекьютор возвращается «ленивым» и падает лишь при первом запросе —
/// значит, сборка проходит, а случайное использование видно сразу.
QueryExecutor openContentExecutor(String lang) => LazyDatabase(
      () async => throw UnsupportedError(
        'content.db недоступна на web: нужны wasm-ассеты SQLite',
      ),
    );
