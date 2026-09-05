import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/database_provider.dart';

/// Свои слова: личное созвездие произвольного размера.
///
/// Взрослому нужен «Врач» на этой неделе, а не через четыре месяца по
/// программе — и иногда ему нужны слова, которых в курсе нет вовсе:
/// профессиональные, из конкретного учебника, из письма от чиновника.
/// Импорт списком, а не по одному: никто не будет вводить сорок слов
/// через форму.
class CustomWordsScreen extends ConsumerStatefulWidget {
  const CustomWordsScreen({super.key});

  @override
  ConsumerState<CustomWordsScreen> createState() => _CustomWordsScreenState();
}

class _CustomWordsScreenState extends ConsumerState<CustomWordsScreen> {
  final _controller = TextEditingController();
  List<CustomConceptRow> _words = const [];
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final words = await ref.read(appDatabaseProvider).loadCustomConcepts();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '$e';
      });
    }
  }

  /// Разбор списка: «слово — перевод» построчно.
  ///
  /// Принимаются любые разумные разделители: люди копируют списки из
  /// учебников, таблиц и заметок, и заставлять их приводить формат к одному
  /// виду — верный способ, чтобы импортом никто не воспользовался.
  Future<void> _import() async {
    final lines = _controller.text.split('\n');
    final parsed = <CustomConceptsCompanion>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s*[-—–:;\t|]\s*|\s{2,}'));
      if (parts.length < 2) continue;

      final target = parts.first.trim();
      final native = parts.sublist(1).join(' ').trim();
      if (target.isEmpty || native.isEmpty) continue;

      parsed.add(CustomConceptsCompanion.insert(
        id: 'custom_${target.toLowerCase()}',
        target: target,
        native: native,
        deck: 'custom',
      ));
    }

    if (parsed.isEmpty) {
      setState(() => _message =
          'Не нашлось ни одной пары. Формат: «Wort — слово», по строке на '
          'пару.');
      return;
    }

    try {
      final db = ref.read(appDatabaseProvider);
      final existing = await db.loadCustomConcepts();
      final merged = <String, CustomConceptsCompanion>{
        for (final row in existing)
          row.id: CustomConceptsCompanion(
            id: Value(row.id),
            target: Value(row.target),
            native: Value(row.native),
            deck: Value(row.deck),
          ),
        for (final item in parsed) item.id.value: item,
      };

      await db.replaceCustomConcepts(merged.values.toList());
      _controller.clear();
      setState(() => _message = 'Добавлено: ${parsed.length}');
      await _load();
    } catch (e) {
      setState(() => _message = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Свои слова')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Список из вашего учебника, письма или заметок. По строке '
                  'на пару: «Wort — слово».',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Rechnung — счёт\nQuittung — квитанция',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Добавить'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: 24),
                Text(
                  'В личном созвездии: ${_words.length}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final word in _words)
                  ListTile(
                    dense: true,
                    title: Text(word.target),
                    subtitle: Text(word.native),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _remove(word.id),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _remove(String id) async {
    final db = ref.read(appDatabaseProvider);
    final rest = _words.where((w) => w.id != id).map(
          (w) => CustomConceptsCompanion(
            id: Value(w.id),
            target: Value(w.target),
            native: Value(w.native),
            deck: Value(w.deck),
          ),
        );
    await db.replaceCustomConcepts(rest.toList());
    await _load();
  }
}
