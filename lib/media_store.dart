// ŞƏKİL SAXLAMA — Firebase Storage olmadan.
//
// Firebase Storage Blaze planı tələb etdiyi üçün şəkillər sıxılıb
// birbaşa Firestore-da saxlanılır (data URI kimi).
//
//  • kiçik nüsxə (thumb)  → users/{uid}.photoUrl      ~6-10 KB, siyahılarda
//  • böyük nüsxə (full)   → users/{uid}/media/photo   ~60-90 KB, profil səhifəsində
//
// Firestore sənəd limiti 1 MB-dır; ölçülər bilərəkdən onun çox altındadır.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Sıxılmış şəkil cütlüyü.
class StoredImage {
  const StoredImage({required this.thumb, required this.full});

  /// Siyahılar üçün kiçik data URI.
  final String thumb;

  /// Profil/detal səhifəsi üçün böyük data URI.
  final String full;
}

/// Firestore sənədinə sığması üçün təhlükəsiz hədd.
const _maxDataUriBytes = 700 * 1024;

/// Şəkil seçir və iki ölçüdə sıxır. İstifadəçi ləğv etsə `null`.
Future<StoredImage?> pickStoredImage({
  ImageSource source = ImageSource.gallery,
  int fullWidth = 720,
  int thumbWidth = 160,
  int fullQuality = 72,
  int thumbQuality = 62,
}) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    // Böyük fayl oxumamaq üçün seçim anında da kiçildirik.
    maxWidth: 1600,
    imageQuality: 88,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  return compressToStoredImage(
    bytes,
    fullWidth: fullWidth,
    thumbWidth: thumbWidth,
    fullQuality: fullQuality,
    thumbQuality: thumbQuality,
  );
}

/// Baytları iki ölçüdə sıxıb data URI-yə çevirir.
StoredImage? compressToStoredImage(
  Uint8List bytes, {
  int fullWidth = 720,
  int thumbWidth = 160,
  int fullQuality = 72,
  int thumbQuality = 62,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  String encode(int width, int quality) {
    final resized = decoded.width <= width
        ? decoded
        : img.copyResize(decoded, width: width);
    final jpg = img.encodeJpg(resized, quality: quality);
    return 'data:image/jpeg;base64,${base64Encode(jpg)}';
  }

  var full = encode(fullWidth, fullQuality);

  // Çox böyük çıxsa, keyfiyyəti pilləli azaldırıq.
  var quality = fullQuality;
  var width = fullWidth;
  while (full.length > _maxDataUriBytes && quality > 35) {
    quality -= 12;
    width = (width * 0.85).round();
    full = encode(width, quality);
  }

  return StoredImage(thumb: encode(thumbWidth, thumbQuality), full: full);
}

// ============================================================
// YAZMA
// ============================================================

/// Profil şəkli: kiçik nüsxə profil sənədinə, böyük nüsxə alt sənədə.
Future<void> saveProfilePhoto({
  required String uid,
  required StoredImage image,
  FirebaseFirestore? database,
}) async {
  final db = database ?? FirebaseFirestore.instance;
  final user = db.collection('users').doc(uid);

  final batch = db.batch();
  batch.set(user, {
    'photoUrl': image.thumb,
    'photoUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  batch.set(user.collection('media').doc('photo'), {
    'data': image.full,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  await batch.commit();
}

/// Örtük şəkli — yalnız bir nüsxə saxlanılır.
Future<void> saveCoverPhoto({
  required String uid,
  required StoredImage image,
  FirebaseFirestore? database,
}) async {
  final db = database ?? FirebaseFirestore.instance;

  await db.collection('users').doc(uid).collection('media').doc('cover').set({
    'data': image.full,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  // Siyahılarda istifadə olunmur, ona görə yalnız kiçik nüsxə profil sənədinə.
  await db.collection('users').doc(uid).set({
    'coverUrl': image.thumb,
  }, SetOptions(merge: true));
}

/// Qalereyaya şəkil əlavə edir.
Future<void> addGalleryPhoto({
  required String uid,
  required StoredImage image,
  FirebaseFirestore? database,
}) async {
  final db = database ?? FirebaseFirestore.instance;

  await db.collection('users').doc(uid).collection('gallery').add({
    'thumb': image.thumb,
    'data': image.full,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Böyük nüsxəni oxuyur (profil səhifəsi üçün).
Stream<String?> watchFullPhoto(String uid, {String doc = 'photo'}) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('media')
        .doc(doc)
        .snapshots()
        .map((snap) => snap.data()?['data'] as String?);
