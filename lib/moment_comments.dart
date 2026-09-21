/// Anın şərhləri — sap şəklində.
///
/// Əvvəl bu, düz siyahı idi: ad və mətn, vaxt yox, bəyənmə yox,
/// cavab yox. Beş nəfər danışanda kimin kimə nə dediyi itirdi.
///
/// İndi Threads qaydasıdır: hər şərhə cavab vermək olur, cavablar
/// kökün altında girintili görünür, hər şərhi ayrıca bəyənmək olur.
/// Sap quruluşu `comment_thread.dart`-dadır və ayrıca sınanır.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import 'chat_lock.dart';
import 'comment_thread.dart';
import 'legal.dart';
import 'post_links.dart';
import 'push_send.dart';
import 'rich_post_text.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';

class MomentCommentsSheet extends StatefulWidget {
  const MomentCommentsSheet({
    super.key,
    required this.momentId,
    required this.profile,
    this.database,
  });

  final String momentId;
  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends State<MomentCommentsSheet> {
  final controller = TextEditingController();
  final focus = FocusNode();

  bool sending = false;

  /// Kimə cavab yazılır. `null`-dırsa yeni kök şərhdir.
  ThreadComment? replyTo;

  /// Açılmış cavab qrupları — çox cavab siyahını boğmasın.
  final expanded = <String>{};

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get comments =>
      db.collection('moments').doc(widget.momentId).collection('comments');

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    // Söyüş süzgəci və mövzu süzgəci. Şərh açıq məzmundur —
    // paylaşımın özü ilə eyni qaydaya tabedir.
    if (!guardContent(context, text)) return;
    if (!guardTopic(context, text)) return;

    final target = replyTo;
    setState(() => sending = true);

    try {
      await comments.add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        // İki pillə qaydası: cavabın cavabı eyni kökə gedir.
        if (target != null) 'parentId': rootIdFor(target),
        if (target != null) 'replyToName': target.name,
        'likeCount': 0,
        'likedBy': <String>[],
        'createdAt': Timestamp.now(),
      });

      await db.collection('moments').doc(widget.momentId).set(
        {'commentCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      unawaited(_notify(text, target));

      controller.clear();
      if (mounted) {
        setState(() {
          replyTo = null;
          // Cavab yazıldısa qrupu açıq saxlayırıq — adam öz
          // yazdığını dərhal görsün.
          if (target != null) expanded.add(rootIdFor(target));
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şərh göndərilmədi.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  /// Şərhdən xəbər verir.
  ///
  /// İki nəfərə: paylaşımın sahibinə və (cavabdırsa) cavab verilən
  /// adama. Özünə bildiriş getmir — adam öz yazdığını onsuz da bilir.
  /// Eyni adam hər iki rolda olsa, bir dəfə xəbər alır.
  Future<void> _notify(String text, ThreadComment? target) async {
    final me = widget.profile.uid;
    final sent = <String>{me};

    Future<void> send(String uid, String title) async {
      if (uid.isEmpty || sent.contains(uid)) return;
      sent.add(uid);

      try {
        await db
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .add({
          'type': 'comment',
          'title': title,
          'body': text.length > 80 ? '${text.substring(0, 80)}…' : text,
          'fromUid': me,
          'momentId': widget.momentId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      unawaited(sendPushToUser(
        toUid: uid,
        title: title,
        body: text,
        fromName: widget.profile.name,
      ));
    }

    if (target != null) {
      await send(target.uid, '${widget.profile.name} sənə cavab verdi');
    }

    try {
      final moment =
          await db.collection('moments').doc(widget.momentId).get();
      final owner = '${moment.data()?['ownerUid'] ?? ''}';

      await send(owner, '${widget.profile.name} anına şərh yazdı');
    } catch (_) {}
  }

  /// Şərhi bəyənir və ya bəyənməni götürür.
  ///
  /// Ekranda əl ilə heç nə saymırıq. Firestore yazını əvvəlcə yerli
  /// yaddaşda tətbiq edir və dinləyici dərhal yeni dəyərlə oyanır —
  /// toxunuş ani görünür, server cavabı gələndə isə rəqəm iki dəfə
  /// sayılmır. Əl ilə hesablasaydıq, həmin ikiqat sayma olardı.
  Future<void> _toggleLike(ThreadComment comment) async {
    final on = comment.likedBy.contains(widget.profile.uid);

    try {
      await comments.doc(comment.id).set({
        'likeCount': FieldValue.increment(on ? -1 : 1),
        'likedBy': on
            ? FieldValue.arrayRemove([widget.profile.uid])
            : FieldValue.arrayUnion([widget.profile.uid]),
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bəyənmə yazılmadı.')),
        );
      }
    }
  }

  Future<void> _delete(ThreadComment comment) async {
    try {
      await comments.doc(comment.id).delete();
      await db.collection('moments').doc(widget.momentId).set(
        {'commentCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void _startReply(ThreadComment comment) {
    setState(() => replyTo = comment);
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
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
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: comments.limit(300).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: vPink),
                    );
                  }

                  final nodes = buildThread(
                    snap.data!.docs.map(
                      (d) => ThreadComment.from(d.id, {
                        ...d.data(),
                        'createdAt':
                            (d.data()['createdAt'] as Timestamp?)?.toDate(),
                      }),
                    ),
                  );

                  return Column(
                    children: [
                      _title(countComments(nodes)),
                      Expanded(
                        child: nodes.isEmpty
                            ? _empty()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 4, 14, 10),
                                itemCount: nodes.length,
                                itemBuilder: (context, i) => _node(nodes[i]),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _title(int count) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Row(
          children: [
            const Text(
              'Şərhlər',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$count',
                style: const TextStyle(
                  color: vPink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _empty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'İlk şərhi sən yaz 💜',
            textAlign: TextAlign.center,
            style: TextStyle(color: vMuted, fontSize: 13.5),
          ),
        ),
      );

  Widget _node(ThreadNode node) {
    final open = expanded.contains(node.comment.id);
    final replies = node.replies;

    // İki cavabdan çoxu qapalı başlayır: uzun sap bütün ekranı yeyir.
    final shown = open ? replies : replies.take(2).toList();
    final hidden = replies.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tile(node.comment),
        for (final reply in shown)
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: _tile(reply),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 0, 0, 10),
            child: PressableScale(
              onTap: () => setState(() => expanded.add(node.comment.id)),
              child: Row(
                children: [
                  Container(width: 18, height: 1, color: vLine),
                  const SizedBox(width: 8),
                  Text(
                    'Daha $hidden cavab',
                    style: const TextStyle(
                      color: vMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _tile(ThreadComment comment) {
    final mine = comment.uid == widget.profile.uid;
    final isLiked = comment.likedBy.contains(widget.profile.uid);
    final count = comment.likeCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: ClipOval(
              child: _CommentAvatar(uid: comment.uid, name: comment.name),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.name.isEmpty ? 'İstifadəçi' : comment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      shortAgo(comment.createdAt),
                      style: const TextStyle(color: vMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (comment.replyToName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '@${comment.replyToName}',
                      style: const TextStyle(
                        color: vPink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                RichPostText(
                  maskProfanity(comment.text),
                  style: const TextStyle(
                    color: Color(0xffe2dcee),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                  onMention: (name) =>
                      openMention(context, widget.profile, name),
                  onHashtag: (tag) => openHashtag(context, widget.profile, tag),
                  onLink: (url) => openPostLink(context, url),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PressableScale(
                      onTap: () => _startReply(comment),
                      child: const Text(
                        'Cavab ver',
                        style: TextStyle(
                          color: vMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 16),
                      PressableScale(
                        onTap: () => _delete(comment),
                        child: const Text(
                          'Sil',
                          style: TextStyle(
                            color: Color(0xffff8a9b),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            onTap: () => _toggleLike(comment),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                children: [
                  Icon(
                    isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 16,
                    color: isLiked ? vPink : vMuted,
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        color: isLiked ? vPink : vMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    final target = replyTo;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xff0d0917),
        border: Border(top: BorderSide(color: vLine)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 15, color: vPink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${target.name} şərhinə cavab',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: vPink, fontSize: 12),
                    ),
                  ),
                  PressableScale(
                    onTap: () => setState(() => replyTo = null),
                    child: const Icon(Icons.close_rounded,
                        size: 17, color: vMuted),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: target == null
                        ? 'Şərh yaz…'
                        : '${target.name} üçün cavab…',
                    hintStyle: const TextStyle(color: vMuted, fontSize: 13.5),
                    filled: true,
                    fillColor: const Color(0xff1b1426),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              PressableScale(
                onTap: sending ? null : _send,
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: vHot,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Şərh sahibinin şəkli.
///
/// Şəkil şərh sənədində saxlanılmır (köhnələrdə heç yoxdur), ona görə
/// istifadəçi sənədindən oxunur.
class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return VibePhoto(url: '', name: name);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) => VibePhoto(
        url: '${snap.data?.data()?['photoUrl'] ?? ''}',
        name: name,
      ),
    );
  }
}

/// "3 dəq", "2 saat", "5 gün".
String shortAgo(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inMinutes < 1) return 'indi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dəq';
  if (diff.inHours < 24) return '${diff.inHours} saat';
  if (diff.inDays < 7) return '${diff.inDays} gün';
  return '${(diff.inDays / 7).floor()} həftə';
}
