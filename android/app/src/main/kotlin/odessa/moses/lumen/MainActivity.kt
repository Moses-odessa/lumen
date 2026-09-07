package odessa.moses.lumen

import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Единственный нативный код в проекте, и он существует ради одного:
 * отправить игрока туда, где можно поставить голос нужного языка.
 *
 * Приложение перешло на синтез речи устройства вместо записанных файлов.
 * На Android движок Google предустановлен почти везде, а языковые данные
 * докачиваются — и без них озвучка молчит. Сказать «голоса нет» мало:
 * система умеет открыть страницу установки сама, и грех этим не
 * воспользоваться.
 *
 * Плагином это не делается: `flutter_tts` умеет спросить, установлен ли
 * язык, но не умеет предложить его поставить.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "lumen/speech_settings"

        /** Системная страница языков и движков синтеза. */
        const val TTS_SETTINGS = "com.android.settings.TTS_SETTINGS"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Диалог загрузки языковых данных движка. Это самый
                    // короткий путь: сразу список языков, без блуждания по
                    // настройкам.
                    "installVoiceData" -> result.success(
                        launch(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))
                    )

                    // Запасной путь: общая страница синтеза речи. Нужен
                    // потому, что диалога установки нет у сторонних движков
                    // и на части прошивок.
                    "openVoiceSettings" -> result.success(
                        launch(Intent(TTS_SETTINGS))
                    )

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Возвращает `false`, если открыть нечего. Отсутствие страницы — не
     * ошибка приложения: на урезанной прошивке её может просто не быть, и
     * игроку тогда показывают путь текстом.
     */
    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    }
}
