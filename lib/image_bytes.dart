/// Data URI-dən baytları çıxarır.
///
/// Şəkillər Firestore-da `data:image/jpeg;base64,...` şəklində
/// saxlanılır — pullu Storage tələb etməsin deyə.
library;

import 'dart:convert';
import 'dart:typed_data';

Uint8List? imageBytesFrom(String dataUri) {
  final value = dataUri.trim();
  if (value.isEmpty) return null;

  final comma = value.indexOf(',');
  if (!value.startsWith('data:') || comma < 0) return null;

  try {
    return base64Decode(value.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Data URI-dəki növ ("image/jpeg"). Tapılmasa JPEG sayılır.
String imageTypeFrom(String dataUri) {
  final start = dataUri.indexOf(':');
  final semi = dataUri.indexOf(';');
  if (start < 0 || semi < 0 || semi <= start) return 'image/jpeg';
  return dataUri.substring(start + 1, semi);
}
