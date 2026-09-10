import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/interface_lang.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/theme/palette.dart';
import '../../../data/content/constellation_naming.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/sky/progression.dart';
import '../application/sky_controller.dart';
import 'sky_map.dart';

/// Карта созвездий — главный экран приложения.
///
/// Здесь не нужно объяснять интервальное повторение: игрок открывает карту и
/// видит, что часть неба потускнела. Это и есть весь интерфейс прогресса.
class SkyScreen extends ConsumerWidget {
  const SkyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(skySnapshotProvider);
    final selected = ref.watch(selectedConstellationProvider);
    // Имена созвездий — не строки интерфейса, а контент: они приходят из той
    // же базы, что и состав неба, и ждутся вместе с ним (см. ниже, у `body`).
    final naming = ref.watch(constellationNamingProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LumenPalette.skyZenith, LumenPalette.skyHorizon],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.skyTitle),
          actions: [
            switch (snapshot) {
              AsyncData(:final value) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    value.tier.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
        // Небо и имена — одно ожидание, а не два.
        //
        // Карта могла бы появиться раньше имён: состав неба и имена — разные
        // запросы. Но подпись, которая на глазах игрока меняется со слага на
        // имя, читается как поломка отрисовки, а слаг — всего лишь как
        // непереведённая тема. Поэтому индикатор загрузки держится до обоих
        // ответов, и первый же кадр карты подписан правильно. Стоит это
        // почти ничего: обе выборки идут из одной уже открытой базы, а небо
        // и так ждёт её (`phrasesUpTo`). Подробнее — у
        // `constellationNamingProvider`, там же про то, почему имена не
        // умеют отвечать ошибкой.
        body: switch ((snapshot, naming)) {
          (AsyncData(:final value), AsyncData(value: final names)) =>
            value.isEmpty
                ? const _EmptySky()
                : Stack(
                    children: [
                      Positioned.fill(
                        child: SkyMap(
                          constellations: value.placements,
                          states: value.states,
                          selected: selected,
                          onSelect: (name) => ref
                              .read(selectedConstellationProvider.notifier)
                              .toggle(name),
                        ),
                      ),
                      if (selected == null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: _TierSuggestionBanner(snapshot: value),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: selected == null
                            ? _SkySummary(snapshot: value)
                            : _ConstellationCard(
                                state: value.states[selected],
                                naming: names,
                                onClose: () => ref
                                    .read(
                                      selectedConstellationProvider.notifier,
                                    )
                                    .clear(),
                              ),
                      ),
                    ],
                  ),
          // Небо не прочиталось — и это всё, что игроку можно сказать честно.
          //
          // Здесь стоял `Text('$error')`, то есть `SqliteException(1): no
          // such table: phrases, SQL logic error` на весь экран. Сделать с
          // этим текстом игрок не может ничего: ни исправить схему, ни
          // отличить её от отказа диска. Сырой текст при этом не потерян —
          // обе базы со своими ошибками показывает диагностика в настройках,
          // то есть он остался там, где его читает разработчик.
          //
          // Ошибка имён сюда попасть не может: именование отвечает пустыми
          // картами, а не исключением, — так обещано у него в докстроке. Но
          // ветка написана на любую из двух ошибок, потому что цена доверия к
          // обещанию здесь — вечный индикатор загрузки, а цена недоверия —
          // одна альтернатива в образце.
          (AsyncError(), _) || (_, AsyncError()) =>
            const _EmptySky.unreadable(),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Предложение сменить ярус.
///
/// Именно предложение: запертого уровня в игре нет, и система не имеет права
/// двигать игрока сама. Баннер можно проигнорировать, и он не будет
/// возвращаться на каждый кадр — он исчезнет, как только условие перестанет
/// выполняться.
class _TierSuggestionBanner extends ConsumerWidget {
  const _TierSuggestionBanner({required this.snapshot});

  final SkySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suggestion = Progression.suggest(
      constellations: snapshot.states.values.toList(),
      current: snapshot.tier,
    );
    if (suggestion == TierSuggestion.stay) return const SizedBox.shrink();

    final target = suggestion == TierSuggestion.up
        ? snapshot.tier.up
        : snapshot.tier.down;
    if (target == null) return const SizedBox.shrink();

    // Подниматься некуда, если верхний ярус ещё не вычитан.
    if (suggestion == TierSuggestion.up &&
        target.index > ref.watch(maxTierProvider).index) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: LumenPalette.starlight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion == TierSuggestion.up
                      ? l10n.tierSuggestUp(target.label)
                      : l10n.tierSuggestDown(
                          snapshot.tier.label,
                          target.label,
                        ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () {
                  ref.read(analyticsProvider).log(
                    AnalyticsEvents.tierChanged,
                    {'from': snapshot.tier.code, 'to': target.code},
                  );
                  ref.read(playerControllerProvider.notifier).setTier(target);
                  ref.invalidate(skySnapshotProvider);
                },
                child: Text(target.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Сводка по небу: сколько звёзд, сколько горит, сколько созвездий зажжено.
class _SkySummary extends StatelessWidget {
  const _SkySummary({required this.snapshot});

  final SkySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Сводка лежит поверх ночного неба, поэтому всегда светлая, независимо
    // от темы интерфейса.
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LumenPalette.skyHorizon.withValues(alpha: 0),
              LumenPalette.skyHorizon,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Metric(value: '${snapshot.totalStars}', label: l10n.skyStars),
            // Светящие звёзды, а не XP — главная цифра.
            //
            // Подпись `skyShining`, а не `skyBurning`, и это не переименование
            // ради вкуса. Одно слово стояло над четырьмя разными порогами
            // (здесь — 15 lm, на карточке созвездия — 70, в профиле — 85 и
            // флаг скорости), и игрок в одну сессию читал «5 світять» в
            // сводке, «0 із 30 зір світять» на карточке и «0 світять» в
            // профиле. Всё это была правда, но под одним словом. Здесь
            // остался самый слабый порог — «звезда вообще светит», тот, что
            // обязан совпадать с картинкой на карте; порог карточки и профиля
            // называется «яскраві». Разбор целиком — у `SkySnapshot.litStars`.
            _Metric(
              value: '${snapshot.litStars}',
              label: l10n.skyShining,
              highlight: true,
            ),
            _Metric(
              value:
                  '${snapshot.litConstellations}'
                  '/${snapshot.unlockedConstellations}',
              label: l10n.skyConstellations,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: highlight ? LumenPalette.starlight : Colors.white,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

/// Карточка выбранного созвездия.
class _ConstellationCard extends StatelessWidget {
  const _ConstellationCard({
    required this.state,
    required this.naming,
    required this.onClose,
  });

  final ConstellationState? state;

  /// Имена тем: единственное место на этом экране, где созвездие называется
  /// человеческим словом.
  final ConstellationNaming naming;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final constellation = state;
    if (constellation == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  // `name` — идентичность темы: по нему ищут состояние,
                  // раскладку и выбор на карте (`SkyLayout`, `SkyMap`), и
                  // переименовывать его нельзя. Человек видит имя, машина
                  // ищет по слагу — это два разных значения, и перевод
                  // одного в другое происходит здесь, в одной строке.
                  child: Text(
                    naming.nameOf(constellation.name),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (constellation.isLit)
                  const Icon(
                    Icons.auto_awesome,
                    color: LumenPalette.starlight,
                    size: 20,
                  ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              constellation.unlocked
                  ? l10n.constellationLitOf(
                      constellation.litStars,
                      constellation.starCount,
                    )
                  : l10n.constellationLocked,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: constellation.litProgress,
                minHeight: 6,
              ),
            ),
            if (constellation.unlocked && !constellation.isLit) ...[
              const SizedBox(height: 10),
              Text(
                constellation.starsToLight == 0
                    ? l10n.constellationAboutToLight
                    : l10n.constellationToLight(constellation.starsToLight),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Неба не видно: контент ещё не собран или база не прочиталась.
///
/// Случая два, вид один. Игрок в обоих смотрит на одно и то же — карты нет,
/// играть не по чему, — и сделать может одно и то же: перезапустить
/// приложение или обновить сборку. Разная картинка на два состояния, между
/// которыми игрок не выбирает, только притворялась бы разницей.
class _EmptySky extends StatelessWidget {
  const _EmptySky() : _explained = true;

  /// База не отдала небо: та же картинка без объяснения, которого нет.
  const _EmptySky.unreadable() : _explained = false;

  /// Показывать ли причину.
  ///
  /// Строка причины — «в контентной базе нет созвездий для этого яруса» — это
  /// утверждение о данных, а не о чтении. При отказе базы оно было бы
  /// неправдой: сборка могла быть в полном порядке, а не прочитаться база.
  /// Своей строки у отказа нет — ключа под «не прочиталось» в arb не
  /// заведено, — и лучше заголовок без причины, чем причина не та.
  final bool _explained;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: Colors.white38),
            const SizedBox(height: 16),
            Text(l10n.skyEmptyTitle, style: theme.textTheme.titleMedium),
            if (_explained) ...[
              const SizedBox(height: 8),
              Text(
                l10n.skyEmptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
