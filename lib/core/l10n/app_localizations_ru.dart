// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Lumen';

  @override
  String get tabSky => 'Небо';

  @override
  String get tabGame => 'Игра';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get tabSettings => 'Настройки';

  @override
  String get skyTitle => 'Ваше небо';

  @override
  String get gameTitle => 'Дневной ритуал';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get commonNext => 'Дальше';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get onboardingTitle => 'Найдём, где начинается ваше небо';

  @override
  String get onboardingSubtitle =>
      'Вместо анкеты — несколько кругов: вы играете, мы измеряем.';

  @override
  String get onboardingStartCalibration => 'Начать калибровку';

  @override
  String get onboardingFromScratch => 'Я с нуля';

  @override
  String get languagesTitle => 'Языки';

  @override
  String get languagesSubtitle =>
      'Язык подсказок и язык интерфейса — разные настройки.';

  @override
  String get languagesLearning => 'Учу';

  @override
  String get languagesHints => 'Подсказки на';

  @override
  String get languagesInterface => 'Интерфейс';

  @override
  String get languagesSystem => 'Как в системе';

  @override
  String get calibrationHintComb => 'Просто соединяйте то, что знаете';

  @override
  String get calibrationHintSearch => 'Подбираем, с чего начать';

  @override
  String get calibrationHintConfirm => 'Проверяем ещё раз';

  @override
  String get calibrationHintPhrases => 'Теперь целые фразы';

  @override
  String get calibrationHintDone => 'Готово';

  @override
  String get calibrationResultTitle => 'Ваше небо начинается здесь';

  @override
  String calibrationResultVocabulary(int count) {
    return 'Вы уже знаете примерно $count слов — они станут звёздами, которые уже горят.';
  }

  @override
  String get calibrationResultTierChangeable =>
      'Ярус можно сменить в настройках в любой момент.';

  @override
  String get calibrationResultOpen => 'Открыть небо';

  @override
  String get ritualHeading => 'Дневной ритуал';

  @override
  String get ritualSubtitle =>
      'Восход — уровень — ночной вызов. Шесть минут с началом и концом.';

  @override
  String get ritualStart => 'Начать';

  @override
  String get ritualLevelOnly => 'Только уровень';

  @override
  String get ritualLevelOnlySubtitle => 'Пропустить Восход и сразу взять новое';

  @override
  String get ritualSunrise => 'Восход';

  @override
  String get ritualLevel => 'Уровень';

  @override
  String get sunriseReturned => 'вернулось небу';

  @override
  String get sunriseNothing => 'небо и так горело — повторять было нечего';

  @override
  String get sunriseNext => 'К новому уровню';

  @override
  String get ritualScore => 'очков за ритуал';

  @override
  String get ritualNewWords => 'новых слов';

  @override
  String get ritualLumens => 'люменов';

  @override
  String get ritualDoneTitle => 'Ритуал пройден';

  @override
  String ritualDoneBody(int lumens, int words) {
    return 'Небу вернулось $lumens lm, выучено $words новых слов.';
  }

  @override
  String get ritualToSky => 'К небу';

  @override
  String get runAccuracy => 'точность';

  @override
  String get runCircles => 'кругов';

  @override
  String get runCombo => 'комбо';

  @override
  String get runPerfect => 'без ошибок';

  @override
  String get runContinue => 'Дальше';

  @override
  String get audioReplay => 'Прослушать ещё раз';

  @override
  String get skyStars => 'звёзд';

  @override
  String get skyBurning => 'горят';

  @override
  String get skyConstellations => 'созвездий';

  @override
  String get skyEmptyTitle => 'Небо пустое';

  @override
  String get skyEmptyBody => 'В контентной базе нет созвездий для этого яруса.';

  @override
  String get skyDictionary => 'Словарь';

  @override
  String constellationLitOf(int lit, int total) {
    return '$lit из $total звёзд горят';
  }

  @override
  String get constellationLocked => 'Ещё не открыто';

  @override
  String constellationToLight(int count) {
    return 'До зажжения — ещё $count звёзд';
  }

  @override
  String get constellationAboutToLight => 'Созвездие вот-вот зажжётся';

  @override
  String tierSuggestUp(String tier) {
    return 'Большая часть неба горит. Перейти на $tier? Старые звёзды останутся на местах.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return 'Похоже, $current даётся тяжело. Попробовать $target?';
  }

  @override
  String get dictionaryTitle => 'Словарь';

  @override
  String get dictionarySearchHint => 'Слово на любом из двух языков';

  @override
  String get dictionaryNothing => 'Ничего не нашлось';

  @override
  String get dictionaryResetFilters => 'Сбросить фильтры';

  @override
  String get dictionaryBurningFilter => 'горят';

  @override
  String get bandBurning => 'горит';

  @override
  String get bandSteady => 'ровный свет';

  @override
  String get bandFlickering => 'мерцает';

  @override
  String get bandDimming => 'тускнеет';

  @override
  String get bandFading => 'гаснет';

  @override
  String get profileOrbit => 'орбита';

  @override
  String get profileOrbitExplain =>
      'Пропуск опускает на один. Полный сброс — только после трёх пропусков подряд.';

  @override
  String get profileOrbitRisk => 'Ещё один пропуск — и орбита обнулится.';

  @override
  String get profileEclipse => 'затмение';

  @override
  String get profileWeek => 'Неделя';

  @override
  String get profileWeeklyGoalMet => 'Цель недели выполнена';

  @override
  String profileWeeklyGoal(int days) {
    return 'Цель недели — $days дней из 7. Два выходных законны.';
  }

  @override
  String get profileBurning => 'горят';

  @override
  String get profileWordsInWork => 'слов в работе';

  @override
  String get profileLatency => 'отклик';

  @override
  String get profileSparks => 'искр';

  @override
  String get profileBrightness => 'Яркость по созвездиям';

  @override
  String get profileEmpty => 'Пока пусто — сыграйте первый уровень.';

  @override
  String profileBurningOf(int burning, int total) {
    return '$burning из $total горят';
  }

  @override
  String get customWordsTitle => 'Свои слова';

  @override
  String get customWordsHint =>
      'Список из вашего учебника, письма или заметок. По строке на пару: «Wort — слово».';

  @override
  String get customWordsAdd => 'Добавить';

  @override
  String customWordsAdded(int count) {
    return 'Добавлено: $count';
  }

  @override
  String get customWordsNoPairs =>
      'Не нашлось ни одной пары. Формат: «Wort — слово», по строке на пару.';

  @override
  String customWordsCount(int count) {
    return 'В личном созвездии: $count';
  }

  @override
  String get settingsTier => 'Ярус';

  @override
  String get settingsTierExplain =>
      'Размер созвездий растёт вместе с ярусом. Старые звёзды остаются на местах.';

  @override
  String settingsTierLocked(String tier) {
    return 'Ярусы выше $tier ещё не вычитаны носителем и поэтому недоступны.';
  }

  @override
  String get settingsSound => 'Звук';

  @override
  String get settingsSoundSubtitle =>
      'Без звука верный ответ отмечается вибрацией';

  @override
  String get settingsPace => 'Свой темп';

  @override
  String get settingsPaceOn => 'Новые слова не ограничены одним уровнем в день';

  @override
  String get settingsPaceOff =>
      'Один уровень в день — дидактическое ограничение, а не платная стена';

  @override
  String get settingsPaceDialogTitle => 'Свой темп';

  @override
  String get settingsPaceDialogBody =>
      'Каждое новое слово возвращается на повторение — и завтра, и через неделю. Если брать много нового сразу, очередь повторений вырастет быстрее, чем вы успеваете её разгребать.\n\nДоля новых слов в сессии всё равно останется ограниченной.';

  @override
  String get settingsPaceKeep => 'Оставить как есть';

  @override
  String get settingsPaceEnable => 'Включить';

  @override
  String get settingsNotifications => 'Напоминание';

  @override
  String get settingsNotificationsSubtitle =>
      'Одно в день, в тот час, когда вы обычно играете';

  @override
  String get settingsNotificationsDenied =>
      'Система не дала разрешения на уведомления';

  @override
  String get settingsRecalibrate => 'Перекалибровка';

  @override
  String get settingsRecalibrateSubtitle =>
      'Пройти тест заново — доступно в любой момент';

  @override
  String get settingsWipe => 'Удалить все данные';

  @override
  String get settingsWipeSubtitle => 'Без возможности восстановить';

  @override
  String get settingsWipeDialogTitle => 'Удалить все данные?';

  @override
  String get settingsWipeDialogBody =>
      'Прогресс, история ответов и свои слова будут стёрты без возможности восстановить. Придётся начать заново, включая калибровку.';

  @override
  String get settingsWipeConfirm => 'Удалить';

  @override
  String get settingsAbout => 'О проекте';

  @override
  String get settingsAboutSubtitle => 'Бесплатно целиком · донаты · лицензии';

  @override
  String get aboutTitle => 'О проекте';

  @override
  String get aboutTagline =>
      'Словарь как ночное небо. Яркость звезды — вероятность вспомнить слово прямо сейчас.';

  @override
  String get aboutFreeTitle => 'Бесплатно целиком';

  @override
  String get aboutFreeBody =>
      'Ни подписки, ни платных ярусов, ни рекламы, ни валюты за деньги. Всё, что есть в игре, доступно всем и всегда.';

  @override
  String get aboutCostBody =>
      'Держится это на том, что один пользователь стоит проекту около нуля: контент и озвучка лежат в самом приложении, сервера нет, а единственный сетевой запрос — ночной вызов, один статический файл в день.';

  @override
  String get aboutDonate => 'Поддержать проект';

  @override
  String get aboutDonateNote =>
      'Донор получает метку и имя в титрах — и ничего, что даёт преимущество в игре или в обучении.';

  @override
  String get aboutExpenses => 'Куда уходят деньги';

  @override
  String get aboutExpensesSubtitle => 'Публичная страница расходов';

  @override
  String get aboutSource => 'Исходный код';

  @override
  String get aboutSourceSubtitle => 'Код — MIT, контент — CC BY-SA 4.0';

  @override
  String get aboutNotHereTitle => 'Чего в игре нет намеренно';

  @override
  String get aboutNoLives =>
      'Жизней, сердец и энергии — ошибка стоит очков, а не доступа';

  @override
  String get aboutNoStreakReset =>
      'Обнуления серии: один пропуск не стирает полгода';

  @override
  String get aboutNoTimer => 'Таймера на новом материале';

  @override
  String get aboutNoXp => 'Рейтинга по XP';

  @override
  String get aboutNoBots => 'Ботов под видом живых соперников';

  @override
  String get aboutNoForcedOrder => 'Обязательного порядка прохождения';

  @override
  String get aboutNoAds => 'Рекламы и трекеров';

  @override
  String get aboutPrivacy =>
      'Приватность: Sentry без персональных данных и без трейсинга, никакой аналитики по сети. Экспорт и удаление данных — в настройках.';

  @override
  String unitSeconds(String value) {
    return '$value с';
  }

  @override
  String get customWordsPlaceholder => 'Rechnung — счёт\nQuittung — квитанция';
}
