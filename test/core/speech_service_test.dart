import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lumen/core/audio/speech_locale.dart';
import 'package:lumen/core/audio/speech_service.dart';
// Корень приложения — там живёт глобальная тишина: голос один на все экраны,
// которые говорят, и молчать он должен целиком.
import 'package:lumen/main.dart';

/// Проверка наличия голоса — самое рискованное место перехода на синтез
/// устройства.
///
/// Записанные файлы либо лежали в установке, либо нет, и это было видно
/// валидатором на сборке. Голос принадлежит устройству: его может не быть,
/// он может быть только сетевым, а платформы отвечают по-разному — на
/// Android есть строгая проверка «установлен и работает офлайн», на iOS
/// только «такой язык вообще бывает».
///
/// Ошибиться здесь дорого в обе стороны. Сказать «голоса нет», когда он
/// есть, — отобрать у игрока звук. Сказать «есть», когда нет, — оставить
/// его с тишиной и без объяснения, то есть ровно с тем впечатлением, что
/// приложение сломано.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;

  /// Подменяет канал плагина: тест решает, что отвечает платформа.
  void mockPlatform(Map<String, Object?> answers) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (!answers.containsKey(call.method)) {
        // Метода нет на этой платформе — плагин получит MissingPluginException.
        throw MissingPluginException('нет ${call.method}');
      }
      final answer = answers[call.method];
      if (answer is Exception) throw answer;
      return answer;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  DeviceSpeechService serviceFor(Map<String, Object?> answers) {
    mockPlatform(answers);
    return DeviceSpeechService(lang: 'de', engine: FlutterTts.new);
  }

  group('локаль', () {
    test('язык проекта разворачивается в тег с регионом', () {
      // Без региона Android выбирает вариант сам, и «de» может оказаться
      // швейцарским; для образца произношения это не мелочь.
      expect(speechLocaleFor('de'), 'de-DE');
      expect(speechLocaleFor('en'), 'en-US');
    });

    test('неизвестный язык отдаётся как есть', () {
      // Молчать хуже, чем дать движку решить самому.
      expect(speechLocaleFor('sv'), 'sv');
    });
  });

  group('наличие голоса', () {
    test('установленный язык — можно говорить', () async {
      final service = serviceFor({'isLanguageInstalled': true});
      expect(await service.status(), SpeechStatus.ready);
      expect(calls.single.arguments, 'de-DE');
    });

    test('язык не установлен, но синтез есть — предлагаем установить',
        () async {
      final service = serviceFor({
        'isLanguageInstalled': false,
        'getLanguages': ['en-US', 'fr-FR'],
      });
      expect(await service.status(), SpeechStatus.languageMissing);
    });

    test('движок не знает ни одного языка — ставить нечего', () async {
      // Различие принципиальное: тут игроку нечего предложить, кроме
      // беззвучной игры, и кнопка «установить голос» была бы обманом.
      final service = serviceFor({
        'isLanguageInstalled': false,
        'getLanguages': <String>[],
      });
      expect(await service.status(), SpeechStatus.unavailable);
    });

    test('на платформе без строгой проверки спрашиваем то, что есть',
        () async {
      // iOS: `isLanguageInstalled` не реализован, остаётся список
      // системных голосов.
      final service = serviceFor({'isLanguageAvailable': true});
      expect(await service.status(), SpeechStatus.ready);
      expect(calls.map((c) => c.method),
          ['isLanguageInstalled', 'isLanguageAvailable']);
    });

    test('обе проверки недоступны — синтеза нет', () async {
      final service = serviceFor(const {});
      expect(await service.status(), SpeechStatus.unavailable);
    });

    test('состояние спрашивается у платформы один раз', () async {
      // Проверка живёт в горячем пути забега: каждый круг дёргать канал
      // нельзя.
      final service = serviceFor({'isLanguageInstalled': true});
      await service.status();
      await service.status();
      await service.status();
      expect(calls.length, 1);
    });

    test('refresh переспрашивает — игрок вернулся с установки', () async {
      final service = serviceFor({'isLanguageInstalled': false,
        'getLanguages': ['de-DE']});
      expect(await service.status(), SpeechStatus.languageMissing);

      // Игрок ушёл, поставил голос, вернулся. Без переспроса он остался бы
      // с закэшированным «языка нет» до перезапуска приложения.
      mockPlatform({'isLanguageInstalled': true});
      expect(await service.status(refresh: true), SpeechStatus.ready);
    });
  });

  group('произнесение', () {
    test('без голоса вместо звука вибрация, а не исключение', () async {
      final service = serviceFor(const {});
      // Инвариант: speak не бросает и не ждёт. Ошибка звука не имеет права
      // остановить забег.
      expect(() => service.speak('Arzt'), returnsNormally);
      await service.status();
    });

    test('выключенный звук не доходит до платформы', () async {
      final service = serviceFor({'isLanguageInstalled': true});
      service.enabled = false;
      service.speak('Arzt');
      expect(calls, isEmpty);
    });

    test('начатое слово договаривается, а не обрывается следующим', () async {
      // Слышно это было так: игрок верно соединяет слово, оно начинает
      // звучать и обрывается на середине, потому что следующий круг оказался
      // кругом на слух и его центр заиграл поверх. На Android новое
      // произнесение по умолчанию идёт с `QUEUE_FLUSH`, то есть рубит
      // текущее.
      //
      // Платформа здесь отвечает не сразу — так же, как отвечает настоящий
      // движок при `awaitSpeakCompletion(true)`: вызов возвращается по
      // окончании произнесения.
      final spoken = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') {
          spoken.add(call.arguments as String);
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return true;
        }
        if (call.method == 'isLanguageInstalled') return true;
        return true;
      });

      final service = DeviceSpeechService(lang: 'de', engine: FlutterTts.new);
      service.speak('Zeit');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.speak('Uhr');

      // Второе слово ещё не начиналось: первое договаривается.
      expect(spoken, ['Zeit']);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(spoken, ['Zeit', 'Uhr']);
    });

    test('ждёт своей очереди только последний запрос', () async {
      // Очередь любой длины означала бы, что звук отстаёт от экрана на весь
      // хвост: игрок ушёл на три круга вперёд, а телефон дочитывает прошлые.
      final spoken = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') {
          spoken.add(call.arguments as String);
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return true;
        }
        if (call.method == 'isLanguageInstalled') return true;
        return true;
      });

      final service = DeviceSpeechService(lang: 'de', engine: FlutterTts.new);
      service.speak('Zeit');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.speak('Uhr');
      service.speak('Arzt');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(spoken, ['Zeit', 'Arzt'], reason: 'вытесненное слово прозвучало');
    });

    test('сигнал окончания приходит после произнесения, а не до', () async {
      // Нужен он ровно одному месту — кругу на слух: пока фраза звучит,
      // отвечать физически не на что, и окно на ответ открывается по этому
      // сигналу. Без него часы шли сквозь озвучку, и от пяти секунд игроку
      // оставалось две.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return true;
        }
        return true;
      });

      final service = DeviceSpeechService(lang: 'de', engine: FlutterTts.new);
      var done = false;
      unawaited(service.speakAndWait('Die Rechnung, bitte')
          .then((_) => done = true));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse, reason: 'сигнал пришёл, пока фраза ещё звучала');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(done, isTrue, reason: 'сигнал окончания не пришёл вовсе');
    });

    test('ждущий сигнала дожидается и того, что стояло перед ним', () async {
      // Очередь длиной в один здесь та же: пока говорится прошлая фраза, новый
      // запрос не обрывает её, а ждёт. Значит «дозвучало» для вытесняющего
      // запроса — это конец всей цепочки, иначе окно открылось бы посреди
      // произнесения центра.
      final spoken = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') {
          spoken.add(call.arguments as String);
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return true;
        }
        return true;
      });

      final service = DeviceSpeechService(lang: 'de', engine: FlutterTts.new);
      service.speak('Satz eins');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var done = false;
      unawaited(service.speakAndWait('Satz zwei').then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(spoken, ['Satz eins', 'Satz zwei']);
      expect(done, isFalse, reason: 'сигнал пришёл до второй фразы');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(done, isTrue);
    });

    test('без голоса сигнал приходит сразу, а не никогда', () async {
      // Круг со слухом без синтеза непроходим, но повиснуть он не должен:
      // ждать сигнала, которого не будет, значило бы никогда не открыть окно.
      final service = serviceFor(const {});
      await expectLater(service.speakAndWait('Arzt'), completes);
      // То же на выключенном звуке: вместо голоса вибрация, но круг живёт.
      service.enabled = false;
      await expectLater(service.speakAndWait('Arzt'), completes);
    });

    test('остановка снимает и ждавшее своей очереди', () async {
      final spoken = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'speak') {
          spoken.add(call.arguments as String);
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return true;
        }
        if (call.method == 'isLanguageInstalled') return true;
        return true;
      });

      final service = DeviceSpeechService(lang: 'de', engine: FlutterTts.new);
      service.speak('Zeit');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      service.speak('Uhr');
      service.stop();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(spoken, ['Zeit'],
          reason: '«остановить» домолчало до следующего слова');
    });
  });

  // ── Контракт службы речи ──────────────────────────────────────────────────
  //
  // Одна группа проверок, прогнанная **и по настоящей службе, и по заглушке**.
  //
  // Нужна она из-за находки, которую иначе не поймать ничем: заглушка
  // моделировала не ту сторону службы, которую ею и проверяют. У устройства —
  // одна цепочка и очередь длиной в один, то есть второй запрос во время
  // произнесения ждёт своей очереди; у заглушки на каждый вызов была своя
  // независимая задержка, а `stop()` только считался и висящих ждущих не
  // разрешал. Группа «окно ждёт озвучку» зеленела против семантики
  // одновременных произнесений, которой в игре не существует, — ровно там, где
  // идёт проверка.
  //
  // Теперь расхождение — падающий тест, а не находка через полгода. Настоящая
  // служба гоняется с подменённым каналом `flutter_tts`, а не с движком
  // устройства: контракт про очередь и тишину, а не про качество голоса.

  /// Сколько «длится» одно произнесение в контрактных проверках.
  ///
  /// Мгновенным голосом контракт не проверить: «пока звучит» и «после того как
  /// прозвучало» пришлись бы на один миг — та самая слепота, из-за которой
  /// расхождение жило незамеченным.
  const voice = Duration(milliseconds: 60);

  /// Столько ждём там, где произнесение обязано кончиться (с запасом на
  /// платформенные вызовы настоящей службы).
  const afterVoice = Duration(milliseconds: 250);

  /// Служба и то, что у неё **прозвучало**.
  ///
  /// Наблюдать надо прозвучавшее, а не запрошенное: расходились реализации
  /// именно здесь — заглушка «произносила» каждый запрос, включая тот, что
  /// очередь вытеснила. У устройства прозвучавшее видно по вызовам канала, у
  /// заглушки — по её списку.
  void contract(
    String name,
    ({SpeechService service, List<String> uttered}) Function() open,
  ) {
    group('контракт службы речи — $name', () {
      late SpeechService speech;
      late List<String> uttered;

      setUp(() {
        final opened = open();
        speech = opened.service;
        uttered = opened.uttered;
      });

      test('произнесение не задерживает вызывающего', () async {
        // Инвариант README: звук не блокирует переход к следующему кругу.
        // Ждать окончания разрешено ровно одному месту — кругу на слух, — и
        // даже там ожидание не задерживает вызов, а приходит сигналом.
        SpeechOutcome? outcome;
        unawaited(speech.speakAndWait('eins').then((value) => outcome = value));
        expect(outcome, isNull, reason: 'вызов дождался конца произнесения');

        await Future<void>.delayed(afterVoice);
        expect(outcome, SpeechOutcome.done,
            reason: 'сигнала окончания не пришло вовсе');
        expect(uttered, ['eins']);
      });

      test('начатое договаривается, а не обрывается следующим', () async {
        // Слышно это было так: игрок верно соединяет фразу, она начинает
        // звучать и обрывается на середине, потому что следующий круг оказался
        // кругом на слух и его центр заиграл поверх.
        speech.speak('eins');
        await Future<void>.delayed(voice ~/ 3);
        speech.speak('zwei');

        expect(uttered, ['eins'],
            reason: 'второе произнесение началось поверх первого');
        await Future<void>.delayed(afterVoice);
        expect(uttered, ['eins', 'zwei']);
      });

      test('очередь длиной в один: прозвучит последний', () async {
        // Очередь любой длины означала бы, что звук отстаёт от экрана на весь
        // хвост: игрок ушёл на три круга вперёд, а телефон дочитывает прошлые.
        speech.speak('eins');
        await Future<void>.delayed(voice ~/ 3);
        speech.speak('zwei');
        speech.speak('drei');

        await Future<void>.delayed(afterVoice);
        expect(uttered, ['eins', 'drei'],
            reason: 'вытесненное произнесение всё-таки прозвучало');
      });

      test('вытесненное произнесение это знает, а вытеснившее — нет', () async {
        // То, чем окно на ответ узнаёт **своё** произнесение. «Дозвучало» само
        // по себе ничего не значит: если следом уже стоит другое чтение,
        // тишины после моего не наступило, и окно откроет тот, кто вытеснил.
        final first = speech.speakAndWait('eins');
        await Future<void>.delayed(voice ~/ 3);
        SpeechOutcome? last;
        unawaited(speech.speakAndWait('zwei').then((value) => last = value));

        expect(await first, SpeechOutcome.displaced,
            reason: 'вытесненное произнесение отчиталось тишиной после себя');
        expect(last, isNull,
            reason: 'вытеснившее отчиталось раньше, чем прозвучало');

        await Future<void>.delayed(afterVoice);
        expect(uttered, ['eins', 'zwei'],
            reason: 'вытеснившее произнесение не прозвучало');
        expect(last, SpeechOutcome.done,
            reason: 'после последнего произнесения тишина так и не наступила');
      });

      test('stop обрывает начатое и разрешает ждущих', () async {
        final started = speech.speakAndWait('eins');
        await Future<void>.delayed(voice ~/ 3);
        final queued = speech.speakAndWait('zwei');
        speech.stop();

        // Ждать сигнала, которого уже не будет, значило бы для круга на слух
        // никогда не открыть окно — то есть повиснуть.
        expect(await started, SpeechOutcome.displaced);
        expect(await queued, SpeechOutcome.displaced);

        await Future<void>.delayed(afterVoice);
        expect(uttered, ['eins'],
            reason: '«остановить» домолчало до следующего слова');
      });

      test('вне экрана служба молчит и не копит сказанное', () async {
        // Обещание «вне экрана тишина» — свойство службы, а не поведение
        // одного вызывающего: остановить произнесение и запретить произнесения
        // это разные вещи, и первое из них жалобу владельца не закрывает.
        speech.silence();
        expect(await speech.speakAndWait('eins'), SpeechOutcome.displaced,
            reason: 'служба взялась говорить вне экрана');

        await Future<void>.delayed(afterVoice);
        expect(uttered, isEmpty, reason: 'голос дошёл до закрытого окна');

        speech.allowSpeech();
        await Future<void>.delayed(afterVoice);
        expect(uttered, isEmpty,
            reason: 'сказанное вне экрана прозвучало после возвращения');

        // Разрешение возвращает голос целиком, а не оставляет службу немой до
        // перезапуска.
        speech.speak('zwei');
        await Future<void>.delayed(afterVoice);
        expect(uttered, ['zwei']);
      });

      test('тишина обрывает уже начатое произнесение', () async {
        final started = speech.speakAndWait('eins');
        await Future<void>.delayed(voice ~/ 3);
        speech.silence();

        expect(speech.silenced, isTrue);
        // Фраза, доигранная в закрытом окне, и есть жалоба владельца — целиком
        // и дословно.
        expect(await started, SpeechOutcome.displaced);
      });
    });
  }

  contract('устройство', () {
    final uttered = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'speak') {
        uttered.add(call.arguments as String);
        // Платформа отвечает по окончании произнесения — так и настроен
        // движок (`awaitSpeakCompletion(true)`).
        await Future<void>.delayed(voice);
        return true;
      }
      if (call.method == 'isLanguageInstalled') return true;
      return true;
    });
    return (
      service: DeviceSpeechService(lang: 'de', engine: FlutterTts.new),
      uttered: uttered,
    );
  });

  contract('заглушка', () {
    final silent = SilentSpeechService(sounds: voice);
    return (service: silent, uttered: silent.uttered);
  });

  group('заглушка', () {
    test('запоминает, что просили произнести', () {
      final silent = SilentSpeechService();
      silent.speak('Rechnung');
      expect(silent.spoken, ['Rechnung']);
    });

    test('помнит и то, о чём просили, и то, что прозвучало', () async {
      // Два списка, потому что это две разные вещи, и путать их нельзя.
      // «Просили» — то, что сказала игра; «прозвучало» — то, что дошло до
      // голоса. Между ними стоит очередь длиной в один, и вытесненное в
      // «прозвучало» не попадает.
      final silent = SilentSpeechService(sounds: voice);
      silent.speak('eins');
      silent.speak('zwei');
      silent.speak('drei');

      expect(silent.spoken, ['eins', 'zwei', 'drei']);
      expect(silent.uttered, ['eins'], reason: 'заглушка заговорила хором');

      await Future<void>.delayed(afterVoice);
      expect(silent.uttered, ['eins', 'drei'],
          reason: 'вытесненное «zwei» прозвучало');
    });

    test('умеет притворяться устройством без голоса', () async {
      final silent =
          SilentSpeechService(reported: SpeechStatus.languageMissing);
      expect((await silent.status()).canSpeak, isFalse);
    });

    test('умеет говорить не мгновенно', () async {
      // Мгновенный голос — умолчание, и он нужен большинству тестов. Но
      // правило «окно открывается, когда фраза дозвучала» на мгновенном голосе
      // не проверить: «до» и «после» приходятся на один и тот же миг.
      final silent = SilentSpeechService(sounds: const Duration(seconds: 2));
      var done = false;
      unawaited(silent.speakAndWait('Rechnung').then((_) => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(silent.spoken, ['Rechnung']);
      expect(done, isFalse);
    });
  });

  group('тишина вне экрана', () {
    // Жалоба владельца дословно: «когда я закрыл окно с игрой — она продолжает
    // работать в фоне — я слышу текст». Таймеры круга останавливает забег, а
    // голос — приложение: он один на забег и калибровку, и корень
    // (`SilenceOffScreen`) — единственное место, которое знает, где
    // приложение. Поставь остановку в забеге, и онбординг продолжал бы читать
    // фразы в закрытом окне.
    //
    // Проверяется здесь **тишина**, а не факт вызова `stop()`, и это ровно та
    // разница, которой обещание не выполнялось: остановка обрывала
    // произнесение и не запрещала произнесений, так что всё, о чём игра
    // попросила после этого мига, доходило до голоса. Тест на «позвали ли
    // stop» проходил и тогда.
    Future<void> screen(AppLifecycleState state) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          SystemChannels.lifecycle.name,
          const StringCodec().encodeMessage(state.toString()),
          (_) {},
        );

    tearDown(() => WidgetsBinding.instance.resetInternalState());

    Future<SilentSpeechService> root(
      WidgetTester tester, {
      Duration sounds = const Duration(milliseconds: 60),
    }) async {
      final silent = SilentSpeechService(sounds: sounds);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [speechServiceProvider.overrideWithValue(silent)],
          child: const SilenceOffScreen(child: SizedBox()),
        ),
      );
      return silent;
    }

    testWidgets('вне экрана голос молчит, а не «замолчал один раз»',
        (tester) async {
      final silent = await root(tester);

      // На экране голос работает — иначе всё, что ниже, прошло бы и у службы,
      // которая молчит всегда.
      expect(silent.stopCount, 0, reason: 'замолчали, не уходя с экрана');
      silent.speak('на экране');
      await tester.pump(const Duration(milliseconds: 200));
      expect(silent.uttered, ['на экране']);

      await screen(AppLifecycleState.paused);
      await tester.pump();

      silent.speak('в фоне');
      await tester.pump(const Duration(milliseconds: 200));
      expect(silent.uttered, ['на экране'],
          reason: 'голос дошёл до закрытого окна');

      // И не копится: отложенная фраза, прозвучавшая через минуту после
      // возвращения, — тот же голос из закрытого окна, только с опозданием.
      await screen(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      expect(silent.uttered, ['на экране'],
          reason: 'сказанное вне экрана прозвучало после возвращения');

      // Возвращение речь не запускает — что произносить, решает не корень, а
      // тот, кто ведёт круг, — но и не оставляет приложение немым: голос
      // отпущен.
      //
      // Считать сами остановки бессмысленно, и это не небрежность: путь от
      // `resumed` до `paused` платформа проходит через `inactive` и `hidden`,
      // и каждое из этих состояний — «игрок не смотрит». Замолчать трижды не
      // хуже, чем один раз: прерывать во второй раз уже нечего.
      silent.speak('снова на экране');
      await tester.pump(const Duration(milliseconds: 200));
      expect(silent.uttered, ['на экране', 'снова на экране'],
          reason: 'после возвращения приложение осталось немым');
    });

    testWidgets('уход с экрана обрывает начатое произнесение', (tester) async {
      // Фраза длиннее ухода: доигранная в закрытом окне, она и есть жалоба
      // владельца.
      final silent = await root(tester, sounds: const Duration(seconds: 3));

      SpeechOutcome? outcome;
      unawaited(
        silent.speakAndWait('длинная фраза').then((value) => outcome = value),
      );
      await tester.pump(const Duration(seconds: 1));

      await screen(AppLifecycleState.paused);
      await tester.pump();

      // Ждущий получает отказ, а не тишину без ответа: круг на слух, ждущий
      // конца озвучки, иначе не открыл бы окно никогда.
      expect(outcome, SpeechOutcome.displaced,
          reason: 'ждущий остался ждать сигнала, которого уже не будет');
      expect(silent.stopCount, greaterThan(0),
          reason: 'озвучка осталась играть в фоне');

      // Дожимаем ту задержку, которую заглушка отменить не умеет: цепочку она
      // больше не двигает, а таймер тест за собой оставлять не должен.
      await tester.pump(const Duration(seconds: 3));
      expect(silent.uttered, ['длинная фраза']);
    });
  });

  group('замер задержки', () {
    test('медиана считается по накопленным пробам', () {
      final probe = SpeechLatencyProbe();
      for (final ms in [10, 500, 20]) {
        probe.record(Duration(milliseconds: ms));
      }
      expect(probe.median, const Duration(milliseconds: 20));
    });

    test('без проб медианы нет и приемлемость не утверждается', () {
      final probe = SpeechLatencyProbe();
      expect(probe.median, isNull);
      expect(probe.isAcceptable, isFalse);
    });
  });
}
