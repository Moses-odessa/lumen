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
  String get commonUndo => 'Undo';

  @override
  String get commonNext => 'Next';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get comingSoon => 'Coming soon';

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
  String get languagesTitle => 'Languages';

  @override
  String get languagesSubtitle =>
      'The hint language and the interface language are separate settings.';

  @override
  String get languagesLearning => 'Learning';

  @override
  String get languagesHints => 'Hints in';

  @override
  String get languagesInterface => 'Interface';

  @override
  String get languagesSystem => 'Same as system';

  @override
  String get calibrationHintComb => 'Just connect what you know';

  @override
  String get calibrationHintSearch => 'Finding where to start';

  @override
  String get calibrationHintConfirm => 'Checking once more';

  @override
  String get calibrationHintPhrases => 'Now whole phrases';

  @override
  String get calibrationHintDone => 'Done';

  @override
  String get calibrationResultTitle => 'Your sky begins here';

  @override
  String calibrationResultVocabulary(int count) {
    return 'You already know about $count words — they become stars that are already lit.';
  }

  @override
  String get calibrationResultTierChangeable =>
      'You can change the tier in settings at any time.';

  @override
  String get calibrationResultOpen => 'Open the sky';

  @override
  String get ritualHeading => 'Daily ritual';

  @override
  String get ritualSubtitle =>
      'Sunrise — level — night challenge. Six minutes with a beginning and an end.';

  @override
  String get ritualStart => 'Start';

  @override
  String get ritualLevelOnly => 'Level only';

  @override
  String get ritualLevelOnlySubtitle => 'Skip Sunrise and take something new';

  @override
  String get ritualSunrise => 'Sunrise';

  @override
  String get ritualLevel => 'Level';

  @override
  String get sunriseReturned => 'returned to the sky';

  @override
  String get sunriseNothing => 'the sky was already lit — nothing to review';

  @override
  String get sunriseNext => 'On to a new level';

  @override
  String get ritualScore => 'points for the ritual';

  @override
  String get ritualNewWords => 'new words';

  @override
  String get ritualLumens => 'lumens';

  @override
  String get ritualDoneTitle => 'Ritual complete';

  @override
  String ritualDoneBody(int lumens, int words) {
    return '$lumens lm returned to the sky, $words new words learned.';
  }

  @override
  String get ritualToSky => 'To the sky';

  @override
  String get runAccuracy => 'accuracy';

  @override
  String get runCircles => 'circles';

  @override
  String get runCombo => 'combo';

  @override
  String get runPerfect => 'no mistakes';

  @override
  String get runContinue => 'Continue';

  @override
  String get audioReplay => 'Listen again';

  @override
  String get skyStars => 'stars';

  @override
  String get skyBurning => 'burning';

  @override
  String get skyConstellations => 'constellations';

  @override
  String get skyEmptyTitle => 'The sky is empty';

  @override
  String get skyEmptyBody =>
      'There are no constellations for this tier in the content database.';

  @override
  String get skyDictionary => 'Dictionary';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit of $total stars are burning';
  }

  @override
  String get constellationLocked => 'Not unlocked yet';

  @override
  String constellationToLight(int count) {
    return '$count more stars until it lights up';
  }

  @override
  String get constellationAboutToLight => 'About to light up';

  @override
  String tierSuggestUp(String tier) {
    return 'Most of the sky is burning. Move to $tier? Old stars stay where they are.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return '$current seems hard. Try $target?';
  }

  @override
  String get dictionaryTitle => 'Dictionary';

  @override
  String get dictionarySearchHint => 'A word in either language';

  @override
  String get dictionaryNothing => 'Nothing found';

  @override
  String get dictionaryResetFilters => 'Reset filters';

  @override
  String get dictionaryBurningFilter => 'burning';

  @override
  String get bandBurning => 'burning';

  @override
  String get bandSteady => 'steady light';

  @override
  String get bandFlickering => 'flickering';

  @override
  String get bandDimming => 'dimming';

  @override
  String get bandFading => 'fading';

  @override
  String get profileOrbit => 'orbit';

  @override
  String get profileOrbitExplain =>
      'A missed day lowers it by one. A full reset happens only after three misses in a row.';

  @override
  String get profileOrbitRisk => 'One more miss and the orbit resets.';

  @override
  String get profileEclipse => 'eclipse';

  @override
  String get profileWeek => 'Week';

  @override
  String get profileWeeklyGoalMet => 'Weekly goal met';

  @override
  String profileWeeklyGoal(int days) {
    return 'Weekly goal — $days days out of 7. Two days off are legitimate.';
  }

  @override
  String get profileBurning => 'burning';

  @override
  String get profileWordsInWork => 'words in progress';

  @override
  String get profileLatency => 'response';

  @override
  String get profileSparks => 'sparks';

  @override
  String get profileBrightness => 'Brightness by constellation';

  @override
  String get profileEmpty => 'Nothing yet — play your first level.';

  @override
  String profileBurningOf(int burning, int total) {
    return '$burning of $total burning';
  }

  @override
  String get customWordsTitle => 'Your own words';

  @override
  String get customWordsHint =>
      'A list from your textbook, a letter or your notes. One pair per line: \"Wort — word\".';

  @override
  String get customWordsAdd => 'Add';

  @override
  String customWordsAdded(int count) {
    return 'Added: $count';
  }

  @override
  String get customWordsNoPairs =>
      'No pairs found. Format: \"Wort — word\", one pair per line.';

  @override
  String customWordsCount(int count) {
    return 'In your own constellation: $count';
  }

  @override
  String get settingsTier => 'Tier';

  @override
  String get settingsTierExplain =>
      'Constellations grow with the tier. Old stars stay where they are.';

  @override
  String settingsTierLocked(String tier) {
    return 'Tiers above $tier have not been proofread yet and are unavailable.';
  }

  @override
  String get settingsSound => 'Sound';

  @override
  String get settingsSoundSubtitle =>
      'Without sound a correct answer is marked by vibration';

  @override
  String get settingsPace => 'Your own pace';

  @override
  String get settingsPaceOn => 'New words are not limited to one level per day';

  @override
  String get settingsPaceOff =>
      'One level a day is a teaching limit, not a paywall';

  @override
  String get settingsPaceDialogTitle => 'Your own pace';

  @override
  String get settingsPaceDialogBody =>
      'Every new word comes back for review — tomorrow and next week. Taking too much at once makes the review queue grow faster than you can clear it.\n\nThe share of new words in a session stays limited anyway.';

  @override
  String get settingsPaceKeep => 'Leave it as is';

  @override
  String get settingsPaceEnable => 'Turn on';

  @override
  String get settingsNotifications => 'Reminder';

  @override
  String get settingsNotificationsSubtitle =>
      'One a day, at the hour you usually play';

  @override
  String get settingsNotificationsDenied =>
      'The system did not grant notification permission';

  @override
  String get settingsRecalibrate => 'Recalibrate';

  @override
  String get settingsRecalibrateSubtitle =>
      'Take the test again — available at any time';

  @override
  String get settingsWipe => 'Delete all data';

  @override
  String get settingsWipeSubtitle => 'Without any way to restore';

  @override
  String get settingsWipeDialogTitle => 'Delete all data?';

  @override
  String get settingsWipeDialogBody =>
      'Progress, answer history and your own words will be erased with no way to restore them. You will start over, including calibration.';

  @override
  String get settingsWipeConfirm => 'Delete';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'Completely free · donations · licences';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline =>
      'A vocabulary as a night sky. A star\'s brightness is the probability of recalling a word right now.';

  @override
  String get aboutFreeTitle => 'Completely free';

  @override
  String get aboutFreeBody =>
      'No subscription, no paid tiers, no ads, no currency for money. Everything in the game is available to everyone, always.';

  @override
  String get aboutCostBody =>
      'This holds because one user costs the project close to nothing: content and audio live inside the app, there is no server, and the only network request is the night challenge — one static file a day.';

  @override
  String get aboutDonate => 'Support the project';

  @override
  String get aboutDonateNote =>
      'A donor gets a badge and a name in the credits — and nothing that gives an advantage in the game or in learning.';

  @override
  String get aboutExpenses => 'Where the money goes';

  @override
  String get aboutExpensesSubtitle => 'Public expenses page';

  @override
  String get aboutSource => 'Source code';

  @override
  String get aboutSourceSubtitle => 'Code — MIT, content — CC BY-SA 4.0';

  @override
  String get aboutNotHereTitle => 'What the game deliberately does not have';

  @override
  String get aboutNoLives =>
      'Lives, hearts and energy — a mistake costs points, not access';

  @override
  String get aboutNoStreakReset =>
      'Streak resets: one missed day does not erase half a year';

  @override
  String get aboutNoTimer => 'A timer on new material';

  @override
  String get aboutNoXp => 'Ranking by XP';

  @override
  String get aboutNoBots => 'Bots posing as live opponents';

  @override
  String get aboutNoForcedOrder => 'A mandatory order of topics';

  @override
  String get aboutNoAds => 'Ads and trackers';

  @override
  String get aboutReviewTitle => 'How the content was checked';

  @override
  String get aboutReviewBody =>
      'The German phrases and words were generated by a language model and then cross-checked by a second, different model. A native speaker has not reviewed them.';

  @override
  String get aboutReviewLimit =>
      'Two models can be wrong in the same way: they are trained on overlapping data. Cross-checking catches carelessness and contradictions, not a mistake both share. If you spot an error, the content lives in the open repository and a fix is one file away.';

  @override
  String get profileDays => 'days played';

  @override
  String get profileStreak => 'days in a row';

  @override
  String get profileTimeTotal => 'time in the app';

  @override
  String get profileTimePerDay => 'per day played';

  @override
  String get profileScaleTitle => 'From A0 to B2';

  @override
  String profileScaleHint(String tier, int percent) {
    return 'You are on $tier: $percent% of its words are held in memory.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'Tiers above $tier are not proofread yet, so the game does not offer them.';
  }

  @override
  String unitMinutes(int value) {
    return '$value min';
  }

  @override
  String unitHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get aboutPrivacy =>
      'Privacy: Sentry with no personal data and no tracing, no analytics over the network. Export and deletion are in settings.';

  @override
  String unitSeconds(String value) {
    return '$value s';
  }

  @override
  String get customWordsPlaceholder => 'Rechnung — invoice\nQuittung — receipt';

  @override
  String voiceMissingTitle(String language) {
    return 'No $language voice on this device';
  }

  @override
  String voiceMissingBody(String language) {
    return 'Lumen speaks with your device’s own voice, so it needs the $language voice data installed. Without it the correct answer is marked by a short vibration instead.';
  }

  @override
  String get voiceUnavailableTitle => 'This device has no speech synthesis';

  @override
  String get voiceInstall => 'Install the voice';

  @override
  String get voicePlaySilent => 'Play without sound';

  @override
  String voiceManualPath(String path) {
    return 'Where to look: $path';
  }

  @override
  String voiceReady(String language) {
    return 'Speaking with the $language system voice';
  }

  @override
  String get recordsTitle => 'Your records';

  @override
  String get recordsClimb => 'Best run';

  @override
  String get recordsHour => 'Best hour';

  @override
  String get recordsDay => 'Best day';

  @override
  String get recordsWeek => 'Best week';

  @override
  String get recordsMonth => 'Best month';

  @override
  String recordsNow(String value) {
    return 'now $value';
  }

  @override
  String recordsToBeat(String value) {
    return '$value to go';
  }

  @override
  String get recordsBeaten => 'record!';

  @override
  String get recordsEmpty => 'Play a level and the first records appear here.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Level $level · ×$multiplier';
  }
}
