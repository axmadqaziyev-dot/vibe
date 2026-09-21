import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

class VideoSearchPage extends StatefulWidget {
  const VideoSearchPage({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<VideoSearchPage> createState() => _VideoSearchPageState();
}

class _VideoSearchPageState extends State<VideoSearchPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: TextField(
          autofocus: true,
          onChanged: (value) => setState(
            () => query = value.trim().toLowerCase(),
          ),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t('Video, istifadəçi, hashtag axtar...'),
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .where('visibility', isEqualTo: 'public')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xffff2bd6),
              ),
            );
          }

          final docs = snap.data!.docs.where((doc) {
            if (query.isEmpty) return true;
            final d = doc.data();
            final text =
                '${d['ownerName'] ?? ''} ${d['caption'] ?? ''}'.toLowerCase();
            return text.contains(query);
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nəticə tapılmadı.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff151020),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xff342743),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 62,
                      height: 82,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xff21172c),
                          borderRadius: BorderRadius.all(
                            Radius.circular(12),
                          ),
                        ),
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white54,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${d['ownerName'] ?? 'VIBE'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${d['caption'] ?? ''}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
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
