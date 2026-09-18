import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class MomentCommentsSheet extends StatefulWidget {
  const MomentCommentsSheet({
    super.key,
    required this.momentId,
    required this.profile,
  });

  final String momentId;
  final UserProfile profile;

  @override
  State<MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends State<MomentCommentsSheet> {
  final controller = TextEditingController();
  bool sending = false;

  CollectionReference<Map<String, dynamic>> get comments =>
      FirebaseFirestore.instance
          .collection('moments')
          .doc(widget.momentId)
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
      });
      controller.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
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
        height: MediaQuery.of(context).size.height * .72,
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
            const Text(
              'Şərhlər',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: comments
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

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'İlk şərhi sən yaz 💜',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xff2d2540)),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xff8b5cff),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          '${d['name'] ?? 'VIBE'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${d['text'] ?? ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  );
                },
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
                        hintText: 'Şərh yaz...',
                        hintStyle: const TextStyle(color: Colors.white38),
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
