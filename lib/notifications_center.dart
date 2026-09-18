import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);
const _muted = Color(0xffa89fbd);

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key, required this.profile});
  final UserProfile profile;

  CollectionReference<Map<String, dynamic>> get ref =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('notifications');

  Future<void> _markAllRead() async {
    final snap = await ref.where('read', isEqualTo: false).limit(100).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Bildirişlər',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Hamısını oxu'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (_, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text(
                'Bildirişlər yüklənmədi.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _pink),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: _purple,
                    size: 62,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Hələ bildiriş yoxdur',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final doc = docs[i];
              final d = doc.data();
              final type = '${d['type'] ?? 'info'}';
              final read = d['read'] == true;
              final title = '${d['title'] ?? 'VIBE'}';
              final body = '${d['body'] ?? ''}';
              final createdAt = d['createdAt'];
              final date = createdAt is Timestamp ? createdAt.toDate() : null;

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => doc.reference.set(
                  {'read': true},
                  SetOptions(merge: true),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: read ? _panel : const Color(0xff21132d),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: read
                          ? const Color(0xff342743)
                          : const Color(0xff6e3d82),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _iconColor(type).withValues(alpha: .18),
                        child: Icon(_icon(type), color: _iconColor(type)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (!read)
                                  const CircleAvatar(
                                    radius: 4,
                                    backgroundColor: _pink,
                                  ),
                              ],
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: const TextStyle(color: _muted),
                              ),
                            ],
                            if (date != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _time(date),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
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
            },
          );
        },
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'follow':
        return Icons.person_add_alt_1_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'room':
        return Icons.mic_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'message':
        return const Color(0xff22a7ff);
      case 'follow':
        return _pink;
      case 'gift':
        return const Color(0xffffd86b);
      case 'room':
        return const Color(0xff35e18b);
      default:
        return _purple;
    }
  }

  String _time(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'indi';
    if (diff.inHours < 1) return '${diff.inMinutes} dəq əvvəl';
    if (diff.inDays < 1) return '${diff.inHours} saat əvvəl';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.profile,
    required this.onPressed,
  });

  final UserProfile profile;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(profile.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Bildirişlər',
              onPressed: onPressed,
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _pink,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _bg, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
