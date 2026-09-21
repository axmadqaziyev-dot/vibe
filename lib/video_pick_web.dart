import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Vebdə videonu qalereyadan seçir.
///
/// `accept` yalnız `video/*` qoyulur: iOS Safari məhz bu halda
/// "Foto kitabxanası / Video çək / Fayl seç" menyusunu göstərir.
/// Uzun MIME siyahısı verilsə birbaşa Fayllar açılır.
Future<({String name, Uint8List bytes})?> pickGalleryVideo() async {
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'video/*';

  // Səhifəyə əlavə edilmədən bəzi brauzerlər hadisəni buraxmır.
  input.style.display = 'none';
  web.document.body?.append(input);

  final completer = Completer<({String name, Uint8List bytes})?>();

  void finish(({String name, Uint8List bytes})? value) {
    if (!completer.isCompleted) completer.complete(value);
    input.remove();
  }

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }

    final file = files.item(0)!;
    final reader = web.FileReader();

    reader.onload = (web.Event _) {
      final result = reader.result;
      if (result == null) {
        finish(null);
        return;
      }
      finish((
        name: file.name,
        bytes: (result as JSArrayBuffer).toDart.asUint8List(),
      ));
    }.toJS;

    reader.onerror = ((web.Event _) => finish(null)).toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  // İstifadəçi pəncərəni bağlasa `change` gəlmir; səhifəyə qayıdanda
  // heç nə seçilməyibsə gözləməyi bitiririk.
  input.oncancel = ((web.Event _) => finish(null)).toJS;

  input.click();
  return completer.future;
}
