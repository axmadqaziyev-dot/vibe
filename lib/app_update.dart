/// Yeni versiyanın xəbəri.
///
/// Veb tətbiq yayımlananda brauzer köhnə nüsxəni işlətməyə davam edə
/// bilər — xüsusən iOS-da, ana ekrandakı tətbiq günlərlə bağlanmadan
/// qala bilir. Nəticədə istifadəçi düzəlişləri görmür və "niyə hələ
/// də belədir?" deyir.
///
/// Həll: yığım zamanı `version.json` yazılır, tətbiq onu vaxtaşırı
/// oxuyur. Damğa dəyişibsə, aşağıda kiçik zolaq çıxır — istifadəçi
/// basır və səhifə təzələnir.
///
/// Öz-özünə təzələmirik: adam mesaj yazarkən ekranın sıfırlanması
/// pisdir. Qərar onun olur.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'reload_page.dart';

/// Yeni yayım varmı?
final ValueNotifier<bool> updateReady = ValueNotifier<bool>(false);

/// Hazırda işləyən versiyanın damğası.
String runningBuild = '';

Timer? _timer;

/// Nə qədər bir yoxlanılır.
///
/// Tez-tez yoxlamaq mənasızdır: yayım gündə bir neçə dəfə olur, fayl
/// isə kiçikdir, amma şəbəkəni boş yerə yormaq istəmirik.
const Duration _every = Duration(minutes: 10);

/// Yoxlamanı başladır.
void startUpdateWatch() {
  if (!kIsWeb) return;

  runningBuild = currentBuildTag();
  if (runningBuild.isEmpty) return;

  _timer?.cancel();
  _timer = Timer.periodic(_every, (_) => unawaited(checkForUpdate()));

  // İlk yoxlama dərhal deyil: açılış onsuz da yüklüdür.
  Timer(const Duration(seconds: 30), () => unawaited(checkForUpdate()));
}

void stopUpdateWatch() {
  _timer?.cancel();
  _timer = null;
}

/// Serverdəki damğa ilə müqayisə edir.
Future<void> checkForUpdate() async {
  if (!kIsWeb || runningBuild.isEmpty || updateReady.value) return;

  try {
    // Sorğuya vaxt damğası qoşulur: əks halda brauzer öz yaddaşından
    // köhnə cavabı qaytarır və yenilik heç vaxt görünmür.
    final url = Uri.parse(
      'version.json?t=${DateTime.now().millisecondsSinceEpoch}',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    if (data is! Map) return;

    final build = '${data['build'] ?? ''}';
    if (build.isEmpty || build == runningBuild) return;

    updateReady.value = true;
  } catch (_) {
    // Şəbəkə yoxdursa səssiz keçirik — bu, ikinci dərəcəli işdir.
  }
}
