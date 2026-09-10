// `widgets.dart` — не за виджетами: отсюда нужны `Locale` для загрузки строк
// и `@visibleForTesting`, а `foundation.dart` рядом с ним лишний, потому что
// он весь в него реэкспортирован. Дерева виджетов планировщику по-прежнему
// не нужно — см. [ReminderScheduler._localizations].
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/interface_lang.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/content/constellation_naming.dart';
import '../../../data/content/content_provider.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/entities/tier.dart';
import '../../../domain/retention/orbit.dart';
import '../../../domain/scoring/balance.dart';
import '../../../domain/srs/memory_state.dart';

/// Ставит ежедневное напоминание с конкретным текстом.
///
/// «Не забудь позаниматься» игрок отключает после третьего раза. «7 звёзд в
/// созвездии Врач тускнеют» — читает, потому что это про него и про его
/// небо. Чтобы так написать, нужно посмотреть в базу, а не в шаблон.
///
/// «Врач» в этом обещании — имя темы из контентной базы, и до сих пор оно
/// было обещанием: в текст уезжал slug созвездия, то есть игрок получал на
/// телефон «В созвездии «place_time_price»». Откуда берётся имя и почему
/// именно оттуда — у [composeText].
class ReminderScheduler {
  const ReminderScheduler(this._ref);

  final Ref _ref;

  Future<void> reschedule() async {
    final player = _ref.read(playerControllerProvider);
    if (player == null || !player.notificationsEnabled) {
      await _ref.read(notificationServiceProvider).cancelAll();
      return;
    }

    try {
      final l10n = await _localizations();
      final text = await composeText(player.tier);
      await _ref.read(notificationServiceProvider).scheduleDaily(
            title: text.title,
            body: text.body,
            // Подписи канала — на том же языке, что и текст: их видно в
            // системных настройках Android, рядом с тумблером «показывать
            // ли это приложение». Русский литерал стоял и там.
            channelName: l10n.reminderChannel,
            channelDescription: l10n.reminderChannelBody,
            // Час игры, а не «удобный нам»: если человек играет вечером,
            // утреннее напоминание для него — просто шум. Час доезжает до
            // будильника: сервис ставит напоминание на ближайшее его
            // наступление, а не через сутки от этой минуты, — до чего этот
            // аргумент принимался и выбрасывался. Чем исполненное обещание
            // оплачено, записано у `scheduleDaily`.
            hour: player.preferredHour ?? await _guessHour() ?? 20,
          );
    } catch (_) {
      // Напоминание — сервис, а не механика: его отказ игру не трогает.
    }
  }

  /// Сколько звёзд тускнеет и в каком созвездии их больше всего.
  ///
  /// Текст собирается **на языке интерфейса целиком**, а не только имя темы:
  /// строки берутся из `AppLocalizations` (см. [_localizations]), число звёзд
  /// уезжает в ICU-плюрал. Прежде здесь получалась половина перевода —
  /// правильно названное созвездие в русской фразе; чем это было плохо,
  /// записано у `ReminderText`.
  ///
  /// Метод открыт ради теста, и это не удобство: у планировщика больше нет
  /// наблюдаемого результата. [NotificationService] — синглтон с приватным
  /// конструктором, подменить его в контейнере нечем, а в тестовой среде
  /// плагин не инициализируется и `scheduleDaily` молча ничего не делает. То
  /// есть проверить «в текст уехало имя, а не slug» можно только спросив
  /// текст, не ставя уведомление.
  @visibleForTesting
  Future<({String title, String body})> composeText(Tier tier) async {
    final db = _ref.read(appDatabaseProvider);
    final content = _ref.read(currentContentDatabaseProvider);
    final player = _ref.read(playerControllerProvider);
    final now = DateTime.now();

    final dimming = <String, int>{};
    var total = 0;

    final constellationByItem = {
      for (final p in await content.phrasesUpTo(tier)) p.id: p.constellation,
    };

    for (final row in await db.loadWordStates()) {
      final lm = MemoryState(
        difficulty: row.difficulty,
        stability: row.stability,
        lastReview: row.lastReview,
        reps: row.reps,
        lapses: row.lapses,
      ).lumensAt(now);

      // «Тускнеет» — это полосы ниже уверенного знания, а не всё подряд:
      // напоминание должно называть настоящее число, иначе оно врёт.
      if (lm >= LumenBand.flickering.minLm) continue;
      total++;

      final constellation = constellationByItem[row.itemId];
      if (constellation != null) {
        dimming.update(constellation, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final worst = dimming.isEmpty
        ? null
        : dimming.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final orbit = Orbit.refresh(
      OrbitState(
        level: player?.orbit ?? 0,
        missedInRow: player?.missedInRow ?? 0,
        lastPlayedAt: player?.lastPlayedAt,
        eclipseUntil: player?.eclipseUntil,
      ),
      now,
    );

    return ReminderText.build(
      l10n: await _localizations(),
      dimmingStars: total,
      constellation: worst == null ? null : await _nameOf(worst),
      orbit: orbit.level,
      missesBeforeReset: Orbit.missesBeforeReset(orbit),
    );
  }

  /// Строки интерфейса для фонового кода — по языку [interfaceLangProvider].
  ///
  /// `AppLocalizations.delegate.load` принимает локаль аргументом и дерева
  /// виджетов не требует: `BuildContext` нужен только `AppLocalizations.of`,
  /// который ищет ближайший `Localizations`. Поэтому напоминание может
  /// говорить на языке интерфейса, хотя ставится оно из провайдера, а не с
  /// экрана, — и ровно за этим язык интерфейса живёт провайдером, а не
  /// читается из `Localizations.localeOf`.
  ///
  /// Локаль берётся тем же одним источником, что и имя созвездия ниже. Иначе
  /// обёртка и имя разошлись бы по языкам — то, чем прежние русские литералы
  /// и были заметны: украинское имя в русской фразе.
  ///
  /// Загрузка дешёвая: `lookupAppLocalizations` — это `switch` по коду языка,
  /// возвращающий готовый объект со строками; `SynchronousFuture` завершается
  /// в той же микрозадаче. Кешировать её нечего.
  Future<AppLocalizations> _localizations() =>
      AppLocalizations.delegate.load(Locale(_ref.read(interfaceLangProvider)));

  /// Имя темы для текста напоминания — по тому же правилу, что подпись на небе.
  ///
  /// Slug — идентичность темы, а не подпись, и уведомление — худшее место,
  /// где ему показываться: это не экран, который игрок открыл сам, а
  /// сообщение, которое пришло к нему само. Правило показа не пишется здесь
  /// заново и не берётся выражением `names[lang]`: [ConstellationNaming]
  /// хранит откат целиком, а собранное именование для нынешнего игрока даёт
  /// [constellationNamingProvider] — тот же, которым подписано небо. Второго
  /// ответа на «на каком языке эта подпись» в проекте быть не должно, и
  /// напоминание — не повод его завести.
  ///
  /// **Откат здесь начинается с первого звена, языка интерфейса**, хотя
  /// дерева виджетов у планировщика нет: язык интерфейса решает
  /// [interfaceLangProvider] — по настройке игрока и локалям системы через
  /// биндинг, — и `BuildContext` ему не нужен. Ровно за этим он и живёт
  /// провайдером, а не читается из `Localizations.localeOf`: иначе фоновому
  /// коду пришлось бы начинать откат со второго звена, языка подсказок, и
  /// напоминание называло бы тему не так, как её же подписывает небо.
  ///
  /// Отказ базы имён напоминание не отменяет: провайдер отдаёт в этом случае
  /// [ConstellationNaming.slugsOnly], то есть худшее, что здесь может
  /// случиться, — прежний slug в тексте, а не пропавшее уведомление. Причина
  /// записана у самого провайдера.
  ///
  /// Спрашивается имя только когда есть что называть: без созвездия текст
  /// его всё равно не упомянет.
  ///
  /// Одно про язык, чего этот метод не решает: текст ставится один раз и
  /// повторяется каждый день, поэтому имя в нём — на языке, который был у
  /// игрока в момент постановки. Смену языка интерфейса напоминание догонит
  /// следующей постановкой — после сессии или переключения тумблера в
  /// настройках; отдельного пересчёта на смену языка нет, как нет его и на
  /// изменившееся за день число звёзд.
  Future<String> _nameOf(String constellation) async {
    final naming = await _ref.read(constellationNamingProvider.future);
    return naming.nameOf(constellation);
  }

  /// Час, в который игрок обычно играет — по журналу сессий.
  Future<int?> _guessHour() async {
    try {
      final sessions =
          await _ref.read(appDatabaseProvider).loadSessions(limit: 30);
      if (sessions.isEmpty) return null;

      final byHour = <int, int>{};
      for (final session in sessions) {
        final hour = session.startedAt.toLocal().hour;
        byHour.update(hour, (n) => n + 1, ifAbsent: () => 1);
      }
      return byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    } catch (_) {
      return null;
    }
  }
}

final reminderSchedulerProvider =
    Provider<ReminderScheduler>(ReminderScheduler.new);
