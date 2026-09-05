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
  String get commonNext => 'Suivant';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

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
  String get calibrationHintPhrases => 'Maintenant des phrases entières';

  @override
  String get calibrationHintDone => 'Terminé';

  @override
  String get calibrationResultTitle => 'Votre ciel commence ici';

  @override
  String calibrationResultVocabulary(int count) {
    return 'Vous connaissez déjà environ $count mots : ils deviendront des étoiles déjà allumées.';
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
  String get ritualChallenge => 'Défi nocturne';

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
  String get skyDictionary => 'Dictionnaire';

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
  String get dictionaryTitle => 'Dictionnaire';

  @override
  String get dictionarySearchHint => 'Un mot dans l\'une des deux langues';

  @override
  String get dictionaryNothing => 'Aucun résultat';

  @override
  String get dictionaryResetFilters => 'Réinitialiser les filtres';

  @override
  String get dictionaryBurningFilter => 'allumées';

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
  String get challengeTitle => 'Défi nocturne';

  @override
  String challengeSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get challengeUnavailableTitle => 'Défi indisponible';

  @override
  String get challengeUnavailableNotConfigured =>
      'Le CDN des défis n\'est pas encore configuré. Tout le reste fonctionne sans réseau.';

  @override
  String get challengeUnavailableOffline =>
      'Pas de connexion. Tout le reste fonctionne sans réseau : le défi reviendra de lui-même.';

  @override
  String get challengeAlreadyTitle => 'Déjà joué aujourd\'hui';

  @override
  String get challengeAlreadyBody =>
      'Une tentative par jour. Demain, un nouveau tirage, le même pour tout le monde.';

  @override
  String challengeAlreadyResult(int correct, int total, int seconds) {
    return '$correct sur $total en $seconds s';
  }

  @override
  String challengeSparks(int count) {
    return '+$count étincelles';
  }

  @override
  String get challengeShare => 'Partager';

  @override
  String challengeCardSeconds(String seconds) {
    return 'en $seconds s';
  }

  @override
  String get settingsTier => 'Palier';

  @override
  String get settingsTierExplain =>
      'Les constellations grandissent avec le palier. Les anciennes étoiles restent en place.';

  @override
  String settingsTierLocked(String tier) {
    return 'Les paliers au-dessus de $tier n\'ont pas encore été relus par un locuteur natif et ne sont pas disponibles.';
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
  String get settingsCloud => 'Cloud';

  @override
  String get settingsCloudSubtitle =>
      'Le compte ne sert qu\'à plusieurs appareils';

  @override
  String get settingsExport => 'Exporter les données';

  @override
  String get settingsExportSubtitle => 'Toute la progression dans un fichier';

  @override
  String settingsExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

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
  String get cloudTitle => 'Cloud';

  @override
  String get cloudIntro =>
      'Le compte ne sert qu\'à continuer sur un autre appareil. Sans compte, le jeu fonctionne entièrement : ce n\'est pas un mode réduit.';

  @override
  String get cloudNotConfiguredTitle => 'Cloud non connecté';

  @override
  String get cloudNotConfiguredBody =>
      'Un serveur n\'arrivera que si les dons couvrent l\'hébergement. D\'ici là, les données restent sur l\'appareil et peuvent être exportées dans un fichier depuis les réglages.';

  @override
  String get cloudEmail => 'E-mail';

  @override
  String get cloudPassword => 'Mot de passe';

  @override
  String get cloudSignIn => 'Se connecter';

  @override
  String get cloudSignUp => 'Créer un compte';

  @override
  String get cloudForgot => 'Mot de passe oublié ?';

  @override
  String get cloudSyncOn => 'Synchronisation activée';

  @override
  String get cloudNeverSynced => 'Pas encore synchronisé';

  @override
  String cloudLastSync(String time) {
    return 'Dernière fois : $time';
  }

  @override
  String get cloudPushNow => 'Envoyer maintenant';

  @override
  String get cloudPull => 'Récupérer depuis le cloud';

  @override
  String get cloudSignOut => 'Se déconnecter';

  @override
  String get cloudSignOutNote =>
      'La déconnexion ne supprime pas les données locales.';

  @override
  String get cloudDeleteRemote => 'Supprimer la copie dans le cloud';

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
      'Cela tient parce qu\'un utilisateur ne coûte presque rien au projet : le contenu et l\'audio sont dans l\'application, il n\'y a pas de serveur, et la seule requête réseau est le défi nocturne, un fichier statique par jour.';

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
  String get aboutPrivacy =>
      'Confidentialité : Sentry sans données personnelles ni tracing, aucune analytique par le réseau. L\'export et la suppression sont dans les réglages.';

  @override
  String unitSeconds(String value) {
    return '$value s';
  }

  @override
  String get customWordsPlaceholder => 'Rechnung — facture\nQuittung — reçu';
}
