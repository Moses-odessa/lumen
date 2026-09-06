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
    required this.burningStars,
  });

  final List<ConstellationPlacement> placements;
  final Map<String, ConstellationState> states;
  final Tier tier;

  /// Сколько звёзд на карте всего.
  final int totalStars;

  final int litConstellations;

  /// Горящих слов — главная цифра профиля.
  final int burningStars;

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
  final tier = player?.tier ?? Tier.a0;
  final content = ref.watch(currentContentDatabaseProvider);
  final db = ref.watch(appDatabaseProvider);

  final now = DateTime.now();

  // Яркость считается из тройки FSRS, а не берётся из кеша: кеш обновляется
  // при старте сессии, а карту могут открыть и через неделю простоя.
  final lumensByConcept = <String, Lumens>{};
  for (final row in await db.loadWordStates()) {
    lumensByConcept[row.itemId] = MemoryState(
      difficulty: row.difficulty,
      stability: row.stability,
      lastReview: row.lastReview,
      reps: row.reps,
      lapses: row.lapses,
    ).lumensAt(now);
  }

  final concepts = await content.conceptsUpTo(tier);
  final byConstellation = <String, List<StarInput>>{};
  for (final concept in concepts) {
    byConstellation.putIfAbsent(concept.constellation, () => []).add(
          StarInput(
            itemId: concept.id,
            lumens: lumensByConcept[concept.id] ?? 0,
          ),
        );
  }

  final placements = SkyLayout.place(constellations: byConstellation);

  // Первое созвездие открыто всегда: с чего-то начинать надо, а выбирать
  // из пустого списка игрок не может.
  final starters = placements.isEmpty ? <String>{} : {placements.first.name};

  final draft = [
    for (final placement in placements)
      ConstellationState(
        name: placement.name,
        tier: tier,
        starLumens: [for (final s in placement.stars) s.lumens],
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
    totalStars: concepts.length,
    litConstellations: states.values.where((s) => s.isLit).length,
    burningStars: await db.countBurning(),
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
