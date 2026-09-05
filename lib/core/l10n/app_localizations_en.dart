// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Sky';

  @override
  String get tabGame => 'Play';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabSettings => 'Settings';

  @override
  String get skyTitle => 'Your sky';

  @override
  String get gameTitle => 'Daily ritual';

  @override
  String get profileTitle => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get onboardingTitle => 'Let\'s find where your sky begins';

  @override
  String get onboardingSubtitle =>
      'A few circles instead of a questionnaire: you play, we measure.';

  @override
  String get onboardingStartCalibration => 'Start calibration';

  @override
  String get onboardingFromScratch => 'I\'m starting from scratch';

  @override
  String get comingSoon => 'Coming soon';
}
