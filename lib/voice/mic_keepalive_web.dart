import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.MediaStream? _stream;

bool get micWarm => _stream != null;

/// Mikrofonu bir dəfə açır və açıq saxlayır.
///
/// Trek söndürülür: heç nə eşidilmir, yalnız icazə qüvvədə qalır.
Future<void> warmMic() async {
  if (_stream != null) return;

  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;

    // Səs almırıq — məqsəd yalnız icazəni saxlamaqdır.
    final tracks = stream.getAudioTracks().toDart;
    for (final track in tracks) {
      track.enabled = false;
    }

    _stream = stream;
  } catch (_) {
    // İcazə verilmədi — yazı cəhdi onsuz da öz xətasını verəcək.
  }
}

/// Axını bağlayır.
///
/// Tətbiq arxa plana keçəndə çağırılır: narıncı nöqtə ekranda
/// qalmamalıdır.
void releaseMic() {
  final stream = _stream;
  _stream = null;
  if (stream == null) return;

  try {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  } catch (_) {}
}
