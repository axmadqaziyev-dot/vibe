import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Səhifəni yenidən yükləyir.
void reloadPage() => web.window.location.reload();

/// `index.html`-ə yığım zamanı yazılan damğa.
///
/// Damğa səhifənin özündədir: müqayisə üçün əlavə sorğu getmir.
@JS('vibeBuild')
external JSString? get _vibeBuild;

String currentBuildTag() {
  try {
    return _vibeBuild?.toDart ?? '';
  } catch (_) {
    return '';
  }
}
