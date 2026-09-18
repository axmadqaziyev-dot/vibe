import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class HashtagExplorerPage extends StatefulWidget {
  const HashtagExplorerPage({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<HashtagExplorerPage> createState() => _HashtagExplorerPageState();
}

class _HashtagExplorerPageState extends State<HashtagExplorerPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Hashtag kəşf et',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(
                () => query = v.trim().toLowerCase(),
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '#musiqi, #baku, #vibe...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.tag_rounded,
                  color: Color(0xff8b5cff),
                ),
                filled: true,
                fillColor: const Color(0xff151020),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  final caption =
                      '${doc.data()['caption'] ?? ''}'.toLowerCase();

                  if (query.isEmpty) return caption.contains('#');

                  final normalized =
                      query.startsWith('#') ? query : '#$query';

                  return caption.contains(normalized);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Hashtag nəticəsi yoxdur.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xff8b5cff),
                        child: Icon(
                          Icons.tag_rounded,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        '@${d['ownerName'] ?? 'VIBE'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        '${d['caption'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
