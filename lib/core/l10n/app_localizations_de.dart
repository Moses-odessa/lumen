// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Himmel';

  @override
  String get tabGame => 'Spielen';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabSettings => 'Einstellungen';

  @override
  String get skyTitle => 'Dein Himmel';

  @override
  String get gameTitle => 'Tägliches Ritual';

  @override
  String get profileTitle => 'Profil';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get onboardingTitle => 'Finden wir, wo dein Himmel beginnt';

  @override
  String get onboardingSubtitle =>
      'Kein Fragebogen, sondern ein paar Runden: du spielst, wir messen.';

  @override
  String get onboardingStartCalibration => 'Kalibrierung starten';

  @override
  String get onboardingFromScratch => 'Ich fange bei null an';

  @override
  String get comingSoon => 'Kommt bald';
}
