import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final entries = ref.watch(dictionaryProvider);
    final filter = ref.watch(dictionaryFilterProvider);
    final controller = ref.read(dictionaryFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Словарь'),
        actions: [
          if (filter.constellation != null ||
              filter.band != null ||
              filter.onlyBurning ||
              filter.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Сбросить фильтры',
              onPressed: controller.clear,
            ),
        ],
      ),
      body: switch (entries) {
        AsyncData(:final value) => Column(
            children: [
              _SearchField(
                value: filter.query,
                onChanged: controller.setQuery,
              ),
              _Filters(
                entries: value,
                filter: filter,
                controller: controller,
              ),
              Expanded(child: _EntryList(entries: value, filter: filter)),
            ],
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          onChanged: onChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Слово на любом из двух языков',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.entries,
    required this.filter,
    required this.controller,
  });

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
            label: const Text('горят'),
            selected: filter.onlyBurning,
            avatar: const Icon(Icons.local_fire_department, size: 18),
            onSelected: (_) => controller.toggleBurning(),
          ),
          const SizedBox(width: 8),
          for (final band in LumenBand.values.reversed) ...[
            FilterChip(
              label: Text(_bandLabel(band)),
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

  static String _bandLabel(LumenBand band) => switch (band) {
        LumenBand.burning => 'горит',
        LumenBand.steady => 'ровный свет',
        LumenBand.flickering => 'мерцает',
        LumenBand.dimming => 'тускнеет',
        LumenBand.fading => 'гаснет',
      };
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.filter});

  final List<DictionaryEntry> entries;
  final DictionaryFilter filter;

  @override
  Widget build(BuildContext context) {
    final visible = entries.where(filter.test).toList();

    if (visible.isEmpty) {
      return const Center(child: Text('Ничего не нашлось'));
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
