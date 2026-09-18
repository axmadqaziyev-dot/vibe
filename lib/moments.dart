import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';
import 'moment_create.dart';
import 'moment_detail.dart';
import 'moment_comments.dart';

class MomentsPage extends StatelessWidget {
  const MomentsPage({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Anlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton.filled(
            tooltip: 'Yeni An',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateMomentPage(profile: profile),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('moments')
            .where('visibility', isEqualTo: 'public')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (_, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Anlar yüklənmədi:\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xffff2bd6),
              ),
            );
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Hələ An paylaşılmayıb.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data();
              final imageUrl = '${d['imageUrl'] ?? ''}';

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xff151020),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xff342743),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xff8b5cff),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        '${d['ownerName'] ?? 'VIBE'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MomentDetailPage(
                            profile: profile,
                            momentId: doc.id,
                          ),
                        ),
                      ),
                      child: AspectRatio(
                        aspectRatio: .92,
                        child: imageUrl.isEmpty
                            ? const ColoredBox(
                                color: Color(0xff21172c),
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.white38,
                                  size: 56,
                                ),
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                      child: Row(
                        children: [
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: doc.reference
                                .collection('likes')
                                .doc(profile.uid)
                                .snapshots(),
                            builder: (_, mineSnap) => IconButton(
                              onPressed: () async {
                                final like = doc.reference
                                    .collection('likes')
                                    .doc(profile.uid);

                                if (mineSnap.data?.exists == true) {
                                  await like.delete();
                                } else {
                                  await like.set({
                                    'createdAt': Timestamp.now(),
                                  });
                                }
                              },
                              icon: Icon(
                                mineSnap.data?.exists == true
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: mineSnap.data?.exists == true
                                    ? const Color(0xffff2bd6)
                                    : Colors.white,
                              ),
                            ),
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: doc.reference
                                .collection('likes')
                                .snapshots(),
                            builder: (_, likeSnap) => Text(
                              '${likeSnap.data?.docs.length ?? 0}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () =>
                                showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: const Color(0xff120d1d),
                              builder: (_) => MomentCommentsSheet(
                                momentId: doc.id,
                                profile: profile,
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ('${d['caption'] ?? ''}'.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          '${d['caption']}',
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
