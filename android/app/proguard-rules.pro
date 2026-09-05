# Правила сжатия для релизной сборки.
#
# Flutter-плагины обращаются к платформенному коду через рефлексию, поэтому
# их точки входа обязаны пережить обфускацию.

# Drift и sqlite3 — нативная библиотека и её загрузчик.
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# just_audio и ExoPlayer.
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# flutter_local_notifications хранит расписание сериализованным.
-keep class com.dexterous.** { *; }

# Sentry: имена классов нужны, чтобы стектрейсы читались.
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
