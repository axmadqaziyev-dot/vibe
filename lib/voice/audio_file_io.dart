import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> newRecordingPath() async {
  final directory = await getTemporaryDirectory();
  return '${directory.path}/vibe_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
}

Future<String> playableAudio(Uint8List bytes) async {
  final path = await newRecordingPath();
  await File(path).writeAsBytes(bytes, flush: true);
  return Uri.file(path).toString();
}

Future<void> releaseAudio(String path) async {
  final file = File(
    path.startsWith('file:') ? Uri.parse(path).toFilePath() : path,
  );
  if (await file.exists()) await file.delete();
}
