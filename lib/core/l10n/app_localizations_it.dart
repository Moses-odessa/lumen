// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Cielo';

  @override
  String get tabGame => 'Gioca';

  @override
  String get tabProfile => 'Profilo';

  @override
  String get tabSettings => 'Impostazioni';

  @override
  String get skyTitle => 'Il tuo cielo';

  @override
  String get gameTitle => 'Rituale quotidiano';

  @override
  String get profileTitle => 'Profilo';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get onboardingTitle => 'Troviamo dove inizia il tuo cielo';

  @override
  String get onboardingSubtitle =>
      'Nessun questionario, solo qualche cerchio: tu giochi, noi misuriamo.';

  @override
  String get onboardingStartCalibration => 'Avvia la calibrazione';

  @override
  String get onboardingFromScratch => 'Parto da zero';

  @override
  String get comingSoon => 'Prossimamente';
}
