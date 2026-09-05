/// Системный синтезатор речи Windows (SAPI) — напрямую через COM.
///
/// Зачем он вообще: озвучка — часть ядра игры, без неё нельзя проверить ни
/// один круг. Облачный TTS требует ключей и денег, а системный бесплатен,
/// работает офлайн и на большинстве машин уже умеет нужные языки.
///
/// Почему через COM, а не через PowerShell. Раньше каждая позиция запускала
/// `powershell.exe` со скриптом в командной строке. Это работало, но выглядело
/// ровно как доставка вредоносного кода: поведенческие эвристики антивирусов
/// (Avast `IDP.HELU.PSE90` и родня) блокировали запуск пачками, не разбирая
/// содержимого. Инструмент сборки не должен выглядеть как малварь. SAPI — это
/// COM-интерфейс, и Dart умеет его вызывать сам: ни одного дочернего процесса,
/// нечему срабатывать. Побочно это ещё и быстрее — процесс не поднимается на
/// каждое слово.
library;

import 'dart:io';

import 'package:win32/win32.dart';

import 'tts_provider.dart';

/// Подбирает провайдера под платформу и язык. `null` — озвучить нечем.
Future<TtsProvider?> resolveProvider(String lang) async {
  if (Platform.isWindows) return SapiProvider.forLanguage(lang);
  // TODO(data): для macOS есть `say`, для Linux — piper/espeak. Появятся,
  // когда сборка озвучки понадобится не только на машине разработчика.
  return null;
}

/// Первичные языковые идентификаторы Windows (младшие 10 бит LCID).
///
/// SAPI отдаёт язык голоса как LCID в шестнадцатеричном виде: `407` — немецкий
/// Германии, `809` — английский Британии. Сравнивать надо именно первичную
/// часть, иначе `de-AT` не найдётся при поиске немецкого.
const _primaryLanguages = <int, String>{
  0x07: 'de',
  0x09: 'en',
  0x19: 'ru',
  0x22: 'uk',
  0x10: 'it',
  0x0c: 'fr',
  0x0a: 'es',
  0x15: 'pl',
};

/// Формат записи: 22 кГц, 16 бит, моно (`SAFT22kHz16BitMono`).
///
/// Задаётся явно, а не берётся из умолчаний голоса: иначе один и тот же текст
/// у разных голосов давал бы файлы разного размера, и бюджет озвучки поплыл бы.
const _formatType = 22;

/// `SSFMCreateForWrite` — создать файл, перезаписав существующий.
const _createForWrite = 3;

/// `SVSFIsNotXML` — текст произносится буквально.
///
/// Без этого флага угловая скобка в слове превратила бы его в разметку, и
/// позиция молча озвучилась бы неправильно.
const _speakPlainText = 16;

class SapiProvider implements TtsProvider {
  SapiProvider._(this.voiceName, this._voice, this._token);

  @override
  final String voiceName;

  /// `SAPI.SpVoice`, живёт до конца работы инструмента.
  final Dispatcher _voice;

  /// Токен выбранного голоса. Ссылку держит вариант, поэтому освобождать его
  /// нельзя до последнего синтеза.
  final Variant<IDispatch> _token;

  /// Готовит COM. Повторный вызов безвреден.
  static void _ensureCom() {
    if (_comReady) return;
    final hr = CoInitializeEx(COINIT_APARTMENTTHREADED);
    if (hr.isError) throw WindowsException(hr);
    _comReady = true;
  }

  static bool _comReady = false;

  /// Первый установленный голос нужного языка. `null` — такого нет.
  static SapiProvider? forLanguage(String lang) {
    _ensureCom();
    final voice = Dispatcher.fromProgID('SAPI.SpVoice');
    final tokensVariant = voice.invoke<IDispatch>('GetVoices', ['', '']);
    final tokens = Dispatcher(tokensVariant.value);

    try {
      final countVariant = tokens.get<int>('Count');
      final count = countVariant.value;
      countVariant.free();

      for (var i = 0; i < count; i++) {
        final itemVariant = tokens.invoke<IDispatch>('Item', [i]);
        final token = Dispatcher(itemVariant.value);

        if (_languageOf(token) == lang) {
          final name = _attribute(token, 'Name') ?? 'неизвестный голос';
          // Токен остаётся жить: его держит itemVariant, который уходит в
          // провайдера и освобождается вместе с ним.
          return SapiProvider._(name, voice, itemVariant);
        }
        itemVariant.free();
      }
    } finally {
      tokensVariant.free();
    }

    voice.dispose();
    return null;
  }

  /// Двухбуквенный код языка голоса или `null`, если атрибута нет.
  static String? _languageOf(Dispatcher token) {
    final raw = _attribute(token, 'Language');
    if (raw == null) return null;
    // У голоса может быть перечислено несколько языков через точку с запятой.
    for (final part in raw.split(';')) {
      final lcid = int.tryParse(part.trim(), radix: 16);
      if (lcid == null) continue;
      final iso = _primaryLanguages[lcid & 0x3ff];
      if (iso != null) return iso;
    }
    return null;
  }

  /// Атрибут токена; отсутствие атрибута — не ошибка, а `null`.
  static String? _attribute(Dispatcher token, String name) {
    try {
      final variant = token.invoke<String>('GetAttribute', [name]);
      final value = variant.value;
      variant.free();
      return value;
    } on WindowsException {
      return null;
    }
  }

  @override
  Future<bool> speakToFile(String text, File output) async {
    _ensureCom();

    // Каталог должен существовать: SpFileStream его не создаёт и падает с
    // невнятным HRESULT.
    final parent = output.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);

    final stream = Dispatcher.fromProgID('SAPI.SpFileStream');
    try {
      final formatVariant = stream.get<IDispatch>('Format');
      final format = Dispatcher(formatVariant.value);
      format.set('Type', _formatType);
      formatVariant.free();

      stream.invoke('Open', [output.path, _createForWrite, false]);

      // `Dispatcher.set` кладёт интерфейс в VARIANT без AddRef, а в конце
      // чистит вариант — то есть отпускает чужую ссылку. Без компенсации
      // объект умирает под ногами: поток разрушался до `Close`, и процесс
      // падал по обращению к освобождённой памяти.
      _addRef(stream.dispatch);
      _voice.set('AudioOutputStream', stream.dispatch, byReference: true);
      _voice.set('Rate', -1);
      _addRef(_token.value);
      _voice.set('Voice', _token.value, byReference: true);
      _voice.invoke('Speak', [text, _speakPlainText]);
      // Синхронный Speak возвращается после произнесения, но поток надо
      // отвязать до закрытия файла, иначе последний блок может не дойти.
      _voice.set('AudioOutputStream', null);

      stream.invoke('Close');
    } on WindowsException catch (e) {
      stderr.writeln('SAPI: ${e.hr} на «$text»');
      return false;
    } finally {
      stream.dispose();
    }

    return output.existsSync() && output.lengthSync() > 0;
  }

  /// Компенсирует освобождение, которое сделает `Dispatcher.set`.
  static void _addRef(IDispatch? value) => value?.addRef();

  /// Освобождает голос и токен. После этого провайдер непригоден.
  void dispose() {
    _token.free();
    _voice.dispose();
  }
}
