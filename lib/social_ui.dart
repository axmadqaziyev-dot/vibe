import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show RealChatPage;
import 'user_profile.dart';
import 'preferences.dart';
import 'admin_panel.dart';
import 'party_rooms.dart';
import 'game_center.dart';
import 'vibe_levels.dart';
import 'vibe_ranking.dart';
import 'vibe_status.dart';
import 'profile_header.dart';
import 'blocking.dart';
import 'account_delete.dart';
import 'legal.dart';
import 'invite.dart';
import 'install_app.dart';
import 'app/i18n.dart';
import 'auth_phone.dart';
import 'push_notifications.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';
import 'media_store.dart';

const ink = Color(0xfff7f3ff);
const mutedInk = Color(0xffa89fbd);
const vibePink = Color(0xffff2bd6);
const vibePurple = Color(0xff8b5cff);
const vibeBlue = Color(0xff22a7ff);
const vibeBg = Color(0xff070510);
const vibePanel = Color(0xff121020);

class SocialSurface extends StatelessWidget {
  const SocialSurface({
    super.key,
    required this.child,
    this.color = const Color(0xff120b22),
  });
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Material(
      type: MaterialType.transparency,
      child: SafeArea(bottom: false, child: child),
    ),
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: padding,
    decoration: BoxDecoration(
      color: vibePanel.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xff2d2540)),
      boxShadow: const [
        BoxShadow(color: Color(0x331c0b34), blurRadius: 24, offset: Offset(0, 10)),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.name,
    this.size = 64,
    this.online = false,
    this.symbol = '',
    this.imageUrl = '',
  });
  final String name, symbol, imageUrl;
  final double size;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffff3bd4), Color(0xff814dff), Color(0xff1d9fff)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .8), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x66ff2bd6), blurRadius: 16)],
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(color: Color(0xff171323), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: vibeImageProvider(imageUrl) != null
                ? Image(
                    image: vibeImageProvider(imageUrl)!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        symbol.isNotEmpty
                            ? symbol
                            : (name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase()),
                        style: TextStyle(fontSize: size * .36, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  )
                : Text(
                    symbol.isNotEmpty
                        ? symbol
                        : (name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase()),
                    style: TextStyle(
                      fontSize: size * .36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xff2de28a),
                shape: BoxShape.circle,
                border: Border.all(color: vibeBg, width: 3),
              ),
            ),
          ),
      ],
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xffff4bdb), Color(0xff9b62ff), Color(0xff32a8ff)],
                ).createShader(r),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                    color: Colors.white,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(subtitle!, style: const TextStyle(color: mutedInk, fontSize: 13)),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class EmptySocial extends StatelessWidget {
  const EmptySocial(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.chat_bubble_outline_rounded,
  });
  final String title, description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    child: Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xff8b5cff), Color(0xffff2bd6)]),
            boxShadow: const [BoxShadow(color: Color(0x55ff2bd6), blurRadius: 20)],
          ),
          child: Icon(icon, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: Colors.white)),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(color: mutedInk, height: 1.5)),
      ],
    ),
  );
}


void openChat(
  BuildContext context,
  UserProfile profile,
  String uid,
  String name,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RealChatPage(
        currentProfile: profile,
        targetUid: uid,
        targetName: name,
      ),
    ),
  );
}

bool isUnread(Map<String, dynamic> data, String uid) {
  if (data['lastSenderId'] == null || data['lastSenderId'] == uid) return false;
  final updated = data['updatedAt'];
  final read = (data['readAt'] as Map?)?[uid];
  return updated is Timestamp &&
      (read is! Timestamp || updated.compareTo(read) > 0);
}


class VibeWalletCard extends StatelessWidget {
  const VibeWalletCard({super.key, required this.profile, this.database});
  final UserProfile profile;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _dailyGift(BuildContext context) async {
    final ref = db.collection('users').doc(profile.uid);
    try {
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final today = _todayKey();
        if ('${data['lastDailyGift'] ?? ''}' == today) {
          throw StateError('already');
        }
        tx.set(ref, {
          'coins': FieldValue.increment(25),
          'lastDailyGift': today,
        }, SetOptions(merge: true));
      });
      if (context.mounted) notifySocial(context, '+25 VIBE Coin hesabına əlavə olundu ✨');
    } on StateError {
      if (context.mounted) notifySocial(context, 'Bugünkü hədiyyəni artıq götürmüsən.');
    } catch (_) {
      if (context.mounted) notifySocial(context, 'Coin hədiyyəsi alınmadı. Yenidən sına.');
    }
  }

  Future<void> _buyVip(BuildContext context, int coins) async {
    if (coins < 200) {
      notifySocial(context, 'VIP üçün 200 coin lazımdır.');
      return;
    }
    final ref = db.collection('users').doc(profile.uid);
    try {
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final current = (data['coins'] as num?)?.toInt() ?? 0;
        if (current < 200) throw StateError('coins');
        final now = DateTime.now();
        final existing = data['vipUntil'];
        final base = existing is Timestamp && existing.toDate().isAfter(now)
            ? existing.toDate()
            : now;
        tx.set(ref, {
          'coins': current - 200,
          'vip': true,
          'vipUntil': Timestamp.fromDate(base.add(const Duration(days: 30))),
        }, SetOptions(merge: true));
      });
      if (context.mounted) notifySocial(context, 'VIP 30 gün aktiv edildi 👑');
    } on StateError {
      if (context.mounted) notifySocial(context, 'Coin balansı kifayət deyil.');
    } catch (_) {
      if (context.mounted) notifySocial(context, 'VIP aktiv edilmədi. Yenidən sına.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(profile.uid).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final coins = (d['coins'] as num?)?.toInt() ?? 0;
        final vipUntil = d['vipUntil'];
        final vipActive = d['vip'] == true &&
            vipUntil is Timestamp &&
            vipUntil.toDate().isAfter(DateTime.now());

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff21103a), Color(0xff151020), Color(0xff30112c)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xff4b2b66)),
            boxShadow: const [BoxShadow(color: Color(0x332f0b54), blurRadius: 24)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [vibePurple, vibePink]),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Flexible(
                            child: Text(
                              'VIBE Wallet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (vipActive) ...[
                            const SizedBox(width: 7),
                            const Text('VIP', style: TextStyle(color: Color(0xffffd76b), fontWeight: FontWeight.w900)),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text('$coins coin', style: const TextStyle(color: Color(0xffc9bdd9), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.diamond_rounded, color: Color(0xffffd76b)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _dailyGift(context),
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label: Text(t('Gündəlik +25')),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff6f4cff),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: vipActive ? null : () => _buyVip(context, coins),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(vipActive ? 'VIP aktivdir' : 'VIP · 200'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffffd76b),
                        side: const BorderSide(color: Color(0xff6b4c72)),
                        minimumSize: const Size(0, 46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileGalleryCard extends StatefulWidget {
  const ProfileGalleryCard({super.key, required this.profile, this.database});
  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<ProfileGalleryCard> createState() => _ProfileGalleryCardState();
}

class _ProfileGalleryCardState extends State<ProfileGalleryCard> {
  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  bool uploading = false;

  Future<void> _addPhoto() async {
    if (uploading) return;

    setState(() => uploading = true);
    try {
      final image = await pickStoredImage();
      if (image == null) return;

      await addGalleryPhoto(
        uid: widget.profile.uid,
        image: image,
        database: widget.database,
      );
      if (mounted) notifySocial(context, 'Şəkil qalereyaya əlavə olundu.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Şəkil saxlanmadı. Yenidən sına.');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _setProfilePhoto(String docId, String thumb, String full) async {
    try {
      await saveProfilePhoto(
        uid: widget.profile.uid,
        image: StoredImage(thumb: thumb, full: full),
        database: widget.database,
      );
      if (mounted) notifySocial(context, 'Profil şəkli dəyişdirildi.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Profil şəkli dəyişmədi.');
    }
  }

  Future<void> _removePhoto(String docId) async {
    try {
      await db
          .collection('users')
          .doc(widget.profile.uid)
          .collection('gallery')
          .doc(docId)
          .delete();
      if (mounted) notifySocial(context, 'Şəkil silindi.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Şəkil silinmədi.');
    }
  }

  void _photoMenu(String docId, String thumb, String full) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_rounded, color: vibePink),
              title: Text(t('Profil şəkli et'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                _setProfilePhoto(docId, thumb, full);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xffff6b7d)),
              title: Text(t('Şəkli sil'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                _removePhoto(docId);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('users')
          .doc(widget.profile.uid)
          .collection('gallery')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        final gallery = snap.data?.docs ?? const [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff121020),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xff332444)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto qalereya', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text(t('Şəkilə basıb profil şəkli edə bilərsən'), style: TextStyle(color: mutedInk, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: uploading ? null : _addPhoto,
                    style: IconButton.styleFrom(backgroundColor: const Color(0xff2b1740)),
                    icon: uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_a_photo_rounded),
                  ),
                ],
              ),
              if (gallery.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xff0d0a15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xff2c2039)),
                  ),
                  child: Text(t('Hələ şəkil əlavə edilməyib'), style: TextStyle(color: mutedInk)),
                ),
              ] else ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _photoMenu(
                        gallery[i].id,
                        '${gallery[i].data()['thumb'] ?? ''}',
                        '${gallery[i].data()['data'] ?? ''}',
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 92,
                          height: 112,
                          child: VibePhoto(
                            url: '${gallery[i].data()['thumb'] ?? ''}',
                            name: widget.profile.name,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class SocialProfile extends StatelessWidget {
  const SocialProfile({
    super.key,
    this.database,
    required this.profile,
    required this.navigate,
  });
  final FirebaseFirestore? database;
  final UserProfile profile;
  final ValueChanged<int> navigate;
  @override
  Widget build(BuildContext context) => SocialSurface(
    child: ListView(
      padding: const EdgeInsets.only(bottom: 10),
      children: [
        ProfileCoverHeader(
          profile: profile,
          database: database,
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditSocialProfile(profile: profile, data: const {}),
            ),
          ),
          onSettings: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SocialSettings(profile: profile)),
          ),
          onShare: () {
            Clipboard.setData(ClipboardData(text: "VIBE profili: ${profile.name} (ID: ${profile.uid})"));
            notifySocial(context, "Profil məlumatı kopyalandı.");
          },
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        MyVibeCard(uid: profile.uid, database: database),
        const SizedBox(height: 18),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (database ?? FirebaseFirestore.instance).collection('users').doc(profile.uid).snapshots(),
          builder: (context, adminSnap) {
            final d = adminSnap.data?.data() ?? const <String, dynamic>{};
            if (d['isAdmin'] != true && d['role'] != 'admin') return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xff26163f), Color(0xff42152f)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xff704a8f)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xff8b5cff),
                    child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  ),
                  title: const Text('Admin panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  subtitle: Text(t('Şikayətləri yoxla və idarə et'), style: TextStyle(color: mutedInk)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VibeAdminPanel())),
                ),
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: _ProfileShortcut(
                icon: Icons.sports_esports_rounded,
                title: 'Oyunlar',
                colors: const [Color(0xff8b5cff), Color(0xffff2bd6)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeGameCenterPage(profile: profile),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileShortcut(
                icon: Icons.military_tech_rounded,
                title: 'Level',
                colors: const [Color(0xffffb347), Color(0xffffd86b)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeLevelsPage(profile: profile),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileShortcut(
                icon: Icons.leaderboard_rounded,
                title: 'Ranking',
                colors: const [Color(0xff22a7ff), Color(0xff48e08a)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeRankingPage(profile: profile),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        VibeWalletCard(profile: profile, database: database),
        const SizedBox(height: 14),
        ProfileGalleryCard(profile: profile, database: database),
        const SizedBox(height: 20),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Öz rəngini seç',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Profilin də sənin kimi özəl olsun',
                style: TextStyle(color: mutedInk, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _decorTile(
                      context,
                      'Profil dekoru',
                      'Səni ifadə et',
                      Icons.auto_awesome,
                      const Color(0xff3a2a12),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditSocialProfile(
                            profile: profile,
                            data: const {},
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _decorTile(
                      context,
                      'Görünüş',
                      'Rəngini dəyiş',
                      Icons.palette_outlined,
                      const Color(0xff25193f),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocialSettings(profile: profile),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tez keçidlər',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 23),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _quick(
                      'Mesajlar',
                      Icons.chat_bubble_outline,
                      const Color(0xff132a46),
                      () => navigate(3),
                    ),
                  ),
                  Expanded(
                    child: _quick(
                      'Anlar',
                      Icons.auto_awesome_outlined,
                      const Color(0xff3a1730),
                      () => navigate(1),
                    ),
                  ),
                  Expanded(
                    child: _quick(
                      'Otaqlar',
                      Icons.meeting_room_outlined,
                      const Color(0xff153421),
                      () => navigate(2),
                    ),
                  ),
                  Expanded(
                    child: _quick(
                      'Ayarlar',
                      Icons.tune,
                      const Color(0xff2b1839),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocialSettings(profile: profile),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(t('Haqqımda')),
                subtitle: Text(
                  profile.about.isEmpty
                      ? 'Özün haqqında bir az danış'
                      : profile.about,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditSocialProfile(profile: profile, data: const {}),
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16, height: 1),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(profile.city),
                subtitle: Text(t('Şəhər')),
              ),
            ],
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'VIBE · Bir salamla başlasın',
              style: TextStyle(color: mutedInk, fontSize: 12),
            ),
          ),
        ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _quick(String title, IconData icon, Color color, VoidCallback tap) =>
      InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: ink),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
  Widget _decorTile(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    Color color,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: .45)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: ink),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 12, color: mutedInk)),
        ],
      ),
    ),
  );
}



class _ProfileShortcut extends StatelessWidget {
  const _ProfileShortcut({
    required this.icon,
    required this.title,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x3320002e), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


int _ageFrom(DateTime birth) => ageFromBirth(birth);

class EditSocialProfile extends StatefulWidget {
  const EditSocialProfile({
    super.key,
    required this.profile,
    required this.data,
  });
  final UserProfile profile;
  final Map<String, dynamic> data;
  @override
  State<EditSocialProfile> createState() => _EditSocialProfileState();
}

class _EditSocialProfileState extends State<EditSocialProfile> {
  late final name = TextEditingController(text: widget.profile.name);
  late final city = TextEditingController(text: widget.profile.city);
  late final about = TextEditingController(text: widget.profile.about);
  String symbol = '';
  String gender = '';
  DateTime? birthDate;
  bool saving = false, loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d =
          (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.profile.uid)
                  .get())
              .data() ??
          widget.data;
      if (!mounted) return;
      name.text = '${d['name'] ?? widget.profile.name}';
      city.text = '${d['city'] ?? widget.profile.city}';
      about.text = '${d['about'] ?? widget.profile.about}';
      final raw = d['birthDate'];
      setState(() {
        symbol = '${d['avatarEmoji'] ?? ''}';
        gender = '${d['gender'] ?? d['sex'] ?? ''}';
        birthDate = raw is Timestamp ? raw.toDate() : null;
        loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loaded = true);
        notifySocial(context, 'Profil yüklənmədi. Bağlantını yoxla.');
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    about.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || city.text.trim().isEmpty) {
      notifySocial(context, 'Ad və şəhəri doldur.');
      return;
    }
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .update({
            'name': name.text.trim(),
            'city': city.text.trim(),
            'about': about.text.trim(),
            'avatarEmoji': symbol,
            if (gender.isNotEmpty) 'gender': gender,
            if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
            if (birthDate != null) 'age': _ageFrom(birthDate!),
          });
      if (mounted) {
        notifySocial(context, 'Profil yadda saxlandı');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) notifySocial(context, 'Profil saxlanmadı. Yenidən sına.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Profili düzəlt'))),
    body: !loaded
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Center(
                child: SocialAvatar(name: name.text, symbol: symbol, size: 100),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cinsiyyət',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ana səhifədəki "Qızlar / Oğlanlar" filtri buna görə işləyir.',
                style: TextStyle(color: mutedInk, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final option in const [
                    ('qız', 'Qız', Icons.female_rounded),
                    ('oğlan', 'Oğlan', Icons.male_rounded),
                  ]) ...[
                    Expanded(
                      child: ChoiceChip(
                        avatar: Icon(option.$3, size: 18),
                        label: Text(option.$2),
                        selected: gender == option.$1,
                        onSelected: (_) => setState(
                          () => gender = gender == option.$1 ? '' : option.$1,
                        ),
                      ),
                    ),
                    if (option.$1 == 'qız') const SizedBox(width: 10),
                  ],
                ],
              ),
              const Divider(height: 26),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined, color: vibePink),
                title: Text(t('Doğum günü')),
                subtitle: Text(
                  birthDate == null
                      ? 'Seçilməyib — bürcün profilində görünəcək'
                      : '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}'
                            '  ·  ${zodiacName(birthDate!)}',
                  style: const TextStyle(color: mutedInk, fontSize: 12.5),
                ),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: birthDate ?? DateTime(now.year - 20, 1, 1),
                    firstDate: DateTime(now.year - 90),
                    lastDate: DateTime(now.year - 13, now.month, now.day),
                    helpText: 'Doğum tarixini seç',
                  );
                  if (picked != null) setState(() => birthDate = picked);
                },
              ),
              const Divider(height: 26),
              const Text(
                'Profil dekoru',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in [
                    '',
                    '🌸',
                    '🦋',
                    '🌙',
                    '🧸',
                    '🎮',
                    '🌿',
                    '✨',
                  ])
                    ChoiceChip(
                      label: Text(emoji.isEmpty ? 'Baş hərf' : emoji),
                      selected: symbol == emoji,
                      onSelected: (_) => setState(() => symbol = emoji),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: city,
                maxLength: 60,
                decoration: InputDecoration(labelText: t('Şəhər')),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: about,
                maxLength: 240,
                maxLines: 3,
                decoration: InputDecoration(labelText: t('Haqqımda')),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saxlanır…' : 'Yadda saxla'),
              ),
            ],
          ),
  );
}

void notifySocial(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class SocialSettings extends StatefulWidget {
  const SocialSettings({super.key, required this.profile, this.database});
  final UserProfile profile;

  /// Testlərdə saxta baza verilə bilsin deyə.
  final FirebaseFirestore? database;
  @override
  State<SocialSettings> createState() => _SocialSettingsState();
}

class _SocialSettingsState extends State<SocialSettings> {
  bool remember = true, busy = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => remember = LoginMemory(p).remember);
    });
  }

  /// Tətbiq dilini seçdirir — seçim dərhal tətbiq olunur və yadda qalır.
  Future<void> _pickLanguage(BuildContext context, AppLang current) async {
    final picked = await showModalBottomSheet<AppLang>(
      context: context,
      backgroundColor: const Color(0xff141020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            for (final lang in AppLang.values)
              ListTile(
                title: Text(
                  languageLabel(lang),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: lang == current
                    ? const Icon(Icons.check_rounded, color: Color(0xffff2bd6))
                    : null,
                onTap: () => Navigator.pop(sheet, lang),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked != null && picked != current) await setLanguage(picked);
  }

  Future<void> changeRemember(bool value) async {
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          value ? Persistence.LOCAL : Persistence.SESSION,
        );
      }
      await LoginMemory(
        await SharedPreferences.getInstance(),
      ).save(value, widget.profile.email);
      if (mounted) setState(() => remember = value);
    } catch (_) {
      if (mounted) {
        notifySocial(
          context,
          'Seçim saxlanmadı. Brauzerin yaddaş icazəsini yoxla.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Hesabdan çıxılsın?')),
        content: Text(t('Yenidən daxil olmaq üçün şifrən lazım olacaq.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('Ləğv et')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('Çıxış')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .update({'online': false, 'lastSeen': FieldValue.serverTimestamp()})
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      await stopPushNotifications(widget.profile.uid);
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        notifySocial(context, 'Çıxış alınmadı. Yenidən sına.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xff07040f),
        appBar: AppBar(
          backgroundColor: const Color(0xff07040f),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Ayarlar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _accountCard(),
            const SizedBox(height: 22),

            _sectionTitle('Görünüş'),
            _group([
              _appearanceRow(),
              _divider(),
              ValueListenableBuilder<AppLang>(
                valueListenable: appLanguage,
                builder: (context, lang, _) => _tile(
                  icon: Icons.language_rounded,
                  color: const Color(0xff22a7ff),
                  title: 'Dil',
                  subtitle: languageLabel(lang),
                  onTap: () => _pickLanguage(context, lang),
                ),
              ),
            ]),
            const SizedBox(height: 22),

            _sectionTitle('Hesab'),
            _group([
              _switchTile(
                icon: Icons.vpn_key_rounded,
                color: const Color(0xff8b5cff),
                title: 'Yadda saxla',
                subtitle: 'Tətbiqi bağlayanda hesab açıq qalsın',
                value: remember,
                onChanged: busy ? null : changeRemember,
              ),
              _divider(),
              _phoneRow(),
              _divider(),
              _tile(
                icon: Icons.group_add_rounded,
                color: const Color(0xffff2bd6),
                title: 'Dostlarını dəvət et',
                subtitle: 'Linki paylaş, birlikdə daha əyləncəlidir',
                onTap: () => showInviteSheet(
                  context,
                  name: widget.profile.name,
                  referrerUid: widget.profile.uid,
                ),
              ),
              if (shouldOfferInstall) ...[
                _divider(),
                _tile(
                  icon: Icons.install_mobile_rounded,
                  color: const Color(0xff48e08a),
                  title: 'Tətbiqi telefona qur',
                  subtitle: 'Ana ekranda ikon, tam ekran görünüş',
                  onTap: () {
                    if (isIosBrowser && !canInstallApp) {
                      showIosInstallHelp(context);
                    } else {
                      promptInstallApp();
                    }
                  },
                ),
              ],
            ]),
            const SizedBox(height: 22),

            _sectionTitle('Təhlükəsizlik'),
            _group([
              _tile(
                icon: Icons.block_rounded,
                color: const Color(0xffff657b),
                title: 'Bloklanmış istifadəçilər',
                subtitle: 'Siyahıya bax, blokdan çıxar',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlockedListPage(myUid: widget.profile.uid),
                  ),
                ),
              ),
              _divider(),
              _tile(
                icon: Icons.shield_outlined,
                color: const Color(0xff48e08a),
                title: 'İcma qaydaları',
                subtitle: 'Uyğunsuz məzmuna sıfır dözümlülük',
                onTap: () => LegalPage.openRules(context),
              ),
              _divider(),
              _tile(
                icon: Icons.mic_none_rounded,
                color: const Color(0xffffb347),
                title: 'Zəng icazələri',
                subtitle: 'Mikrofon və kamera icazələri haqqında',
                onTap: _showPermissionHelp,
              ),
            ]),
            const SizedBox(height: 22),

            _sectionTitle('Haqqında'),
            _group([
              _tile(
                icon: Icons.description_outlined,
                color: const Color(0xff8b5cff),
                title: 'İstifadə şərtləri',
                onTap: () => LegalPage.openTerms(context),
              ),
              _divider(),
              _tile(
                icon: Icons.lock_outline_rounded,
                color: const Color(0xff22a7ff),
                title: 'Məxfilik siyasəti',
                onTap: () => LegalPage.openPrivacy(context),
              ),
              _divider(),
              _tile(
                icon: Icons.support_agent_rounded,
                color: const Color(0xffffb347),
                title: 'Dəstək ilə əlaqə',
                subtitle: supportEmail,
                trailing: const Icon(Icons.copy_rounded,
                    size: 17, color: mutedInk),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: supportEmail));
                  notifySocial(context, 'E-poçt kopyalandı.');
                },
              ),
            ]),
            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xff2d2540)),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: Text(t('Hesabdan çıxış')),
              ),
            ),
            const SizedBox(height: 14),

            // App Store tələbi: hesab tətbiq daxilindən silinə bilməlidir.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final done = await showDeleteAccountFlow(
                          context,
                          widget.profile.uid,
                        );
                        if (done && mounted) {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        }
                      },
                child: const Text(
                  'Hesabı həmişəlik sil',
                  style: TextStyle(
                    color: Color(0xffff657b),
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'VIBE · 1.0.0',
                style: TextStyle(color: mutedInk, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  // ----------------------------------------------------------
  // AYARLAR ÜÇÜN KİÇİK HİSSƏLƏR
  // ----------------------------------------------------------

  /// Yuxarıdakı profil kartı.
  Widget _accountCard() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: (widget.database ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(widget.profile.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final name = '${data['name'] ?? widget.profile.name}';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff141020),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xff2d2540)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: ClipOval(
                    child: VibePhoto(
                      url: '${data['photoUrl'] ?? ''}',
                      name: name,
                      emoji: '${data['avatarEmoji'] ?? ''}',
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.profile.email.isEmpty
                            ? 'VIBE hesabı'
                            : widget.profile.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: mutedInk, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

  /// Hesaba bağlı telefon nömrəsi.
  ///
  /// Nömrə bağlıdırsa, şifrəni unudanda SMS ilə geri qayıtmaq olur.
  Widget _phoneRow() {
    // Testlərdə Firebase işə salınmır — sətir yenə də qurulmalıdır.
    String phone;
    try {
      phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    } catch (_) {
      phone = '';
    }

    return _tile(
      icon: Icons.phone_iphone_rounded,
      color: const Color(0xff2de28a),
      title: 'Telefon nömrəsi',
      subtitle: phone.isEmpty
          ? 'Bağlı deyil — şifrəni unutsan bərpa üçün lazımdır'
          : phone,
      trailing: phone.isEmpty
          ? const Icon(Icons.chevron_right_rounded, color: mutedInk, size: 20)
          : const Icon(Icons.verified_rounded,
              color: Color(0xff2de28a), size: 18),
      onTap: phone.isNotEmpty
          ? null
          : () async {
              final done = await showPhoneAuthSheet(
                context,
                mode: PhoneAuthMode.link,
              );
              if (done && mounted) {
                setState(() {});
                notifySocial(context, 'Nömrə hesabına bağlandı.');
              }
            },
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 9),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: mutedInk,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      );

  /// Ayar sətirlərini birləşdirən kart.
  ///
  /// Fon `Material`-dədir: əks halda ListTile-ın toxunuş dalğası
  /// rəngli fonun altında qalıb görünmür.
  Widget _group(List<Widget> children) => Material(
        color: const Color(0xff141020),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xff2d2540)),
          ),
          child: Column(children: children),
        ),
      );

  Widget _divider() => const Divider(
        height: 1,
        thickness: 1,
        indent: 58,
        color: Color(0xff221a33),
      );

  Widget _iconBox(IconData icon, Color color) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: _iconBox(icon, color),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: const TextStyle(color: mutedInk, fontSize: 12.5),
              ),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded,
                color: mutedInk, size: 20),
      );

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) =>
      SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xffff2bd6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: _iconBox(icon, color),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: mutedInk, fontSize: 12.5),
        ),
      );

  /// Rəng seçimi sətri.
  Widget _appearanceRow() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          children: [
            _iconBox(Icons.palette_rounded, const Color(0xffff2bd6)),
            const SizedBox(width: 16),
            const Text(
              'Rəng',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: appearance,
              builder: (context, selected, _) => Row(
                children: [
                  for (var i = 0; i < accentColors.length; i++)
                    GestureDetector(
                      onTap: () async {
                        appearance.value = i;
                        await (await SharedPreferences.getInstance())
                            .setInt('appearance', i);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: accentColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == selected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: i == selected
                            ? const Icon(Icons.check_rounded,
                                size: 15, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  void _showPermissionHelp() {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff141020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Zəng icazələri',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'Səsli zəng və səsli otaq üçün mikrofon, video zəng üçün kamera '
          'icazəsi lazımdır. İcazəni telefonun ayarlarından, brauzerdə isə '
          'ünvan sətrindəki sayt ayarlarından dəyişə bilərsən.',
          style: TextStyle(color: mutedInk, height: 1.55, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t('Anladım'),
                style: TextStyle(color: Color(0xffff2bd6))),
          ),
        ],
      ),
    );
  }
}

class SocialFeed extends StatefulWidget {
  const SocialFeed({super.key, required this.profile, this.rooms = false});
  final UserProfile profile;
  final bool rooms;
  @override
  State<SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends State<SocialFeed> {
  late final collection = FirebaseFirestore.instance.collection(
    widget.rooms ? 'socialRooms' : 'moments',
  );
  late final stream = collection
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();
  Future<void> create() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => ComposeSocial(room: widget.rooms),
    );
    if (text == null || !mounted) return;
    try {
      await collection.add({
        'owner': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) notifySocial(context, 'Paylaşım saxlanmadı. Yenidən sına.');
    }
  }

  Future<void> _toggleMomentLike(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final likes = (data['likes'] as List?)?.map((e) => '$e').toSet() ?? <String>{};
    final liked = likes.contains(widget.profile.uid);
    try {
      await ref.set({
        'likes': liked ? FieldValue.arrayRemove([widget.profile.uid]) : FieldValue.arrayUnion([widget.profile.uid]),
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted) notifySocial(context, 'Like saxlanmadı. Yenidən sına.');
    }
  }

  Future<void> _shareMoment(String text) async {
    await Clipboard.setData(ClipboardData(text: 'VIBE · $text'));
    if (mounted) notifySocial(context, 'Paylaşım mətni kopyalandı.');
  }

  void _openMomentComments(DocumentReference<Map<String, dynamic>> ref) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff120d1d),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: Column(
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 14),
              Text(t('Şərhlər'), style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ref.collection('comments').orderBy('createdAt', descending: true).limit(100).snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: vibePink));
                    if (snap.data!.docs.isEmpty) return Center(child: Text(t('İlk şərhi sən yaz 💜'), style: TextStyle(color: mutedInk)));
                    return ListView.builder(
                      reverse: true,
                      itemCount: snap.data!.docs.length,
                      itemBuilder: (_, i) {
                        final d = snap.data!.docs[i].data();
                        return ListTile(
                          leading: SocialAvatar(name: '${d['name'] ?? 'V'}', imageUrl: '${d['photoUrl'] ?? ''}', size: 38),
                          title: Text('${d['name'] ?? 'VIBE'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          subtitle: Text('${d['text'] ?? ''}', style: const TextStyle(color: Color(0xffd8d0e7))),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: controller, style: TextStyle(color: Colors.white), decoration: InputDecoration(hintText: t('Şərh yaz...')))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      try {
                        await ref.collection('comments').add({
                          'uid': widget.profile.uid,
                          'name': widget.profile.name,
                          'text': text,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        controller.clear();
                      } catch (_) {
                        if (sheetContext.mounted) notifySocial(sheetContext, 'Şərh göndərilmədi.');
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rooms) {
      return PartyRoomsPage(profile: widget.profile);
    }
    return SocialSurface(
      color: const Color(0xff120817),
    child: Column(
      children: [
        PageHeading(
          widget.rooms ? 'Otaqlar' : 'Anlar',
          subtitle: widget.rooms
              ? 'Canlı səsli otaqlara qoşul və söhbət et'
              : 'Şəkil, fikir və anlarını dostlarınla paylaş',
          action: IconButton.filled(
            tooltip: widget.rooms ? 'Otaq yarat' : 'An paylaş',
            onPressed: create,
            icon: const Icon(Icons.add),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptySocial(
                  'Yüklənmədi',
                  'Bağlantını yoxlayıb yenidən aç.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return ListView(
                  children: [
                    EmptySocial(
                      widget.rooms
                          ? 'İlk otağı sən yarat'
                          : 'İlk anı sən paylaş',
                      widget.rooms
                          ? 'Yuxarıdakı + ilə mövzu aç və dostlarınla yazış.'
                          : 'Yuxarıdakı + ilə günündən bir fikir paylaş.',
                      icon: widget.rooms
                          ? Icons.meeting_room_outlined
                          : Icons.auto_awesome_outlined,
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  for (final doc in snapshot.data!.docs)
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SocialAvatar(
                                name: '${doc.data()['name']}',
                                size: 44,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${doc.data()['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!widget.rooms &&
                                  doc.data()['owner'] == widget.profile.uid)
                                IconButton(
                                  tooltip: t('Paylaşımı sil'),
                                  onPressed: () async {
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(t('Paylaşım silinsin?')),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text(t('Ləğv et')),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(t('Sil')),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (yes == true) {
                                      try {
                                        await doc.reference.delete();
                                      } catch (_) {
                                        if (context.mounted) {
                                          notifySocial(
                                            context,
                                            'Silinmədi. Yenidən sına.',
                                          );
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${doc.data()['text']}',
                            style: const TextStyle(fontSize: 17, height: 1.5),
                          ),
                          if (!widget.rooms) ...[
                            const SizedBox(height: 14),
                            Builder(builder: (context) {
                              final likes = (doc.data()['likes'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
                              final liked = likes.contains(widget.profile.uid);
                              return Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _toggleMomentLike(doc.reference, doc.data()),
                                    icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? vibePink : mutedInk),
                                    label: Text('${likes.length}', style: const TextStyle(color: Colors.white70)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _openMomentComments(doc.reference),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: mutedInk),
                                    label: Text(t('Şərh'), style: TextStyle(color: Colors.white70)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: t('Paylaş'),
                                    onPressed: () => _shareMoment('${doc.data()['text'] ?? ''}'),
                                    icon: const Icon(Icons.ios_share_rounded, color: mutedInk),
                                  ),
                                ],
                              );
                            }),
                          ],
                          if (widget.rooms) ...[
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SocialRoomChat(
                                    profile: widget.profile,
                                    room: doc.reference,
                                    title: '${doc.data()['text']}',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text(t('Söhbətə qoşul')),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
    );
  }
}

class ComposeSocial extends StatefulWidget {
  const ComposeSocial({super.key, required this.room});
  final bool room;
  @override
  State<ComposeSocial> createState() => _ComposeSocialState();
}

class _ComposeSocialState extends State<ComposeSocial> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.room ? 'Otaq yarat' : 'Bir an paylaş'),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: widget.room ? 80 : 500,
      maxLines: widget.room ? 2 : 5,
      decoration: InputDecoration(
        hintText: widget.room ? 'Nədən danışaq?' : 'Bu gün nə düşünürsən?',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t('Ləğv et')),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isNotEmpty) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: Text(t('Paylaş')),
      ),
    ],
  );
}

class SocialRoomChat extends StatefulWidget {
  const SocialRoomChat({
    super.key,
    required this.profile,
    required this.room,
    required this.title,
  });
  final UserProfile profile;
  final DocumentReference<Map<String, dynamic>> room;
  final String title;
  @override
  State<SocialRoomChat> createState() => _SocialRoomChatState();
}

class _SocialRoomChatState extends State<SocialRoomChat> {
  final controller = TextEditingController();
  bool sending = false;
  late final stream = widget.room
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.room.collection('messages').add({
        'senderId': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (controller.text.trim() == text) controller.clear();
    } catch (_) {
      if (mounted) notifySocial(context, 'Mesaj göndərilmədi. Yenidən sına.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, s) {
              if (s.hasError) {
                return const EmptySocial(
                  'Mesajlar yüklənmədi',
                  'Bağlantını yoxla.',
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.data!.docs.isEmpty) {
                return const EmptySocial(
                  'Söhbəti sən başlat',
                  'Otaqdakı hər kəs mesajını görə bilər.',
                );
              }
              return ListView(
                reverse: true,
                padding: const EdgeInsets.all(18),
                children: [
                  for (final d in s.data!.docs)
                    Align(
                      alignment: d.data()['senderId'] == widget.profile.uid
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: d.data()['senderId'] == widget.profile.uid
                              ? const Color(0xff2a1c43)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.data()['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('${d.data()['text']}'),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yaz…',
                      counterText: '',
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
        ),
      ],
    ),
  );
}
