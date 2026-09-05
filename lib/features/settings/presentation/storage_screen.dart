import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_pack_manager.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/repositories/player_repository.dart';

/// Что скачано, сколько занимает и как удалить.
///
/// Экран существует потому, что докачка обязана быть обратимой: игрок,
/// которому не хватает места на телефоне, должен уметь освободить его сам,
/// а не удалять приложение целиком.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  final _manager = AudioPackManager();

  List<PackState> _packs = const [];
  int _usedBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  String get _lang =>
      ref.read(playerControllerProvider)?.targetLang ?? defaultTargetLang;

  Future<void> _refresh() async {
    setState(() => _loading = true);

    final available = await _manager.available(_lang);
    final installed = await _manager.installedTiers(_lang);
    final used = await _manager.installedBytes(_lang);

    if (!mounted) return;
    setState(() {
      _packs = [
        for (final pack in available)
          PackState(
            pack: pack,
            status: installed.contains(pack.tier)
                ? PackStatus.installed
                : PackStatus.notInstalled,
          ),
      ];
      _usedBytes = used;
      _loading = false;
    });
  }

  Future<void> _install(PackState state) async {
    setState(() => _update(state.copyWith(status: PackStatus.downloading)));

    final ok = await _manager.install(
      state.pack,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _update(
              state.copyWith(
                status: PackStatus.downloading,
                receivedBytes: received,
              ),
            ));
      },
    );

    if (!mounted) return;
    setState(() => _update(
          state.copyWith(
            status: ok ? PackStatus.installed : PackStatus.failed,
          ),
        ));
    await _refresh();
  }

  Future<void> _remove(PackState state) async {
    await _manager.remove(state.pack);
    await _refresh();
  }

  void _update(PackState next) {
    _packs = [
      for (final p in _packs) if (p.pack.tier == next.pack.tier) next else p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    l10n.storageUsed(
                      (_usedBytes / 1024 / 1024).toStringAsFixed(1),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.storageExplain,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_manager.isConfigured)
                    Text(
                      l10n.storageNotConfigured,
                      style: theme.textTheme.bodySmall,
                    )
                  else if (_packs.isEmpty)
                    Text(l10n.storageNothingToDownload,
                        style: theme.textTheme.bodySmall)
                  else
                    for (final state in _packs)
                      _PackTile(
                        l10n: l10n,
                        state: state,
                        onInstall: () => _install(state),
                        onRemove: () => _remove(state),
                      ),
                ],
              ),
            ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.l10n,
    required this.state,
    required this.onInstall,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final PackState state;
  final VoidCallback onInstall;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pack = state.pack;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pack.tier.toUpperCase(),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                l10n.storagePackSize(pack.megabytes.toStringAsFixed(1)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              switch (state.status) {
                PackStatus.installed => IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.storageRemove,
                    onPressed: onRemove,
                  ),
                PackStatus.downloading => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                _ => IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: l10n.storageDownload,
                    onPressed: onInstall,
                  ),
              },
            ],
          ),
          if (state.status == PackStatus.downloading) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 4,
              ),
            ),
          ],
          if (state.status == PackStatus.failed) ...[
            const SizedBox(height: 4),
            Text(
              l10n.storageFailed,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
