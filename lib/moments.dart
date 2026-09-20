// ANLAR — paylaşımlar lenti.
// Maket: üst panel, "Anlar · Takip etdiklərim · Populyar" tabları,
// hekayə zolağı və şəkilli paylaşım kartları.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'user_profile.dart';
import 'moment_create.dart';
import 'moment_detail.dart';
import 'gift_sheet.dart';
import 'moment_video.dart';
import 'moment_comments.dart';
import 'main.dart' show PersonPage, isReallyOnline;
import 'vibe_levels.dart';
import 'video_search.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  static const tabs = ['Anlar', 'Takip etdiklərim', 'Populyar'];

  int tab = 0;
  Set<String> following = <String>{};

  /// Firestore kompozit indeksi hazır deyilsə, sadə sorğuya keçirik —
  /// ekran xəta vermir, sıralama kodda aparılır.
  bool fallback = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> get feed {
    final base = FirebaseFirestore.instance.collection('moments');
    if (fallback) return base.limit(40).snapshots();
    return base
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .collection('following')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() => following = snap.docs.map((e) => e.id).toSet());
        }, onError: (Object _) {});
  }

  void _create() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CreateMomentPage(profile: widget.profile)),
  );

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Material(
      type: MaterialType.transparency,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            VibeTopBar(
              actions: [
                TopIconButton(
                  icon: Icons.search_rounded,
                  tooltip: 'Axtar',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoSearchPage(profile: widget.profile),
                    ),
                  ),
                ),
                VipCrown(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VibeLevelsPage(profile: widget.profile),
                    ),
                  ),
                ),
              ],
            ),
            UnderlineTabs(
              labels: tabs,
              index: tab,
              onChanged: (i) => setState(() => tab = i),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: feed,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    if (!fallback) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => fallback = true);
                      });
                      return _skeleton();
                    }
                    return const _MomentsError();
                  }
                  if (!snapshot.hasData) {
                    return _skeleton();
                  }

                  final all = snapshot.data!.docs.where((doc) {
                    // Ehtiyat sorğuda görünürlük/sıralama kodda tətbiq olunur.
                    if (!fallback) return true;
                    return '${doc.data()['visibility'] ?? 'public'}' == 'public';
                  }).toList();

                  if (fallback) {
                    all.sort((a, b) {
                      final ta = a.data()['createdAt'];
                      final tb = b.data()['createdAt'];
                      if (ta is! Timestamp || tb is! Timestamp) return 0;
                      return tb.compareTo(ta);
                    });
                  }

                  final docs = all.where((doc) {
                    if (tab == 1) {
                      final owner = '${doc.data()['ownerUid'] ?? ''}';
                      return following.contains(owner) ||
                          owner == widget.profile.uid;
                    }
                    return true;
                  }).toList();

                  if (tab == 2) {
                    num likes(Map<String, dynamic> d) =>
                        d['likeCount'] is num ? d['likeCount'] as num : 0;
                    docs.sort(
                      (a, b) => likes(b.data()).compareTo(likes(a.data())),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
                    itemCount: docs.isEmpty ? 2 : docs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _storyRow(all);
                      }

                      if (docs.isEmpty) return _emptyFeed();

                      final doc = docs[index - 1];
                      return MomentCard(
                        key: ValueKey(doc.id),
                        momentId: doc.id,
                        data: doc.data(),
                        profile: widget.profile,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// Lent boş olanda çıxılmaz ekran əvəzinə hərəkət təklifi.
  Widget _emptyFeed() => Padding(
    padding: const EdgeInsets.fromLTRB(28, 46, 28, 20),
    child: Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: vHot),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          tab == 1 ? 'İzlədiklərin hələ paylaşmayıb' : 'Hələ an paylaşılmayıb',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          tab == 1
              ? 'Ana səhifədən yeni insanları izlə, anları burada görünsün.'
              : 'İlk anı sən paylaş — şəkil və ya bir cümlə kifayətdir.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: vMuted, height: 1.45),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: tab == 1 ? 'Kəşf etməyə başla' : 'Anını paylaş',
          icon: tab == 1 ? Icons.explore_rounded : Icons.add_rounded,
          expand: false,
          height: 44,
          onPressed: tab == 1 ? () => setState(() => tab = 0) : _create,
        ),
      ],
    ),
  );

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
    children: const [
      VibeShimmer(height: 92, radius: 20),
      SizedBox(height: 18),
      VibeShimmer(height: 54, radius: 16),
      SizedBox(height: 10),
      VibeShimmer(height: 300, radius: 20),
    ],
  );

  /// Yuxarıdakı hekayə zolağı: "Anını paylaş" + son paylaşanlar.
  Widget _storyRow(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final seen = <String>{};
    final owners = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final d = doc.data();
      final uid = '${d['ownerUid'] ?? ''}';
      if (uid.isEmpty || uid == widget.profile.uid) continue;
      if (!seen.add(uid)) continue;
      owners.add({
        'uid': uid,
        'name': '${d['ownerName'] ?? 'VIBE'}',
        'image': '${d['imageUrl'] ?? ''}',
      });
      if (owners.length >= 14) break;
    }

    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        itemCount: owners.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _story(
              label: 'Anını paylaş',
              onTap: _create,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff1b1430),
                  shape: BoxShape.circle,
                  border: Border.all(color: vPurple, width: 1.6),
                ),
                child: const Icon(Icons.add_rounded, color: vPink, size: 26),
              ),
              ring: false,
            );
          }

          if (index == 1) {
            return _story(
              label: 'Sən',
              onTap: _create,
              child: _StoryAvatar(
                uid: widget.profile.uid,
                name: widget.profile.name,
              ),
            );
          }

          final owner = owners[index - 2];
          return _story(
            label: '${owner['name']}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonPage(
                  currentProfile: widget.profile,
                  targetUid: '${owner['uid']}',
                ),
              ),
            ),
            child: _StoryAvatar(uid: '${owner['uid']}', name: '${owner['name']}'),
          );
        },
      ),
    );
  }

  Widget _story({
    required String label,
    required VoidCallback onTap,
    required Widget child,
    bool ring = true,
  }) => Padding(
    padding: const EdgeInsets.only(right: 13),
    child: PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ring
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [vPink, vPurple, vBlue],
                      )
                    : null,
              ),
              child: ClipOval(child: child),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xffd4ccdf),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hekayə zolağındakı canlı avatar.
class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.uid, required this.name});

  final String uid, name;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final d = snapshot.data?.data() ?? const <String, dynamic>{};
          return VibePhoto(
            url: '${d['photoUrl'] ?? ''}',
            name: '${d['name'] ?? name}',
            emoji: '${d['avatarEmoji'] ?? ''}',
          );
        },
      );
}

// ============================================================
// PAYLAŞIM KARTI
// ============================================================

class MomentCard extends StatefulWidget {
  const MomentCard({
    super.key,
    required this.momentId,
    required this.data,
    required this.profile,
    this.database,
  });

  final String momentId;
  final Map<String, dynamic> data;
  final UserProfile profile;

  /// Testlərdə saxta baza verilə bilsin deyə.
  final FirebaseFirestore? database;

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  final controller = PageController();
  int page = 0;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get moment =>
      db.collection('moments').doc(widget.momentId);

  DocumentReference<Map<String, dynamic>> get myLike =>
      moment.collection('likes').doc(widget.profile.uid);

  List<String> get images {
    final list = widget.data['images'];
    if (list is List && list.isNotEmpty) {
      return list.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
    }
    final single = '${widget.data['imageUrl'] ?? ''}'.trim();
    return single.isEmpty ? const [] : [single];
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final snap = await myLike.get();
    final liked = snap.exists;

    try {
      if (liked) {
        await myLike.delete();
      } else {
        await myLike.set({'createdAt': Timestamp.now()});
      }
    } catch (_) {
      return;
    }

    // Sıralama üçün sayğac — qaydalar icazə verməsə, bəyənmə yenə işləyir.
    try {
      await moment.set({
        'likeCount': FieldValue.increment(liked ? -1 : 1),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _openComments() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff120d1d),
    builder: (_) => MomentCommentsSheet(
      momentId: widget.momentId,
      profile: widget.profile,
    ),
  );

  void _openDetail() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MomentDetailPage(
        profile: widget.profile,
        momentId: widget.momentId,
      ),
    ),
  );

  String _ago() {
    final at = widget.data['createdAt'];
    if (at is! Timestamp) return '';
    final diff = DateTime.now().difference(at.toDate());
    if (diff.inMinutes < 1) return 'indicə';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dəq əvvəl';
    if (diff.inHours < 24) return '${diff.inHours} saat əvvəl';
    if (diff.inDays < 7) return '${diff.inDays} gün əvvəl';
    return '${at.toDate().day}.${at.toDate().month}.${at.toDate().year}';
  }

  @override
  Widget build(BuildContext context) {
    final ownerUid = '${widget.data['ownerUid'] ?? ''}';
    final ownerName = '${widget.data['ownerName'] ?? 'VIBE'}';
    final caption = '${widget.data['caption'] ?? ''}'.trim();
    final photos = images;
    final videoUrl = '${widget.data['videoUrl'] ?? ''}'.trim();

    // Threads quruluşu: solda avatar sütunu və şaquli xətt,
    // sağda ad, mətn, media və əməliyyatlar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _avatar(ownerUid, ownerName),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(width: 2, color: const Color(0xff221a33)),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _nameRow(ownerUid, ownerName),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: MomentVideo(url: videoUrl),
                    ),
                  ] else if (photos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: _openDetail,
                              onDoubleTap: _toggleLike,
                              child: PageView.builder(
                                controller: controller,
                                itemCount: photos.length,
                                onPageChanged: (i) => setState(() => page = i),
                                itemBuilder: (context, i) =>
                                    VibePhoto(url: photos[i], name: ownerName),
                              ),
                            ),
                            if (photos.length > 1)
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .55),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${page + 1}/${photos.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _actions(ownerName, caption),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Profil şəkli — onlayn nişanı ilə.
  Widget _avatar(String ownerUid, String ownerName) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ownerUid.isEmpty
            ? const Stream.empty()
            : db.collection('users').doc(ownerUid).snapshots(),
        builder: (context, snapshot) {
          final d = snapshot.data?.data() ?? const <String, dynamic>{};
          final online = isReallyOnline(d);

          return PressableScale(
            onTap: ownerUid.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonPage(
                          currentProfile: widget.profile,
                          targetUid: ownerUid,
                        ),
                      ),
                    ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipOval(
                    child: VibePhoto(
                      url: '${d['photoUrl'] ?? ''}',
                      name: ownerName,
                      emoji: '${d['avatarEmoji'] ?? ''}',
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xff2de28a),
                        shape: BoxShape.circle,
                        border: Border.all(color: vBg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  /// Ad, vaxt və seçimlər — bir sətirdə.
  Widget _nameRow(String ownerUid, String ownerName) => Row(
        children: [
          Flexible(
            child: GestureDetector(
              onTap: ownerUid.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonPage(
                            currentProfile: widget.profile,
                            targetUid: ownerUid,
                          ),
                        ),
                      ),
              child: Text(
                ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _ago(),
            style: const TextStyle(color: vMuted, fontSize: 11.5),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openDetail,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.more_horiz_rounded, color: vMuted, size: 18),
            ),
          ),
        ],
      );

  /// Anın sahibinə hədiyyə göndərir.
  Future<void> _sendGiftToOwner(String ownerName) async {
    final ownerUid = '${widget.data['ownerUid'] ?? ''}';
    if (ownerUid.isEmpty) return;

    await showGiftSheet(
      context,
      fromUid: widget.profile.uid,
      fromName: widget.profile.name,
      toUid: ownerUid,
      toName: ownerName,
      target: moment,
      database: widget.database,
    );
  }

  Widget _actions(String ownerName, String caption) => Row(
    children: [
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: myLike.snapshots(),
        builder: (context, mine) {
          final liked = mine.data?.exists == true;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: moment.collection('likes').snapshots(),
            builder: (context, all) => _pill(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: '${all.data?.docs.length ?? 0}',
              color: liked ? vPink : Colors.white,
              onTap: _toggleLike,
            ),
          );
        },
      ),
      const SizedBox(width: 18),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: moment.collection('comments').snapshots(),
        builder: (context, snap) => _pill(
          icon: Icons.mode_comment_outlined,
          label: '${snap.data?.docs.length ?? 0}',
          onTap: _openComments,
        ),
      ),
      const SizedBox(width: 18),
      // Paylaşıma hədiyyə — sahibinin xalına yazılır.
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: moment.snapshots(),
        builder: (context, snap) {
          final count =
              int.tryParse('${snap.data?.data()?['giftCount'] ?? 0}') ?? 0;
          return _pill(
            icon: Icons.card_giftcard_rounded,
            label: count > 0 ? '$count' : '',
            color: count > 0 ? vGold : Colors.white,
            onTap: () => _sendGiftToOwner(ownerName),
          );
        },
      ),
      const Spacer(),
      _pill(
        icon: Icons.ios_share_rounded,
        label: '',
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: const Color(0xff120d1d),
          showDragHandle: true,
          builder: (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_full_rounded, color: vPurple),
                  title: const Text('Anı aç', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _openDetail();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mode_comment_outlined, color: vBlue),
                  title: const Text('Şərh yaz', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _openComments();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _pill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) => PressableScale(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    ),
  );
}

class _MomentsError extends StatelessWidget {
  const _MomentsError();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 46, color: vMuted),
          SizedBox(height: 14),
          Text(
            'Anlar yüklənmədi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text('Bağlantını yoxla və yenidən aç.', style: TextStyle(color: vMuted)),
        ],
      ),
    ),
  );
}
