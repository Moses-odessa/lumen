import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../data/repositories/player_repository.dart';
import '../application/diagnostics.dart';

/// Настройки: языки, звук, темп, донаты, экспорт данных. На M0 здесь живут
/// три реальных переключателя и диагностика обеих баз.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final player = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          if (player != null) ...[
            SwitchListTile(
              value: player.soundEnabled,
              onChanged: controller.setSoundEnabled,
              title: const Text('Звук'),
              subtitle: const Text(
                'Без звука верный ответ отмечается вибрацией',
              ),
              secondary: const Icon(Icons.volume_up_outlined),
            ),
            SwitchListTile(
              value: player.freePace,
              onChanged: controller.setFreePace,
              title: const Text('Свой темп'),
              subtitle: const Text(
                'Больше одного уровня в день — очередь повторений вырастет',
              ),
              secondary: const Icon(Icons.speed_outlined),
            ),
            const Divider(),
          ],
          const _DiagnosticsTile(),
        ],
      ),
    );
  }
}

/// Диагностика обеих баз — критерий приёмки M0 в видимой форме.
class _DiagnosticsTile extends ConsumerWidget {
  const _DiagnosticsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(databasesDiagnosticsProvider);
    final scheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      leading: const Icon(Icons.storage_outlined),
      title: const Text('Базы данных'),
      subtitle: Text(
        switch (async) {
          AsyncData(:final value) => value.contentOpened
              ? 'user.db v${value.userSchemaVersion} · '
                  'content.db ${value.contentLang}: '
                  '${value.contentConcepts} концептов'
              : 'user.db v${value.userSchemaVersion} · content.db не открылась',
          AsyncError() => 'не удалось прочитать',
          _ => 'проверка…',
        },
      ),
      children: [
        switch (async) {
          AsyncData(:final value) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('user.db',
                      value.userTablesOpened ? 'открыта' : 'недоступна'),
                  _row('схема user.db', 'v${value.userSchemaVersion}'),
                  for (final e in value.contentMeta.entries)
                    _row('content.${e.key}', e.value),
                  if (value.contentError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        value.contentError!,
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          AsyncError(:final error) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('$error', style: TextStyle(color: scheme.error)),
            ),
          _ => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
        },
      ],
    );
  }

  Widget _row(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(key, style: const TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
}
