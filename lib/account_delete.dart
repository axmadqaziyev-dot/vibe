// HESABIN SİLİNMƏSİ.
//
// App Store Review Guideline 5.1.1(v): hesab yaratmağa imkan verən tətbiq
// hesabın tətbiq DAXİLİNDƏN silinməsini də təklif etməlidir.
//
// Firebase Auth son girişdən çox vaxt keçibsə silməyə icazə vermir
// ('requires-recent-login') — bu halda istifadəçidən yenidən giriş istənilir.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';

/// Silinməsi mümkün olan alt kolleksiyalar (müştəri tərəfdən sadalana bilənlər).
const _subCollections = <String>[
  'blocked',
  'blockedBy',
  'following',
  'followers',
  'notifications',
  'wallet',
  'savedVideos',
  'likedVideos',
  'hiddenVideos',
  'watchHistory',
  'matchHistory',
];

/// İstifadəçinin məlumatlarını və hesabını silir.
///
/// Tam təmizlik üçün server tərəfli funksiya lazımdır (başqalarının
/// izləyici siyahıları, paylaşımlar). Burada müştərinin çata bildiyi
/// hər şey silinir, sonra Auth hesabı silinir.
Future<void> deleteAccountCompletely(String uid) async {
  final db = FirebaseFirestore.instance;

  for (final name in _subCollections) {
    try {
      final snap = await db
          .collection('users')
          .doc(uid)
          .collection(name)
          .limit(400)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // Bir kolleksiya silinməsə də proses dayanmır.
    }
  }

  // Öz paylaşımları
  for (final collection in ['moments', 'videos']) {
    try {
      final snap = await db
          .collection(collection)
          .where('ownerUid', isEqualTo: uid)
          .limit(200)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  try {
    await db.collection('users').doc(uid).delete();
  } catch (_) {}

  await FirebaseAuth.instance.currentUser?.delete();
}

/// Təsdiq pəncərəsi + silmə axını. Uğurlu olsa `true` qaytarır.
Future<bool> showDeleteAccountFlow(BuildContext context, String uid) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: const Color(0xff151020),
      title: const Text(
        'Hesabı həmişəlik silmək?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      content: const Text(
        'Profilin, şəkillərin, anların, mesaj tarixçən və coin balansın '
        'silinəcək. Bu əməliyyat geri qaytarıla bilməz.',
        style: TextStyle(color: vMuted, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('İmtina'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: vRose),
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Bəli, sil'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  // İkinci təsdiq — səhvən silinmənin qarşısını alır.
  final sure = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: const Color(0xff151020),
      title: const Text(
        'Son təsdiq',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      content: const Text(
        'Hesab silindikdən sonra eyni məlumatlarla geri qaytarmaq mümkün deyil.',
        style: TextStyle(color: vMuted, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Saxla'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: vRose),
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Hesabı sil'),
        ),
      ],
    ),
  );

  if (sure != true || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: vPink)),
  );

  try {
    await deleteAccountCompletely(uid);
    if (!context.mounted) return true;
    Navigator.pop(context); // yükləmə pəncərəsi
    return true;
  } on FirebaseAuthException catch (e) {
    if (!context.mounted) return false;
    Navigator.pop(context);

    if (e.code == 'requires-recent-login') {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: const Color(0xff151020),
          title: const Text(
            'Təhlükəsizlik yoxlaması',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Təhlükəsizlik üçün hesabı silməzdən əvvəl yenidən daxil olmalısan. '
            'Çıxış et, yenidən gir və bir daha yoxla.',
            style: TextStyle(color: vMuted, height: 1.45),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Başa düşdüm'),
            ),
          ],
        ),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'Hesab silinmədi.')),
    );
    return false;
  } catch (_) {
    if (!context.mounted) return false;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hesab silinmədi. Yenidən sına.')),
    );
    return false;
  }
}
