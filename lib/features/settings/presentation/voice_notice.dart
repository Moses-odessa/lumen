import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/speech_locale.dart';
import '../../../core/audio/speech_service.dart';
import '../../../core/audio/speech_settings.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/repositories/player_repository.dart';

/// Честное сообщение о том, что голоса для языка изучения нет.
///
/// Появилось вместе с переходом на синтез устройства. Записанные файлы
/// всегда были в установке; голос устройства — нет, и молчать об этом
/// нельзя: игрок решит, что приложение сломано, а не что в системе не
/// хватает языкового пакета.
///
/// Поэтому предлагается ровно два выхода, оба настоящие: поставить голос
/// или играть без звука. Второй не «отмена» — беззвучный режим в игре
/// полноценный, верный ответ отмечается вибрацией.
class VoiceNotice extends ConsumerWidget {
  const VoiceNotice({super.key, this.compact = false});

  /// Короткий вид для списка настроек: без рамки и заголовка экрана.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    // Игрок уже выбрал тишину — не напоминать. Предложение, которое
    // повторяется после отказа, перестаёт быть предложением.
    if (player == null || !player.soundEnabled) return const SizedBox.shrink();

    final status = ref.watch(speechStatusProvider);
    return status.maybeWhen(
      data: (value) => value.canSpeak
          ? const SizedBox.shrink()
          : _Notice(status: value, lang: player.targetLang, compact: compact),
      // Пока проверка идёт, ничего не обещаем и ничего не пугаем.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Notice extends ConsumerWidget {
  const _Notice({
    required this.status,
    required this.lang,
    required this.compact,
  });

  final SpeechStatus status;
  final String lang;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = speechLanguageNames[lang] ?? lang;

    final title = status == SpeechStatus.languageMissing
        ? l10n.voiceMissingTitle(language)
        : l10n.voiceUnavailableTitle;

    // Кнопка установки показывается только там, где ей есть куда вести, и
    // только когда дело в языке: если синтеза нет вовсе, ставить нечего.
    final canInstall = status == SpeechStatus.languageMissing &&
        SpeechSettings.canOpenVoiceSettings;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.record_voice_over_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.voiceMissingBody(language),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (!canInstall) ...[
          const SizedBox(height: 8),
          Text(
            l10n.voiceManualPath(SpeechSettings.manualPath),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            if (canInstall)
              FilledButton.tonal(
                onPressed: () => _install(ref),
                child: Text(l10n.voiceInstall),
              ),
            TextButton(
              onPressed: () => ref
                  .read(playerControllerProvider.notifier)
                  .setSoundEnabled(false),
              child: Text(l10n.voicePlaySilent),
            ),
          ],
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: content,
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }

  /// Открывает страницу установки и перепроверяет состояние по возвращении.
  ///
  /// Перепроверка обязательна: игрок уходит ставить голос и возвращается, а
  /// закэшированный ответ «языка нет» так и останется, пока приложение не
  /// перезапустят.
  Future<void> _install(WidgetRef ref) async {
    await SpeechSettings.openVoiceSettings();
    await ref.read(speechServiceProvider).status(refresh: true);
    ref.invalidate(speechStatusProvider);
  }
}
