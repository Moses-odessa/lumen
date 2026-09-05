// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Cielo';

  @override
  String get tabGame => 'Gioca';

  @override
  String get tabProfile => 'Profilo';

  @override
  String get tabSettings => 'Impostazioni';

  @override
  String get skyTitle => 'Il tuo cielo';

  @override
  String get gameTitle => 'Rituale quotidiano';

  @override
  String get profileTitle => 'Profilo';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get commonNext => 'Avanti';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get comingSoon => 'Prossimamente';

  @override
  String get onboardingTitle => 'Troviamo dove inizia il tuo cielo';

  @override
  String get onboardingSubtitle =>
      'Nessun questionario, solo qualche cerchio: tu giochi, noi misuriamo.';

  @override
  String get onboardingStartCalibration => 'Avvia la calibrazione';

  @override
  String get onboardingFromScratch => 'Parto da zero';

  @override
  String get languagesTitle => 'Lingue';

  @override
  String get languagesSubtitle =>
      'La lingua dei suggerimenti e quella dell\'interfaccia sono impostazioni separate.';

  @override
  String get languagesLearning => 'Imparo';

  @override
  String get languagesHints => 'Suggerimenti in';

  @override
  String get languagesInterface => 'Interfaccia';

  @override
  String get languagesSystem => 'Come il sistema';

  @override
  String get calibrationHintComb => 'Collega semplicemente quello che sai';

  @override
  String get calibrationHintSearch => 'Cerchiamo da dove partire';

  @override
  String get calibrationHintConfirm => 'Controlliamo ancora';

  @override
  String get calibrationHintPhrases => 'Ora frasi intere';

  @override
  String get calibrationHintDone => 'Fatto';

  @override
  String get calibrationResultTitle => 'Il tuo cielo inizia qui';

  @override
  String calibrationResultVocabulary(int count) {
    return 'Conosci già circa $count parole: diventeranno stelle già accese.';
  }

  @override
  String get calibrationResultTierChangeable =>
      'Puoi cambiare il livello nelle impostazioni in qualsiasi momento.';

  @override
  String get calibrationResultOpen => 'Apri il cielo';

  @override
  String get ritualHeading => 'Rituale quotidiano';

  @override
  String get ritualSubtitle =>
      'Alba — livello — sfida notturna. Sei minuti con un inizio e una fine.';

  @override
  String get ritualStart => 'Inizia';

  @override
  String get ritualLevelOnly => 'Solo il livello';

  @override
  String get ritualLevelOnlySubtitle =>
      'Salta l\'alba e prendi qualcosa di nuovo';

  @override
  String get ritualSunrise => 'Alba';

  @override
  String get ritualLevel => 'Livello';

  @override
  String get sunriseReturned => 'tornati al cielo';

  @override
  String get sunriseNothing =>
      'il cielo era già acceso: non c\'era nulla da ripassare';

  @override
  String get sunriseNext => 'Al nuovo livello';

  @override
  String get ritualScore => 'punti per il rituale';

  @override
  String get ritualNewWords => 'parole nuove';

  @override
  String get ritualLumens => 'lumen';

  @override
  String get ritualDoneTitle => 'Rituale completato';

  @override
  String ritualDoneBody(int lumens, int words) {
    return '$lumens lm sono tornati al cielo, $words parole nuove imparate.';
  }

  @override
  String get ritualToSky => 'Al cielo';

  @override
  String get runAccuracy => 'precisione';

  @override
  String get runCircles => 'cerchi';

  @override
  String get runCombo => 'combo';

  @override
  String get runPerfect => 'senza errori';

  @override
  String get runContinue => 'Avanti';

  @override
  String get audioReplay => 'Ascolta di nuovo';

  @override
  String get skyStars => 'stelle';

  @override
  String get skyBurning => 'accese';

  @override
  String get skyConstellations => 'costellazioni';

  @override
  String get skyEmptyTitle => 'Il cielo è vuoto';

  @override
  String get skyEmptyBody =>
      'Nel database dei contenuti non ci sono costellazioni per questo livello.';

  @override
  String get skyDictionary => 'Dizionario';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit stelle su $total sono accese';
  }

  @override
  String get constellationLocked => 'Non ancora sbloccata';

  @override
  String constellationToLight(int count) {
    return 'Mancano ancora $count stelle per accenderla';
  }

  @override
  String get constellationAboutToLight => 'La costellazione sta per accendersi';

  @override
  String tierSuggestUp(String tier) {
    return 'Gran parte del cielo è accesa. Passare a $tier? Le vecchie stelle restano dove sono.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return 'Sembra che $current sia difficile. Provare $target?';
  }

  @override
  String get dictionaryTitle => 'Dizionario';

  @override
  String get dictionarySearchHint => 'Una parola in una delle due lingue';

  @override
  String get dictionaryNothing => 'Nessun risultato';

  @override
  String get dictionaryResetFilters => 'Azzera i filtri';

  @override
  String get dictionaryBurningFilter => 'accese';

  @override
  String get bandBurning => 'accesa';

  @override
  String get bandSteady => 'luce stabile';

  @override
  String get bandFlickering => 'tremola';

  @override
  String get bandDimming => 'si affievolisce';

  @override
  String get bandFading => 'si spegne';

  @override
  String get profileOrbit => 'orbita';

  @override
  String get profileOrbitExplain =>
      'Un giorno saltato la abbassa di uno. L\'azzeramento completo solo dopo tre giorni saltati di fila.';

  @override
  String get profileOrbitRisk =>
      'Ancora un giorno saltato e l\'orbita si azzera.';

  @override
  String get profileEclipse => 'eclissi';

  @override
  String get profileWeek => 'Settimana';

  @override
  String get profileWeeklyGoalMet => 'Obiettivo settimanale raggiunto';

  @override
  String profileWeeklyGoal(int days) {
    return 'Obiettivo settimanale: $days giorni su 7. Due giorni di riposo sono legittimi.';
  }

  @override
  String get profileBurning => 'accese';

  @override
  String get profileWordsInWork => 'parole in corso';

  @override
  String get profileLatency => 'risposta';

  @override
  String get profileSparks => 'scintille';

  @override
  String get profileBrightness => 'Luminosità per costellazione';

  @override
  String get profileEmpty => 'Ancora vuoto: gioca il primo livello.';

  @override
  String profileBurningOf(int burning, int total) {
    return '$burning su $total accese';
  }

  @override
  String get customWordsTitle => 'Parole tue';

  @override
  String get customWordsHint =>
      'Un elenco dal tuo libro, da una lettera o dai tuoi appunti. Una coppia per riga: «Wort — parola».';

  @override
  String get customWordsAdd => 'Aggiungi';

  @override
  String customWordsAdded(int count) {
    return 'Aggiunte: $count';
  }

  @override
  String get customWordsNoPairs =>
      'Nessuna coppia trovata. Formato: «Wort — parola», una coppia per riga.';

  @override
  String customWordsCount(int count) {
    return 'Nella costellazione personale: $count';
  }

  @override
  String get settingsTier => 'Livello';

  @override
  String get settingsTierExplain =>
      'Le costellazioni crescono con il livello. Le vecchie stelle restano dove sono.';

  @override
  String settingsTierLocked(String tier) {
    return 'I livelli sopra $tier non sono ancora stati revisionati da madrelingua e non sono disponibili.';
  }

  @override
  String get settingsSound => 'Audio';

  @override
  String get settingsSoundSubtitle =>
      'Senza audio la risposta corretta è segnalata da una vibrazione';

  @override
  String get settingsPace => 'Ritmo personale';

  @override
  String get settingsPaceOn =>
      'Le parole nuove non sono limitate a un livello al giorno';

  @override
  String get settingsPaceOff =>
      'Un livello al giorno è un limite didattico, non un muro a pagamento';

  @override
  String get settingsPaceDialogTitle => 'Ritmo personale';

  @override
  String get settingsPaceDialogBody =>
      'Ogni parola nuova torna per il ripasso: domani e tra una settimana. Se prendi troppo insieme, la coda dei ripassi cresce più in fretta di quanto riesci a smaltirla.\n\nLa quota di parole nuove per sessione resta comunque limitata.';

  @override
  String get settingsPaceKeep => 'Lascia com\'è';

  @override
  String get settingsPaceEnable => 'Attiva';

  @override
  String get settingsNotifications => 'Promemoria';

  @override
  String get settingsNotificationsSubtitle =>
      'Uno al giorno, nell\'ora in cui giochi di solito';

  @override
  String get settingsNotificationsDenied =>
      'Il sistema non ha concesso il permesso per le notifiche';

  @override
  String get settingsRecalibrate => 'Ricalibra';

  @override
  String get settingsRecalibrateSubtitle =>
      'Rifai il test: disponibile in qualsiasi momento';

  @override
  String get settingsWipe => 'Elimina tutti i dati';

  @override
  String get settingsWipeSubtitle => 'Senza possibilità di recupero';

  @override
  String get settingsWipeDialogTitle => 'Eliminare tutti i dati?';

  @override
  String get settingsWipeDialogBody =>
      'Progressi, cronologia delle risposte e parole tue verranno cancellati senza possibilità di recupero. Ricomincerai da capo, calibrazione compresa.';

  @override
  String get settingsWipeConfirm => 'Elimina';

  @override
  String get settingsAbout => 'Informazioni';

  @override
  String get settingsAboutSubtitle =>
      'Del tutto gratuito · donazioni · licenze';

  @override
  String get aboutTitle => 'Informazioni';

  @override
  String get aboutTagline =>
      'Il vocabolario come cielo notturno. La luminosità di una stella è la probabilità di ricordare la parola proprio adesso.';

  @override
  String get aboutFreeTitle => 'Del tutto gratuito';

  @override
  String get aboutFreeBody =>
      'Nessun abbonamento, nessun livello a pagamento, nessuna pubblicità, nessuna valuta acquistabile. Tutto quello che c\'è nel gioco è per tutti, sempre.';

  @override
  String get aboutCostBody =>
      'Regge perché un utente costa al progetto quasi nulla: contenuti e audio stanno dentro l\'app, non c\'è un server e l\'unica richiesta di rete è la sfida notturna, un file statico al giorno.';

  @override
  String get aboutDonate => 'Sostieni il progetto';

  @override
  String get aboutDonateNote =>
      'Chi dona riceve un contrassegno e il nome nei titoli di coda, e nulla che dia un vantaggio nel gioco o nell\'apprendimento.';

  @override
  String get aboutExpenses => 'Dove vanno i soldi';

  @override
  String get aboutExpensesSubtitle => 'Pagina pubblica delle spese';

  @override
  String get aboutSource => 'Codice sorgente';

  @override
  String get aboutSourceSubtitle => 'Codice — MIT, contenuti — CC BY-SA 4.0';

  @override
  String get aboutNotHereTitle => 'Cosa il gioco non ha di proposito';

  @override
  String get aboutNoLives =>
      'Vite, cuori ed energia: un errore costa punti, non l\'accesso';

  @override
  String get aboutNoStreakReset =>
      'Azzeramento della serie: un giorno saltato non cancella sei mesi';

  @override
  String get aboutNoTimer => 'Un timer sul materiale nuovo';

  @override
  String get aboutNoXp => 'Una classifica per XP';

  @override
  String get aboutNoBots => 'Bot travestiti da avversari in carne e ossa';

  @override
  String get aboutNoForcedOrder => 'Un ordine obbligatorio degli argomenti';

  @override
  String get aboutNoAds => 'Pubblicità e tracker';

  @override
  String get aboutPrivacy =>
      'Privacy: Sentry senza dati personali e senza tracing, nessuna analitica via rete. Esportazione ed eliminazione sono nelle impostazioni.';

  @override
  String unitSeconds(String value) {
    return '$value s';
  }

  @override
  String get customWordsPlaceholder =>
      'Rechnung — fattura\nQuittung — ricevuta';
}
