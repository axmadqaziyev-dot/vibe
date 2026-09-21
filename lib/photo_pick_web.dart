import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Vebdə şəkilləri qalereyadan seçir.
///
/// `accept` yalnız `image/*` qoyulur: iOS Safari məhz bu halda
/// "Foto kitabxanası / Şəkil çək / Fayl seç" menyusunu göstərir.
/// Uzun MIME siyahısı verilsə birbaşa Fayllar açılır və hər dəfə
/// "tam giriş" icazəsi soruşulur.
///
/// `multiple` açıqdır — bir dəfəyə bir neçə şəkil seçilir.
Future<List<({String name, Uint8List bytes})>> pickGalleryPhotos({
  int max = 4,
}) async {
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = true;

  // Səhifəyə əlavə edilmədən bəzi brauzerlər hadisəni buraxmır.
  input.style.display = 'none';
  web.document.body?.append(input);

  final completer = Completer<List<({String name, Uint8List bytes})>>();

  void finish(List<({String name, Uint8List bytes})> value) {
    if (!completer.isCompleted) completer.complete(value);
    input.remove();
  }

  // `toJS` yalnız void qaytaran funksiyanı qəbul edir — burada
  // `async` yazmaq olmaz. Oxumanı ayrıca funksiyaya veririk.
  input.onchange = (web.Event _) {
    _collect(input.files, max).then(finish);
  }.toJS;

  // İstifadəçi pəncərəni bağlasa `change` gəlmir; səhifəyə qayıdanda
  // heç nə seçilməyibsə gözləməyi bitiririk.
  input.oncancel = ((web.Event _) => finish(const [])).toJS;

  input.click();
  return completer.future;
}

/// Seçilmiş faylları oxuyur.
Future<List<({String name, Uint8List bytes})>> _collect(
  web.FileList? files,
  int max,
) async {
  if (files == null || files.length == 0) return const [];

  final out = <({String name, Uint8List bytes})>[];
  final count = files.length < max ? files.length : max;

  for (var i = 0; i < count; i++) {
    final file = files.item(i);
    if (file == null) continue;

    final bytes = await _read(file);
    if (bytes != null) out.add((name: file.name, bytes: bytes));
  }

  return out;
}

Future<Uint8List?> _read(web.File file) {
  final completer = Completer<Uint8List?>();
  final reader = web.FileReader();

  reader.onload = (web.Event _) {
    final result = reader.result;
    if (result == null) {
      completer.complete(null);
      return;
    }
    completer.complete((result as JSArrayBuffer).toDart.asUint8List());
  }.toJS;

  reader.onerror = ((web.Event _) => completer.complete(null)).toJS;
  reader.readAsArrayBuffer(file);

  return completer.future;
}
