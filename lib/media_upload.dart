import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FileOptions, StorageException;

/// Böyük faylların (video, səs) saxlanması üçün Supabase Storage.
///
/// Firebase Storage pullu Blaze planı tələb edir; Supabase-in pulsuz tarifi
/// isə 1 GB yer verir və layihədə artıq qurulub (səsli mesajlar onunla işləyir).
/// Şəkillər ayrıca `media_store.dart`-da Firestore-da data URI kimi saxlanır.
class MediaUpload {
  static const String videoBucket = 'videos';

  /// Faylı yükləyib açıq (public) linkini qaytarır.
  ///
  /// Bucket tapılmasa [MediaBucketMissing] atılır — çağıran tərəf istifadəçiyə
  /// nə etməli olduğunu izah edir.
  static Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final storage = Supabase.instance.client.storage;
    try {
      await storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '3600',
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      if (_missingBucket(e)) throw MediaBucketMissing(bucket);
      rethrow;
    }
    return storage.from(bucket).getPublicUrl(path);
  }

  /// Yüklənmiş faylı silir. Link Supabase-ə aid deyilsə `false` qaytarır.
  static Future<bool> deleteByUrl(String url) async {
    final marker = '/storage/v1/object/public/';
    final index = url.indexOf(marker);
    if (index < 0) return false;

    final rest = url.substring(index + marker.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) return false;

    final bucket = rest.substring(0, slash);
    final path = Uri.decodeComponent(rest.substring(slash + 1).split('?').first);

    await Supabase.instance.client.storage.from(bucket).remove([path]);
    return true;
  }

  static bool _missingBucket(StorageException e) {
    final text = '${e.statusCode} ${e.message}'.toLowerCase();
    return text.contains('not found') || text.contains('bucket');
  }
}

/// Supabase-də bucket yaradılmayıb.
class MediaBucketMissing implements Exception {
  MediaBucketMissing(this.bucket);

  final String bucket;

  @override
  String toString() =>
      'Supabase-də "$bucket" adlı public bucket yaradılmayıb.';
}
