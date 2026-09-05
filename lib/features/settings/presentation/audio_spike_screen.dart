import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_manifest.dart';
import '../../../core/audio/audio_service.dart';
import '../../../core/theme/palette.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/scoring/balance.dart';

/// Спайк по задержке звука — первая задача M1 из PLAN.md.
///
/// Смысл спайка: узнать, приходит ли озвучка раньше, чем разворачивается
/// следующий круг. На эмуляторе и на десктопе это измерять бессмысленно —
/// нужен реальный телефон, поэтому замер живёт в самом приложении, а не в
/// тестах.
///
/// Если медиана окажется выше порога, менять придётся библиотеку или момент
/// озвучки, а не анимации: звук после следующего круга ломает темп игры.
class AudioSpikeScreen extends ConsumerStatefulWidget {
  const AudioSpikeScreen({super.key});

  @override
  ConsumerState<AudioSpikeScreen> createState() => _AudioSpikeScreenState();
}

class _AudioSpikeScreenState extends ConsumerState<AudioSpikeScreen> {
  /// Столько же файлов, сколько кругов в забеге: спайк должен воспроизводить
  /// нагрузку игры, а не абстрактную.
  static const int _rounds = SessionBalance.circlesPerRunMax;

  bool _running = false;
  List<String> _ids = const [];
  int _done = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIds();
  }

  Future<void> _loadIds() async {
    final lang = ref.read(playerControllerProvider)?.targetLang ??
        defaultTargetLang;
    final manifest = await AudioManifest.load(lang);
    if (!mounted) return;
    setState(() {
      _ids = manifest.audioIds.take(_rounds).toList();
      _error = _ids.isEmpty
          ? 'В ассетах нет озвучки для «$lang». Запустите '
              'dart run tool/synthesize_audio.dart --lang $lang'
          : null;
    });
  }

  /// Прогон без пауз, как в забеге: 14 файлов подряд, каждый с предзагрузкой
  /// следующего.
  Future<void> _run() async {
    final service = ref.read(audioServiceProvider);
    if (service is! PooledAudioService || _ids.isEmpty) return;

    setState(() {
      _running = true;
      _done = 0;
    });
    service.probe.clear();

    for (var i = 0; i < _ids.length; i++) {
      service.play(_ids[i]);
      if (i + 1 < _ids.length) {
        // Предзагрузка следующего — ровно то, что делает забег.
        unawaited(service.preload(_ids[i + 1]));
      }
      // Пауза примерно равна длительности круга.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _done = i + 1);
    }

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(audioServiceProvider);
    final probe = service is PooledAudioService ? service.probe : null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Задержка звука')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Проигрывает $_rounds файлов подряд, как в забеге, и измеряет '
            'время от вызова до старта воспроизведения. Порог приемлемости — '
            '${AudioLatencyProbe.acceptableMedian.inMilliseconds} мс.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Мерить нужно на реальном телефоне: на эмуляторе и на десктопе '
            'цифра не значит ничего.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _running || _ids.isEmpty ? null : _run,
            icon: const Icon(Icons.play_arrow),
            label: Text(_running ? 'Идёт: $_done / ${_ids.length}' : 'Запустить'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 28),
          if (probe != null && probe.count > 0) _Result(probe: probe),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.probe});

  final AudioLatencyProbe probe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = probe.isAcceptable ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Результат', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _row('замеров', '${probe.count}'),
        _row('медиана', '${probe.median?.inMilliseconds} мс'),
        _row('худший', '${probe.worst?.inMilliseconds} мс'),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? LumenPalette.correct : theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok
                    ? 'Укладывается: озвучка успевает до следующего круга.'
                    : 'Не укладывается. Пробуйте audioplayers с AudioPool или '
                        'платформенный SoundPool — либо переносите момент '
                        'озвучки.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(key)),
            Text(value),
          ],
        ),
      );
}
