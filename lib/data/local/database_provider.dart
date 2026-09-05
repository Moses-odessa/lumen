import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Единственный экземпляр пользовательской БД на время жизни приложения.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
