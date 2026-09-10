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
  String get commonUndo => 'Отменить';

  @override
  String get commonDone => 'Готово';

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
  String get calibrationHintDone => 'Готово';

  @override
  String get calibrationResultTitle => 'Ваше небо начинается здесь';

  @override
  String calibrationResultVocabulary(int count) {
    return 'На этом ярусе и ниже лежит примерно $count фраз курса.';
  }

  @override
  String get calibrationResultCircles => 'Кругов в тесте';

  @override
  String get calibrationResultRecognised => 'Фраз вы узнали';

  @override
  String get calibrationResultMeasured => 'Тест показал';

  @override
  String calibrationResultCapped(String tier) {
    return 'Открыт пока только $tier — небо начинается с него. Это не потолок игры: ярус поднимется вместе с контентом.';
  }

  @override
  String calibrationResultSeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фразы из теста уже горят на вашем небе.',
      many: '$count фраз из теста уже горят на вашем небе.',
      few: '$count фразы из теста уже горят на вашем небе.',
      one: '$count фраза из теста уже горит на вашем небе.',
    );
    return '$_temp0';
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
  String get ritualQuitTitle => 'Прервать ритуал?';

  @override
  String get ritualQuitBody =>
      'Ответы уже записаны: яркость фраз и очередь повторений сохранятся. Незаконченный уровень не зачтётся: очки пропадут, записи сессии не будет, орбита и искры не сдвинутся.';

  @override
  String get ritualQuitConfirm => 'Прервать';

  @override
  String get ritualQuitResume => 'Вернуться к игре';

  @override
  String get sunriseReturned => 'вернулось небу';

  @override
  String get sunriseNothing => 'небо и так горело — повторять было нечего';

  @override
  String get sunriseNext => 'К новому уровню';

  @override
  String get ritualScore => 'очков за ритуал';

  @override
  String get ritualNewWords => 'новых фраз';

  @override
  String get ritualLumens => 'люменов';

  @override
  String get ritualDoneTitle => 'Ритуал пройден';

  @override
  String ritualDoneBody(int lumens, int phrases) {
    String _temp0 = intl.Intl.pluralLogic(
      phrases,
      locale: localeName,
      other: 'Небу вернулось $lumens lm, выучено $phrases новых фраз.',
      many: 'Небу вернулось $lumens lm, выучено $phrases новых фраз.',
      few: 'Небу вернулось $lumens lm, выучено $phrases новые фразы.',
      one: 'Небу вернулось $lumens lm, выучена $phrases новая фраза.',
    );
    return '$_temp0';
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
  String get skyShining => 'светят';

  @override
  String get skyConstellations => 'созвездий';

  @override
  String get skyEmptyTitle => 'Небо пустое';

  @override
  String get skyEmptyBody => 'В контентной базе нет созвездий для этого яруса.';

  @override
  String constellationLitOf(int lit, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      lit,
      locale: localeName,
      other: '$lit из $total звёзд яркие',
      many: '$lit из $total звёзд яркие',
      few: '$lit из $total звёзд яркие',
      one: '$lit из $total звёзд яркая',
    );
    return '$_temp0';
  }

  @override
  String get constellationLocked => 'Ещё не открыто';

  @override
  String constellationToLight(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'До зажжения — ещё $count звёзд',
      many: 'До зажжения — ещё $count звёзд',
      few: 'До зажжения — ещё $count звезды',
      one: 'До зажжения — ещё $count звезда',
    );
    return '$_temp0';
  }

  @override
  String get constellationAboutToLight => 'Созвездие вот-вот зажжётся';

  @override
  String tierSuggestUp(String tier) {
    return 'Большая часть открытых созвездий зажжена. Перейти на $tier? Старые звёзды останутся на местах.';
  }

  @override
  String tierSuggestDown(String current, String target) {
    return 'Похоже, $current даётся тяжело. Попробовать $target?';
  }

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
  String get profileAutomatic => 'на автомате';

  @override
  String get profileWordsInWork => 'фраз в работе';

  @override
  String get profileLatency => 'отклик';

  @override
  String get profileSparks => 'искр';

  @override
  String get profileBrightness => 'Яркость по созвездиям';

  @override
  String get profileEmpty => 'Пока пусто — сыграйте первый уровень.';

  @override
  String profileBrightOf(int bright, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      bright,
      locale: localeName,
      other: '$bright из $total яркие',
      many: '$bright из $total яркие',
      few: '$bright из $total яркие',
      one: '$bright из $total яркая',
    );
    return '$_temp0';
  }

  @override
  String get settingsTier => 'Ярус';

  @override
  String get settingsTierExplain =>
      'Выше ярус — больше созвездий, а не звёзд в каждом: размер созвездия на всех ярусах один. Старые звёзды остаются на местах.';

  @override
  String settingsTierLocked(String tier) {
    return 'Ярусы выше $tier пока черновые и недоступны.';
  }

  @override
  String get settingsSound => 'Звук';

  @override
  String get settingsSoundSubtitle =>
      'Без звука верный ответ отмечается вибрацией';

  @override
  String get settingsPace => 'Свой темп';

  @override
  String get settingsPaceOn =>
      'Новых фраз за уровень больше — ограничена только их доля в сессии';

  @override
  String get settingsPaceOff =>
      'Новых фраз за уровень всегда одинаково — дидактическое ограничение, а не платная стена';

  @override
  String get settingsPaceDialogTitle => 'Свой темп';

  @override
  String get settingsPaceDialogBody =>
      'Каждая новая фраза возвращается на повторение — и завтра, и через неделю. Если брать много нового сразу, очередь повторений вырастет быстрее, чем вы успеваете её разгребать.\n\nДоля новых фраз в сессии всё равно останется ограниченной.';

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
      'Прогресс и история ответов будут стёрты без возможности восстановить. Придётся начать заново, включая калибровку.';

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
      'Разговорник как ночное небо. Яркость звезды — вероятность вспомнить фразу прямо сейчас.';

  @override
  String get aboutFreeTitle => 'Бесплатно целиком';

  @override
  String get aboutFreeBody =>
      'Ни подписки, ни платных ярусов, ни рекламы, ни валюты за деньги. Всё, что есть в игре, доступно всем и всегда.';

  @override
  String get aboutCostBody =>
      'Держится это на том, что один пользователь стоит проекту около нуля: контент лежит в самом приложении, речь синтезирует устройство, а сервера и сетевых запросов нет вовсе.';

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
  String get aboutReviewTitle => 'Кто написал эти фразы';

  @override
  String get aboutReviewBody =>
      'Немецкие фразы и переводы к ним написала языковая модель. После неё их не вычитывал никто — ни вторая модель, ни носитель языка. Это значит не то, что ошибок нет, а то, что их пока никто не искал.';

  @override
  String get aboutReviewLimit =>
      'Поэтому скажите, если что-то заметили: контент лежит в открытом репозитории, правка это один файл, и она приходит всем со следующим обновлением. Ошибка, о которой не сказали, остаётся в игре, и её продолжают заучивать.';

  @override
  String get profileDays => 'дней играл';

  @override
  String get profileStreak => 'дней подряд';

  @override
  String get profileTimeTotal => 'времени в приложении';

  @override
  String get profileTimePerDay => 'в день, когда играл';

  @override
  String get profileScaleTitle => 'От A0 до B2';

  @override
  String profileScaleHint(String tier, int percent) {
    return 'Вы на $tier: $percent% его фраз держатся в памяти.';
  }

  @override
  String profileScaleLocked(String tier) {
    return 'Ярусы выше $tier пока черновые, и игра их не предлагает.';
  }

  @override
  String unitMinutes(int value) {
    return '$value мин';
  }

  @override
  String unitHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String get stageIntroduction => 'Знакомство';

  @override
  String get stageConsolidation => 'Закрепление';

  @override
  String get stageCheck => 'Проверка';

  @override
  String get stageReminder => 'Напоминание';

  @override
  String get stageSprint => 'Спринт';

  @override
  String sprintGoal(int done, int target, int seconds) {
    return '$done из $target за $seconds с';
  }

  @override
  String get sprintReached => 'Планка взята';

  @override
  String sprintMissed(int done, int target) {
    return 'Планка не взята: $done из $target';
  }

  @override
  String sprintAttempt(int attempt, int total) {
    return 'Попытка $attempt из $total';
  }

  @override
  String get aboutPrivacy =>
      'Приватность: Sentry без персональных данных и без трейсинга, никакой аналитики по сети. Экспорт и удаление данных — в настройках.';

  @override
  String unitSeconds(String value) {
    return '$value с';
  }

  @override
  String voiceMissingTitle(String language) {
    return 'Голос для $language не установлен';
  }

  @override
  String voiceMissingBody(String language) {
    return 'Lumen говорит голосом самого устройства, и для этого нужны голосовые данные $language. Без них верный ответ отмечается короткой вибрацией.';
  }

  @override
  String get voiceUnavailableTitle => 'На этом устройстве нет синтеза речи';

  @override
  String get voiceInstall => 'Установить голос';

  @override
  String get voicePlaySilent => 'Играть без звука';

  @override
  String voiceManualPath(String path) {
    return 'Где искать: $path';
  }

  @override
  String voiceReady(String language) {
    return 'Говорит системным голосом: $language';
  }

  @override
  String get recordsTitle => 'Ваши рекорды';

  @override
  String get recordsClimb => 'Лучший заход';

  @override
  String get recordsHour => 'Лучший час';

  @override
  String get recordsDay => 'Лучший день';

  @override
  String get recordsWeek => 'Лучшая неделя';

  @override
  String get recordsMonth => 'Лучший месяц';

  @override
  String recordsNow(String value) {
    return 'сейчас $value';
  }

  @override
  String recordsToBeat(String value) {
    return 'до рекорда $value';
  }

  @override
  String get recordsBeaten => 'рекорд!';

  @override
  String get recordsEmpty =>
      'Сыграйте уровень — здесь появятся первые рекорды.';

  @override
  String recordsClimbLevel(int level, String multiplier) {
    return 'Уровень $level · ×$multiplier';
  }

  @override
  String get promptTagCasual => 'разговорное';

  @override
  String get promptTagFormal => 'официальное';

  @override
  String reminderOrbitTitle(int orbit) {
    return 'Орбита $orbit под угрозой';
  }

  @override
  String get reminderOrbitBody =>
      'Ещё один пропуск — и она обнулится. Две минуты это отменят.';

  @override
  String reminderDimmingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Тускнеют $count звезды',
      many: 'Тускнеют $count звёзд',
      few: 'Тускнеют $count звезды',
      one: 'Тускнеет $count звезда',
    );
    return '$_temp0';
  }

  @override
  String reminderDimmingIn(String constellation) {
    return 'В созвездии «$constellation». Две минуты вернут их.';
  }

  @override
  String get reminderDimmingBody => 'Восход занимает две минуты.';

  @override
  String get reminderCalmTitle => 'Небо в порядке';

  @override
  String get reminderCalmBody => 'Повторять нечего — можно взять что-то новое.';

  @override
  String get reminderChannel => 'Ежедневное напоминание';

  @override
  String get reminderChannelBody =>
      'Одно уведомление в день о звёздах, которые тускнеют';
}
