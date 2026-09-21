import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Mobildə və masaüstündə paketin öz seçicisi işləyir.
///
/// `pickMultiImage` bir neçə şəkli birdən qaytarır — istifadəçi
/// qalereyaya bir dəfə girir.
Future<List<({String name, Uint8List bytes})>> pickGalleryPhotos({
  int max = 4,
}) async {
  final picked = await ImagePicker().pickMultiImage(
    // Seçim anında kiçildirik: orijinal ölçüdə oxumaq yaddaşı yeyir.
    maxWidth: 1600,
    imageQuality: 88,
    limit: max,
  );

  if (picked.isEmpty) return const [];

  final out = <({String name, Uint8List bytes})>[];
  for (final file in picked.take(max)) {
    out.add((name: file.name, bytes: await file.readAsBytes()));
  }
  return out;
}
