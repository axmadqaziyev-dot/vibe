import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'image_bytes.dart';

/// Şəkli brauzerdə yükləyir.
///
/// Üç şey bir yerdə edilir:
///
/// 1. Baytlardan `Blob` qurulur və ona müvəqqəti ünvan verilir.
/// 2. `download` atributu ilə keçid yaradılıb basılır — masaüstü və
///    Android-də fayl birbaşa yüklənir.
/// 3. iOS Safari `download` atributunu tanımır: orada keçid şəkli
///    açır. Bu da işimizə yarayır — açılan şəklə uzun basıb
///    "Şəkilləri əlavə et" demək olur. Flutter-in kətanında isə bu
///    mümkün deyildi.
///
/// Gözləmə (await) yoxdur: brauzer yalnız toxunuşun öz anında
/// yaranan keçidə icazə verir, `await`-dən sonra bloklayır.
Future<String?> saveImage(String source, {String name = 'vibe.jpg'}) async {
  try {
    // Şəbəkə ünvanı (video və Supabase-dəki şəkillər) birbaşa verilir.
    //
    // Baytları əvvəlcə endirmək olardı, amma bu, `await` tələb edir və
    // toxunuşun anı itir — brauzer belə keçidi bloklayır.
    if (!source.startsWith('data:')) {
      _click(source, name, revoke: false);
      return name;
    }

    final bytes = imageBytesFrom(source);
    if (bytes == null) return null;

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: imageTypeFrom(source)),
    );

    final url = web.URL.createObjectURL(blob);
    _click(url, name, revoke: true);

    return name;
  } catch (_) {
    return null;
  }
}

void _click(String url, String name, {required bool revoke}) {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = name
    // iOS-da yeni sekmədə açılsın ki, uzun basıb saxlamaq olsun.
    ..target = '_blank'
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Ünvan dərhal silinsə iOS faylı endirə bilmir — bir az gözləyirik.
  if (revoke) {
    Future<void>.delayed(const Duration(minutes: 1)).then((_) {
      web.URL.revokeObjectURL(url);
    });
  }
}
