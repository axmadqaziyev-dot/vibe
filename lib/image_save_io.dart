import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'image_bytes.dart';

/// Mobildə və masaüstündə fayl sənədlər qovluğuna yazılır.
///
/// Qalereyaya birbaşa yazmaq üçün ayrıca kitabxana lazımdır; hazırda
/// tətbiq vebdə işləyir, ona görə burada sadə yol saxlanılır.
Future<String?> saveImage(String source, {String name = 'vibe.jpg'}) async {
  final bytes = imageBytesFrom(source);
  if (bytes == null) return null;

  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
