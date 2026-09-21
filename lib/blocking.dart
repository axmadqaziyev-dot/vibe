// BLOKLAMA — iki tərəfli.
//
// users/{me}/blocked/{peer}    → mən onu bloklamışam
// users/{peer}/blockedBy/{me}  → onun tərəfində güzgü qeyd
//
// Güzgü qeyd olmasa, bloklanan adam yenə mesaj yaza bilərdi:
// qarşı tərəf öz sənədində kimin onu bloklamasını görməlidir.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// İki nəfər arasındakı blok vəziyyəti.
class BlockState {
  const BlockState({required this.iBlocked, required this.blockedMe});

  /// Mən onu bloklamışam.
  final bool iBlocked;

  /// O məni bloklayıb.
  final bool blockedMe;

  bool get blocked => iBlocked || blockedMe;

  static const none = BlockState(iBlocked: false, blockedMe: false);
}

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// RealChatPage ilə eyni qayda: uid-lər sıralanıb "_" ilə birləşir.
String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return '${ids[0]}_${ids[1]}';
}

DocumentReference<Map<String, dynamic>> _blockedRef(String me, String peer) =>
    _db.collection('users').doc(me).collection('blocked').doc(peer);


/// Bloklayır: həm öz siyahıma, həm də qarşı tərəfin "blockedBy" siyahısına yazır.
Future<void> blockUser({
  required String myUid,
  required String myName,
  required String targetUid,
  required String targetName,
  FirebaseFirestore? database,
}) async {
  final db = database ?? _db;
  final batch = db.batch();

  batch.set(db.collection('users').doc(myUid).collection('blocked').doc(targetUid), {
    'uid': targetUid,
    'name': targetName,
    'createdAt': FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('users').doc(targetUid).collection('blockedBy').doc(myUid), {
    'uid': myUid,
    'name': myName,
    'createdAt': FieldValue.serverTimestamp(),
  });

  await batch.commit();

  // Söhbət sənədinə də yazılır — Firestore qaydaları bunu oxuyub
  // bloklanan tərəfin mesaj yazmasını server səviyyəsində dayandırır.
  try {
    await db.collection('chats').doc(chatIdFor(myUid, targetUid)).set({
      'blockedBy': FieldValue.arrayUnion([myUid]),
    }, SetOptions(merge: true));
  } catch (_) {}
}

/// Bloku götürür.
Future<void> unblockUser({
  required String myUid,
  required String targetUid,
  FirebaseFirestore? database,
}) async {
  final db = database ?? _db;
  final batch = db.batch();

  batch.delete(db.collection('users').doc(myUid).collection('blocked').doc(targetUid));
  batch.delete(db.collection('users').doc(targetUid).collection('blockedBy').doc(myUid));

  await batch.commit();

  try {
    await db.collection('chats').doc(chatIdFor(myUid, targetUid)).set({
      'blockedBy': FieldValue.arrayRemove([myUid]),
    }, SetOptions(merge: true));
  } catch (_) {}
}

/// İki istiqamətli blok vəziyyətini canlı izləyir.
Stream<BlockState> watchBlockState(String myUid, String peerUid) {
  if (myUid.isEmpty || peerUid.isEmpty || myUid == peerUid) {
    return Stream.value(BlockState.none);
  }

  return _blockedRef(myUid, peerUid).snapshots().asyncExpand(
    (mine) => _db
        .collection('users')
        .doc(myUid)
        .collection('blockedBy')
        .doc(peerUid)
        .snapshots()
        .map(
          (theirs) => BlockState(
            iBlocked: mine.exists,
            blockedMe: theirs.exists,
          ),
        ),
  );
}

/// Mənim görməməli olduğum bütün uid-lər (mən bloklamışam + məni bloklayıblar).
Stream<Set<String>> watchHiddenUids(String myUid, {FirebaseFirestore? database}) {
  final db = database ?? _db;
  final blocked = db
      .collection('users')
      .doc(myUid)
      .collection('blocked')
      .snapshots();
  final blockedBy = db
      .collection('users')
      .doc(myUid)
      .collection('blockedBy')
      .snapshots();

  return blocked.asyncExpand(
    (a) => blockedBy.map(
      (b) => {...a.docs.map((e) => e.id), ...b.docs.map((e) => e.id)},
    ),
  );
}

/// Söhbətin yuxarısında görünən xəbərdarlıq zolağı.
class BlockBanner extends StatelessWidget {
  const BlockBanner({
    super.key,
    required this.state,
    required this.name,
    this.onUnblock,
  });

  final BlockState state;
  final String name;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    if (!state.blocked) return const SizedBox.shrink();

    final iBlocked = state.iBlocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      color: const Color(0xff2a1220),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: vRose, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              iBlocked
                  ? '$name bloklanıb. Mesaj göndərə bilməzsən.'
                  : 'Bu istifadəçi səni bloklayıb.',
              style: const TextStyle(
                color: Color(0xffffc9d3),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          if (iBlocked && onUnblock != null) ...[
            const SizedBox(width: 8),
            PressableScale(
              onTap: onUnblock,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: vRose.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: vRose.withValues(alpha: .6)),
                ),
                child: const Text(
                  'Blokdan çıxar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bloklanmış istifadəçilərin siyahısı (Ayarlar səhifəsi üçün).
class BlockedListPage extends StatelessWidget {
  const BlockedListPage({super.key, required this.myUid});

  final String myUid;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: vBg,
    appBar: AppBar(
      backgroundColor: const Color(0xff0b0711),
      foregroundColor: Colors.white,
      title: const Text(
        'Bloklanmış istifadəçilər',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('blocked')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: vPink));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 46, color: vMuted),
                  SizedBox(height: 14),
                  Text(
                    'Bloklanmış istifadəçi yoxdur',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xff2a183f),
                child: Text(
                  '${d['name'] ?? '?'}'.characters.firstOrNull?.toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              title: Text(
                '${d['name'] ?? 'İstifadəçi'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              trailing: TextButton(
                onPressed: () async {
                  await unblockUser(myUid: myUid, targetUid: docs[index].id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('Blok götürüldü.'))),
                  );
                },
                child: Text(t('Blokdan çıxar'), style: TextStyle(color: vPink)),
              ),
            );
          },
        );
      },
    ),
  );
}
