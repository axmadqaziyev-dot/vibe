import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class CreatorDashboardPage extends StatelessWidget {
  const CreatorDashboardPage({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final videos = FirebaseFirestore.instance
        .collection('videos')
        .where('ownerUid', isEqualTo: profile.uid);

    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Creator Studio',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: videos.snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          int views = 0;
          int shares = 0;

          for (final doc in docs) {
            final d = doc.data();
            views += int.tryParse('${d['views'] ?? 0}') ?? 0;
            shares += int.tryParse('${d['shares'] ?? 0}') ?? 0;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Ümumi göstəricilər',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      Icons.smart_display_rounded,
                      '${docs.length}',
                      'Videolar',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _stat(
                      Icons.visibility_rounded,
                      '$views',
                      'Baxış',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _stat(
                      Icons.share_rounded,
                      '$shares',
                      'Paylaşım',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Videoların performansı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final doc in docs)
                _videoTile(doc.data()),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xff151020),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff342743)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xff8b5cff)),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoTile(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff151020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff342743)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.play_circle_fill_rounded,
            color: Color(0xffff2bd6),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${d['caption'] ?? 'Video'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${d['views'] ?? 0} baxış',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
