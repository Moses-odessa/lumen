import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/content/content_provider.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/sky/progression.dart';
import '../../../domain/sky/sky_layout.dart';
import '../../../domain/srs/memory_state.dart';

/// Небо целиком: раскладка, состояния созвездий и сводка по ярусу.
class SkySnapshot {
  const SkySnapshot({
    required this.placements,
    required this.states,
    required this.tier,
    required this.totalStars,
    required this.litConstellations,
    required this.litStars,
  });

  final List<ConstellationPlacement> placements;
  final Map<String, ConstellationState> states;
  final Tier tier;

  /// Сколько звёзд на карте всего.
  final int totalStars;

  final int litConstellations;

  /// Сколько звёзд светит — главная цифра неба.
  ///
  /// Считается по яркости, а не по флагу «горящего слова», и это была не
  /// придирка к названию. Флаг `word_states.burning` — это достижение за
  /// скорость (три верных подряд быстрее 1.5 с в продуктивной механике), и
  /// засев калибровки его не ставит вовсе. Поэтому сразу после онбординга
  /// небо показывало три зажжённые звезды и подпись «0 світять»: картинку
  /// рисовала живая яркость из тройки FSRS, а цифру брал SQL-запрос по
  /// достижению, которого у новичка быть не может.
  ///
  /// Порог — выход из полосы [LumenBand.fading] («практически забыто,
  /// вернётся как новое»). Ниже него звезда на карте самая тусклая, и назвать
  /// её светящей было бы ложью в другую сторону.
  ///
  /// **Слово над этим числом — не то же, что над остальными.** Одна подпись
  /// («світять», «горят») стояла над четырьмя разными порогами, и три из них
  /// игрок видел за одну сессию: здесь 15 lm, на карточке созвездия
  /// [ProgressionBalance.litStarMinLm] (70), в строке созвездия в профиле
  /// [LumenBand.burning] (85), а в главном числе профиля — вообще не яркость,
  /// а флаг скорости. Отсюда «5 світять» в сводке, «0 із 30 зір світять» на
  /// карточке и «0 світять» в профиле: каждое число правдиво, и все три
  /// назывались одинаково.
  ///
  /// Развели так: одного порога на всех не вышло — 70 lm нельзя ни поднять,
  /// ни опустить (на нём держится зажжение созвездия), а поставить его сюда
  /// значило бы вернуть «0 світять» сразу после онбординга, потому что засев
  /// калибровки даёт 50–60 lm ([CalibrationBalance.seedLmMin]). Поэтому:
  ///
  /// * **сводка неба** — самое слабое утверждение, «звезда вообще светит»
  ///   (подпись `skyShining`). Оно обязано совпадать с картинкой: карта
  ///   рисует звезду ровно с этого порога;
  /// * **карточка созвездия и строка созвездия в профиле** — «яркие»
  ///   (`constellationLitOf`, `profileBrightOf`), порог один, 70 lm. Это один
  ///   вопрос про один объект, и раньше два экрана отвечали на него разными
  ///   числами только потому, что пороги выбирались независимо;
  /// * **главное число профиля** — «на автомате» (`profileAutomatic`): флаг
  ///   скорости назван словом про скорость.
  ///
  /// Полосы яркости отдельными подписями больше не переводятся: пять ключей
  /// `band*` были вторым набором слов для тех же пяти полос, и не читал их ни
  /// один экран. Запись об их удалении — в `test/l10n_test.dart`.
  final int litStars;

  int get unlockedConstellations =>
      states.values.where((s) => s.unlocked).length;

  double get tierProgress => Progression.tierProgress(states.values.toList());

  bool get isEmpty => placements.isEmpty;
}

/// Собирает небо: состав созвездий — из `content.db`, яркость — из `user.db`.
///
/// Обе базы нужны одновременно и ровно один раз за открытие карты: считать
/// яркость по слову на каждый кадр нельзя, а держать её в кеше базы — можно.
final skySnapshotProvider = FutureProvider<SkySnapshot>((ref) async {
  final player = ref.watch(playerControllerProvider);

  // Ярус урезается до запущенного — та же последняя линия обороны, что в
  // загрузчике сессии, и здесь её не было.
  //
  // Ценой был не только бейдж «B2» на сборке с одним запущенным A0. Запрос
  // отдавал фразы всех пяти ярусов: полторы тысячи звёзд вместо ста
  // пятидесяти и пятьдесят созвездий вместо пяти. То есть небо показывало
  // сорок пять тем, играть в которые загрузчик всё равно не давал, и предел
  // «сколько тут ещё осталось» игрок читал неверно с первого дня.
  //
  // Прежде цена была и хуже: пока созвездие было темой словника, тема жила
  // на нескольких ярусах сразу, и его состав раздувался с 12 слов до 96 — а
  // по составу считаются `isLit` (80 % ярче 70 lm) и `opensNeighbours`
  // (среднее ≥ 60 lm), то есть небо зажигалось примерно в восемь раз
  // труднее, чем задумано. В разговорнике каждая тема лежит ровно на одном
  // ярусе (проверено по `assets/content/de.db`: ни одного созвездия с двумя
  // ярусами), поэтому состав созвездия от урезания яруса больше не зависит —
  // тридцать фраз при любом. Урез остаётся ради числа созвездий и звёзд.
  final tier = (player?.tier ?? Tier.a0).atMost(ref.watch(maxTierProvider));
  final content = ref.watch(currentContentDatabaseProvider);
  final db = ref.watch(appDatabaseProvider);

  final now = DateTime.now();

  // Яркость считается из тройки FSRS, а не берётся из кеша: кеш обновляется
  // при старте сессии, а карту могут открыть и через неделю простоя.
  final lumensByItem = <String, Lumens>{};
  for (final row in await db.loadWordStates()) {
    lumensByItem[row.itemId] = MemoryState(
      difficulty: row.difficulty,
      stability: row.stability,
      lastReview: row.lastReview,
      reps: row.reps,
      lapses: row.lapses,
    ).lumensAt(now);
  }

  final items = await content.phrasesUpTo(tier);

  // Небо делится на два множества, и это деление принципиальное.
  //
  // Отдельные координаты получают только **тронутые** звёзды — те, у которых
  // есть строка памяти. Всё остальное рисуется свечением Млечного Пути. Это и
  // делает карту масштабируемой: координаты растут вместе с прогрессом, а не
  // вместе с объёмом контента, и небо на B2 не оказывается нарисованным
  // целиком с первого дня — полторы тысячи точек, из которых тронуты три.
  //
  // Но состояния созвездий считаются по **полному** составу яруса. Возьми
  // прогрессия только выученные — и «зажжено» означало бы «80 % из того, что
  // я уже знаю», то есть загоралось бы с двух ярких слов, а предложение
  // подняться ярусом выше приходило бы в первый день.
  final worked = <String, List<StarInput>>{};
  final allStars = <String, List<Lumens>>{};
  final totals = <String, int>{};

  // Светящие звёзды считаются по тем же фразам, что рисует карта, а не
  // запросом по всей базе: строка памяти может остаться от яруса выше или от
  // фразы, которой в контенте больше нет.
  var litStars = 0;

  for (final item in items) {
    totals.update(item.constellation, (n) => n + 1, ifAbsent: () => 1);
    final lumens = lumensByItem[item.id];
    allStars.putIfAbsent(item.constellation, () => []).add(lumens ?? 0);
    if (lumens == null) continue;
    if (lumens >= LumenBand.dimming.minLm) litStars++;
    worked.putIfAbsent(item.constellation, () => []).add(
          StarInput(itemId: item.id, lumens: lumens),
        );
  }

  // Созвездие, где не тронуто ни одного слова, всё равно должно быть на
  // карте: непроработанная тема — это приглашение, а не пустота.
  for (final name in totals.keys) {
    worked.putIfAbsent(name, () => []);
  }

  // Созвездие показывается на ярусе, только если набрало порог звёзд. Тема
  // из одного слова — не созвездие, а точка.
  worked.removeWhere((name, _) => !Progression.appears(totals[name] ?? 0));

  final placements = SkyLayout.place(
    constellations: worked,
    totals: totals,
  );

  // Первое созвездие открыто всегда: с чего-то начинать надо, а выбирать
  // из пустого списка игрок не может.
  final starters = placements.isEmpty ? <String>{} : {placements.first.name};

  final draft = [
    for (final placement in placements)
      ConstellationState(
        name: placement.name,
        tier: tier,
        starLumens: allStars[placement.name] ?? const [],
      ),
  ];

  final open = Progression.unlocked(
    constellations: draft,
    neighbours: _neighbours(placements),
    starters: starters,
  );

  final states = {
    for (final state in draft)
      state.name: state.copyWith(unlocked: open.contains(state.name)),
  };

  return SkySnapshot(
    placements: placements,
    states: states,
    tier: tier,
    totalStars: items.length,
    litConstellations: states.values.where((s) => s.isLit).length,
    litStars: litStars,
  );
});

/// Соседство определяется расстоянием на карте, а не отдельной таблицей.
///
/// Так «соседнее созвездие» и выглядит соседним: игрок открывает то, что
/// видит рядом, а не то, что кто-то прописал в конфиге.
Map<String, List<String>> _neighbours(
  List<ConstellationPlacement> placements, {
  int count = 3,
}) {
  final result = <String, List<String>>{};
  for (final from in placements) {
    final others = placements.where((c) => c.name != from.name).toList()
      ..sort((a, b) => from.center
          .distanceTo(a.center)
          .compareTo(from.center.distanceTo(b.center)));
    result[from.name] = others.take(count).map((c) => c.name).toList();
  }
  return result;
}

/// Какое созвездие выбрано на карте.
class SelectedConstellation extends Notifier<String?> {
  @override
  String? build() => null;

  /// Повторный тап по выбранному созвездию снимает выбор — так карта
  /// возвращается к общей сводке без отдельной кнопки.
  void toggle(String? name) => state = state == name ? null : name;

  void clear() => state = null;
}

final selectedConstellationProvider =
    NotifierProvider<SelectedConstellation, String?>(
  SelectedConstellation.new,
);
