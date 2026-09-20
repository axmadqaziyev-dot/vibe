import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'countries.dart';
import 'gift_sheet.dart';
import 'main.dart' show PersonPage, RealChatPage;
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'vip.dart';

/// OTAQDA PROFİL KARTI.
///
/// Otaqda kiminsə şəklinə toxunanda açılır: çərçivəli avatar, nişanlar,
/// medal və hədiyyə sayı, altda isə əsas əməliyyatlar — izlə, hədiyyə
/// göndər, söhbətə keç. Moderator əlavə olaraq masaya dəvət edə və
/// otaqdan çıxara bilər.
Future<void> showRoomProfileCard(
  BuildContext context, {
  required UserProfile viewer,
  required String uid,
  required String name,
  bool canModerate = false,
  VoidCallback? onInvite,
  VoidCallback? onKick,
  FirebaseFirestore? database,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => _RoomProfileCard(
      viewer: viewer,
      uid: uid,
      fallbackName: name,
      canModerate: canModerate,
      onInvite: onInvite,
      onKick: onKick,
      database: database,
    ),
  );
}

class _RoomProfileCard extends StatelessWidget {
  const _RoomProfileCard({
    required this.viewer,
    required this.uid,
    required this.fallbackName,
    required this.canModerate,
    this.onInvite,
    this.onKick,
    this.database,
  });

  final UserProfile viewer;
  final String uid;
  final String fallbackName;
  final bool canModerate;
  final VoidCallback? onInvite;
  final VoidCallback? onKick;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  bool get isMe => uid == viewer.uid;

  Future<void> _toggleFollow(BuildContext context, bool following) async {
    final mine = db
        .collection('users')
        .doc(viewer.uid)
        .collection('following')
        .doc(uid);
    final theirs = db
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(viewer.uid);

    final batch = db.batch();
    if (following) {
      batch.delete(mine);
      batch.delete(theirs);
    } else {
      batch.set(mine, {
        'uid': uid,
        'name': fallbackName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(theirs, {
        'uid': viewer.uid,
        'name': viewer.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alınmadı. Yenidən sına.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = '${data['name'] ?? fallbackName}';
        final about = '${data['about'] ?? ''}'.trim();
        final tier = tierOf(data);
        final medals = earnedMedals(data).length;
        final gifts = int.tryParse('${data['giftReceived'] ?? 0}') ?? 0;
        final country = countryByCode('${data['countryCode'] ?? ''}');

        return Container(
          decoration: const BoxDecoration(
            color: vPanel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: vLine)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Çərçivəli avatar — halqanın rəngi VIP pilləsindəndir.
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: tier.colors),
                      boxShadow: [
                        BoxShadow(
                          color: tier.color.withValues(alpha: .45),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: vPanel,
                      ),
                      child: SizedBox(
                        width: 78,
                        height: 78,
                        child: ClipOval(
                          child: VibePhoto(
                            url: '${data['photoUrl'] ?? ''}',
                            name: name,
                            emoji: '${data['avatarEmoji'] ?? ''}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Column(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: vInk,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // ID — kopyalana bilir.
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ID kopyalandı.')),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ID: ${uid.length > 10 ? uid.substring(0, 10) : uid}',
                              style: const TextStyle(
                                color: vMuted,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.copy_rounded,
                                size: 13, color: vMuted),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Nişanlar sırası.
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          GenderAgeChip(
                            gender: genderCode(data),
                            age: '${data['age'] ?? ''}',
                            fontSize: 10.5,
                          ),
                          if (country != null)
                            _chip('${country.flag} ${country.code}'),
                          VipBadge(tier: tier, fontSize: 10.5),
                        ],
                      ),

                      if (about.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          about,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: vMuted,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Medal və hədiyyə kartları.
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        colors: const [Color(0xffffb347), Color(0xffff8a3d)],
                        icon: Icons.workspace_premium_rounded,
                        title: 'Medallar',
                        value: '$medals',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        colors: const [Color(0xffff2bd6), Color(0xffb02ba6)],
                        icon: Icons.card_giftcard_rounded,
                        title: 'Hədiyyələr',
                        value: compactCount(gifts),
                      ),
                    ),
                  ],
                ),

                if (canModerate && !isMe) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onInvite != null)
                        Expanded(
                          child: _smallAction(
                            icon: Icons.record_voice_over_rounded,
                            label: 'Masaya dəvət',
                            color: vMint,
                            onTap: () {
                              Navigator.pop(context);
                              onInvite!();
                            },
                          ),
                        ),
                      if (onInvite != null && onKick != null)
                        const SizedBox(width: 10),
                      if (onKick != null)
                        Expanded(
                          child: _smallAction(
                            icon: Icons.person_remove_rounded,
                            label: 'Otaqdan at',
                            color: vRose,
                            onTap: () {
                              Navigator.pop(context);
                              onKick!();
                            },
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: vLine),
                const SizedBox(height: 8),

                // Aşağı əməliyyat sırası.
                if (isMe)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Bu sənin profilindir',
                      style: TextStyle(color: vMuted, fontSize: 13),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: db
                              .collection('users')
                              .doc(viewer.uid)
                              .collection('following')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, snap) {
                            final following = snap.data?.exists == true;
                            return _action(
                              icon: following
                                  ? Icons.check_rounded
                                  : Icons.person_add_alt_1_rounded,
                              label: following ? 'İzlənir' : 'İzlə',
                              color: following ? vMint : vInk,
                              onTap: () => _toggleFollow(context, following),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _action(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Hədiyyə',
                          color: vPink,
                          onTap: () {
                            Navigator.pop(context);
                            showGiftSheet(
                              context,
                              fromUid: viewer.uid,
                              fromName: viewer.name,
                              toUid: uid,
                              toName: name,
                              database: database,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _action(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Söhbət',
                          color: vBlue,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RealChatPage(
                                  currentProfile: viewer,
                                  targetUid: uid,
                                  targetName: name,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _action(
                          icon: Icons.person_rounded,
                          label: 'Profil',
                          color: vPurple,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonPage(
                                  currentProfile: viewer,
                                  targetUid: uid,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: vLine),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: vInk,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _statCard({
    required List<Color> colors,
    required IconData icon,
    required String title,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _smallAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}
