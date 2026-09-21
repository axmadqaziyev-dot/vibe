/// Paylaşım mətnindəki toxunuşların nəticəsi.
///
/// `RichPostText` yalnız mətni ayırır — nəyə toxunulanda nə açılacağı
/// burada qərar verilir. Bu ayrılıq ona görədir ki, mətnin ayrılması
/// Flutter-siz sınana bilsin.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hashtag_feed.dart';
import 'main.dart' show PersonPage;
import 'user_profile.dart';
import 'app/i18n.dart';

/// `#söz` — həmin hashtagın lenti.
void openHashtag(BuildContext context, UserProfile me, String tag) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HashtagFeedPage(profile: me, tag: tag)),
  );
}

/// `@ad` — həmin adamın profili.
///
/// Bizdə istifadəçi adı yox, görünən ad var. Ona görə ad üzrə axtarıb
/// tapırıq. Eyni adlı bir neçə adam ola bilər — birincisi açılır,
/// çünki mətndə hansının nəzərdə tutulduğu yazılmır.
Future<void> openMention(
  BuildContext context,
  UserProfile me,
  String name,
) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('"$name" adlı istifadəçi tapılmadı.')),
      );
      return;
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonPage(
          currentProfile: me,
          targetUid: snap.docs.first.id,
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(t('Profil açılmadı.'))),
    );
  }
}

/// Link — brauzerdə açılır.
Future<void> openPostLink(BuildContext context, String raw) async {
  final messenger = ScaffoldMessenger.of(context);

  // "www.vibe.az" kimi yazılışda sxem yoxdur — `Uri.parse` onu
  // nisbi yol sayır və heç nə açılmır.
  final url = raw.startsWith('http') ? raw : 'https://$raw';

  try {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) messenger.showSnackBar(SnackBar(content: Text('Link açılmadı: $url')));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(t('Link açılmadı.'))));
  }
}
