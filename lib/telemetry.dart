import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Çökmə hesabatı (Crashlytics) və istifadə statistikası (Analytics).
///
/// Buraxılışdan sonra tətbiqin kimdəsə çökdüyünü bilməyin yeganə yolu budur.
/// Hər ikisi Firebase-in pulsuz Spark planına daxildir.
///
/// Crashlytics veb-də işləmir, ona görə veb tərəfdə yalnız konsola yazırıq.
class Telemetry {
  static bool get _supported => !kIsWeb;

  static FirebaseAnalytics? _analytics;

  static FirebaseAnalytics get analytics =>
      _analytics ??= FirebaseAnalytics.instance;

  /// `main()`-də Firebase hazır olandan sonra çağırılır.
  ///
  /// Gözləmir: xəta tutucuları dərhal qurulur, platformaya gedən sorğu isə
  /// arxa planda qalır. Əvvəl bu sorğu gözlənilirdi və açılışı ləngidirdi.
  static void start() {
    if (!_supported) return;

    try {
      // Flutter-in tutduğu bütün widget xətaları.
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

      // Flutter-dən kənarda qalan xətalar (isolate, async).
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      unawaited(
        FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode),
      );
    } catch (_) {
      // Telemetriya qurulmasa da tətbiq normal işləməlidir.
    }
  }

  /// Giriş edən istifadəçini hesabatlara bağlayır.
  static Future<void> setUser(String uid) async {
    if (!_supported) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      await analytics.setUserId(id: uid);
    } catch (_) {}
  }

  static Future<void> clearUser() async {
    if (!_supported) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await analytics.setUserId(id: null);
    } catch (_) {}
  }

  /// Vacib hadisələr: qeydiyyat, otaq yaradılması, hədiyyə və s.
  static Future<void> log(String name, [Map<String, Object>? params]) async {
    if (!_supported) {
      if (kDebugMode) debugPrint('analytics: $name $params');
      return;
    }
    try {
      await analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  /// Tutulmuş, amma araşdırılmalı olan xətalar.
  static Future<void> error(Object error, StackTrace stack, {String? hint}) async {
    if (!_supported) {
      if (kDebugMode) debugPrint('error: $error\n$stack');
      return;
    }
    try {
      await FirebaseCrashlytics.instance
          .recordError(error, stack, reason: hint, fatal: false);
    } catch (_) {}
  }
}
