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
  String get commonUndo => 'Annuler';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get comingSoon => 'Bientôt';

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
  String get languagesTitle => 'Langues';

  @override
  String get languagesSubtitle =>
      'La langue des indices et celle de l\'interface sont deux réglages distincts.';

  @override
  String get languagesLearning => 'J\'apprends';

  @override
  String get languagesHints => 'Indices en';

  @override
  String get languagesInterface => 'Interface';

  @override
  String get languagesSystem => 'Comme le système';

  @override
  String get calibrationHintComb => 'Reliez simplement ce que vous savez';

  @override
  String get calibrationHintSearch => 'Nous cherchons par où commencer';

  @override
  String get calibrationHintConfirm => 'Nous vérifions encore';

  @override
  String get calibrationHintDone => 'Terminé';

  @override
  String get calibrationResultTitle => 'Votre ciel commence ici';

  @override
  String calibrationResultVocabulary(int count) {
    return 'À ce niveau et en dessous se trouvent environ $count mots du cours.';
  }

  @override
  String get calibrationResultCircles => 'Cercles dans le test';

  @override
  String get calibrationResultRecognised => 'Mots reconnus';

  @override
  String get calibrationResultMeasured => 'Le test a mesuré';

  @override
  String calibrationResultCapped(String tier) {
    return 'Seul $tier est relu et lancé pour l\'instant : le ciel commence là. Ce n\'est pas le plafond du jeu : le niveau montera avec le contenu.';
  }

  @override
  String calibrationResultSeeded(int count) {
    return '$count mots du test brillent déjà dans votre ciel.';
  }

  @override
  String get calibrationResultTierChangeable =>
      'Le palier se change à tout moment dans les réglages.';

  @override
  String get calibrationResultOpen => 'Ouvrir le ciel';

  @override
  String get ritualHeading => 'Rituel quotidien';

  @override
  String get ritualSubtitle =>
      'Aube — niveau — défi nocturne. Six minutes avec un début et une fin.';

  @override
  String get ritualStart => 'Commencer';

  @override
  String get ritualLevelOnly => 'Le niveau seulement';

  @override
  String get ritualLevelOnlySubtitle => 'Passer l\'aube et prendre du nouveau';

  @override
  String get ritualSunrise => 'Aube';

  @override
  String get ritualLevel => 'Niveau';

  @override
  String get sunriseReturned => 'revenus au ciel';

  @override
  String get sunriseNothing => 'le ciel brillait déjà : rien à réviser';

  @override
  String get sunriseNext => 'Vers le nouveau niveau';

  @override
  String get ritualScore => 'points pour le rituel';

  @override
  String get ritualNewWords => 'mots nouveaux';

  @override
  String get ritualLumens => 'lumens';

  @override
  String get ritualDoneTitle => 'Rituel terminé';

  @override
  String ritualDoneBody(int lumens, int words) {
    return '$lumens lm sont revenus au ciel, $words mots nouveaux appris.';
  }

  @override
  String get ritualToSky => 'Vers le ciel';

  @override
  String get runAccuracy => 'précision';

  @override
  String get runCircles => 'cercles';

  @override
  String get runCombo => 'combo';

  @override
  String get runPerfect => 'sans faute';

  @override
  String get runContinue => 'Suivant';

  @override
  String get audioReplay => 'Réécouter';

  @override
  String get skyStars => 'étoiles';

  @override
  String get skyBurning => 'allumées';

  @override
  String get skyConstellations => 'constellations';

  @override
  String get skyEmptyTitle => 'Le ciel est vide';

  @override
  String get skyEmptyBody =>
      'La base de contenu ne contient aucune constellation pour ce palier.';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit étoiles sur $total sont allumées';
  }

  @override
  String get constellationLocked => 'Pas encore débloquée';

  @override
  String constellationToLight(int count) {
    return 'Encore $count étoiles avant l\'allumage';
  }

  @override
  String get constellationAboutToLight => 'La constellation va s\'allumer';

  @override
  String tierSuggestUp(String tier) {
    return 'La plus grande partie du ciel brille. Passer à $tier ? Les anciennes étoiles restent en place.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return '$current semble difficile. Essayer $target ?';
  }

  @override
  String get bandBurning => 'allumée';

  @override
  String get bandSteady => 'lumière stable';

  @override
  String get bandFlickering => 'vacille';

  @override
  String get bandDimming => 's\'affaiblit';

  @override
  String get bandFading => 's\'éteint';

  @override
  String get profileOrbit => 'orbite';

  @override
  String get profileOrbitExplain =>
      'Un jour manqué la baisse d\'un cran. La remise à zéro complète seulement après trois jours manqués d\'affilée.';

  @override
  String get profileOrbitRisk =>
      'Encore un jour manqué et l\'orbite sera remise à zéro.';

  @override
  String get profileEclipse => 'éclipse';

  @override
  String get profileWeek => 'Semaine';

  @override
  String get profileWeeklyGoalMet => 'Objectif de la semaine atteint';

  @override
  String profileWeeklyGoal(int days) {
    return 'Objectif de la semaine : $days jours sur 7. Deux jours de repos sont légitimes.';
  }

  @override
  String get profileBurning => 'allumées';

  @override
  String get profileWordsInWork => 'mots en cours';

  @override
  String get profileLatency => 'réponse';

  @override
  String get profileSparks => 'étincelles';

  @override
  String get profileBrightness => 'Luminosité par constellation';

  @override
  String get profileEmpty => 'Encore vide : jouez votre premier niveau.';

  @override
  String profileBurningOf(int burning, int total) {
    return '$burning sur $total allumées';
  }

  @override
  String get customWordsTitle => 'Vos propres mots';

  @override
  String get customWordsHint =>
      'Une liste tirée de votre manuel, d\'une lettre ou de vos notes. Une paire par ligne : « Wort — mot ».';

  @override
  String get customWordsAdd => 'Ajouter';

  @override
  String customWordsAdded(int count) {
    return 'Ajoutés : $count';
  }

  @override
  String get customWordsNoPairs =>
      'Aucune paire trouvée. Format : « Wort — mot », une paire par ligne.';

  @override
  String customWordsCount(int count) {
    return 'Dans la constellation personnelle : $count';
  }

  @override
  String get settingsTier => 'Palier';

  @override
  String get settingsTierExplain =>
      'Les constellations grandissent avec le palier. Les anciennes étoiles restent en place.';

  @override
  String settingsTierLocked(String tier) {
    return 'Les paliers au-dessus de $tier n\'ont pas encore été relus et ne sont pas disponibles.';
  }

  @override
  String get settingsSound => 'Son';

  @override
  String get settingsSoundSubtitle =>
      'Sans le son, une bonne réponse est signalée par une vibration';

  @override
  String get settingsPace => 'Votre rythme';

  @override
  String get settingsPaceOn =>
      'Les mots nouveaux ne sont plus limités à un niveau par jour';

  @override
  String get settingsPaceOff =>
      'Un niveau par jour est une limite pédagogique, pas un mur payant';

  @override
  String get settingsPaceDialogTitle => 'Votre rythme';

  @override
  String get settingsPaceDialogBody =>
      'Chaque mot nouveau revient en révision : demain et dans une semaine. Si vous en prenez trop d\'un coup, la file de révisions grossit plus vite que vous ne la videz.\n\nLa part de mots nouveaux par séance reste malgré tout limitée.';

  @override
  String get settingsPaceKeep => 'Laisser ainsi';

  @override
  String get settingsPaceEnable => 'Activer';

  @override
  String get settingsNotifications => 'Rappel';

  @override
  String get settingsNotificationsSubtitle =>
      'Un par jour, à l\'heure où vous jouez d\'habitude';

  @override
  String get settingsNotificationsDenied =>
      'Le système n\'a pas accordé l\'autorisation de notification';

  @override
  String get settingsRecalibrate => 'Recalibrer';

  @override
  String get settingsRecalibrateSubtitle =>
      'Refaire le test — possible à tout moment';

  @override
  String get settingsWipe => 'Supprimer toutes les données';

  @override
  String get settingsWipeSubtitle => 'Sans possibilité de restauration';

  @override
  String get settingsWipeDialogTitle => 'Supprimer toutes les données ?';

  @override
  String get settingsWipeDialogBody =>
      'La progression, l\'historique des réponses et vos propres mots seront effacés sans possibilité de restauration. Vous recommencerez à zéro, calibration comprise.';

  @override
  String get settingsWipeConfirm => 'Supprimer';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsAboutSubtitle => 'Entièrement gratuit · dons · licences';

  @override
  String get aboutTitle => 'À propos';

  @override
  String get aboutTagline =>
      'Le vocabulaire comme un ciel nocturne. L\'éclat d\'une étoile, c\'est la probabilité de se rappeler le mot à l\'instant.';

  @override
  String get aboutFreeTitle => 'Entièrement gratuit';

  @override
  String get aboutFreeBody =>
      'Ni abonnement, ni paliers payants, ni publicité, ni monnaie contre de l\'argent. Tout ce qui existe dans le jeu est accessible à tous, toujours.';

  @override
  String get aboutCostBody =>
      'Cela tient parce qu\'un utilisateur ne coûte presque rien au projet : le contenu est dans l\'application, la parole est synthétisée par l\'appareil, et il n\'y a ni serveur ni requête réseau.';

  @override
  String get aboutDonate => 'Soutenir le projet';

  @override
  String get aboutDonateNote =>
      'Un donateur reçoit une mention et son nom au générique, et rien qui donne un avantage dans le jeu ou dans l\'apprentissage.';

  @override
  String get aboutExpenses => 'Où va l\'argent';

  @override
  String get aboutExpensesSubtitle => 'Page publique des dépenses';

  @override
  String get aboutSource => 'Code source';

  @override
  String get aboutSourceSubtitle => 'Code — MIT, contenu — CC BY-SA 4.0';

  @override
  String get aboutNotHereTitle => 'Ce que le jeu n\'a pas, volontairement';

  @override
  String get aboutNoLives =>
      'Vies, cœurs et énergie : une erreur coûte des points, pas l\'accès';

  @override
  String get aboutNoStreakReset =>
      'Remise à zéro de la série : un jour manqué n\'efface pas six mois';

  @override
  String get aboutNoTimer => 'Un chronomètre sur le matériel nouveau';

  @override
  String get aboutNoXp => 'Un classement à l\'XP';

  @override
  String get aboutNoBots => 'Des bots déguisés en adversaires réels';

  @override
  String get aboutNoForcedOrder => 'Un ordre imposé des thèmes';

  @override
  String get aboutNoAds => 'Publicité et traqueurs';

  @override
  String get aboutReviewTitle => 'Comment le contenu a été vérifié';

  @override
  String get aboutReviewBody =>
      'Les mots et phrases allemands ont été générés par un modèle de langue, puis relus par un second modèle, différent. Aucun locuteur natif ne les a vérifiés.';

  @override
  String get aboutReviewLimit =>
      'Deux modèles peuvent se tromper de la même façon : leurs données d\'entraînement se recoupent. La relecture croisée repère les inattentions et les contradictions, pas l\'erreur qu\'ils partagent. Si vous en repérez une, le contenu est dans le dépôt ouvert et la correction tient dans un fichier.';

  @override
  String get profileDays => 'jours joués';

  @override
  String get profileStreak => 'jours d\'affilée';

  @override
  String get profileTimeTotal => 'temps dans l\'app';

  @override
  String get profileTimePerDay => 'par jour joué';

  @override
  String get profileScaleTitle => 'De A0 à B2';

  @override
  String profileScaleHint(String tier, int percent) {
    return 'Vous êtes au palier $tier : $percent% de ses mots sont en mémoire.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'Les paliers au-dessus de $tier ne sont pas encore relus, le jeu ne les propose donc pas.';
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
  String get stageIntroduction => 'Découverte';

  @override
  String get stageConsolidation => 'Consolidation';

  @override
  String get stageCheck => 'Vérification';

  @override
  String get stageReminder => 'Rappel';

  @override
  String get stageSprint => 'Sprint';

  @override
  String sprintGoal(int done, int target, int seconds) {
    return '$done sur $target en $seconds s';
  }

  @override
  String get sprintReached => 'Objectif atteint';

  @override
  String sprintMissed(int done, int target) {
    return 'Objectif manqué : $done sur $target';
  }

  @override
  String sprintAttempt(int attempt, int total) {
    return 'Essai $attempt sur $total';
  }

  @override
  String get aboutPrivacy =>
      'Confidentialité : Sentry sans données personnelles ni tracing, aucune analytique par le réseau. L\'export et la suppression sont dans les réglages.';

  @override
  String unitSeconds(String value) {
    return '$value s';
  }

  @override
  String get customWordsPlaceholder => 'Rechnung — facture\nQuittung — reçu';

  @override
  String voiceMissingTitle(String language) {
    return 'Aucune voix $language sur cet appareil';
  }

  @override
  String voiceMissingBody(String language) {
    return 'Lumen parle avec la voix de votre appareil et a donc besoin des données vocales $language. Sans elles, la bonne réponse est seulement signalée par une brève vibration.';
  }

  @override
  String get voiceUnavailableTitle => 'Cet appareil n’a pas de synthèse vocale';

  @override
  String get voiceInstall => 'Installer la voix';

  @override
  String get voicePlaySilent => 'Jouer sans son';

  @override
  String voiceManualPath(String path) {
    return 'Où chercher : $path';
  }

  @override
  String voiceReady(String language) {
    return 'Parle avec la voix système : $language';
  }

  @override
  String get recordsTitle => 'Tes records';

  @override
  String get recordsClimb => 'Meilleure série';

  @override
  String get recordsHour => 'Meilleure heure';

  @override
  String get recordsDay => 'Meilleur jour';

  @override
  String get recordsWeek => 'Meilleure semaine';

  @override
  String get recordsMonth => 'Meilleur mois';

  @override
  String recordsNow(String value) {
    return 'maintenant $value';
  }

  @override
  String recordsToBeat(String value) {
    return 'encore $value';
  }

  @override
  String get recordsBeaten => 'record !';

  @override
  String get recordsEmpty =>
      'Joue un niveau et les premiers records apparaîtront ici.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Niveau $level · ×$multiplier';
  }

  @override
  String get promptTagCasual => 'familier';

  @override
  String get promptTagFormal => 'formel';
}
