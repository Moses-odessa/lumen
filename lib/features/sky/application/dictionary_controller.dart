import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/content/content_provider.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/srs/memory_state.dart';

/// Одна звезда в словаре.
class DictionaryEntry {
  const DictionaryEntry({
    required this.itemId,
    required this.constellation,
    required this.tier,
    required this.target,
    required this.native,
    required this.lumens,
    required this.due,
    required this.burning,
    this.article,
  });

  final String itemId;
  final String constellation;
  final Tier tier;

  /// Форма на языке изучения и на родном.
  final String target;
  final String native;
  final String? article;

  final Lumens lumens;

  /// Когда слово вернётся; `null` — ещё не показывали.
  final DateTime? due;

  final bool burning;

  bool get isNew => due == null;

  LumenBand get band => LumenBand.of(lumens);

  String get targetWithArticle =>
      article == null ? target : '$article $target';

  /// Совпадение с поисковым запросом. Ищем по обеим формам: игрок вспоминает
  /// слово то на одном языке, то на другом.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return target.toLowerCase().contains(q) ||
        native.toLowerCase().contains(q) ||
        constellation.toLowerCase().contains(q);
  }
}

/// Фильтры словаря.
class DictionaryFilter {
  const DictionaryFilter({
    this.query = '',
    this.constellation,
    this.band,
    this.onlyBurning = false,
  });

  final String query;
  final String? constellation;
  final LumenBand? band;
  final bool onlyBurning;

  DictionaryFilter copyWith({
    String? query,
    String? Function()? constellation,
    LumenBand? Function()? band,
    bool? onlyBurning,
  }) =>
      DictionaryFilter(
        query: query ?? this.query,
        constellation:
            constellation == null ? this.constellation : constellation(),
        band: band == null ? this.band : band(),
        onlyBurning: onlyBurning ?? this.onlyBurning,
      );

  bool test(DictionaryEntry entry) {
    if (!entry.matches(query)) return false;
    if (constellation != null && entry.constellation != constellation) {
      return false;
    }
    if (band != null && entry.band != band) return false;
    if (onlyBurning && !entry.burning) return false;
    return true;
  }
}

class DictionaryFilterController extends Notifier<DictionaryFilter> {
  @override
  DictionaryFilter build() => const DictionaryFilter();

  void setQuery(String value) => state = state.copyWith(query: value);

  void toggleConstellation(String? name) => state = state.copyWith(
        constellation: () => state.constellation == name ? null : name,
      );

  void toggleBand(LumenBand? band) => state = state.copyWith(
        band: () => state.band == band ? null : band,
      );

  void toggleBurning() =>
      state = state.copyWith(onlyBurning: !state.onlyBurning);

  void clear() => state = const DictionaryFilter();
}

final dictionaryFilterProvider =
    NotifierProvider<DictionaryFilterController, DictionaryFilter>(
  DictionaryFilterController.new,
);

/// Полный словарь игрока: все звёзды его яруса и ниже.
///
/// Сортировка — от самых тусклых: словарь нужен не чтобы любоваться
/// выученным, а чтобы видеть, что вот-вот забудется.
final dictionaryProvider = FutureProvider<List<DictionaryEntry>>((ref) async {
  final player = ref.watch(playerControllerProvider);
  final tier = player?.tier ?? Tier.a0;
  final targetLang = player?.targetLang ?? defaultTargetLang;
  final nativeLang = player?.nativeLang ?? defaultNativeLang;

  final content = ref.watch(currentContentDatabaseProvider);
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();

  final states = {
    for (final row in await db.loadWordStates()) row.itemId: row,
  };

  final entries = <DictionaryEntry>[];
  for (final concept in await content.conceptsUpTo(tier)) {
    final target = await content.lexeme(concept.id, targetLang);
    final native = await content.lexeme(concept.id, nativeLang);
    if (target == null || native == null) continue;

    final row = states[concept.id];
    final memory = row == null
        ? MemoryState.unseen
        : MemoryState(
            difficulty: row.difficulty,
            stability: row.stability,
            lastReview: row.lastReview,
            reps: row.reps,
            lapses: row.lapses,
          );

    entries.add(DictionaryEntry(
      itemId: concept.id,
      constellation: concept.constellation,
      tier: Tier.fromCode(concept.tier),
      target: target.form,
      article: target.article,
      native: native.form,
      lumens: memory.lumensAt(now),
      due: row?.due,
      burning: row?.burning ?? false,
    ));
  }

  entries.sort((a, b) => a.lumens.compareTo(b.lumens));
  return entries;
});
