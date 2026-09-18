import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class VideoLibraryPage extends StatefulWidget {
  const VideoLibraryPage({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Video kitabxanam',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _tab('Videolarım', 0),
                _tab('Bəyəndiklərim', 1),
                _tab('Saxlanılanlar', 2),
                _tab('Repostlar', 3),
                _tab('Tarixçə', 4),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xff2a1b3e)),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _tab(String title, int value) {
    final active = tab == value;
    return InkWell(
      onTap: () => setState(() => tab = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (tab == 0) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .where('ownerUid', isEqualTo: widget.profile.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) => _videoGridFromDocs(snap),
      );
    }

    final collection = tab == 1
        ? 'likedVideos'
        : tab == 2
            ? 'savedVideos'
            : tab == 3
                ? 'reposts'
                : 'watchHistory';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .collection(collection)
          .orderBy(
            tab == 1
                ? 'likedAt'
                : tab == 2
                    ? 'savedAt'
                    : tab == 3
                        ? 'createdAt'
                        : 'watchedAt',
            descending: true,
          )
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xffff2bd6)),
          );
        }

        final ids = snap.data!.docs.map((e) => e.id).toList();
        if (ids.isEmpty) {
          return const Center(
            child: Text(
              'Hələ burada video yoxdur.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: ids.length,
          itemBuilder: (_, i) => FutureBuilder<
              DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('videos')
                .doc(ids[i])
                .get(),
            builder: (_, videoSnap) {
              if (!videoSnap.hasData) {
                return const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final doc = videoSnap.data!;
              if (!doc.exists) return const SizedBox.shrink();
              final d = doc.data() ?? {};

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff151020),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xff342743)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 64,
                      height: 84,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xff21172c),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
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
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _videoGridFromDocs(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
  ) {
    if (!snap.hasData) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xffff2bd6)),
      );
    }

    final docs = snap.data!.docs;
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'Hələ video paylaşmamısan.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: .72,
      ),
      itemBuilder: (_, i) {
        final d = docs[i].data();
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff151020),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xff342743)),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  '${d['caption'] ?? ''}',
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
  }
}
