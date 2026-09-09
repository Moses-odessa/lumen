import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tier.dart';
import '../repositories/player_repository.dart';
import 'content_database.dart';

/// Контентная база открывается по языку изучения: смена языка — это смена
/// базы, а не запрос с другим `WHERE`.
final contentDatabaseProvider =
    Provider.family<ContentDatabase, String>((ref, lang) {
  final db = ContentDatabase.forLanguage(lang);
  ref.onDispose(db.close);
  return db;
});

/// База для текущего языка изучения игрока.
final currentContentDatabaseProvider = Provider<ContentDatabase>((ref) {
  final lang = ref.watch(playerControllerProvider)?.targetLang ??
      defaultTargetLang;
  return ref.watch(contentDatabaseProvider(lang));
});

/// Метаданные сборки контента — что за язык, из чего собрано.
final contentMetaProvider = FutureProvider<Map<String, String>>((ref) =>
    ref.watch(currentContentDatabaseProvider).loadMeta());

/// Ярусы, которые можно играть: вычитанные и запущенные.
///
/// Выше этого приложение не предлагает подниматься ни калибровкой, ни
/// ручной сменой яруса. Лучше играть меньше, чем играть по невычитанному.
final launchedTiersProvider = FutureProvider<Set<Tier>>((ref) =>
    ref.watch(currentContentDatabaseProvider).launchedTiers());

/// Сколько слов курса лежит на ярусе и ниже.
///
/// Экран результата калибровки говорит игроку это число, и оно обязано
/// приходить из базы: курс растёт файлами контента, а не константой в коде.
final vocabularyUpToProvider =
    FutureProvider.family<int, Tier>((ref, tier) =>
        ref.watch(currentContentDatabaseProvider).countConceptsUpTo(tier));

/// Языки, которыми можно подсказывать, и языки, на которых можно учить.
///
/// Читаются из базы, а не из списка в коде: язык — это файл в
/// `content/lang/`, и добавление языка не должно требовать правки Dart.
final nativeLanguagesProvider = FutureProvider<List<LanguageRow>>((ref) =>
    ref.watch(currentContentDatabaseProvider).nativeLanguages());

final targetLanguagesProvider = FutureProvider<List<LanguageRow>>((ref) =>
    ref.watch(currentContentDatabaseProvider).targetLanguages());

/// Самый высокий доступный ярус.
final maxTierProvider = Provider<Tier>((ref) {
  final tiers = switch (ref.watch(launchedTiersProvider)) {
    AsyncData(:final value) => value,
    // Пока метаданные не прочитаны, разрешён только нижний ярус.
    //
    // Раньше здесь не запрещалось ничего: «мигающий запрет хуже, чем запрет,
    // появившийся на полсекунды позже». Для интерфейса это верно, а для
    // решения, которое **записывается в базу игрока**, — нет.
    //
    // Калибровка читала потолок ровно один раз, в конце теста, и этим первым
    // чтением сама же инициализировала `launchedTiersProvider`. То есть на
    // первом запуске потолок всегда отвечал «ничего не запрещаю», и
    // измеренный B2 доставался игроку насовсем — на сборке, где запущен один
    // A0. Не гонка, которая иногда случается: порядок был всегда такой.
    //
    // Осторожность стоит мигания в двух местах — баннер подъёма и выбор яруса
    // в настройках, — а прежняя щедрость стоила невычитанного текста,
    // записанного в базу игрока. Правило «лучше играть меньше, чем играть по
    // невычитанному» записано двумя строчками выше, и теперь оно верно и
    // здесь.
    _ => {Tier.a0},
  };
  if (tiers.isEmpty) return Tier.b2;
  return tiers.reduce((a, b) => a.index >= b.index ? a : b);
});
