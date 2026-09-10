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
  String get commonUndo => 'Annulla';

  @override
  String get commonDone => 'Fatto';

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
  String get calibrationHintDone => 'Fatto';

  @override
  String get calibrationResultTitle => 'Il tuo cielo inizia qui';

  @override
  String calibrationResultVocabulary(int count) {
    return 'A questo livello e sotto ci sono circa $count frasi del corso.';
  }

  @override
  String get calibrationResultCircles => 'Cerchi nel test';

  @override
  String get calibrationResultRecognised => 'Frasi riconosciute';

  @override
  String get calibrationResultMeasured => 'Il test ha misurato';

  @override
  String calibrationResultCapped(String tier) {
    return 'Per ora solo $tier è stato riletto e lanciato: il cielo comincia da lì. Non è il tetto del gioco: il livello sale insieme ai contenuti.';
  }

  @override
  String calibrationResultSeeded(int count) {
    return '$count frasi del test brillano già nel tuo cielo.';
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
  String get ritualNewWords => 'frasi nuove';

  @override
  String get ritualLumens => 'lumen';

  @override
  String get ritualDoneTitle => 'Rituale completato';

  @override
  String ritualDoneBody(int lumens, int phrases) {
    return '$lumens lm sono tornati al cielo, $phrases frasi nuove imparate.';
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
  String get skyShining => 'accese';

  @override
  String get skyConstellations => 'costellazioni';

  @override
  String get skyEmptyTitle => 'Il cielo è vuoto';

  @override
  String get skyEmptyBody =>
      'Nel database dei contenuti non ci sono costellazioni per questo livello.';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit stelle su $total sono luminose';
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
    return 'Gran parte delle costellazioni aperte è accesa. Passare a $tier? Le vecchie stelle restano dove sono.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return 'Sembra che $current sia difficile. Provare $target?';
  }

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
  String get profileAutomatic => 'automatiche';

  @override
  String get profileWordsInWork => 'frasi in corso';

  @override
  String get profileLatency => 'risposta';

  @override
  String get profileSparks => 'scintille';

  @override
  String get profileBrightness => 'Luminosità per costellazione';

  @override
  String get profileEmpty => 'Ancora vuoto: gioca il primo livello.';

  @override
  String profileBrightOf(int bright, int total) {
    return '$bright su $total luminose';
  }

  @override
  String get settingsTier => 'Livello';

  @override
  String get settingsTierExplain =>
      'Le costellazioni crescono con il livello. Le vecchie stelle restano dove sono.';

  @override
  String settingsTierLocked(String tier) {
    return 'I livelli sopra $tier non sono ancora stati riletti e non sono disponibili.';
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
      'Più frasi nuove per livello: resta limitata solo la loro quota per sessione';

  @override
  String get settingsPaceOff =>
      'Sempre lo stesso numero di frasi nuove per livello: un limite didattico, non un muro a pagamento';

  @override
  String get settingsPaceDialogTitle => 'Ritmo personale';

  @override
  String get settingsPaceDialogBody =>
      'Ogni frase nuova torna per il ripasso: domani e tra una settimana. Se prendi troppo insieme, la coda dei ripassi cresce più in fretta di quanto riesci a smaltirla.\n\nLa quota di frasi nuove per sessione resta comunque limitata.';

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
      'Progressi e cronologia delle risposte verranno cancellati senza possibilità di recupero. Ricomincerai da capo, calibrazione compresa.';

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
      'Il frasario come cielo notturno. La luminosità di una stella è la probabilità di ricordare la frase proprio adesso.';

  @override
  String get aboutFreeTitle => 'Del tutto gratuito';

  @override
  String get aboutFreeBody =>
      'Nessun abbonamento, nessun livello a pagamento, nessuna pubblicità, nessuna valuta acquistabile. Tutto quello che c\'è nel gioco è per tutti, sempre.';

  @override
  String get aboutCostBody =>
      'Regge perché un utente costa al progetto quasi nulla: i contenuti stanno dentro l\'app, la voce la sintetizza il dispositivo, e non ci sono né server né richieste di rete.';

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
  String get aboutReviewTitle => 'Come è stato verificato il contenuto';

  @override
  String get aboutReviewBody =>
      'Le frasi tedesche sono state generate da un modello linguistico e poi rilette da un secondo modello, diverso. Nessun madrelingua le ha verificate.';

  @override
  String get aboutReviewLimit =>
      'Due modelli possono sbagliare nello stesso modo: i loro dati di addestramento si sovrappongono. La rilettura incrociata trova le distrazioni e le contraddizioni, non l\'errore che entrambi condividono. Se ne noti uno, il contenuto è nel repository aperto e la correzione è un file.';

  @override
  String get profileDays => 'giorni giocati';

  @override
  String get profileStreak => 'giorni di fila';

  @override
  String get profileTimeTotal => 'tempo nell\'app';

  @override
  String get profileTimePerDay => 'per giorno giocato';

  @override
  String get profileScaleTitle => 'Da A0 a B2';

  @override
  String profileScaleHint(String tier, int percent) {
    return 'Sei al livello $tier: il $percent% delle sue frasi è in memoria.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'I livelli sopra $tier non sono ancora riletti, quindi il gioco non li propone.';
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
  String get stageIntroduction => 'Incontro';

  @override
  String get stageConsolidation => 'Consolidamento';

  @override
  String get stageCheck => 'Verifica';

  @override
  String get stageReminder => 'Richiamo';

  @override
  String get stageSprint => 'Sprint';

  @override
  String sprintGoal(int done, int target, int seconds) {
    return '$done su $target in $seconds s';
  }

  @override
  String get sprintReached => 'Obiettivo raggiunto';

  @override
  String sprintMissed(int done, int target) {
    return 'Obiettivo mancato: $done su $target';
  }

  @override
  String sprintAttempt(int attempt, int total) {
    return 'Tentativo $attempt di $total';
  }

  @override
  String get aboutPrivacy =>
      'Privacy: Sentry senza dati personali e senza tracing, nessuna analitica via rete. Esportazione ed eliminazione sono nelle impostazioni.';

  @override
  String unitSeconds(String value) {
    return '$value s';
  }

  @override
  String voiceMissingTitle(String language) {
    return 'Nessuna voce $language su questo dispositivo';
  }

  @override
  String voiceMissingBody(String language) {
    return 'Lumen parla con la voce del dispositivo e per questo servono i dati vocali $language. Senza di essi la risposta corretta è segnalata solo da una breve vibrazione.';
  }

  @override
  String get voiceUnavailableTitle =>
      'Questo dispositivo non ha la sintesi vocale';

  @override
  String get voiceInstall => 'Installa la voce';

  @override
  String get voicePlaySilent => 'Gioca senza audio';

  @override
  String voiceManualPath(String path) {
    return 'Dove cercare: $path';
  }

  @override
  String voiceReady(String language) {
    return 'Parla con la voce di sistema: $language';
  }

  @override
  String get recordsTitle => 'I tuoi record';

  @override
  String get recordsClimb => 'Serie migliore';

  @override
  String get recordsHour => 'Ora migliore';

  @override
  String get recordsDay => 'Giorno migliore';

  @override
  String get recordsWeek => 'Settimana migliore';

  @override
  String get recordsMonth => 'Mese migliore';

  @override
  String recordsNow(String value) {
    return 'ora $value';
  }

  @override
  String recordsToBeat(String value) {
    return 'mancano $value';
  }

  @override
  String get recordsBeaten => 'record!';

  @override
  String get recordsEmpty =>
      'Gioca un livello e qui compariranno i primi record.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Livello $level · ×$multiplier';
  }

  @override
  String get promptTagCasual => 'informale';

  @override
  String get promptTagFormal => 'formale';

  @override
  String reminderOrbitTitle(int orbit) {
    return 'Orbita $orbit a rischio';
  }

  @override
  String get reminderOrbitBody =>
      'Un altro giorno saltato e torna a zero. Due minuti lo evitano.';

  @override
  String reminderDimmingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stelle si affievoliscono',
      one: '$count stella si affievolisce',
    );
    return '$_temp0';
  }

  @override
  String reminderDimmingIn(String constellation) {
    return 'Nella costellazione «$constellation». Due minuti le riportano.';
  }

  @override
  String get reminderDimmingBody => 'Il sorgere dura due minuti.';

  @override
  String get reminderCalmTitle => 'Il cielo è in ordine';

  @override
  String get reminderCalmBody =>
      'Non c’è nulla da ripassare: puoi prendere qualcosa di nuovo.';

  @override
  String get reminderChannel => 'Promemoria giornaliero';

  @override
  String get reminderChannelBody =>
      'Una notifica al giorno sulle stelle che si affievoliscono';
}
