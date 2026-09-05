// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Небо';

  @override
  String get tabGame => 'Игра';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get tabSettings => 'Настройки';

  @override
  String get skyTitle => 'Ваше небо';

  @override
  String get gameTitle => 'Дневной ритуал';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get onboardingTitle => 'Найдём, где начинается ваше небо';

  @override
  String get onboardingSubtitle =>
      'Вместо анкеты — несколько кругов: вы играете, мы измеряем.';

  @override
  String get onboardingStartCalibration => 'Начать калибровку';

  @override
  String get onboardingFromScratch => 'Я с нуля';

  @override
  String get comingSoon => 'Скоро';
}
