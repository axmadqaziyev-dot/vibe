/// Bir hashtagın lenti.
///
/// `#bakı` sözünə toxunanda həmin sözlə paylaşılan bütün anlar
/// açılır. Axtarış mətnin içində deyil, paylaşım yaradılanda yazılan
/// `tags` siyahısında gedir — belə sorğu həm sürətlidir, həm də
/// böyük hərf/kiçik hərf fərqindən asılı deyil.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'moment_detail.dart';
import 'rich_post_text.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

class HashtagFeedPage extends StatelessWidget {
  const HashtagFeedPage({
    super.key,
    required this.profile,
    required this.tag,
    this.database,
  });

  final UserProfile profile;
  final String tag;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final key = normalizeTag(tag);

    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        foregroundColor: Colors.white,
        title: Text(
          '#$key',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // `orderBy` qəsdən yoxdur: `array-contains` ilə birlikdə
        // Firestore-da ayrıca indeks tələb edir. Sıralama burada,
        // cihazda aparılır — yüz sənəd üçün bu, ucuzdur.
        stream: db
            .collection('moments')
            .where('tags', arrayContains: key)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(t('Lent açılmadı.'), style: TextStyle(color: vMuted)),
            );
          }

          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: vPink),
            );
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final x = a.data()['createdAt'];
              final y = b.data()['createdAt'];
              if (x is Timestamp && y is Timestamp) return y.compareTo(x);
              return 0;
            });

          if (docs.isEmpty) return _empty(key);

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _tile(context, docs[i]),
          );
        },
      ),
    );
  }

  Widget _empty(String key) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tag_rounded, size: 46, color: vPurple),
              const SizedBox(height: 12),
              Text(
                '#$key ilə hələ paylaşım yoxdur',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Birinci sən ol — anını paylaşanda bu sözü yaz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      );

  Widget _tile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = '${data['ownerName'] ?? 'İstifadəçi'}';
    final caption = '${data['caption'] ?? ''}'.trim();

    return PressableScale(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MomentDetailPage(
            momentId: doc.id,
            profile: profile,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: vPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: vLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: ClipOval(
                child: VibePhoto(
                  url: '${data['ownerPhoto'] ?? ''}',
                  name: name,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xffd8d1e6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
