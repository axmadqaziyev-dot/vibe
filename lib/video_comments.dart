import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class VideoCommentsSheet extends StatefulWidget {
  const VideoCommentsSheet({
    super.key,
    required this.videoId,
    required this.profile,
  });

  final String videoId;
  final UserProfile profile;

  @override
  State<VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

class _VideoCommentsSheetState extends State<VideoCommentsSheet> {
  final controller = TextEditingController();
  bool sending = false;
  String? replyingToId;
  String? replyingToName;

  CollectionReference<Map<String, dynamic>> get comments =>
      FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.videoId)
          .collection('comments');

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);
    try {
      await comments.add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        'createdAt': Timestamp.now(),
        'replyToId': replyingToId,
        'replyToName': replyingToName,
      });

      controller.clear();
      replyingToId = null;
      replyingToName = null;
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> toggleLike(DocumentReference<Map<String, dynamic>> ref) async {
    final like = ref.collection('likes').doc(widget.profile.uid);
    final snap = await like.get();

    if (snap.exists) {
      await like.delete();
    } else {
      await like.set({'createdAt': Timestamp.now()});
    }
  }

  Future<void> deleteComment(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await ref.delete();
  }

  void replyTo(
    String id,
    String name,
  ) {
    setState(() {
      replyingToId = id;
      replyingToName = name;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .76,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: comments.snapshots(),
              builder: (_, snap) => Text(
                'Şərhlər · ${snap.data?.docs.length ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: comments
                    .orderBy('createdAt', descending: true)
                    .limit(300)
                    .snapshots(),
                builder: (_, snap) {
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
                        'İlk şərhi sən yaz 💜',
                        style: TextStyle(color: Colors.white60),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data();
                      final mine = d['uid'] == widget.profile.uid;
                      final name = '${d['name'] ?? 'VIBE'}';
                      final replyName = '${d['replyToName'] ?? ''}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xff151020),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xff8b5cff),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (mine)
                                PopupMenuButton<String>(
                                  color: const Color(0xff21172c),
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    color: Colors.white54,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      deleteComment(doc.reference);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Şərhi sil',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (replyName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '@$replyName cavab',
                                    style: const TextStyle(
                                      color: Color(0xffb995ff),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              Text(
                                '${d['text'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => replyTo(doc.id, name),
                                    child: const Text(
                                      'Cavab ver',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: doc.reference
                                        .collection('likes')
                                        .snapshots(),
                                    builder: (_, likeCount) => Text(
                                      '${likeCount.data?.docs.length ?? 0} bəyənmə',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: doc.reference
                                .collection('likes')
                                .doc(widget.profile.uid)
                                .snapshots(),
                            builder: (_, mineLike) => IconButton(
                              onPressed: () => toggleLike(doc.reference),
                              icon: Icon(
                                mineLike.data?.exists == true
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: mineLike.data?.exists == true
                                    ? const Color(0xffff2bd6)
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (replyingToName != null)
              Container(
                width: double.infinity,
                color: const Color(0xff1b1328),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@$replyingToName istifadəçisinə cavab',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        replyingToId = null;
                        replyingToName = null;
                      }),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: replyingToName == null
                            ? 'Şərh yaz...'
                            : '@$replyingToName cavab yaz...',
                        hintStyle: const TextStyle(
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: const Color(0xff21172c),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
