# Flutter və plaginlər üçün saxlanmalı siniflər.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications sxemləri refleksiya ilə oxuyur.
-keep class com.dexterous.** { *; }

# WebRTC yerli kodu.
-keep class org.webrtc.** { *; }

# Firebase xəbərdarlıqlarını susdur.
-dontwarn com.google.firebase.**

# Flutter-in "deferred components" kodu Play Core kitabxanasına istinad edir,
# amma biz o funksiyadan istifadə etmirik — xəbərdarlıqları susdururuq.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
