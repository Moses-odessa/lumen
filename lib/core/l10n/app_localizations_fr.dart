// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Ciel';

  @override
  String get tabGame => 'Jouer';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabSettings => 'Réglages';

  @override
  String get skyTitle => 'Votre ciel';

  @override
  String get gameTitle => 'Rituel quotidien';

  @override
  String get profileTitle => 'Profil';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get onboardingTitle => 'Trouvons où commence votre ciel';

  @override
  String get onboardingSubtitle =>
      'Pas de questionnaire, quelques cercles : vous jouez, nous mesurons.';

  @override
  String get onboardingStartCalibration => 'Lancer la calibration';

  @override
  String get onboardingFromScratch => 'Je débute de zéro';

  @override
  String get comingSoon => 'Bientôt';
}
