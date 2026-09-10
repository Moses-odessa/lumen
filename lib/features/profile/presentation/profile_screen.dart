import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/interface_lang.dart';
import '../../../core/theme/palette.dart';
import '../../../data/content/constellation_naming.dart';
import '../../../data/content/content_provider.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/scoring/balance.dart';
import '../application/records_controller.dart';
import '../application/stats_controller.dart';
import 'records_wall.dart';

/// Профиль: орбита, искры, статистика.
///
/// Главная цифра здесь — горящие слова, а не XP. Любая валюта, которую можно
/// нафармить повтором лёгкого, будет фармиться, поэтому её тут нет.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(playerStatsProvider);
    // Имя темы подставляется здесь, на экране, а не в `playerStatsProvider`.
    //
    // За контроллер говорило то, что экрану не пришлось бы знать про откат по
    // языкам. Но знать и не приходится: откат — это один вызов
    // `ConstellationNaming.nameOf`, и правило заведено отдельным классом ровно
    // затем, чтобы вызывающие его не повторяли. Третьего правила отката в
    // проекте так и не появилось.
    //
    // За экран — два довода потяжелее. Первый: подпись на небе уже собирается в
    // точке показа (`_ConstellationCard`), и перенос этой работы в слой
    // приложения дал бы два разных ответа на вопрос «кто превращает slug в
    // подпись»; расходиться такие ответы начинают тихо. Второй: язык интерфейса
    // стал бы зависимостью статистики, и его смена пересчитывала бы её
    // целиком — состояния слов, сессии, все фразы яруса, медиану отклика, —
    // хотя измениться должна одна строка в каждой строке списка.
    final naming = ref.watch(constellationNamingProvider);

    return Scaffold(
      // Кнопки «Свои слова» в шапке больше нет: экран собирал у игрока пары
      // «слово → перевод», которых не читала ни одна механика.
      appBar: AppBar(title: Text(l10n.profileTitle)),
      // Статистика и имена — одно ожидание, как на небе: подпись, меняющаяся
      // у игрока на глазах со слага на имя, читается как поломка отрисовки.
      // Плата нулевая, потому что статистика и так ждёт эту же контентную базу
      // (`phrasesUpTo` по всему ярусу), а имена — двести пятьдесят коротких
      // рядов из неё же.
      body: switch ((stats, naming)) {
        (AsyncData(:final value), AsyncData(value: final names)) =>
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playerStatsProvider);
              ref.invalidate(recordWallProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OrbitCard(l10n: l10n, stats: value),
                const SizedBox(height: 12),
                _KeyNumbers(l10n: l10n, stats: value),
                const SizedBox(height: 12),
                _TierScale(
                  l10n: l10n,
                  stats: value,
                  maxTier: ref.watch(maxTierProvider),
                ),
                const SizedBox(height: 12),
                const RecordsWall(),
                const SizedBox(height: 20),
                Text(
                  l10n.profileBrightness,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final c in value.constellations)
                  _ConstellationRow(l10n: l10n, brightness: c, naming: names),
                if (value.constellations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.profileEmpty),
                  ),
              ],
            ),
          ),
        // Статистика не прочиталась.
        //
        // Здесь стоял `Text('$error')` — `SqliteException(1): no such table:
        // word_states, SQL logic error` посреди пустого экрана. Игроку это не
        // говорит ничего: ни исправить схему, ни отличить её от отказа диска
        // он не может. Сырой текст не потерян — обе базы со своими ошибками
        // показывает диагностика в настройках.
        //
        // Заголовок взят у неба (`skyEmptyTitle`), и это компромисс, а не
        // находка: профиль — это яркость созвездий и орбита, то есть рассказ
        // про то же небо, но отдельного ключа под «данные не прочитались» в
        // arb не заведено. Пока он не заведён, заголовок неба — самое близкое
        // по смыслу из того, что уже переведено на все шесть языков.
        //
        // Имена ошибкой не отвечают (см. `constellationNamingProvider`), но
        // ветка написана на любую из двух: у экрана «ни данных, ни ошибки» —
        // это индикатор загрузки, то есть ошибка, не попавшая в эту ветку,
        // стоила бы игроку вечного ожидания.
        (AsyncError(), _) || (_, AsyncError()) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 44, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    l10n.skyEmptyTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Орбита: высота, недельная цель и честное предупреждение о сбросе.
class _OrbitCard extends StatelessWidget {
  const _OrbitCard({required this.l10n, required this.stats});

  final AppLocalizations l10n;
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbit = stats.orbit;
    final risky = Orbit.missesBeforeReset(orbit) <= 1 && orbit.level > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${orbit.level}',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(color: LumenPalette.starlight),
                ),
                const SizedBox(width: 8),
                Text(l10n.profileOrbit, style: theme.textTheme.bodyMedium),
                const Spacer(),
                if (orbit.eclipseUntil != null &&
                    orbit.eclipsedAt(DateTime.now()))
                  Chip(
                    label: Text(l10n.profileEclipse),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              // Пропуск опускает, а не обнуляет: это главное отличие от
              // стрика, и о нём стоит сказать прямо.
              l10n.profileOrbitExplain,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (risky) ...[
              const SizedBox(height: 10),
              Text(
                l10n.profileOrbitRisk,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(l10n.profileWeek, style: theme.textTheme.labelLarge),
                const SizedBox(width: 12),
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: i < stats.weeklyProgress
                          ? LumenPalette.starlight
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              stats.weeklyGoalMet
                  ? l10n.profileWeeklyGoalMet
                  : l10n.profileWeeklyGoal(RetentionBalance.weeklyGoalDays),
              style: theme.textTheme.bodySmall?.copyWith(
                color: stats.weeklyGoalMet
                    ? LumenPalette.correct
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyNumbers extends StatelessWidget {
  const _KeyNumbers({required this.l10n, required this.stats});

  final AppLocalizations l10n;
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final latency = stats.medianLatency;

    final time = stats.playTime;

    // Восемь чисел в одну строку не влезают: на экране 360dp уже четыре
    // делили место впритык. Сетка по четыре в ряд, а не Row со
    // spaceEvenly, — иначе добавление девятого числа снова означало бы
    // переписывать раскладку.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 340 ? 3 : 4;
            final width = constraints.maxWidth / columns;

            return Wrap(
              alignment: WrapAlignment.center,
              runSpacing: 18,
              children: [
                for (final number in [
                  // Флаг скорости, а не яркость, — и подпись про скорость.
                  // Прежняя («світять») стояла и здесь, и над тремя порогами
                  // яркости; разбор — у `PlayerStats.burningWords`.
                  _NumberData(
                    value: '${stats.burningWords}',
                    label: l10n.profileAutomatic,
                    highlight: true,
                  ),
                  _NumberData(
                    value: '${stats.knownWords}',
                    label: l10n.profileWordsInWork,
                  ),
                  _NumberData(
                    value: latency == null
                        ? '—'
                        : l10n.unitSeconds(
                            (latency.inMilliseconds / 1000).toStringAsFixed(1),
                          ),
                    label: l10n.profileLatency,
                    // Целевая метрика из CONCEPT.md — медиана меньше 1.8 с.
                    highlight: latency != null &&
                        latency <= const Duration(milliseconds: 1800),
                  ),
                  _NumberData(
                    value: '${stats.sparks}',
                    label: l10n.profileSparks,
                  ),
                  _NumberData(
                    value: '${time.days}',
                    label: l10n.profileDays,
                  ),
                  _NumberData(
                    value: '${time.streak}',
                    label: l10n.profileStreak,
                    highlight: time.streak > 1,
                  ),
                  _NumberData(
                    value: _hours(l10n, time.total),
                    label: l10n.profileTimeTotal,
                  ),
                  _NumberData(
                    value: _minutes(l10n, time.perDay),
                    label: l10n.profileTimePerDay,
                  ),
                ])
                  SizedBox(
                    width: width,
                    child: _Number(
                      value: number.value,
                      label: number.label,
                      highlight: number.highlight,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Часы и минуты: «7 ч 20 мин», а не «440 мин».
  static String _hours(AppLocalizations l10n, Duration d) {
    if (d.inMinutes < 60) return l10n.unitMinutes(d.inMinutes);
    return l10n.unitHoursMinutes(d.inHours, d.inMinutes % 60);
  }

  static String _minutes(AppLocalizations l10n, Duration d) =>
      l10n.unitMinutes(d.inMinutes);
}

/// Число профиля до раскладки: чтобы список чисел читался списком, а не
/// восемью вложенными виджетами.
class _NumberData {
  const _NumberData({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;
}

/// Шкала A0→B2: где игрок сейчас и насколько заполнен его ярус.
///
/// Пять засечек, из них доступна не каждая: ярус выше запущенного игра не
/// предлагает. Недоступные показаны, но приглушены — обещать пять уровней и
/// молча держать четыре запертыми хуже, чем сказать, что дальше пока не
/// написано.
class _TierScale extends StatelessWidget {
  const _TierScale({
    required this.l10n,
    required this.stats,
    required this.maxTier,
  });

  final AppLocalizations l10n;
  final PlayerStats stats;
  final Tier maxTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileScaleTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final tier in Tier.values) ...[
                  Expanded(
                    child: _Tick(
                      label: tier.label,
                      // Заполнение показывается только у текущего яруса:
                      // ниже он пройден по определению, выше не начат.
                      fill: switch (tier.index.compareTo(stats.tier.index)) {
                        < 0 => 1.0,
                        0 => stats.tierProgress,
                        _ => 0.0,
                      },
                      current: tier == stats.tier,
                      available: tier.index <= maxTier.index,
                    ),
                  ),
                  if (tier != Tier.values.last) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.profileScaleHint(
                stats.tier.label,
                (stats.tierProgress * 100).round(),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (maxTier != Tier.values.last) ...[
              const SizedBox(height: 6),
              Text(
                l10n.profileScaleLocked(maxTier.label),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({
    required this.label,
    required this.fill,
    required this.current,
    required this.available,
  });

  final String label;
  final double fill;
  final bool current;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = available ? 1.0 : 0.35;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fill.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor:
                LumenPalette.constellationLine.withValues(alpha: 0.2 * dim),
            valueColor: AlwaysStoppedAnimation(
              LumenPalette.starlight.withValues(alpha: dim),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: current
                ? LumenPalette.starlight
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: dim),
            fontWeight: current ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({
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
          style: theme.textTheme.titleLarge?.copyWith(
            color: highlight ? LumenPalette.starlight : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ConstellationRow extends StatelessWidget {
  const _ConstellationRow({
    required this.l10n,
    required this.brightness,
    required this.naming,
  });

  final AppLocalizations l10n;
  final ConstellationBrightness brightness;

  /// Имена тем: единственное место экрана, где созвездие называется
  /// человеческим словом.
  final ConstellationNaming naming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final band = LumenBand.of(brightness.averageLumens.round());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // Перевод «идентичность → подпись» в одной строке: список
                // отсортирован по яркости (`playerStatsProvider`), а не по
                // имени, поэтому подпись ни на что, кроме чтения, не влияет.
                child: Text(
                  naming.nameOf(brightness.constellation),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${brightness.averageLumens.round()} lm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: brightness.averageLumens / 100,
              minHeight: 6,
              color: LumenPalette.star(band),
            ),
          ),
          const SizedBox(height: 4),
          // Тот же порог и то же слово, что на карточке созвездия на небе
          // (`constellationLitOf`): вопрос у двух экранов один, и разными
          // числами они на него больше не отвечают.
          Text(
            l10n.profileBrightOf(brightness.bright, brightness.stars),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
