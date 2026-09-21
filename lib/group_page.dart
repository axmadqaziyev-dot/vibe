/// Qrup söhbəti.
///
/// İki nəfərlik söhbətdən üç fərqi var:
///
/// * mesajın yanında **kimin yazdığı** görünür — qrupda bu olmasa
///   yazışma anlaşılmaz olur;
/// * yazmaq icazəyə bağlıdır (`group_chat.dart`);
/// * başlıq qrupun şəkli və üzv sayıdır.
///
/// Mövcud iki nəfərlik söhbətin koduna toxunulmur: qrup ayrı
/// kolleksiyada, ayrı ekrandadır. Belə olanda qrupda nəsə pozulsa,
/// adi yazışma işləməkdə davam edir.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_filter.dart';
import 'chat_lock.dart';
import 'group_chat.dart';
import 'group_info_sheet.dart';
import 'legal.dart';
import 'media_store.dart';
import 'photo_pick.dart';
import 'push_send.dart';
import 'server_time.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({
    super.key,
    required this.profile,
    required this.groupId,
    this.database,
  });

  final UserProfile profile;
  final String groupId;
  final FirebaseFirestore? database;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final controller = TextEditingController();
  final focus = FocusNode();

  bool sending = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get ref =>
      db.collection('groups').doc(widget.groupId);

  CollectionReference<Map<String, dynamic>> get messages =>
      ref.collection('messages');

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // GÖNDƏRMƏ
  // ----------------------------------------------------------

  Future<void> _send(GroupInfo group) async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;

    final blocked = group.writeBlockReason(widget.profile.uid);
    if (blocked != null) {
      _toast(blocked);
      return;
    }

    if (!guardContent(context, text)) return;
    if (!guardTopic(context, text)) return;

    setState(() => sending = true);

    try {
      await _write(
        {'text': text, 'type': 'text'},
        preview: text,
        group: group,
      );
      controller.clear();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _sendPhoto(GroupInfo group) async {
    if (group.writeBlockReason(widget.profile.uid) != null) return;

    final files = await pickGalleryPhotos(max: 3);
    if (files.isEmpty || !mounted) return;

    setState(() => sending = true);

    try {
      for (final file in files) {
        final image = compressToStoredImage(
          file.bytes,
          fullWidth: 1080,
          thumbWidth: 320,
        );
        if (image == null) continue;

        await _write(
          {'text': '', 'type': 'photo', 'photo': image.thumb},
          preview: '📷 Şəkil',
          group: group,
          full: image.full,
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  /// Mesajı yazır və qrupun başlığını yeniləyir.
  Future<void> _write(
    Map<String, dynamic> body, {
    required String preview,
    required GroupInfo group,
    String? full,
  }) async {
    try {
      final message = messages.doc();
      final batch = db.batch();

      batch.set(message, {
        ...body,
        'senderId': widget.profile.uid,
        // Ad mesajın içində saxlanılır: hər mesaj üçün istifadəçi
        // sənədini oxumaq qrupda onlarla sorğu deməkdir.
        'senderName': widget.profile.name,
        'createdAt': Timestamp.now(),
      });

      if (full != null) {
        batch.set(message.collection('media').doc('full'), {'data': full});
      }

      // Oxunmamış sayğacı hər üzv üçün ayrıca artır.
      final unread = <String, Object>{};
      for (final uid in group.members) {
        if (uid != widget.profile.uid) {
          unread[uid] = FieldValue.increment(1);
        }
      }

      batch.set(ref, {
        'lastMessage': '${widget.profile.name}: $preview',
        'lastSenderId': widget.profile.uid,
        'unread': unread,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      await batch.commit();

      for (final uid in group.members) {
        if (uid == widget.profile.uid) continue;
        unawaited(sendPushToUser(
          toUid: uid,
          title: group.name,
          body: '${widget.profile.name}: $preview',
          fromName: widget.profile.name,
        ));
      }
    } catch (_) {
      _toast('Mesaj göndərilmədi.');
    }
  }

  Future<void> _markRead() async {
    try {
      await ref.set({
        'unread': {widget.profile.uid: 0},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  // ----------------------------------------------------------
  // EKRAN
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: vBg,
            body: Center(child: CircularProgressIndicator(color: vPink)),
          );
        }

        if (!snap.data!.exists) {
          return _gone('Qrup silinib.');
        }

        final group = GroupInfo.from(widget.groupId, snap.data!.data()!);

        if (group.roleOf(widget.profile.uid) == GroupRole.outsider) {
          return _gone('Bu qrupda deyilsən.');
        }

        // Söhbət açıqdırsa oxunmamış sayğac sıfırlanır.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _markRead();
        });

        return Scaffold(
          backgroundColor: vBg,
          appBar: _bar(group),
          body: Column(
            children: [
              Expanded(child: _list(group)),
              _composer(group),
            ],
          ),
        );
      },
    );
  }

  Widget _gone(String text) => Scaffold(
        backgroundColor: vBg,
        appBar: AppBar(backgroundColor: vBg, foregroundColor: Colors.white),
        body: Center(
          child: Text(text, style: const TextStyle(color: vMuted)),
        ),
      );

  PreferredSizeWidget _bar(GroupInfo group) => AppBar(
        backgroundColor: const Color(0xff0b0711),
        foregroundColor: Colors.white,
        titleSpacing: 4,
        title: InkWell(
          onTap: () => showGroupInfo(
            context,
            profile: widget.profile,
            group: group,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: ClipOval(
                  child: VibePhoto(url: group.photo, name: group.name),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${group.members.length} üzv',
                      style: const TextStyle(color: vMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: t('Qrup haqqında'),
            onPressed: () => showGroupInfo(
              context,
              profile: widget.profile,
              group: group,
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      );

  Widget _list(GroupInfo group) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: messages
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: vPink),
            );
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) return _empty(group);

          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final mine = data['senderId'] == widget.profile.uid;

              // Ardıcıl mesajlarda ad təkrarlanmır — siyahı yüngül
              // görünsün.
              final previous =
                  i + 1 < docs.length ? docs[i + 1].data() : null;
              final sameAuthor =
                  previous?['senderId'] == data['senderId'];

              return _bubble(data, mine: mine, showName: !mine && !sameAuthor);
            },
          );
        },
      );

  Widget _empty(GroupInfo group) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: ClipOval(
                  child: VibePhoto(url: group.photo, name: group.name),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                group.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${group.members.length} nəfər burada. İlk sözü sən de.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: vMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _bubble(
    Map<String, dynamic> data, {
    required bool mine,
    required bool showName,
  }) {
    final type = '${data['type'] ?? 'text'}';
    final at = data['createdAt'];

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.only(bottom: 8),
        padding: type == 'photo'
            ? const EdgeInsets.all(5)
            : const EdgeInsets.fromLTRB(14, 10, 14, 9),
        decoration: BoxDecoration(
          gradient: mine ? vHot : null,
          color: mine ? null : const Color(0xff1b1426),
          borderRadius: BorderRadius.circular(18),
          border: mine ? null : Border.all(color: const Color(0xff352447)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 3),
                child: Text(
                  '${data['senderName'] ?? 'İstifadəçi'}',
                  style: const TextStyle(
                    color: Color(0xffd0b6ff),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (type == 'photo')
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(
                  image: vibeImageProvider('${data['photo'] ?? ''}') ??
                      const AssetImage('assets/sounds/chime.wav')
                          as ImageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => const SizedBox(
                    width: 160,
                    height: 120,
                    child: Icon(Icons.broken_image_rounded, color: vMuted),
                  ),
                ),
              )
            else
              Text(
                maskProfanity('${data['text'] ?? ''}'),
                style: const TextStyle(color: Colors.white, fontSize: 15.5),
              ),
            if (at is Timestamp)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _clock(at.toDate()),
                  style: TextStyle(
                    color: mine ? Colors.white70 : vMuted,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _clock(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _composer(GroupInfo group) {
    final blocked = group.writeBlockReason(widget.profile.uid);

    if (blocked != null) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          color: const Color(0xff1a1330),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 17, color: vMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  blocked,
                  style: const TextStyle(color: vMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: const BoxDecoration(
          color: Color(0xff0d0917),
          border: Border(top: BorderSide(color: Color(0xff2a1a3b))),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: t('Şəkil'),
              onPressed: sending ? null : () => _sendPhoto(group),
              icon: const Icon(Icons.add_photo_alternate_rounded,
                  color: Color(0xffff5bd6)),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: t('Qrupa yaz…'),
                  hintStyle: const TextStyle(color: vMuted, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xff1b1426),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(group),
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              onTap: sending ? null : () => _send(group),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: vHot,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    size: 19, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qrupun son fəaliyyət vaxtı — siyahıda işlədilir.
String groupAgo(Object? raw) {
  if (raw is! Timestamp) return '';

  final diff = sinceServer(raw.toDate());
  if (diff.inMinutes < 1) return 'indi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dəq';
  if (diff.inHours < 24) return '${diff.inHours} saat';
  return '${diff.inDays} gün';
}

/// Qrupa şəkil seçmək — yaratma və redaktə ekranları işlədir.
Future<StoredImage?> pickGroupPhoto() => pickStoredImage(
      source: ImageSource.gallery,
      fullWidth: 400,
      thumbWidth: 160,
      fullQuality: 70,
    );
