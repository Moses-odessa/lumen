import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/theme/palette.dart';
import '../../../data/repositories/player_repository.dart';

/// Выбор трёх языков: что учим, с какого и на каком язык интерфейса.
///
/// Три независимые настройки, а не одна: человек может учить немецкий с
/// украинского, а интерфейс держать на английском. Пары собираются на лету
/// из графа концептов, поэтому такие направления ничего не стоят — у крупных
/// приложений их просто нет.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  /// Языки изучения: до M8 в ассетах лежит озвучка ровно одного.
  static const _targets = {'de': 'Deutsch'};

  /// Языки подсказок — те, для которых есть лексемы в контенте.
  static const _natives = {
    'ru': 'Русский',
    'uk': 'Українська',
    'en': 'English',
  };

  /// Язык интерфейса; `null` — как в системе.
  static const _interface = {
    null: 'Как в системе',
    'en': 'English',
    'ru': 'Русский',
    'uk': 'Українська',
    'de': 'Deutsch',
    'it': 'Italiano',
    'fr': 'Français',
  };

  String _target = defaultTargetLang;
  String _native = defaultNativeLang;
  String? _ui;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Text('Языки', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Язык подсказок и язык интерфейса — разные настройки.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              _Group(
                title: 'Учу',
                options: _targets,
                selected: _target,
                onSelect: (value) => setState(() => _target = value!),
              ),
              const SizedBox(height: 20),
              _Group(
                title: 'Подсказки на',
                options: _natives,
                selected: _native,
                onSelect: (value) => setState(() => _native = value!),
              ),
              const SizedBox(height: 20),
              _Group(
                title: 'Интерфейс',
                options: _interface,
                selected: _ui,
                onSelect: (value) => setState(() => _ui = value),
              ),
              const SizedBox(height: 36),
              FilledButton(
                onPressed: _save,
                child: const Text('Дальше'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final controller = ref.read(playerControllerProvider.notifier);
    controller.createDraft(
      targetLang: _target,
      nativeLang: _native,
      uiLang: _ui,
    );
    ref.read(analyticsProvider).log(AnalyticsEvents.languagesChosen, {
      'target': _target,
      'native': _native,
      'ui': _ui ?? 'system',
    });
    widget.onDone();
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final Map<String?, String> options;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => onSelect(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}
