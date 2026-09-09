import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('ru'),
    Locale('uk'),
  ];

  /// Application name shown in the task switcher
  ///
  /// In en, this message translates to:
  /// **'Lumen'**
  String get appTitle;

  /// Bottom navigation tab: the constellation map
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get tabSky;

  /// No description provided for @tabGame.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get tabGame;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @skyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your sky'**
  String get skyTitle;

  /// No description provided for @gameTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily ritual'**
  String get gameTitle;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Placeholder for screens that arrive in a later milestone
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s find where your sky begins'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A few circles instead of a questionnaire: you play, we measure.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingStartCalibration.
  ///
  /// In en, this message translates to:
  /// **'Start calibration'**
  String get onboardingStartCalibration;

  /// No description provided for @onboardingFromScratch.
  ///
  /// In en, this message translates to:
  /// **'I\'m starting from scratch'**
  String get onboardingFromScratch;

  /// No description provided for @languagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languagesTitle;

  /// No description provided for @languagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The hint language and the interface language are separate settings.'**
  String get languagesSubtitle;

  /// No description provided for @languagesLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get languagesLearning;

  /// No description provided for @languagesHints.
  ///
  /// In en, this message translates to:
  /// **'Hints in'**
  String get languagesHints;

  /// No description provided for @languagesInterface.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get languagesInterface;

  /// No description provided for @languagesSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as system'**
  String get languagesSystem;

  /// No description provided for @calibrationHintComb.
  ///
  /// In en, this message translates to:
  /// **'Just connect what you know'**
  String get calibrationHintComb;

  /// No description provided for @calibrationHintSearch.
  ///
  /// In en, this message translates to:
  /// **'Finding where to start'**
  String get calibrationHintSearch;

  /// No description provided for @calibrationHintConfirm.
  ///
  /// In en, this message translates to:
  /// **'Checking once more'**
  String get calibrationHintConfirm;

  /// No description provided for @calibrationHintPhrases.
  ///
  /// In en, this message translates to:
  /// **'Now whole phrases'**
  String get calibrationHintPhrases;

  /// No description provided for @calibrationHintDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get calibrationHintDone;

  /// No description provided for @calibrationResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your sky begins here'**
  String get calibrationResultTitle;

  /// No description provided for @calibrationResultVocabulary.
  ///
  /// In en, this message translates to:
  /// **'You already know about {count} words — they become stars that are already lit.'**
  String calibrationResultVocabulary(int count);

  /// No description provided for @calibrationResultTierChangeable.
  ///
  /// In en, this message translates to:
  /// **'You can change the tier in settings at any time.'**
  String get calibrationResultTierChangeable;

  /// No description provided for @calibrationResultOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the sky'**
  String get calibrationResultOpen;

  /// No description provided for @ritualHeading.
  ///
  /// In en, this message translates to:
  /// **'Daily ritual'**
  String get ritualHeading;

  /// No description provided for @ritualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sunrise — level — night challenge. Six minutes with a beginning and an end.'**
  String get ritualSubtitle;

  /// No description provided for @ritualStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get ritualStart;

  /// No description provided for @ritualLevelOnly.
  ///
  /// In en, this message translates to:
  /// **'Level only'**
  String get ritualLevelOnly;

  /// No description provided for @ritualLevelOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip Sunrise and take something new'**
  String get ritualLevelOnlySubtitle;

  /// No description provided for @ritualSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get ritualSunrise;

  /// No description provided for @ritualLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get ritualLevel;

  /// No description provided for @sunriseReturned.
  ///
  /// In en, this message translates to:
  /// **'returned to the sky'**
  String get sunriseReturned;

  /// No description provided for @sunriseNothing.
  ///
  /// In en, this message translates to:
  /// **'the sky was already lit — nothing to review'**
  String get sunriseNothing;

  /// No description provided for @sunriseNext.
  ///
  /// In en, this message translates to:
  /// **'On to a new level'**
  String get sunriseNext;

  /// No description provided for @ritualScore.
  ///
  /// In en, this message translates to:
  /// **'points for the ritual'**
  String get ritualScore;

  /// No description provided for @ritualNewWords.
  ///
  /// In en, this message translates to:
  /// **'new words'**
  String get ritualNewWords;

  /// No description provided for @ritualLumens.
  ///
  /// In en, this message translates to:
  /// **'lumens'**
  String get ritualLumens;

  /// No description provided for @ritualDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Ritual complete'**
  String get ritualDoneTitle;

  /// No description provided for @ritualDoneBody.
  ///
  /// In en, this message translates to:
  /// **'{lumens} lm returned to the sky, {words} new words learned.'**
  String ritualDoneBody(int lumens, int words);

  /// No description provided for @ritualToSky.
  ///
  /// In en, this message translates to:
  /// **'To the sky'**
  String get ritualToSky;

  /// No description provided for @runAccuracy.
  ///
  /// In en, this message translates to:
  /// **'accuracy'**
  String get runAccuracy;

  /// No description provided for @runCircles.
  ///
  /// In en, this message translates to:
  /// **'circles'**
  String get runCircles;

  /// No description provided for @runCombo.
  ///
  /// In en, this message translates to:
  /// **'combo'**
  String get runCombo;

  /// No description provided for @runPerfect.
  ///
  /// In en, this message translates to:
  /// **'no mistakes'**
  String get runPerfect;

  /// No description provided for @runContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get runContinue;

  /// No description provided for @audioReplay.
  ///
  /// In en, this message translates to:
  /// **'Listen again'**
  String get audioReplay;

  /// No description provided for @skyStars.
  ///
  /// In en, this message translates to:
  /// **'stars'**
  String get skyStars;

  /// No description provided for @skyBurning.
  ///
  /// In en, this message translates to:
  /// **'burning'**
  String get skyBurning;

  /// No description provided for @skyConstellations.
  ///
  /// In en, this message translates to:
  /// **'constellations'**
  String get skyConstellations;

  /// No description provided for @skyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The sky is empty'**
  String get skyEmptyTitle;

  /// No description provided for @skyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'There are no constellations for this tier in the content database.'**
  String get skyEmptyBody;

  /// No description provided for @skyDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get skyDictionary;

  /// No description provided for @constellationLitOf.
  ///
  /// In en, this message translates to:
  /// **'{lit} of {total} stars are burning'**
  String constellationLitOf(int lit, int total);

  /// No description provided for @constellationLocked.
  ///
  /// In en, this message translates to:
  /// **'Not unlocked yet'**
  String get constellationLocked;

  /// No description provided for @constellationToLight.
  ///
  /// In en, this message translates to:
  /// **'{count} more stars until it lights up'**
  String constellationToLight(int count);

  /// No description provided for @constellationAboutToLight.
  ///
  /// In en, this message translates to:
  /// **'About to light up'**
  String get constellationAboutToLight;

  /// No description provided for @tierSuggestUp.
  ///
  /// In en, this message translates to:
  /// **'Most of the sky is burning. Move to {tier}? Old stars stay where they are.'**
  String tierSuggestUp(String tier);

  /// No description provided for @tierSuggestDown.
  ///
  /// In en, this message translates to:
  /// **'{current} seems hard. Try {target}?'**
  String tierSuggestDown(String current, String target);

  /// No description provided for @dictionaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get dictionaryTitle;

  /// No description provided for @dictionarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'A word in either language'**
  String get dictionarySearchHint;

  /// No description provided for @dictionaryNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get dictionaryNothing;

  /// No description provided for @dictionaryResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get dictionaryResetFilters;

  /// No description provided for @dictionaryBurningFilter.
  ///
  /// In en, this message translates to:
  /// **'burning'**
  String get dictionaryBurningFilter;

  /// No description provided for @bandBurning.
  ///
  /// In en, this message translates to:
  /// **'burning'**
  String get bandBurning;

  /// No description provided for @bandSteady.
  ///
  /// In en, this message translates to:
  /// **'steady light'**
  String get bandSteady;

  /// No description provided for @bandFlickering.
  ///
  /// In en, this message translates to:
  /// **'flickering'**
  String get bandFlickering;

  /// No description provided for @bandDimming.
  ///
  /// In en, this message translates to:
  /// **'dimming'**
  String get bandDimming;

  /// No description provided for @bandFading.
  ///
  /// In en, this message translates to:
  /// **'fading'**
  String get bandFading;

  /// No description provided for @profileOrbit.
  ///
  /// In en, this message translates to:
  /// **'orbit'**
  String get profileOrbit;

  /// No description provided for @profileOrbitExplain.
  ///
  /// In en, this message translates to:
  /// **'A missed day lowers it by one. A full reset happens only after three misses in a row.'**
  String get profileOrbitExplain;

  /// No description provided for @profileOrbitRisk.
  ///
  /// In en, this message translates to:
  /// **'One more miss and the orbit resets.'**
  String get profileOrbitRisk;

  /// No description provided for @profileEclipse.
  ///
  /// In en, this message translates to:
  /// **'eclipse'**
  String get profileEclipse;

  /// No description provided for @profileWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get profileWeek;

  /// No description provided for @profileWeeklyGoalMet.
  ///
  /// In en, this message translates to:
  /// **'Weekly goal met'**
  String get profileWeeklyGoalMet;

  /// No description provided for @profileWeeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly goal — {days} days out of 7. Two days off are legitimate.'**
  String profileWeeklyGoal(int days);

  /// No description provided for @profileBurning.
  ///
  /// In en, this message translates to:
  /// **'burning'**
  String get profileBurning;

  /// No description provided for @profileWordsInWork.
  ///
  /// In en, this message translates to:
  /// **'words in progress'**
  String get profileWordsInWork;

  /// No description provided for @profileLatency.
  ///
  /// In en, this message translates to:
  /// **'response'**
  String get profileLatency;

  /// No description provided for @profileSparks.
  ///
  /// In en, this message translates to:
  /// **'sparks'**
  String get profileSparks;

  /// No description provided for @profileBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness by constellation'**
  String get profileBrightness;

  /// No description provided for @profileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet — play your first level.'**
  String get profileEmpty;

  /// No description provided for @profileBurningOf.
  ///
  /// In en, this message translates to:
  /// **'{burning} of {total} burning'**
  String profileBurningOf(int burning, int total);

  /// No description provided for @customWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your own words'**
  String get customWordsTitle;

  /// No description provided for @customWordsHint.
  ///
  /// In en, this message translates to:
  /// **'A list from your textbook, a letter or your notes. One pair per line: \"Wort — word\".'**
  String get customWordsHint;

  /// No description provided for @customWordsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get customWordsAdd;

  /// No description provided for @customWordsAdded.
  ///
  /// In en, this message translates to:
  /// **'Added: {count}'**
  String customWordsAdded(int count);

  /// No description provided for @customWordsNoPairs.
  ///
  /// In en, this message translates to:
  /// **'No pairs found. Format: \"Wort — word\", one pair per line.'**
  String get customWordsNoPairs;

  /// No description provided for @customWordsCount.
  ///
  /// In en, this message translates to:
  /// **'In your own constellation: {count}'**
  String customWordsCount(int count);

  /// No description provided for @settingsTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get settingsTier;

  /// No description provided for @settingsTierExplain.
  ///
  /// In en, this message translates to:
  /// **'Constellations grow with the tier. Old stars stay where they are.'**
  String get settingsTierExplain;

  /// No description provided for @settingsTierLocked.
  ///
  /// In en, this message translates to:
  /// **'Tiers above {tier} have not been proofread yet and are unavailable.'**
  String settingsTierLocked(String tier);

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settingsSound;

  /// No description provided for @settingsSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Without sound a correct answer is marked by vibration'**
  String get settingsSoundSubtitle;

  /// No description provided for @settingsPace.
  ///
  /// In en, this message translates to:
  /// **'Your own pace'**
  String get settingsPace;

  /// No description provided for @settingsPaceOn.
  ///
  /// In en, this message translates to:
  /// **'New words are not limited to one level per day'**
  String get settingsPaceOn;

  /// No description provided for @settingsPaceOff.
  ///
  /// In en, this message translates to:
  /// **'One level a day is a teaching limit, not a paywall'**
  String get settingsPaceOff;

  /// No description provided for @settingsPaceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Your own pace'**
  String get settingsPaceDialogTitle;

  /// No description provided for @settingsPaceDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Every new word comes back for review — tomorrow and next week. Taking too much at once makes the review queue grow faster than you can clear it.\n\nThe share of new words in a session stays limited anyway.'**
  String get settingsPaceDialogBody;

  /// No description provided for @settingsPaceKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave it as is'**
  String get settingsPaceKeep;

  /// No description provided for @settingsPaceEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get settingsPaceEnable;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One a day, at the hour you usually play'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'The system did not grant notification permission'**
  String get settingsNotificationsDenied;

  /// No description provided for @settingsRecalibrate.
  ///
  /// In en, this message translates to:
  /// **'Recalibrate'**
  String get settingsRecalibrate;

  /// No description provided for @settingsRecalibrateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take the test again — available at any time'**
  String get settingsRecalibrateSubtitle;

  /// No description provided for @settingsWipe.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get settingsWipe;

  /// No description provided for @settingsWipeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Without any way to restore'**
  String get settingsWipeSubtitle;

  /// No description provided for @settingsWipeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data?'**
  String get settingsWipeDialogTitle;

  /// No description provided for @settingsWipeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Progress, answer history and your own words will be erased with no way to restore them. You will start over, including calibration.'**
  String get settingsWipeDialogBody;

  /// No description provided for @settingsWipeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsWipeConfirm;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completely free · donations · licences'**
  String get settingsAboutSubtitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A vocabulary as a night sky. A star\'s brightness is the probability of recalling a word right now.'**
  String get aboutTagline;

  /// No description provided for @aboutFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Completely free'**
  String get aboutFreeTitle;

  /// No description provided for @aboutFreeBody.
  ///
  /// In en, this message translates to:
  /// **'No subscription, no paid tiers, no ads, no currency for money. Everything in the game is available to everyone, always.'**
  String get aboutFreeBody;

  /// No description provided for @aboutCostBody.
  ///
  /// In en, this message translates to:
  /// **'This holds because one user costs the project close to nothing: content and audio live inside the app, there is no server, and the only network request is the night challenge — one static file a day.'**
  String get aboutCostBody;

  /// No description provided for @aboutDonate.
  ///
  /// In en, this message translates to:
  /// **'Support the project'**
  String get aboutDonate;

  /// No description provided for @aboutDonateNote.
  ///
  /// In en, this message translates to:
  /// **'A donor gets a badge and a name in the credits — and nothing that gives an advantage in the game or in learning.'**
  String get aboutDonateNote;

  /// No description provided for @aboutExpenses.
  ///
  /// In en, this message translates to:
  /// **'Where the money goes'**
  String get aboutExpenses;

  /// No description provided for @aboutExpensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Public expenses page'**
  String get aboutExpensesSubtitle;

  /// No description provided for @aboutSource.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSource;

  /// No description provided for @aboutSourceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Code — MIT, content — CC BY-SA 4.0'**
  String get aboutSourceSubtitle;

  /// No description provided for @aboutNotHereTitle.
  ///
  /// In en, this message translates to:
  /// **'What the game deliberately does not have'**
  String get aboutNotHereTitle;

  /// No description provided for @aboutNoLives.
  ///
  /// In en, this message translates to:
  /// **'Lives, hearts and energy — a mistake costs points, not access'**
  String get aboutNoLives;

  /// No description provided for @aboutNoStreakReset.
  ///
  /// In en, this message translates to:
  /// **'Streak resets: one missed day does not erase half a year'**
  String get aboutNoStreakReset;

  /// No description provided for @aboutNoTimer.
  ///
  /// In en, this message translates to:
  /// **'A timer on new material'**
  String get aboutNoTimer;

  /// No description provided for @aboutNoXp.
  ///
  /// In en, this message translates to:
  /// **'Ranking by XP'**
  String get aboutNoXp;

  /// No description provided for @aboutNoBots.
  ///
  /// In en, this message translates to:
  /// **'Bots posing as live opponents'**
  String get aboutNoBots;

  /// No description provided for @aboutNoForcedOrder.
  ///
  /// In en, this message translates to:
  /// **'A mandatory order of topics'**
  String get aboutNoForcedOrder;

  /// No description provided for @aboutNoAds.
  ///
  /// In en, this message translates to:
  /// **'Ads and trackers'**
  String get aboutNoAds;

  /// No description provided for @aboutReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'How the content was checked'**
  String get aboutReviewTitle;

  /// No description provided for @aboutReviewBody.
  ///
  /// In en, this message translates to:
  /// **'The German phrases and words were generated by a language model and then cross-checked by a second, different model. A native speaker has not reviewed them.'**
  String get aboutReviewBody;

  /// No description provided for @aboutReviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Two models can be wrong in the same way: they are trained on overlapping data. Cross-checking catches carelessness and contradictions, not a mistake both share. If you spot an error, the content lives in the open repository and a fix is one file away.'**
  String get aboutReviewLimit;

  /// No description provided for @profileDays.
  ///
  /// In en, this message translates to:
  /// **'days played'**
  String get profileDays;

  /// No description provided for @profileStreak.
  ///
  /// In en, this message translates to:
  /// **'days in a row'**
  String get profileStreak;

  /// No description provided for @profileTimeTotal.
  ///
  /// In en, this message translates to:
  /// **'time in the app'**
  String get profileTimeTotal;

  /// No description provided for @profileTimePerDay.
  ///
  /// In en, this message translates to:
  /// **'per day played'**
  String get profileTimePerDay;

  /// No description provided for @profileScaleTitle.
  ///
  /// In en, this message translates to:
  /// **'From A0 to B2'**
  String get profileScaleTitle;

  /// No description provided for @profileScaleHint.
  ///
  /// In en, this message translates to:
  /// **'You are on {tier}: {percent}% of its words are held in memory.'**
  String profileScaleHint(String tier, int percent);

  /// No description provided for @profileScaleLocked.
  ///
  /// In en, this message translates to:
  /// **'Tiers above {tier} are not proofread yet, so the game does not offer them.'**
  String profileScaleLocked(String tier);

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String unitMinutes(int value);

  /// No description provided for @unitHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String unitHoursMinutes(int hours, int minutes);

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy: Sentry with no personal data and no tracing, no analytics over the network. Export and deletion are in settings.'**
  String get aboutPrivacy;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String unitSeconds(String value);

  /// No description provided for @customWordsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Rechnung — invoice\nQuittung — receipt'**
  String get customWordsPlaceholder;

  /// Shown when the study language has no installed voice
  ///
  /// In en, this message translates to:
  /// **'No {language} voice on this device'**
  String voiceMissingTitle(String language);

  /// Explains what is lost without the voice data
  ///
  /// In en, this message translates to:
  /// **'Lumen speaks with your device’s own voice, so it needs the {language} voice data installed. Without it the correct answer is marked by a short vibration instead.'**
  String voiceMissingBody(String language);

  /// No description provided for @voiceUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'This device has no speech synthesis'**
  String get voiceUnavailableTitle;

  /// No description provided for @voiceInstall.
  ///
  /// In en, this message translates to:
  /// **'Install the voice'**
  String get voiceInstall;

  /// No description provided for @voicePlaySilent.
  ///
  /// In en, this message translates to:
  /// **'Play without sound'**
  String get voicePlaySilent;

  /// Path to the system voice settings, for platforms that cannot be opened directly
  ///
  /// In en, this message translates to:
  /// **'Where to look: {path}'**
  String voiceManualPath(String path);

  /// Settings line when the voice is present
  ///
  /// In en, this message translates to:
  /// **'Speaking with the {language} system voice'**
  String voiceReady(String language);

  /// No description provided for @recordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your records'**
  String get recordsTitle;

  /// No description provided for @recordsClimb.
  ///
  /// In en, this message translates to:
  /// **'Best run'**
  String get recordsClimb;

  /// No description provided for @recordsHour.
  ///
  /// In en, this message translates to:
  /// **'Best hour'**
  String get recordsHour;

  /// No description provided for @recordsDay.
  ///
  /// In en, this message translates to:
  /// **'Best day'**
  String get recordsDay;

  /// No description provided for @recordsWeek.
  ///
  /// In en, this message translates to:
  /// **'Best week'**
  String get recordsWeek;

  /// No description provided for @recordsMonth.
  ///
  /// In en, this message translates to:
  /// **'Best month'**
  String get recordsMonth;

  /// Score accumulated in the current window
  ///
  /// In en, this message translates to:
  /// **'now {value}'**
  String recordsNow(String value);

  /// How much is left to beat the record
  ///
  /// In en, this message translates to:
  /// **'{value} to go'**
  String recordsToBeat(String value);

  /// No description provided for @recordsBeaten.
  ///
  /// In en, this message translates to:
  /// **'record!'**
  String get recordsBeaten;

  /// No description provided for @recordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play a level and the first records appear here.'**
  String get recordsEmpty;

  /// Current climb level and its score multiplier
  ///
  /// In en, this message translates to:
  /// **'Level {level} · ×{multiplier}'**
  String recordsClimbLevel(int level, String multiplier);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'fr',
    'it',
    'ru',
    'uk',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
