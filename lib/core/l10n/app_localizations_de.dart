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
  String get commonUndo => 'Zurücknehmen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get comingSoon => 'Kommt bald';

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
  String get languagesTitle => 'Sprachen';

  @override
  String get languagesSubtitle =>
      'Die Sprache der Hinweise und die Sprache der Oberfläche sind getrennte Einstellungen.';

  @override
  String get languagesLearning => 'Ich lerne';

  @override
  String get languagesHints => 'Hinweise auf';

  @override
  String get languagesInterface => 'Oberfläche';

  @override
  String get languagesSystem => 'Wie im System';

  @override
  String get calibrationHintComb => 'Verbinde einfach, was du kennst';

  @override
  String get calibrationHintSearch => 'Wir suchen den Startpunkt';

  @override
  String get calibrationHintConfirm => 'Wir prüfen noch einmal';

  @override
  String get calibrationHintPhrases => 'Jetzt ganze Sätze';

  @override
  String get calibrationHintDone => 'Fertig';

  @override
  String get calibrationResultTitle => 'Hier beginnt dein Himmel';

  @override
  String calibrationResultVocabulary(int count) {
    return 'Auf dieser Stufe und darunter liegen etwa $count Wörter des Kurses.';
  }

  @override
  String get calibrationResultCircles => 'Kreise im Test';

  @override
  String get calibrationResultRecognised => 'Wörter erkannt';

  @override
  String get calibrationResultMeasured => 'Der Test ergab';

  @override
  String calibrationResultCapped(String tier) {
    return 'Bisher ist nur $tier Korrektur gelesen und freigegeben — dort beginnt der Himmel. Das ist keine Obergrenze des Spiels: die Stufe steigt mit den Inhalten.';
  }

  @override
  String calibrationResultSeeded(int count) {
    return '$count Wörter aus dem Test leuchten schon an Ihrem Himmel.';
  }

  @override
  String get calibrationResultTierChangeable =>
      'Die Stufe lässt sich jederzeit in den Einstellungen ändern.';

  @override
  String get calibrationResultOpen => 'Himmel öffnen';

  @override
  String get ritualHeading => 'Tägliches Ritual';

  @override
  String get ritualSubtitle =>
      'Sonnenaufgang — Level — nächtliche Herausforderung. Sechs Minuten mit Anfang und Ende.';

  @override
  String get ritualStart => 'Starten';

  @override
  String get ritualLevelOnly => 'Nur das Level';

  @override
  String get ritualLevelOnlySubtitle =>
      'Sonnenaufgang überspringen und Neues nehmen';

  @override
  String get ritualSunrise => 'Sonnenaufgang';

  @override
  String get ritualLevel => 'Level';

  @override
  String get sunriseReturned => 'sind dem Himmel zurückgekehrt';

  @override
  String get sunriseNothing =>
      'der Himmel leuchtete ohnehin — es gab nichts zu wiederholen';

  @override
  String get sunriseNext => 'Zum neuen Level';

  @override
  String get ritualScore => 'Punkte für das Ritual';

  @override
  String get ritualNewWords => 'neue Wörter';

  @override
  String get ritualLumens => 'Lumen';

  @override
  String get ritualDoneTitle => 'Ritual abgeschlossen';

  @override
  String ritualDoneBody(int lumens, int words) {
    return '$lumens lm sind dem Himmel zurückgekehrt, $words neue Wörter gelernt.';
  }

  @override
  String get ritualToSky => 'Zum Himmel';

  @override
  String get runAccuracy => 'Treffer';

  @override
  String get runCircles => 'Runden';

  @override
  String get runCombo => 'Combo';

  @override
  String get runPerfect => 'ohne Fehler';

  @override
  String get runContinue => 'Weiter';

  @override
  String get audioReplay => 'Noch einmal anhören';

  @override
  String get skyStars => 'Sterne';

  @override
  String get skyBurning => 'leuchten';

  @override
  String get skyConstellations => 'Sternbilder';

  @override
  String get skyEmptyTitle => 'Der Himmel ist leer';

  @override
  String get skyEmptyBody =>
      'In der Inhaltsdatenbank gibt es keine Sternbilder für diese Stufe.';

  @override
  String get skyDictionary => 'Wörterbuch';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit von $total Sternen leuchten';
  }

  @override
  String get constellationLocked => 'Noch nicht freigeschaltet';

  @override
  String constellationToLight(int count) {
    return 'Noch $count Sterne bis zum Entzünden';
  }

  @override
  String get constellationAboutToLight => 'Das Sternbild entzündet sich gleich';

  @override
  String tierSuggestUp(String tier) {
    return 'Der größte Teil des Himmels leuchtet. Auf $tier wechseln? Alte Sterne bleiben, wo sie sind.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return '$current scheint schwer zu fallen. $target versuchen?';
  }

  @override
  String get dictionaryTitle => 'Wörterbuch';

  @override
  String get dictionarySearchHint => 'Ein Wort in einer der beiden Sprachen';

  @override
  String get dictionaryNothing => 'Nichts gefunden';

  @override
  String get dictionaryResetFilters => 'Filter zurücksetzen';

  @override
  String get dictionaryBurningFilter => 'leuchten';

  @override
  String get bandBurning => 'leuchtet';

  @override
  String get bandSteady => 'ruhiges Licht';

  @override
  String get bandFlickering => 'flackert';

  @override
  String get bandDimming => 'verblasst';

  @override
  String get bandFading => 'erlischt';

  @override
  String get profileOrbit => 'Orbit';

  @override
  String get profileOrbitExplain =>
      'Ein versäumter Tag senkt ihn um eins. Ein vollständiger Reset erst nach drei Versäumnissen in Folge.';

  @override
  String get profileOrbitRisk =>
      'Noch ein Versäumnis und der Orbit wird zurückgesetzt.';

  @override
  String get profileEclipse => 'Finsternis';

  @override
  String get profileWeek => 'Woche';

  @override
  String get profileWeeklyGoalMet => 'Wochenziel erreicht';

  @override
  String profileWeeklyGoal(int days) {
    return 'Wochenziel — $days von 7 Tagen. Zwei freie Tage sind erlaubt.';
  }

  @override
  String get profileBurning => 'leuchten';

  @override
  String get profileWordsInWork => 'Wörter in Arbeit';

  @override
  String get profileLatency => 'Reaktion';

  @override
  String get profileSparks => 'Funken';

  @override
  String get profileBrightness => 'Helligkeit nach Sternbildern';

  @override
  String get profileEmpty => 'Noch leer — spiel dein erstes Level.';

  @override
  String profileBurningOf(int burning, int total) {
    return '$burning von $total leuchten';
  }

  @override
  String get customWordsTitle => 'Eigene Wörter';

  @override
  String get customWordsHint =>
      'Eine Liste aus deinem Lehrbuch, einem Brief oder deinen Notizen. Ein Paar pro Zeile: „Wort — слово“.';

  @override
  String get customWordsAdd => 'Hinzufügen';

  @override
  String customWordsAdded(int count) {
    return 'Hinzugefügt: $count';
  }

  @override
  String get customWordsNoPairs =>
      'Kein Paar gefunden. Format: „Wort — слово“, ein Paar pro Zeile.';

  @override
  String customWordsCount(int count) {
    return 'Im eigenen Sternbild: $count';
  }

  @override
  String get settingsTier => 'Stufe';

  @override
  String get settingsTierExplain =>
      'Sternbilder wachsen mit der Stufe. Alte Sterne bleiben, wo sie sind.';

  @override
  String settingsTierLocked(String tier) {
    return 'Stufen über $tier sind noch nicht geprüft und daher nicht verfügbar.';
  }

  @override
  String get settingsSound => 'Ton';

  @override
  String get settingsSoundSubtitle =>
      'Ohne Ton wird eine richtige Antwort durch Vibration bestätigt';

  @override
  String get settingsPace => 'Eigenes Tempo';

  @override
  String get settingsPaceOn =>
      'Neue Wörter sind nicht auf ein Level pro Tag begrenzt';

  @override
  String get settingsPaceOff =>
      'Ein Level pro Tag ist eine didaktische Grenze, keine Bezahlschranke';

  @override
  String get settingsPaceDialogTitle => 'Eigenes Tempo';

  @override
  String get settingsPaceDialogBody =>
      'Jedes neue Wort kommt zur Wiederholung zurück — morgen und in einer Woche. Wer zu viel Neues auf einmal nimmt, dessen Wiederholungsschlange wächst schneller, als er sie abarbeiten kann.\n\nDer Anteil neuer Wörter pro Sitzung bleibt trotzdem begrenzt.';

  @override
  String get settingsPaceKeep => 'So lassen';

  @override
  String get settingsPaceEnable => 'Einschalten';

  @override
  String get settingsNotifications => 'Erinnerung';

  @override
  String get settingsNotificationsSubtitle =>
      'Eine pro Tag, zu der Stunde, zu der du sonst spielst';

  @override
  String get settingsNotificationsDenied =>
      'Das System hat keine Erlaubnis für Benachrichtigungen erteilt';

  @override
  String get settingsRecalibrate => 'Neu kalibrieren';

  @override
  String get settingsRecalibrateSubtitle =>
      'Den Test erneut machen — jederzeit möglich';

  @override
  String get settingsWipe => 'Alle Daten löschen';

  @override
  String get settingsWipeSubtitle => 'Ohne Möglichkeit zur Wiederherstellung';

  @override
  String get settingsWipeDialogTitle => 'Alle Daten löschen?';

  @override
  String get settingsWipeDialogBody =>
      'Fortschritt, Antwortverlauf und eigene Wörter werden unwiderruflich gelöscht. Du fängst von vorne an, einschließlich der Kalibrierung.';

  @override
  String get settingsWipeConfirm => 'Löschen';

  @override
  String get settingsAbout => 'Über das Projekt';

  @override
  String get settingsAboutSubtitle => 'Komplett kostenlos · Spenden · Lizenzen';

  @override
  String get aboutTitle => 'Über das Projekt';

  @override
  String get aboutTagline =>
      'Der Wortschatz als Nachthimmel. Die Helligkeit eines Sterns ist die Wahrscheinlichkeit, das Wort gerade jetzt zu erinnern.';

  @override
  String get aboutFreeTitle => 'Komplett kostenlos';

  @override
  String get aboutFreeBody =>
      'Kein Abo, keine kostenpflichtigen Stufen, keine Werbung, keine Währung für Geld. Alles im Spiel ist für alle da, immer.';

  @override
  String get aboutCostBody =>
      'Das hält, weil ein Nutzer das Projekt fast nichts kostet: die Inhalte liegen in der App selbst, die Sprache erzeugt das Gerät, und es gibt weder Server noch Netzanfragen.';

  @override
  String get aboutDonate => 'Projekt unterstützen';

  @override
  String get aboutDonateNote =>
      'Wer spendet, bekommt eine Markierung und einen Namen im Abspann — und nichts, was im Spiel oder beim Lernen einen Vorteil verschafft.';

  @override
  String get aboutExpenses => 'Wohin das Geld geht';

  @override
  String get aboutExpensesSubtitle => 'Öffentliche Ausgabenseite';

  @override
  String get aboutSource => 'Quellcode';

  @override
  String get aboutSourceSubtitle => 'Code — MIT, Inhalte — CC BY-SA 4.0';

  @override
  String get aboutNotHereTitle => 'Was es im Spiel bewusst nicht gibt';

  @override
  String get aboutNoLives =>
      'Leben, Herzen und Energie — ein Fehler kostet Punkte, nicht Zugang';

  @override
  String get aboutNoStreakReset =>
      'Serien-Reset: ein versäumter Tag löscht kein halbes Jahr';

  @override
  String get aboutNoTimer => 'Einen Timer auf neuem Material';

  @override
  String get aboutNoXp => 'Eine Rangliste nach XP';

  @override
  String get aboutNoBots => 'Bots, die sich als lebende Gegner ausgeben';

  @override
  String get aboutNoForcedOrder =>
      'Eine vorgeschriebene Reihenfolge der Themen';

  @override
  String get aboutNoAds => 'Werbung und Tracker';

  @override
  String get aboutReviewTitle => 'Wie die Inhalte geprüft wurden';

  @override
  String get aboutReviewBody =>
      'Die deutschen Wörter und Sätze wurden von einem Sprachmodell erzeugt und danach von einem zweiten, anderen Modell gegengelesen. Eine Muttersprachlerin oder ein Muttersprachler hat sie nicht geprüft.';

  @override
  String get aboutReviewLimit =>
      'Zwei Modelle können denselben Fehler machen: ihre Trainingsdaten überschneiden sich. Das Gegenlesen findet Unachtsamkeit und Widersprüche, nicht den Fehler, den beide teilen. Wenn Ihnen etwas auffällt: die Inhalte liegen im offenen Repository, eine Korrektur ist eine Datei.';

  @override
  String get profileDays => 'Tage gespielt';

  @override
  String get profileStreak => 'Tage in Folge';

  @override
  String get profileTimeTotal => 'Zeit in der App';

  @override
  String get profileTimePerDay => 'pro gespieltem Tag';

  @override
  String get profileScaleTitle => 'Von A0 bis B2';

  @override
  String profileScaleHint(String tier, int percent) {
    return 'Sie sind auf $tier: $percent% seiner Wörter sitzen.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'Stufen über $tier sind noch nicht geprüft, deshalb bietet das Spiel sie nicht an.';
  }

  @override
  String unitMinutes(int value) {
    return '$value Min.';
  }

  @override
  String unitHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get stageIntroduction => 'Kennenlernen';

  @override
  String get stageConsolidation => 'Festigen';

  @override
  String get stageCheck => 'Prüfen';

  @override
  String get stageReminder => 'Auffrischen';

  @override
  String get stageSprint => 'Sprint';

  @override
  String sprintGoal(int done, int target, int seconds) {
    return '$done von $target in $seconds s';
  }

  @override
  String get sprintReached => 'Ziel erreicht';

  @override
  String sprintMissed(int done, int target) {
    return 'Ziel nicht erreicht: $done von $target';
  }

  @override
  String sprintAttempt(int attempt, int total) {
    return 'Versuch $attempt von $total';
  }

  @override
  String get aboutPrivacy =>
      'Datenschutz: Sentry ohne personenbezogene Daten und ohne Tracing, keine Analytik über das Netz. Export und Löschung stehen in den Einstellungen.';

  @override
  String unitSeconds(String value) {
    return '$value s';
  }

  @override
  String get customWordsPlaceholder => 'Rechnung — Beleg\nQuittung — Quittung';

  @override
  String voiceMissingTitle(String language) {
    return 'Keine Stimme für $language auf diesem Gerät';
  }

  @override
  String voiceMissingBody(String language) {
    return 'Lumen spricht mit der Stimme des Geräts und braucht dafür die Sprachdaten für $language. Ohne sie wird die richtige Antwort nur mit einer kurzen Vibration bestätigt.';
  }

  @override
  String get voiceUnavailableTitle => 'Dieses Gerät hat keine Sprachsynthese';

  @override
  String get voiceInstall => 'Stimme installieren';

  @override
  String get voicePlaySilent => 'Ohne Ton spielen';

  @override
  String voiceManualPath(String path) {
    return 'Zu finden unter: $path';
  }

  @override
  String voiceReady(String language) {
    return 'Spricht mit der Systemstimme: $language';
  }

  @override
  String get recordsTitle => 'Deine Rekorde';

  @override
  String get recordsClimb => 'Beste Serie';

  @override
  String get recordsHour => 'Beste Stunde';

  @override
  String get recordsDay => 'Bester Tag';

  @override
  String get recordsWeek => 'Beste Woche';

  @override
  String get recordsMonth => 'Bester Monat';

  @override
  String recordsNow(String value) {
    return 'jetzt $value';
  }

  @override
  String recordsToBeat(String value) {
    return 'noch $value';
  }

  @override
  String get recordsBeaten => 'Rekord!';

  @override
  String get recordsEmpty =>
      'Spiel eine Ebene, dann stehen hier die ersten Rekorde.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Ebene $level · ×$multiplier';
  }

  @override
  String get promptTagAdverb => 'Adverb';

  @override
  String get promptTagAdjective => 'Adjektiv';

  @override
  String get promptTagUncountable => 'unzählbar';

  @override
  String get promptTagPluralOnly => 'nur Plural';

  @override
  String get promptTagUsuallyPlural => 'meist Plural';

  @override
  String get promptTagCasual => 'umgangssprachlich';

  @override
  String get promptTagFormal => 'formell';
}
