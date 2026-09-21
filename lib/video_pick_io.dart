import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Mobildə və masaüstündə paketin öz seçicisi işləyir —
/// orada qalereya ilə fayl arasında qarışıqlıq yoxdur.
Future<({String name, Uint8List bytes})?> pickGalleryVideo() async {
  final picked = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
    maxDuration: const Duration(minutes: 2),
  );

  if (picked == null) return null;
  return (name: picked.name, bytes: await picked.readAsBytes());
}
