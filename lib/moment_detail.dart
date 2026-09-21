import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_chrome.dart';
import 'post_links.dart';
import 'rich_post_text.dart';
import 'user_profile.dart';
import 'moment_comments.dart';

class MomentDetailPage extends StatelessWidget {
  const MomentDetailPage({
    super.key,
    required this.profile,
    required this.momentId,
  });

  final UserProfile profile;
  final String momentId;

  @override
  Widget build(BuildContext context) {
    final ref =
        FirebaseFirestore.instance.collection('moments').doc(momentId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'An',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xffff2bd6),
              ),
            );
          }

          final d = snap.data!.data() ?? {};
          final imageUrl = '${d['imageUrl'] ?? ''}';

          return ListView(
            children: [
              AspectRatio(
                aspectRatio: .85,
                child: imageUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xff151020),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                          size: 56,
                        ),
                      )
                    : VibePhoto(url: imageUrl, name: 'VIBE'),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xff8b5cff),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '@${d['ownerName'] ?? 'VIBE'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: ref
                          .collection('likes')
                          .doc(profile.uid)
                          .snapshots(),
                      builder: (_, likeSnap) {
                        final active = likeSnap.data?.exists == true;
                        return IconButton(
                          onPressed: () async {
                            final like = ref
                                .collection('likes')
                                .doc(profile.uid);
                            if (active) {
                              await like.delete();
                            } else {
                              await like.set({
                                'createdAt': Timestamp.now(),
                              });
                            }
                          },
                          icon: Icon(
                            active
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: active
                                ? const Color(0xffff2bd6)
                                : Colors.white,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xff120d1d),
                        builder: (_) => MomentCommentsSheet(
                          momentId: momentId,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: RichPostText(
                    '${d['caption']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.45,
                    ),
                    onMention: (name) => openMention(context, profile, name),
                    onHashtag: (tag) => openHashtag(context, profile, tag),
                    onLink: (url) => openPostLink(context, url),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
