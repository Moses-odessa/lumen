// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Небо';

  @override
  String get tabGame => 'Гра';

  @override
  String get tabProfile => 'Профіль';

  @override
  String get tabSettings => 'Налаштування';

  @override
  String get skyTitle => 'Ваше небо';

  @override
  String get gameTitle => 'Денний ритуал';

  @override
  String get profileTitle => 'Профіль';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get commonUndo => 'Скасувати';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonNext => 'Далі';

  @override
  String get commonCancel => 'Скасувати';

  @override
  String get comingSoon => 'Незабаром';

  @override
  String get onboardingTitle => 'Знайдемо, де починається ваше небо';

  @override
  String get onboardingSubtitle =>
      'Замість анкети — кілька кіл: ви граєте, ми міряємо.';

  @override
  String get onboardingStartCalibration => 'Почати калібрування';

  @override
  String get onboardingFromScratch => 'Я з нуля';

  @override
  String get languagesTitle => 'Мови';

  @override
  String get languagesSubtitle =>
      'Мова підказок і мова інтерфейсу — різні налаштування.';

  @override
  String get languagesLearning => 'Вивчаю';

  @override
  String get languagesHints => 'Підказки';

  @override
  String get languagesInterface => 'Інтерфейс';

  @override
  String get languagesSystem => 'Як у системі';

  @override
  String get calibrationHintComb => 'Просто з’єднуйте те, що знаєте';

  @override
  String get calibrationHintSearch => 'Добираємо, з чого почати';

  @override
  String get calibrationHintConfirm => 'Перевіряємо ще раз';

  @override
  String get calibrationHintDone => 'Готово';

  @override
  String get calibrationResultTitle => 'Ваше небо починається тут';

  @override
  String calibrationResultVocabulary(int count) {
    return 'На цьому ярусі й нижче лежить приблизно $count фраз курсу.';
  }

  @override
  String get calibrationResultCircles => 'Кіл у тесті';

  @override
  String get calibrationResultRecognised => 'Фраз ви впізнали';

  @override
  String get calibrationResultMeasured => 'Тест показав';

  @override
  String calibrationResultCapped(String tier) {
    return 'Вичитано й запущено поки лише $tier — небо починається з нього. Це не межа гри: ярус підніметься разом із контентом.';
  }

  @override
  String calibrationResultSeeded(int count) {
    return '$count фраз із тесту вже світять на вашому небі.';
  }

  @override
  String get calibrationResultTierChangeable =>
      'Ярус можна змінити в налаштуваннях будь-коли.';

  @override
  String get calibrationResultOpen => 'Відкрити небо';

  @override
  String get ritualHeading => 'Денний ритуал';

  @override
  String get ritualSubtitle =>
      'Схід — рівень — нічний виклик. Шість хвилин із початком і кінцем.';

  @override
  String get ritualStart => 'Почати';

  @override
  String get ritualLevelOnly => 'Тільки рівень';

  @override
  String get ritualLevelOnlySubtitle => 'Пропустити Схід і взяти нове';

  @override
  String get ritualSunrise => 'Схід';

  @override
  String get ritualLevel => 'Рівень';

  @override
  String get sunriseReturned => 'повернулося небу';

  @override
  String get sunriseNothing => 'небо й так світило — повторювати не було чого';

  @override
  String get sunriseNext => 'До нового рівня';

  @override
  String get ritualScore => 'очок за ритуал';

  @override
  String get ritualNewWords => 'нових фраз';

  @override
  String get ritualLumens => 'люменів';

  @override
  String get ritualDoneTitle => 'Ритуал пройдено';

  @override
  String ritualDoneBody(int lumens, int phrases) {
    return 'Небу повернулося $lumens lm, вивчено $phrases нових фраз.';
  }

  @override
  String get ritualToSky => 'До неба';

  @override
  String get runAccuracy => 'точність';

  @override
  String get runCircles => 'кіл';

  @override
  String get runCombo => 'комбо';

  @override
  String get runPerfect => 'без помилок';

  @override
  String get runContinue => 'Далі';

  @override
  String get audioReplay => 'Прослухати ще раз';

  @override
  String get skyStars => 'зір';

  @override
  String get skyShining => 'світять';

  @override
  String get skyConstellations => 'сузір’їв';

  @override
  String get skyEmptyTitle => 'Небо порожнє';

  @override
  String get skyEmptyBody =>
      'У контентній базі немає сузір’їв для цього ярусу.';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit із $total зір яскраві';
  }

  @override
  String get constellationLocked => 'Ще не відкрито';

  @override
  String constellationToLight(int count) {
    return 'До запалення — ще $count зір';
  }

  @override
  String get constellationAboutToLight => 'Сузір’я ось-ось запалає';

  @override
  String tierSuggestUp(String tier) {
    return 'Більша частина відкритих сузір’їв запалена. Перейти на $tier? Старі зорі залишаться на місцях.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return 'Схоже, $current дається важко. Спробувати $target?';
  }

  @override
  String get profileOrbit => 'орбіта';

  @override
  String get profileOrbitExplain =>
      'Пропуск опускає на один. Повне скидання — лише після трьох пропусків поспіль.';

  @override
  String get profileOrbitRisk => 'Ще один пропуск — і орбіта обнулиться.';

  @override
  String get profileEclipse => 'затемнення';

  @override
  String get profileWeek => 'Тиждень';

  @override
  String get profileWeeklyGoalMet => 'Мету тижня виконано';

  @override
  String profileWeeklyGoal(int days) {
    return 'Мета тижня — $days днів із 7. Два вихідні законні.';
  }

  @override
  String get profileAutomatic => 'на автоматі';

  @override
  String get profileWordsInWork => 'фраз у роботі';

  @override
  String get profileLatency => 'відгук';

  @override
  String get profileSparks => 'іскор';

  @override
  String get profileBrightness => 'Яскравість за сузір’ями';

  @override
  String get profileEmpty => 'Поки порожньо — зіграйте перший рівень.';

  @override
  String profileBrightOf(int bright, int total) {
    return '$bright із $total яскраві';
  }

  @override
  String get settingsTier => 'Ярус';

  @override
  String get settingsTierExplain =>
      'Розмір сузір’їв росте разом із ярусом. Старі зорі залишаються на місцях.';

  @override
  String settingsTierLocked(String tier) {
    return 'Яруси вище $tier ще не вичитані й недоступні.';
  }

  @override
  String get settingsSound => 'Звук';

  @override
  String get settingsSoundSubtitle =>
      'Без звуку правильна відповідь позначається вібрацією';

  @override
  String get settingsPace => 'Свій темп';

  @override
  String get settingsPaceOn =>
      'Нових фраз за рівень більше — обмежена лише їхня частка в сесії';

  @override
  String get settingsPaceOff =>
      'Нових фраз за рівень завжди однаково — дидактичне обмеження, а не платна стіна';

  @override
  String get settingsPaceDialogTitle => 'Свій темп';

  @override
  String get settingsPaceDialogBody =>
      'Кожна нова фраза повертається на повторення — і завтра, і за тиждень. Якщо брати багато нового одразу, черга повторень зростатиме швидше, ніж ви встигаєте її розбирати.\n\nЧастка нових фраз у сесії однаково залишиться обмеженою.';

  @override
  String get settingsPaceKeep => 'Залишити як є';

  @override
  String get settingsPaceEnable => 'Увімкнути';

  @override
  String get settingsNotifications => 'Нагадування';

  @override
  String get settingsNotificationsSubtitle =>
      'Одне на день, о тій годині, коли ви зазвичай граєте';

  @override
  String get settingsNotificationsDenied =>
      'Система не дала дозволу на сповіщення';

  @override
  String get settingsRecalibrate => 'Перекалібрування';

  @override
  String get settingsRecalibrateSubtitle =>
      'Пройти тест заново — доступно будь-коли';

  @override
  String get settingsWipe => 'Видалити всі дані';

  @override
  String get settingsWipeSubtitle => 'Без можливості відновити';

  @override
  String get settingsWipeDialogTitle => 'Видалити всі дані?';

  @override
  String get settingsWipeDialogBody =>
      'Прогрес та історія відповідей будуть стерті без можливості відновити. Доведеться почати спочатку, включно з калібруванням.';

  @override
  String get settingsWipeConfirm => 'Видалити';

  @override
  String get settingsAbout => 'Про проєкт';

  @override
  String get settingsAboutSubtitle =>
      'Безкоштовно повністю · донати · ліцензії';

  @override
  String get aboutTitle => 'Про проєкт';

  @override
  String get aboutTagline =>
      'Розмовник як нічне небо. Яскравість зорі — імовірність згадати фразу просто зараз.';

  @override
  String get aboutFreeTitle => 'Безкоштовно повністю';

  @override
  String get aboutFreeBody =>
      'Ні підписки, ні платних ярусів, ні реклами, ні валюти за гроші. Усе, що є в грі, доступне всім і завжди.';

  @override
  String get aboutCostBody =>
      'Тримається це на тому, що один користувач коштує проєкту близько нуля: контент лежить у самому застосунку, мовлення синтезує пристрій, а сервера й мережевих запитів немає взагалі.';

  @override
  String get aboutDonate => 'Підтримати проєкт';

  @override
  String get aboutDonateNote =>
      'Донор отримує позначку й ім’я в титрах — і нічого, що дає перевагу в грі чи в навчанні.';

  @override
  String get aboutExpenses => 'Куди йдуть гроші';

  @override
  String get aboutExpensesSubtitle => 'Публічна сторінка витрат';

  @override
  String get aboutSource => 'Вихідний код';

  @override
  String get aboutSourceSubtitle => 'Код — MIT, контент — CC BY-SA 4.0';

  @override
  String get aboutNotHereTitle => 'Чого в грі немає навмисно';

  @override
  String get aboutNoLives =>
      'Життів, сердець і енергії — помилка коштує очок, а не доступу';

  @override
  String get aboutNoStreakReset =>
      'Обнулення серії: один пропуск не стирає пів року';

  @override
  String get aboutNoTimer => 'Таймера на новому матеріалі';

  @override
  String get aboutNoXp => 'Рейтингу за XP';

  @override
  String get aboutNoBots => 'Ботів під виглядом живих суперників';

  @override
  String get aboutNoForcedOrder => 'Обов’язкового порядку проходження';

  @override
  String get aboutNoAds => 'Реклами й трекерів';

  @override
  String get aboutReviewTitle => 'Як перевірявся контент';

  @override
  String get aboutReviewBody =>
      'Німецькі фрази згенеровані мовною моделлю, а потім перехресно перевірені другою, іншою моделлю. Носій мови їх не вичитував.';

  @override
  String get aboutReviewLimit =>
      'Дві моделі можуть помилятися однаково: вони навчені на даних, що перетинаються. Перехресна перевірка ловить недбалість і суперечності, але не спільну для обох помилку. Якщо ви побачили неточність — контент лежить у відкритому репозиторії, і виправлення це один файл.';

  @override
  String get profileDays => 'днів грали';

  @override
  String get profileStreak => 'днів підряд';

  @override
  String get profileTimeTotal => 'часу в застосунку';

  @override
  String get profileTimePerDay => 'на день, коли грали';

  @override
  String get profileScaleTitle => 'Від A0 до B2';

  @override
  String profileScaleHint(String tier, int percent) {
    return 'Ви на $tier: $percent% його фраз тримаються в памʼяті.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'Яруси вище $tier ще не вичитані, і гра їх не пропонує.';
  }

  @override
  String unitMinutes(int value) {
    return '$value хв';
  }

  @override
  String unitHoursMinutes(int hours, int minutes) {
    return '$hours год $minutes хв';
  }

  @override
  String get stageIntroduction => 'Знайомство';

  @override
  String get stageConsolidation => 'Закріплення';

  @override
  String get stageCheck => 'Перевірка';

  @override
  String get stageReminder => 'Пригадування';

  @override
  String get stageSprint => 'Спринт';

  @override
  String sprintGoal(int done, int target, int seconds) {
    return '$done з $target за $seconds с';
  }

  @override
  String get sprintReached => 'Планку взято';

  @override
  String sprintMissed(int done, int target) {
    return 'Планку не взято: $done з $target';
  }

  @override
  String sprintAttempt(int attempt, int total) {
    return 'Спроба $attempt з $total';
  }

  @override
  String get aboutPrivacy =>
      'Приватність: Sentry без персональних даних і без трейсингу, жодної аналітики мережею. Експорт і видалення даних — у налаштуваннях.';

  @override
  String unitSeconds(String value) {
    return '$value с';
  }

  @override
  String voiceMissingTitle(String language) {
    return 'Голос для $language не встановлено';
  }

  @override
  String voiceMissingBody(String language) {
    return 'Lumen говорить голосом самого пристрою, і для цього потрібні голосові дані $language. Без них правильна відповідь позначається короткою вібрацією.';
  }

  @override
  String get voiceUnavailableTitle =>
      'На цьому пристрої немає синтезу мовлення';

  @override
  String get voiceInstall => 'Встановити голос';

  @override
  String get voicePlaySilent => 'Грати без звуку';

  @override
  String voiceManualPath(String path) {
    return 'Де шукати: $path';
  }

  @override
  String voiceReady(String language) {
    return 'Говорить системним голосом: $language';
  }

  @override
  String get recordsTitle => 'Ваші рекорди';

  @override
  String get recordsClimb => 'Найкращий захід';

  @override
  String get recordsHour => 'Найкраща година';

  @override
  String get recordsDay => 'Найкращий день';

  @override
  String get recordsWeek => 'Найкращий тиждень';

  @override
  String get recordsMonth => 'Найкращий місяць';

  @override
  String recordsNow(String value) {
    return 'зараз $value';
  }

  @override
  String recordsToBeat(String value) {
    return 'до рекорду $value';
  }

  @override
  String get recordsBeaten => 'рекорд!';

  @override
  String get recordsEmpty => 'Зіграйте рівень — тут з’являться перші рекорди.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Рівень $level · ×$multiplier';
  }

  @override
  String get promptTagCasual => 'розмовне';

  @override
  String get promptTagFormal => 'офіційне';

  @override
  String reminderOrbitTitle(int orbit) {
    return 'Орбіта $orbit під загрозою';
  }

  @override
  String get reminderOrbitBody =>
      'Ще один пропуск — і вона обнулиться. Дві хвилини це скасують.';

  @override
  String reminderDimmingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Тьмяніють $count зорі',
      many: 'Тьмяніють $count зір',
      few: 'Тьмяніють $count зорі',
      one: 'Тьмяніє $count зоря',
    );
    return '$_temp0';
  }

  @override
  String reminderDimmingIn(String constellation) {
    return 'У сузір’ї «$constellation». Дві хвилини їх повернуть.';
  }

  @override
  String get reminderDimmingBody => 'Схід займає дві хвилини.';

  @override
  String get reminderCalmTitle => 'Небо в порядку';

  @override
  String get reminderCalmBody => 'Повторювати нічого — можна взяти щось нове.';

  @override
  String get reminderChannel => 'Щоденне нагадування';

  @override
  String get reminderChannelBody =>
      'Одне сповіщення на день про зорі, що тьмяніють';
}
