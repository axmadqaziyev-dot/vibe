import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';
import 'video_social_actions.dart';

class VideoCreatorProfilePage extends StatelessWidget {
  const VideoCreatorProfilePage({
    super.key,
    required this.currentProfile,
    required this.creatorUid,
    required this.creatorName,
  });

  final UserProfile currentProfile;
  final String creatorUid;
  final String creatorName;

  @override
  Widget build(BuildContext context) {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(creatorUid);

    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: Text(
          creatorName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (_, snap) {
          final d = snap.data?.data() ?? {};
          final photo = '${d['photoUrl'] ?? ''}';
          final name = '${d['name'] ?? creatorName}';

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xff8b5cff),
                  backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: VideoFollowButton(
                  profile: currentProfile,
                  targetUid: creatorUid,
                  targetName: name,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Videolar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .where('ownerUid', isEqualTo: creatorUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (_, videoSnap) {
                  if (!videoSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = videoSnap.data!.docs;
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          'Hələ video yoxdur',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: .72,
                    ),
                    itemBuilder: (_, i) {
                      final data = docs[i].data();
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff151020),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xff342743),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white54,
                                size: 40,
                              ),
                            ),
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 8,
                              child: Text(
                                '${data['caption'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
            ],
          );
        },
      ),
    );
  }
}
