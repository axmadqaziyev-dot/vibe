import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'media_upload.dart';
import 'user_profile.dart';

/// Seçilən video pulsuz yaddaş üçün çox böyükdür.
class _VideoTooLarge implements Exception {
  const _VideoTooLarge();
}

class VideoUploadButton extends StatefulWidget {
  const VideoUploadButton({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<VideoUploadButton> createState() => _VideoUploadButtonState();
}

class _VideoUploadButtonState extends State<VideoUploadButton> {
  bool uploading = false;

  Future<void> upload() async {
    if (uploading) return;

    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null || !mounted) return;

    final caption = await _captionDialog();
    if (caption == null) return;

    setState(() => uploading = true);
    try {
      final Uint8List bytes = await picked.readAsBytes();

      // Telefondan seçilən video çox böyük ola bilər — pulsuz yaddaşı
      // qorumaq üçün 90 MB-dan yuxarısını qəbul etmirik.
      if (bytes.lengthInBytes > 90 * 1024 * 1024) {
        throw const _VideoTooLarge();
      }

      final videoId = FirebaseFirestore.instance.collection('videos').doc().id;
      final url = await MediaUpload.upload(
        bucket: MediaUpload.videoBucket,
        path: '${widget.profile.uid}/$videoId.mp4',
        bytes: bytes,
        contentType: 'video/mp4',
      );

      await FirebaseFirestore.instance.collection('videos').doc(videoId).set({
        'id': videoId,
        'ownerUid': widget.profile.uid,
        'ownerName': widget.profile.name,
        'caption': caption.trim(),
        'videoUrl': url,
        'createdAt': Timestamp.now(),
        'visibility': 'public',
        'views': 0,
        'shares': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video yayımlandı 💜')),
        );
      }
    } catch (e) {
      if (mounted) {
        final String message;
        if (e is _VideoTooLarge) {
          message = 'Video çox böyükdür. 90 MB-a qədər video paylaşa bilərsən.';
        } else if (e is MediaBucketMissing) {
          message = 'Video yaddaşı hazır deyil: Supabase panelində '
              '"${e.bucket}" adlı public bucket yaradılmalıdır.';
        } else {
          message = 'Video yüklənmədi: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(message),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<String?> _captionDialog() async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Video paylaş',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: c,
          maxLength: 2200,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Başlıq, hashtag...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, c.text),
            child: const Text('Paylaş'),
          ),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: 'Video paylaş',
      onPressed: uploading ? null : upload,
      icon: uploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_rounded),
    );
  }
}
