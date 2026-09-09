import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/l10n/app_localizations.dart';
import 'package:lumen/domain/entities/prompt_tag.dart';
import 'package:lumen/features/game/presentation/prompt_tag_text.dart';

/// Пометка под центром круга обязана быть переведена — во всех шести локалях.
///
/// Раньше на её месте стоял текст из контента: под немецким словом русский
/// грамматический ярлык (немецкий файл читает автор контента, а не игрок), а
/// под каждой из 432 фраз — английское `casual` из внутреннего кода. Ни то,
/// ни другое не зависело от языка, который игрок себе выбрал.
///
/// Поэтому проверяется не наличие ключей, а замкнутость: у каждого кода из
/// набора есть непустая строка в каждой локали, и ни одна локаль не осталась
/// английской. Недостающий перевод откатился бы к английскому молча —
/// `test/l10n_test.dart` ловит это по составу ключей, а здесь ловится
/// расхождение между набором кодов и разбором в `promptTagText`.
void main() {
  test('у каждого кода есть строка во всех локалях', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final tag in promptTags) {
        final text = promptTagText(l10n, tag);
        expect(text, isNotNull,
            reason: 'локаль ${locale.languageCode}: код "$tag" не разобран '
                'в promptTagText');
        expect(text, isNotEmpty,
            reason: 'локаль ${locale.languageCode}: код "$tag" пустой');
      }
    }
  });

  test('не-код не показывается', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('uk'));

    // Свободный текст родного языка сюда не попадает: его показывают через
    // promptHint. Если он всё-таки придёт кодом — лучше промолчать, чем
    // вывести «банковская» как имя кода.
    expect(promptTagText(l10n, 'неисчисляемое'), isNull);
    expect(promptTagText(l10n, 'банковская'), isNull);
    expect(promptTagText(l10n, null), isNull);
  });

  test('локали переведены, а не скопированы с английского', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final code in ['ru', 'uk', 'de']) {
      final other = await AppLocalizations.delegate.load(Locale(code));
      final same = promptTags
          .where((t) => promptTagText(other, t) == promptTagText(en, t))
          .toList();
      expect(same, isEmpty,
          reason: 'локаль $code: коды $same оставлены английскими');
    }
  });
}
