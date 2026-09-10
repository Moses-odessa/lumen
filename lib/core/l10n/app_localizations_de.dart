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
  String get calibrationHintDone => 'Fertig';

  @override
  String get calibrationResultTitle => 'Hier beginnt dein Himmel';

  @override
  String calibrationResultVocabulary(int count) {
    return 'Auf dieser Stufe und darunter liegen etwa $count Sätze des Kurses.';
  }

  @override
  String get calibrationResultCircles => 'Kreise im Test';

  @override
  String get calibrationResultRecognised => 'Sätze erkannt';

  @override
  String get calibrationResultMeasured => 'Der Test ergab';

  @override
  String calibrationResultCapped(String tier) {
    return 'Bisher ist nur $tier freigegeben — dort beginnt der Himmel. Das ist keine Obergrenze des Spiels: die Stufe steigt mit den Inhalten.';
  }

  @override
  String calibrationResultSeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sätze aus dem Test leuchten schon an deinem Himmel.',
      one: '$count Satz aus dem Test leuchtet schon an deinem Himmel.',
    );
    return '$_temp0';
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
  String get ritualQuitTitle => 'Ritual abbrechen?';

  @override
  String get ritualQuitBody =>
      'Die Antworten sind schon gespeichert: Helligkeit der Sätze und Wiederholungsschlange bleiben. Das unvollendete Level zählt nicht: die Punkte sind weg, es wird keine Sitzung eingetragen, Orbit und Funken bewegen sich nicht.';

  @override
  String get ritualQuitConfirm => 'Ja, abbrechen';

  @override
  String get ritualQuitResume => 'Zurück zum Spiel';

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
  String get ritualNewWords => 'neue Sätze';

  @override
  String get ritualLumens => 'Lumen';

  @override
  String get ritualDoneTitle => 'Ritual abgeschlossen';

  @override
  String ritualDoneBody(int lumens, int phrases) {
    String _temp0 = intl.Intl.pluralLogic(
      phrases,
      locale: localeName,
      other: '$lumens lm zurück am Himmel, $phrases neue Sätze gelernt.',
      one: '$lumens lm zurück am Himmel, $phrases neuer Satz gelernt.',
    );
    return '$_temp0';
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
  String get skyShining => 'leuchten';

  @override
  String get skyConstellations => 'Sternbilder';

  @override
  String get skyEmptyTitle => 'Der Himmel ist leer';

  @override
  String get skyEmptyBody =>
      'In der Inhaltsdatenbank gibt es keine Sternbilder für diese Stufe.';

  @override
  String constellationLitOf(int lit, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      lit,
      locale: localeName,
      other: '$lit von $total Sternen sind hell',
      one: '$lit von $total Sternen ist hell',
    );
    return '$_temp0';
  }

  @override
  String get constellationLocked => 'Noch nicht freigeschaltet';

  @override
  String constellationToLight(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Sterne bis zum Entzünden',
      one: 'Noch $count Stern bis zum Entzünden',
    );
    return '$_temp0';
  }

  @override
  String get constellationAboutToLight => 'Das Sternbild entzündet sich gleich';

  @override
  String tierSuggestUp(String tier) {
    return 'Die meisten deiner offenen Sternbilder sind entzündet. Auf $tier wechseln? Alte Sterne bleiben, wo sie sind.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return '$current scheint schwer zu fallen. $target versuchen?';
  }

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
  String get profileAutomatic => 'automatisch';

  @override
  String get profileWordsInWork => 'Sätze in Arbeit';

  @override
  String get profileLatency => 'Reaktion';

  @override
  String get profileSparks => 'Funken';

  @override
  String get profileBrightness => 'Helligkeit nach Sternbildern';

  @override
  String get profileEmpty => 'Noch leer — spiel dein erstes Level.';

  @override
  String profileBrightOf(int bright, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      bright,
      locale: localeName,
      other: '$bright von $total hell',
      one: '$bright von $total hell',
    );
    return '$_temp0';
  }

  @override
  String get settingsTier => 'Stufe';

  @override
  String get settingsTierExplain =>
      'Eine höhere Stufe bringt mehr Sternbilder, nicht mehr Sterne pro Sternbild — ein Sternbild ist auf jeder Stufe gleich groß. Alte Sterne bleiben, wo sie sind.';

  @override
  String settingsTierLocked(String tier) {
    return 'Stufen über $tier sind noch Entwürfe und daher nicht verfügbar.';
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
      'Mehr neue Sätze pro Level — begrenzt bleibt nur ihr Anteil an einer Sitzung';

  @override
  String get settingsPaceOff =>
      'Immer gleich viele neue Sätze pro Level — eine didaktische Grenze, keine Bezahlschranke';

  @override
  String get settingsPaceDialogTitle => 'Eigenes Tempo';

  @override
  String get settingsPaceDialogBody =>
      'Jeder neue Satz kommt zur Wiederholung zurück — morgen und in einer Woche. Wer zu viel Neues auf einmal nimmt, dessen Wiederholungsschlange wächst schneller, als er sie abarbeiten kann.\n\nDer Anteil neuer Sätze pro Sitzung bleibt trotzdem begrenzt.';

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
      'Fortschritt und Antwortverlauf werden unwiderruflich gelöscht. Du fängst von vorne an, einschließlich der Kalibrierung.';

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
      'Der Sprachführer als Nachthimmel. Die Helligkeit eines Sterns ist die Wahrscheinlichkeit, sich gerade jetzt an den Satz zu erinnern.';

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
  String get aboutReviewTitle => 'Wer diese Sätze geschrieben hat';

  @override
  String get aboutReviewBody =>
      'Die deutschen Sätze und ihre Übersetzungen stammen von einem Sprachmodell. Danach hat sie niemand gegengelesen — kein zweites Modell, keine Muttersprachlerin, kein Muttersprachler. Das heißt nicht, dass keine Fehler drin sind, sondern dass bisher niemand nach ihnen gesucht hat.';

  @override
  String get aboutReviewLimit =>
      'Wenn dir also etwas auffällt, sag es: die Inhalte liegen in einem offenen Repository, eine Korrektur ist eine Datei, und sie kommt mit dem nächsten Update bei allen an. Ein Fehler, den niemand meldet, bleibt im Spiel und wird weiter mitgelernt.';

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
    return 'Du bist auf $tier: $percent% seiner Sätze sitzen.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'Stufen über $tier sind noch Entwürfe, deshalb bietet das Spiel sie nicht an.';
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
  String get promptTagCasual => 'umgangssprachlich';

  @override
  String get promptTagFormal => 'formell';

  @override
  String reminderOrbitTitle(int orbit) {
    return 'Orbit $orbit ist in Gefahr';
  }

  @override
  String get reminderOrbitBody =>
      'Noch ein verpasster Tag und sie fällt auf null. Zwei Minuten verhindern das.';

  @override
  String reminderDimmingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sterne verblassen',
      one: '$count Stern verblasst',
    );
    return '$_temp0';
  }

  @override
  String reminderDimmingIn(String constellation) {
    return 'Im Sternbild „$constellation“. Zwei Minuten holen sie zurück.';
  }

  @override
  String get reminderDimmingBody => 'Der Aufgang dauert zwei Minuten.';

  @override
  String get reminderCalmTitle => 'Der Himmel ist in Ordnung';

  @override
  String get reminderCalmBody =>
      'Es gibt nichts zu wiederholen — du kannst etwas Neues nehmen.';

  @override
  String get reminderChannel => 'Tägliche Erinnerung';

  @override
  String get reminderChannelBody =>
      'Eine Benachrichtigung pro Tag über verblassende Sterne';
}
