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
  String get calibrationHintPhrases => 'Тепер цілі фрази';

  @override
  String get calibrationHintDone => 'Готово';

  @override
  String get calibrationResultTitle => 'Ваше небо починається тут';

  @override
  String calibrationResultVocabulary(int count) {
    return 'Ви вже знаєте приблизно $count слів — вони стануть зорями, що вже світять.';
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
  String get ritualNewWords => 'нових слів';

  @override
  String get ritualLumens => 'люменів';

  @override
  String get ritualDoneTitle => 'Ритуал пройдено';

  @override
  String ritualDoneBody(int lumens, int words) {
    return 'Небу повернулося $lumens lm, вивчено $words нових слів.';
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
  String get skyBurning => 'світять';

  @override
  String get skyConstellations => 'сузір’їв';

  @override
  String get skyEmptyTitle => 'Небо порожнє';

  @override
  String get skyEmptyBody =>
      'У контентній базі немає сузір’їв для цього ярусу.';

  @override
  String get skyDictionary => 'Словник';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit із $total зір світять';
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
    return 'Більша частина неба світить. Перейти на $tier? Старі зорі залишаться на місцях.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return 'Схоже, $current дається важко. Спробувати $target?';
  }

  @override
  String get dictionaryTitle => 'Словник';

  @override
  String get dictionarySearchHint => 'Слово будь-якою з двох мов';

  @override
  String get dictionaryNothing => 'Нічого не знайшлося';

  @override
  String get dictionaryResetFilters => 'Скинути фільтри';

  @override
  String get dictionaryBurningFilter => 'світять';

  @override
  String get bandBurning => 'світить';

  @override
  String get bandSteady => 'рівне світло';

  @override
  String get bandFlickering => 'мерехтить';

  @override
  String get bandDimming => 'тьмяніє';

  @override
  String get bandFading => 'гасне';

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
  String get profileBurning => 'світять';

  @override
  String get profileWordsInWork => 'слів у роботі';

  @override
  String get profileLatency => 'відгук';

  @override
  String get profileSparks => 'іскор';

  @override
  String get profileBrightness => 'Яскравість за сузір’ями';

  @override
  String get profileEmpty => 'Поки порожньо — зіграйте перший рівень.';

  @override
  String profileBurningOf(int burning, int total) {
    return '$burning із $total світять';
  }

  @override
  String get customWordsTitle => 'Свої слова';

  @override
  String get customWordsHint =>
      'Список із вашого підручника, листа або нотаток. По рядку на пару: «Wort — слово».';

  @override
  String get customWordsAdd => 'Додати';

  @override
  String customWordsAdded(int count) {
    return 'Додано: $count';
  }

  @override
  String get customWordsNoPairs =>
      'Не знайшлося жодної пари. Формат: «Wort — слово», по рядку на пару.';

  @override
  String customWordsCount(int count) {
    return 'В особистому сузір’ї: $count';
  }

  @override
  String get settingsTier => 'Ярус';

  @override
  String get settingsTierExplain =>
      'Розмір сузір’їв росте разом із ярусом. Старі зорі залишаються на місцях.';

  @override
  String settingsTierLocked(String tier) {
    return 'Яруси вище $tier ще не вичитані носієм і тому недоступні.';
  }

  @override
  String get settingsSound => 'Звук';

  @override
  String get settingsSoundSubtitle =>
      'Без звуку правильна відповідь позначається вібрацією';

  @override
  String get settingsPace => 'Свій темп';

  @override
  String get settingsPaceOn => 'Нові слова не обмежені одним рівнем на день';

  @override
  String get settingsPaceOff =>
      'Один рівень на день — дидактичне обмеження, а не платна стіна';

  @override
  String get settingsPaceDialogTitle => 'Свій темп';

  @override
  String get settingsPaceDialogBody =>
      'Кожне нове слово повертається на повторення — і завтра, і за тиждень. Якщо брати багато нового одразу, черга повторень зростатиме швидше, ніж ви встигаєте її розбирати.\n\nЧастка нових слів у сесії однаково залишиться обмеженою.';

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
      'Прогрес, історія відповідей і свої слова будуть стерті без можливості відновити. Доведеться почати спочатку, включно з калібруванням.';

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
      'Словник як нічне небо. Яскравість зорі — імовірність згадати слово просто зараз.';

  @override
  String get aboutFreeTitle => 'Безкоштовно повністю';

  @override
  String get aboutFreeBody =>
      'Ні підписки, ні платних ярусів, ні реклами, ні валюти за гроші. Усе, що є в грі, доступне всім і завжди.';

  @override
  String get aboutCostBody =>
      'Тримається це на тому, що один користувач коштує проєкту близько нуля: контент і озвучка лежать у самому застосунку, сервера немає, а єдиний мережевий запит — нічний виклик, один статичний файл на день.';

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
  String get aboutPrivacy =>
      'Приватність: Sentry без персональних даних і без трейсингу, жодної аналітики мережею. Експорт і видалення даних — у налаштуваннях.';

  @override
  String unitSeconds(String value) {
    return '$value с';
  }

  @override
  String get customWordsPlaceholder =>
      'Rechnung — рахунок\nQuittung — квитанція';

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
  String get recordsTitle => 'Твої рекорди';

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
  String get recordsEmpty => 'Зіграй рівень — тут з’являться перші рекорди.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Рівень $level · ×$multiplier';
  }
}
