import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/palette.dart';

/// Ссылки проекта. Задаются при сборке, чтобы репозиторий не знал про
/// конкретные аккаунты донатов: `--dart-define=DONATE_URL=...`.
const String donateUrl = String.fromEnvironment('DONATE_URL');
const String expensesUrl = String.fromEnvironment('EXPENSES_URL');
const String sourceUrl = String.fromEnvironment(
  'SOURCE_URL',
  defaultValue: 'https://github.com/',
);

/// О проекте и донаты.
///
/// Просим в одном месте и говорим прямо, на что уходят деньги. У бесплатных
/// проектов конвертирует не кнопка, а публичная страница расходов: человек
/// платит не «за приложение», а за то, чтобы оно осталось таким.
///
/// Донор получает метку и имя в титрах — и ничего, что даёт игровое или
/// учебное преимущество. Как только награда за деньги становится желанной,
/// приложение перестаёт быть бесплатным по сути.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Lumen', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l10n.aboutTagline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutFreeTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutFreeBody,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.aboutCostBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (donateUrl.isNotEmpty) ...[
            FilledButton.icon(
              onPressed: () => _open(donateUrl),
              icon: const Icon(Icons.favorite_outline),
              label: Text(l10n.aboutDonate),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.aboutDonateNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (expensesUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.aboutExpenses),
              subtitle: Text(l10n.aboutExpensesSubtitle),
              onTap: () => _open(expensesUrl),
            ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.aboutSource),
            subtitle: Text(l10n.aboutSourceSubtitle),
            onTap: () => _open(sourceUrl),
          ),
          const SizedBox(height: 28),
          Text(l10n.aboutNotHereTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final item in [
            l10n.aboutNoLives,
            l10n.aboutNoStreakReset,
            l10n.aboutNoTimer,
            l10n.aboutNoXp,
            l10n.aboutNoBots,
            l10n.aboutNoForcedOrder,
            l10n.aboutNoAds,
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.remove, size: 16,
                      color: LumenPalette.constellationLine),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          // Кто написал эти фразы — сказано игроку, а не спрятано в
          // репозитории. Человек, который учит по нашим фразам чужой язык,
          // имеет право знать это до того, как выучит ошибку: фразы и
          // переводы написала языковая модель, и после неё их не читал никто.
          //
          // **Здесь стояло обещание, которого проект не выполнял.** Абзац
          // говорил, что фразы «перекрёстно проверены второй, другой
          // моделью», а `content/launch.yaml` держит `passes: []` у всех пяти
          // ярусов: нынешний корпус не прочитан ни одной моделью ни разу.
          // Корпус к тому же сменился дважды за двое суток, и прежние записи
          // о вычитке описывали текст, которого больше нет, — поэтому они
          // удалены, а не переписаны (docs/CONTENT_PIPELINE.md, «Проходы
          // вычитки»). Второй абзац объяснял ограничения этой проверки —
          // «две модели ошибаются согласованно», — то есть держал то же
          // обещание вторым слоем, и ушёл вместе с ним.
          //
          // Уцелело из него то единственное, что работало на игрока:
          // контент открыт, правка это один файл, об ошибке стоит сказать.
          // Признание без этого — реклама честности, а не честность.
          //
          // **Привязать текст к данным честно нельзя, поэтому он не
          // привязан.** Единственное, что доезжает до приложения из записей
          // о вычитке, — `content_meta.launched_tiers`, и это то поле, которое
          // соврало бы: A0 в нём есть, а проходов у него ноль — ярус запущен
          // решением автора, чтобы проверить механику на живом человеке.
          // Честная привязка требует нового поля метаданных, собранного из
          // `passes` (`tool/build_content.dart` и `content_database.dart`), —
          // экран его себе не добавит. Пока его нет, сторожем стоит тест
          // «текст о контенте опирается на ноль проходов вычитки» в
          // `test/l10n_test.dart`: он читает `launch.yaml` и краснеет в тот
          // день, когда появится первый проход, называя эти три ключа.
          Text(l10n.aboutReviewTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(l10n.aboutReviewBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            l10n.aboutReviewLimit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.aboutPrivacy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Браузера нет или ссылка битая — не повод показывать ошибку.
    }
  }
}
