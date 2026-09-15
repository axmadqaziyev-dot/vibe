import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String> newRecordingPath() async => 'voice.wav';
Future<String> playableAudio(Uint8List bytes) async => web.URL.createObjectURL(
  web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'audio/wav')),
);
Future<void> releaseAudio(String path) async {
  if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
}
