import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../domain/scoring/balance.dart';
import '../application/dictionary_controller.dart';

/// Словарь: все звёзды неба списком, с фильтрами по яркости и созвездию.
///
/// Карта отвечает на вопрос «как дела у неба в целом», словарь — на вопрос
/// «что именно я забываю». Поэтому сортировка от тусклых и поиск сразу по
/// обеим формам.
class DictionaryScreen extends ConsumerWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(dictionaryProvider);
    final filter = ref.watch(dictionaryFilterProvider);
    final controller = ref.read(dictionaryFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionaryTitle),
        actions: [
          if (filter.constellation != null ||
              filter.band != null ||
              filter.onlyBurning ||
              filter.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: l10n.dictionaryResetFilters,
              onPressed: controller.clear,
            ),
        ],
      ),
      body: switch (entries) {
        AsyncData(:final value) => Column(
            children: [
              _SearchField(
                value: filter.query,
                hint: l10n.dictionarySearchHint,
                onChanged: controller.setQuery,
              ),
              _Filters(
                l10n: l10n,
                entries: value,
                filter: filter,
                controller: controller,
              ),
              Expanded(
                child: _EntryList(
                  l10n: l10n,
                  entries: value,
                  filter: filter,
                ),
              ),
            ],
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: hint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.l10n,
    required this.entries,
    required this.filter,
    required this.controller,
  });

  final AppLocalizations l10n;
  final List<DictionaryEntry> entries;
  final DictionaryFilter filter;
  final DictionaryFilterController controller;

  @override
  Widget build(BuildContext context) {
    final constellations = {for (final e in entries) e.constellation}.toList()
      ..sort();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          FilterChip(
            label: Text(l10n.dictionaryBurningFilter),
            selected: filter.onlyBurning,
            avatar: const Icon(Icons.local_fire_department, size: 18),
            onSelected: (_) => controller.toggleBurning(),
          ),
          const SizedBox(width: 8),
          for (final band in LumenBand.values.reversed) ...[
            FilterChip(
              label: Text(_bandLabel(l10n, band)),
              selected: filter.band == band,
              avatar: CircleAvatar(
                radius: 6,
                backgroundColor: LumenPalette.star(band),
              ),
              onSelected: (_) => controller.toggleBand(band),
            ),
            const SizedBox(width: 8),
          ],
          for (final name in constellations) ...[
            FilterChip(
              label: Text(name),
              selected: filter.constellation == name,
              onSelected: (_) => controller.toggleConstellation(name),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  static String _bandLabel(AppLocalizations l10n, LumenBand band) =>
      switch (band) {
        LumenBand.burning => l10n.bandBurning,
        LumenBand.steady => l10n.bandSteady,
        LumenBand.flickering => l10n.bandFlickering,
        LumenBand.dimming => l10n.bandDimming,
        LumenBand.fading => l10n.bandFading,
      };
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.l10n,
    required this.entries,
    required this.filter,
  });

  final AppLocalizations l10n;
  final List<DictionaryEntry> entries;
  final DictionaryFilter filter;

  @override
  Widget build(BuildContext context) {
    final visible = entries.where(filter.test).toList();

    if (visible.isEmpty) {
      return Center(child: Text(l10n.dictionaryNothing));
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) => _EntryTile(entry: visible[index]),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: SizedBox(
        width: 28,
        child: Center(
          child: Container(
            width: LumenPalette.starRadius(entry.band) * 3,
            height: LumenPalette.starRadius(entry.band) * 3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LumenPalette.star(entry.band).withValues(
                alpha: LumenPalette.starOpacity(entry.band),
              ),
            ),
          ),
        ),
      ),
      title: Text(entry.targetWithArticle),
      subtitle: Text(
        '${entry.native} · ${entry.constellation} · ${entry.tier.label}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            entry.isNew ? '—' : '${entry.lumens} lm',
            style: theme.textTheme.bodyMedium,
          ),
          if (entry.burning)
            const Icon(Icons.local_fire_department,
                size: 14, color: LumenPalette.starlight),
        ],
      ),
    );
  }
}
