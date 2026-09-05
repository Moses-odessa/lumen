import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/router/app_router.dart';
import '../application/data_controller.dart';
import '../application/reminder_scheduler.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/tier.dart';
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
            _TierTile(
              l10n: l10n,
              player: player,
              controller: controller,
            ),
            const Divider(),
            SwitchListTile(
              value: player.soundEnabled,
              onChanged: controller.setSoundEnabled,
              title: Text(l10n.settingsSound),
              subtitle: Text(l10n.settingsSoundSubtitle),
              secondary: const Icon(Icons.volume_up_outlined),
            ),
            SwitchListTile(
              value: player.freePace,
              onChanged: (value) =>
                  _setPace(context, controller, l10n, value),
              title: Text(l10n.settingsPace),
              subtitle: Text(
                player.freePace
                    ? l10n.settingsPaceOn
                    : l10n.settingsPaceOff,
              ),
              secondary: const Icon(Icons.speed_outlined),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: Text(l10n.settingsRecalibrate),
            subtitle: Text(l10n.settingsRecalibrateSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.recalibrate),
          ),
          // Инструменты разработчика в релиз не едут: игроку нечего делать
          // ни в замере задержки звука, ни в схеме базы.
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Задержка звука'),
              subtitle: const Text('Спайк M1 — мерить на реальном телефоне'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.audioSpike),
            ),
          if (player != null)
            SwitchListTile(
              value: player.notificationsEnabled,
              onChanged: (value) =>
                  _setNotifications(context, ref, l10n, value),
              title: Text(l10n.settingsNotifications),
              subtitle: Text(l10n.settingsNotificationsSubtitle),
              secondary: const Icon(Icons.notifications_outlined),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l10n.settingsCloud),
            subtitle: Text(l10n.settingsCloudSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.cloud),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.settingsExport),
            subtitle: Text(l10n.settingsExportSubtitle),
            onTap: () => _export(context, ref, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: Text(l10n.settingsWipe),
            subtitle: Text(l10n.settingsWipeSubtitle),
            onTap: () => _wipe(context, ref, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsAboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.about),
          ),
          if (kDebugMode) const _DiagnosticsTile(),
        ],
      ),
    );
  }
}

/// Напоминания включаются только с явного согласия и только после того,
/// как разрешение действительно выдано: переключатель, который врёт, что
/// уведомления включены, хуже отсутствующего.
Future<void> _setNotifications(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  bool value,
) async {
  final controller = ref.read(playerControllerProvider.notifier);
  final player = ref.read(playerControllerProvider);
  if (player == null) return;

  if (!value) {
    await ref.read(notificationServiceProvider).cancelAll();
    controller.replace(player.copyWith(notificationsEnabled: false));
    return;
  }

  final granted =
      await ref.read(notificationServiceProvider).requestPermission();
  if (!context.mounted) return;

  if (!granted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsNotificationsDenied)),
    );
    return;
  }

  controller.replace(player.copyWith(notificationsEnabled: true));
  await ref.read(reminderSchedulerProvider).reschedule();
}

/// Экспорт: показываем JSON и отдаём системе через шаринг.
Future<void> _export(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  try {
    final json = await ref.read(dataControllerProvider).export();
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(text: json, subject: 'Lumen — экспорт данных'),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsExportFailed('$e'))),
    );
  }
}

/// Удаление данных: подтверждение обязательно и формулируется прямо.
Future<void> _wipe(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settingsWipeDialogTitle),
      content: Text(l10n.settingsWipeDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsWipeConfirm),
        ),
      ],
    ),
  );

  if (confirmed ?? false) {
    await ref.read(dataControllerProvider).wipe();
  }
}

/// Включение «своего темпа» — единственная настройка, которая может
/// навредить самому игроку, поэтому она предупреждает.
///
/// Предупреждение мягкое и не запрещающее: ограничение здесь дидактическое,
/// а не платная стена, и снять его игрок имеет полное право.
Future<void> _setPace(
  BuildContext context,
  PlayerController controller,
  AppLocalizations l10n,
  bool value,
) async {
  if (!value) {
    controller.setFreePace(false);
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.settingsPaceDialogTitle),
      content: Text(l10n.settingsPaceDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.settingsPaceKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsPaceEnable),
        ),
      ],
    ),
  );

  if (confirmed ?? false) controller.setFreePace(true);
}

/// Ручная смена яруса.
///
/// Запертого уровня в игре нет: результат калибровки — предложение, а не
/// приговор, и сменить ярус можно в любой момент без объяснений.
class _TierTile extends ConsumerWidget {
  const _TierTile({
    required this.l10n,
    required this.player,
    required this.controller,
  });

  final AppLocalizations l10n;
  final Player player;
  final PlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final maxTier = ref.watch(maxTierProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stairs_outlined),
              const SizedBox(width: 16),
              Text(l10n.settingsTier, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              l10n.settingsTierExplain,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: SegmentedButton<Tier>(
              segments: [
                for (final tier in Tier.values)
                  ButtonSegment(
                    value: tier,
                    label: Text(tier.label),
                    // Выше вычитанного играть нельзя: контент там черновой.
                    enabled: tier.index <= maxTier.index,
                  ),
              ],
              selected: {player.tier},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  controller.setTier(selection.first),
            ),
          ),
          if (maxTier != Tier.b2)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Text(
                l10n.settingsTierLocked(maxTier.label),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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
