import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';
import '../../../data/content/content_database.dart';
import '../../../data/content/content_provider.dart';
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
  /// Язык интерфейса. `null` в ключе — «как в системе», `null` в
  /// значении означает, что подпись берётся из локализации.
  ///
  /// Этот список остаётся в коде, и не по недосмотру: язык интерфейса — это
  /// ARB-файлы и `flutter gen-l10n`, то есть кодоген, а не контент. Языки
  /// изучения и подсказок пришли из базы, потому что они данные.
  static const Map<String?, String?> _interface = {
    null: null,
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
    final l10n = AppLocalizations.of(context);

    // Языки читаются из контентной базы, а не из карт в этом файле. Раньше
    // здесь лежали три словаря кодов и названий, и добавление языка означало
    // правку Dart в четырёх местах — при том, что язык это файл в
    // content/lang/. Самоназвание тоже приходит оттуда: его приносит с собой
    // тот же файл.
    final targets = _named(ref.watch(targetLanguagesProvider).value);
    final natives = _named(ref.watch(nativeLanguagesProvider).value);

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
              Text(l10n.languagesTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l10n.languagesSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              // Пока база не ответила, группы пусты, а не заполнены
              // догадками: показать список языков, который потом
              // переставится, хуже, чем показать его через полсекунды.
              _Group(
                title: l10n.languagesLearning,
                options: targets,
                selected: targets.containsKey(_target) ? _target : null,
                onSelect: (value) => setState(() => _target = value!),
              ),
              const SizedBox(height: 20),
              _Group(
                title: l10n.languagesHints,
                options: natives,
                selected: natives.containsKey(_native) ? _native : null,
                onSelect: (value) => setState(() => _native = value!),
              ),
              const SizedBox(height: 20),
              _Group(
                title: l10n.languagesInterface,
                options: {
                  for (final e in _interface.entries)
                    e.key: e.value ?? l10n.languagesSystem,
                },
                selected: _ui,
                onSelect: (value) => setState(() => _ui = value),
              ),
              const SizedBox(height: 36),
              FilledButton(
                onPressed: _save,
                child: Text(l10n.commonNext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Код языка → его самоназвание, как оно записано в файле языка.
  static Map<String?, String> _named(List<LanguageRow>? rows) => {
        for (final row in rows ?? const <LanguageRow>[]) row.code: row.name,
      };

  void _save() {
    // Значение по умолчанию может отсутствовать в базе: язык объявлен
    // draft или его файл убрали. Записать выбор, которого игрок не делал и
    // которого в контенте нет, значит выдать ему пустую игру — концепт
    // играбелен только когда форма есть в обоих языках пары.
    final target = _pick(_target, ref.read(targetLanguagesProvider).value);
    final native = _pick(_native, ref.read(nativeLanguagesProvider).value);

    final controller = ref.read(playerControllerProvider.notifier);
    controller.createDraft(
      targetLang: target,
      nativeLang: native,
      uiLang: _ui,
    );
    ref.read(analyticsProvider).log(AnalyticsEvents.languagesChosen, {
      'target': target,
      'native': native,
      'ui': _ui ?? 'system',
    });
    widget.onDone();
  }

  /// Выбранный язык, если он есть в базе; иначе первый доступный.
  static String _pick(String chosen, List<LanguageRow>? available) {
    if (available == null || available.isEmpty) return chosen;
    if (available.any((l) => l.code == chosen)) return chosen;
    return available.first.code;
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
