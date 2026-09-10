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

/// Сколько фраз курса лежит на ярусе и ниже.
///
/// Экран результата калибровки говорит игроку это число, и оно обязано
/// приходить из базы: курс растёт файлами контента, а не константой в коде.
final vocabularyUpToProvider =
    FutureProvider.family<int, Tier>((ref, tier) =>
        ref.watch(currentContentDatabaseProvider).countPhrasesUpTo(tier));

/// Языки, которыми можно подсказывать, и языки, на которых можно учить.
///
/// Читаются из базы, а не из списка в коде: язык — это файл в
/// `content/lang/`, и добавление языка не должно требовать правки Dart.
final nativeLanguagesProvider = FutureProvider<List<LanguageRow>>((ref) =>
    ref.watch(currentContentDatabaseProvider).nativeLanguages());

final targetLanguagesProvider = FutureProvider<List<LanguageRow>>((ref) =>
    ref.watch(currentContentDatabaseProvider).targetLanguages());

/// Имена созвездий на одном языке: `slug → имя`.
///
/// Провайдер именно по коду языка, а не «имена для текущего игрока», потому
/// что правило показа требует **двух** языков сразу — интерфейса и подсказок
/// (`ConstellationNaming`). Family с одинаковым аргументом Riverpod держит
/// одним состоянием, поэтому совпадение языков само собой даёт один запрос, а
/// не два.
///
/// Собирать `ConstellationNaming` здесь по-прежнему нельзя, и не из-за
/// асинхронности: сборке нужен язык интерфейса, а он при
/// `Player.uiLang == null` — локали системы, сведённые к
/// `AppLocalizations.supportedLocales`. Это l10n, а `lib/data` не
/// импортирует `lib/core` нигде. Собранное именование живёт одним
/// провайдером в `core/l10n/interface_lang.dart`
/// (`constellationNamingProvider`) — там же, где решается язык интерфейса,
/// чтобы второму месту, отвечающему «на каком языке подпись», взяться было
/// неоткуда.
///
/// **Повторов у этого запроса нет — и это правило, а не настройка.** Riverpod
/// сам перезапускает любой упавший провайдер: десять попыток с удвоением
/// задержки, около сорока секунд в сумме. Пока они идут, элемент стоит в
/// `AsyncLoading`, а `future` **не завершается** — то есть `try/catch` вокруг
/// `await ...future` не срабатывает вообще, и откат на слаги, которым
/// `constellationNamingProvider` защищает экраны, включается только на
/// одиннадцатой попытке. Небо и профиль держат в это время индикатор
/// загрузки, а `ReminderScheduler.reschedule()` ждёт те же сорок секунд:
/// ровно тот исход, который откат должен был предотвратить.
///
/// Повторять здесь и нечего. Это `SELECT` из read-only ассета, уже
/// скопированного на диск; он падает, когда таблицы нет (ассет прошлой
/// сборки) или база не читается вовсе, — и второе такое же чтение через
/// двести миллисекунд ответит тем же. Отказ окончателен, а ответ на него
/// готов и стоит дешевле ожидания: латинские слаги на карте.
final constellationNamesProvider =
    FutureProvider.family<Map<String, String>, String>(
  (ref, lang) =>
      ref.watch(currentContentDatabaseProvider).constellationNamesFor(lang),
  retry: (retryCount, error) => null,
);

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
