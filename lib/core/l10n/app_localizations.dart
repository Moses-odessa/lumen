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

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

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
  /// **'About {count} phrases of the course lie on this tier and below.'**
  String calibrationResultVocabulary(int count);

  /// No description provided for @calibrationResultCircles.
  ///
  /// In en, this message translates to:
  /// **'Circles in the test'**
  String get calibrationResultCircles;

  /// No description provided for @calibrationResultRecognised.
  ///
  /// In en, this message translates to:
  /// **'Phrases you recognised'**
  String get calibrationResultRecognised;

  /// No description provided for @calibrationResultMeasured.
  ///
  /// In en, this message translates to:
  /// **'The test measured'**
  String get calibrationResultMeasured;

  /// The tier the sky is capped to. It says open and not proofread on purpose: the cap comes from content_meta.launched_tiers, and a tier is launched by the author's decision, which A0 shows — it is launched with passes: [] in content/launch.yaml. See aboutReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Only {tier} is open so far, so the sky begins there. It is not the ceiling of the game: the tier rises as the content does.'**
  String calibrationResultCapped(String tier);

  /// ICU plural forms and not a bare number: Russian and Ukrainian need one/few/many, and a bare number is what produced lines like 1 phrases are already lit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} phrase from the test is already lit in your sky.} other{{count} phrases from the test are already lit in your sky.}}'**
  String calibrationResultSeeded(int count);

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

  /// No description provided for @ritualQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the ritual?'**
  String get ritualQuitTitle;

  /// Asked by the close button and by the Android back button while a run is going, and every clause of it is checked against the code — a soothing 'your progress is kept' would be the worst kind of untruth here, because the player agrees while leaning on it. What is kept: answers are written through on every circle (WordStateRepository.applyAnswer stores the FSRS triple, the due date and the cached brightness, plus a row in reviews), so brightness and the review queue survive the interruption. What is lost: the session row is written only when the level ends (RitualController._saveSession), and orbit, sparks and the preferred hour are granted from that same place and nowhere else, so an interrupted level grants none of them; the climb does not rise either, because ClimbRules.afterLevel runs at the end of the level too. Move either of those and this text plus its five translations are what has to be rewritten.
  ///
  /// In en, this message translates to:
  /// **'Your answers are already saved: phrase brightness and the review queue stay. The unfinished level counts for nothing — its points are lost, no session is recorded, and orbit and sparks do not move.'**
  String get ritualQuitBody;

  /// No description provided for @ritualQuitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get ritualQuitConfirm;

  /// The second exit, and it is not 'close this dialog': the run goes on from the same circle with a full answer window, because it was frozen while the question stood (RunController.freeze).
  ///
  /// In en, this message translates to:
  /// **'Back to the game'**
  String get ritualQuitResume;

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
  /// **'new phrases'**
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

  /// Ritual summary. The unit of study is a phrase, so the placeholder is named for one; the state field behind it is still newWords, a rename debt recorded in docs/DATA_MODEL.md. The plural is on phrases only: lm is a unit symbol that does not inflect, and the lumens clause is built without a verb that would have to agree with it (de, fr, it), so one lumen does not need a form of its own.
  ///
  /// In en, this message translates to:
  /// **'{phrases, plural, one{{lumens} lm returned to the sky, {phrases} new phrase learned.} other{{lumens} lm returned to the sky, {phrases} new phrases learned.}}'**
  String ritualDoneBody(int lumens, int phrases);

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

  /// Sky summary: stars that carry any light at all, brightness at or above LumenBand.dimming. The weakest of the two brightness claims and the one that has to agree with the picture on the map.
  ///
  /// In en, this message translates to:
  /// **'shining'**
  String get skyShining;

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

  /// Constellation card: stars bright enough to count towards igniting the constellation, ProgressionBalance.litStarMinLm. The same threshold and the same word as profileBrightOf. The plural is on lit, the number the adjective and the verb agree with; total only counts the constellation and never governs the sentence.
  ///
  /// In en, this message translates to:
  /// **'{lit, plural, one{{lit} of {total} stars is bright} other{{lit} of {total} stars are bright}}'**
  String constellationLitOf(int lit, int total);

  /// No description provided for @constellationLocked.
  ///
  /// In en, this message translates to:
  /// **'Not unlocked yet'**
  String get constellationLocked;

  /// How many stars are missing before the constellation lights up. Zero is a different line, constellationAboutToLight, so the one form here is a real one and not a rounding of nothing left.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} more star until it lights up} other{{count} more stars until it lights up}}'**
  String constellationToLight(int count);

  /// No description provided for @constellationAboutToLight.
  ///
  /// In en, this message translates to:
  /// **'About to light up'**
  String get constellationAboutToLight;

  /// Offer to move a tier up. Progression.litShare counts lit constellations among the opened ones, not shining stars, so the sentence names exactly that.
  ///
  /// In en, this message translates to:
  /// **'Most of the constellations you have opened are lit. Move to {tier}? Old stars stay where they are.'**
  String tierSuggestUp(String tier);

  /// No description provided for @tierSuggestDown.
  ///
  /// In en, this message translates to:
  /// **'{current} seems hard. Try {target}?'**
  String tierSuggestDown(String current, String target);

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

  /// Profile headline number: phrases answered fast three times in a row, word_states.burning. A speed achievement and not a brightness, hence a word of its own.
  ///
  /// In en, this message translates to:
  /// **'automatic'**
  String get profileAutomatic;

  /// No description provided for @profileWordsInWork.
  ///
  /// In en, this message translates to:
  /// **'phrases in progress'**
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

  /// Profile, one constellation: stars at or above ProgressionBalance.litStarMinLm. The same question and the same threshold as constellationLitOf, so the two screens agree. English has no separate form for one here, and the two branches are identical on purpose: the template is where the test plural is not lost in translation reads which messages carry a count that governs the sentence, so a plain string here would declare that ru, uk, fr and it need no forms either. gen-l10n itself would accept a plural in one locale only.
  ///
  /// In en, this message translates to:
  /// **'{bright, plural, one{{bright} of {total} bright} other{{bright} of {total} bright}}'**
  String profileBrightOf(int bright, int total);

  /// No description provided for @settingsTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get settingsTier;

  /// What a tier changes. It used to say the constellations grow with the tier, and that was simply not true: the corpus is 50 topics of 30 phrases each, and what a higher tier adds is topics (5 on A0, 9 on A1, 11 on A2, 12 on B1, 13 on B2), never stars inside one. The line names the growth without naming 30: the uniform size is a fact of the current corpus and not a rule, so a number here would go stale on the next import (see SkyLayout.courseConstellations).
  ///
  /// In en, this message translates to:
  /// **'A higher tier adds constellations, not stars to them — a constellation is the same size on every tier. Old stars stay where they are.'**
  String get settingsTierExplain;

  /// Why the higher segments are disabled. Drafts and not unproofread: the boundary is content_meta.launched_tiers, which says launched, and launched does not mean read by anyone — A0 is launched with passes: [] (see aboutReviewBody). Drafted is the word content/launch.yaml uses for a1..b2 itself.
  ///
  /// In en, this message translates to:
  /// **'Tiers above {tier} are still drafts and are not available yet.'**
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

  /// What the free-pace switch really does when on: SessionPlanner.allowedNewWords lifts the per-level count and caps only the share, SessionBalance.maxNewWordShare. It never limited one level a day.
  ///
  /// In en, this message translates to:
  /// **'More new phrases per level — only their share of a session stays capped'**
  String get settingsPaceOn;

  /// Free-pace switch off: SessionBalance.newWordsPerLevel new phrases in every level. The number is deliberately not spelled out, it lives in balance.dart.
  ///
  /// In en, this message translates to:
  /// **'The same number of new phrases every level — a teaching limit, not a paywall'**
  String get settingsPaceOff;

  /// No description provided for @settingsPaceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Your own pace'**
  String get settingsPaceDialogTitle;

  /// No description provided for @settingsPaceDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Every new phrase comes back for review — tomorrow and next week. Taking too much at once makes the review queue grow faster than you can clear it.\n\nThe share of new phrases in a session stays limited anyway.'**
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
  /// **'Progress and answer history will be erased with no way to restore them. You will start over, including calibration.'**
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
  /// **'A phrasebook as a night sky. A star\'s brightness is the probability of recalling a phrase right now.'**
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
  /// **'This holds because one user costs the project close to nothing: the content lives inside the app, speech is synthesised by the device, and there is no server and no network request at all.'**
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

  /// Heading of the content section on the About screen. It used to read How the content was checked, and a heading that promises a check is a claim of its own — the section under it says the content was not checked. The heading now says what the section actually answers.
  ///
  /// In en, this message translates to:
  /// **'Who wrote these phrases'**
  String get aboutReviewTitle;

  /// What the player is learning from. This text said the phrases were cross-checked by a second, different model, and that was untrue: content/launch.yaml carries passes: [] on all five tiers, zero readings of the current corpus, and the corpus itself was replaced twice within two days, so the earlier passes described text that no longer exists. THIS SENTENCE IS NOT BOUND TO ANY DATA, AND IT CANNOT HONESTLY BE. The only review-shaped fact that reaches the app is content_meta.launched_tiers, and it is exactly the field that lies here: A0 is launched with no passes at all, by the author's decision to test the mechanics on a live player. Binding the sentence to launched_tiers would restate the same untruth by machine. An honest binding needs a new content_meta field fed from the passes lists (tool/build_content.dart plus lib/data/content/content_database.dart), which no screen can add on its own. Until then the guard is a test: test/l10n_test.dart reads content/launch.yaml and fails the moment a pass appears, naming these three keys. WHOEVER ENTERS THE FIRST PASS: this text, aboutReviewTitle and aboutReviewLimit stop being true at that moment and are what has to be rewritten, in all six locales.
  ///
  /// In en, this message translates to:
  /// **'The German phrases and their translations were written by a language model. Nobody has proofread them since — no second model, no native speaker. That does not mean there are no mistakes in them; it means nobody has looked for them yet.'**
  String get aboutReviewBody;

  /// The part of the old paragraph that was true and is the only part that works for the player: the content is open, a fix is one file, and reporting an error is worth doing. What went with the paragraph was an explanation of the limits of a cross-check that never happened — it was holding the same promise a second time.
  ///
  /// In en, this message translates to:
  /// **'So if you spot something, say so: the content lives in an open repository, a fix is one file away, and it reaches everyone with the next update. A mistake nobody reports stays in the game and goes on being learned.'**
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
  /// **'You are on {tier}: {percent}% of its phrases are held in memory.'**
  String profileScaleHint(String tier, int percent);

  /// Why the scale stops. Same correction as settingsTierLocked: the reason is that those tiers are not launched, not that they are unproofread — nothing in the corpus is proofread, this tier included.
  ///
  /// In en, this message translates to:
  /// **'Tiers above {tier} are still drafts, so the game does not offer them.'**
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

  /// No description provided for @stageIntroduction.
  ///
  /// In en, this message translates to:
  /// **'Meeting new phrases'**
  String get stageIntroduction;

  /// No description provided for @stageConsolidation.
  ///
  /// In en, this message translates to:
  /// **'Settling in'**
  String get stageConsolidation;

  /// No description provided for @stageCheck.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get stageCheck;

  /// No description provided for @stageReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminding'**
  String get stageReminder;

  /// No description provided for @stageSprint.
  ///
  /// In en, this message translates to:
  /// **'Sprint'**
  String get stageSprint;

  /// No description provided for @sprintGoal.
  ///
  /// In en, this message translates to:
  /// **'{done} of {target} in {seconds} s'**
  String sprintGoal(int done, int target, int seconds);

  /// No description provided for @sprintReached.
  ///
  /// In en, this message translates to:
  /// **'Bar cleared'**
  String get sprintReached;

  /// No description provided for @sprintMissed.
  ///
  /// In en, this message translates to:
  /// **'Bar not cleared: {done} of {target}'**
  String sprintMissed(int done, int target);

  /// No description provided for @sprintAttempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt {attempt} of {total}'**
  String sprintAttempt(int attempt, int total);

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

  /// Register of a phrase: everyday speech
  ///
  /// In en, this message translates to:
  /// **'informal'**
  String get promptTagCasual;

  /// Register of a phrase: formal speech
  ///
  /// In en, this message translates to:
  /// **'formal'**
  String get promptTagFormal;

  /// Reminder, orbit at risk. Wins over dimming stars: an orbit can be lost for good, stars come back.
  ///
  /// In en, this message translates to:
  /// **'Orbit {orbit} is at risk'**
  String reminderOrbitTitle(int orbit);

  /// Reminder body under reminderOrbitTitle
  ///
  /// In en, this message translates to:
  /// **'One more missed day and it resets. Two minutes will undo that.'**
  String get reminderOrbitBody;

  /// Reminder, dimming stars. ICU plural forms and not concatenation: Russian and Ukrainian need one/few/many, and concatenation is what produced titles like 1 stars are dimming.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} star is dimming} other{{count} stars are dimming}}'**
  String reminderDimmingTitle(int count);

  /// Reminder body when one constellation holds most of the dimming stars. The name arrives already translated by ConstellationNaming, so the sentence around it has to be in the same language.
  ///
  /// In en, this message translates to:
  /// **'In the “{constellation}” constellation. Two minutes will bring them back.'**
  String reminderDimmingIn(String constellation);

  /// Reminder body when no single constellation stands out
  ///
  /// In en, this message translates to:
  /// **'Sunrise takes two minutes.'**
  String get reminderDimmingBody;

  /// Reminder when nothing is dimming: it does not invent a reason to play
  ///
  /// In en, this message translates to:
  /// **'The sky is fine'**
  String get reminderCalmTitle;

  /// Reminder body under reminderCalmTitle
  ///
  /// In en, this message translates to:
  /// **'Nothing to review — you can take something new.'**
  String get reminderCalmBody;

  /// Android notification channel name, visible in the system settings, so it belongs in the interface language too
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get reminderChannel;

  /// Android notification channel description
  ///
  /// In en, this message translates to:
  /// **'One notification a day about stars that are dimming'**
  String get reminderChannelBody;
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
