// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Небо';

  @override
  String get tabGame => 'Гра';

  @override
  String get tabProfile => 'Профіль';

  @override
  String get tabSettings => 'Налаштування';

  @override
  String get skyTitle => 'Ваше небо';

  @override
  String get gameTitle => 'Денний ритуал';

  @override
  String get profileTitle => 'Профіль';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get onboardingTitle => 'Знайдемо, де починається ваше небо';

  @override
  String get onboardingSubtitle =>
      'Замість анкети — кілька кіл: ви граєте, ми міряємо.';

  @override
  String get onboardingStartCalibration => 'Почати калібрування';

  @override
  String get onboardingFromScratch => 'Я з нуля';

  @override
  String get comingSoon => 'Незабаром';
}
