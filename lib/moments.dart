// ANLAR — paylaşımlar lenti.
// Maket: üst panel, "Anlar · Takip etdiklərim · Populyar" tabları,
// hekayə zolağı və şəkilli paylaşım kartları.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'user_profile.dart';
import 'moment_create.dart';
import 'stories.dart';
import 'stories_view.dart';
import 'story_editor.dart';
import 'moment_ranking.dart';
import 'voice/moment_voice.dart';
import 'voice/waveform.dart';
import 'share_sheet.dart';
import 'whispers.dart';
import 'moment_detail.dart';
import 'server_time.dart';
import 'image_save.dart';
import 'post_links.dart';
import 'rich_post_text.dart';
import 'blocking.dart';
import 'gift_sheet.dart';
import 'media_upload.dart';
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
  static const tabs = ['Tövsiyə', 'İzlədiklərim', 'Populyar'];

  int tab = 0;
  Set<String> following = <String>{};

  /// "Maraqlandırmır" deyilən anlar.
  Set<String> hiddenMoments = <String>{};

  /// Səssizə alınmış adamlar — bloklamadan, sadəcə lentdə görünmürlər.
  Set<String> mutedUsers = <String>{};

  /// İzlədiklərimin izlədikləri — "dostun dostu" siqnalı üçün.
  Set<String> friendsOfFriends = <String>{};

  /// Öz ölkəm — eyni ölkədən paylaşım tövsiyədə yuxarı qalxır.
  String myCountry = '';

  /// Baxılmış storilər — halqanın rəngi buna görədir.
  final Set<String> seenStories = <String>{};

  FirebaseFirestore get db => FirebaseFirestore.instance;

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

    final me = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid);

    // Üç siyahı da lentin süzgəcidir; hər biri öz axını ilə gəlir ki,
    // biri xəta versə qalanı işləməyə davam etsin.
    _watch(me.collection('following'), (ids) {
      following = ids;
      _loadFriendsOfFriends(ids);
    });
    _loadSeenStories();
    _watch(me.collection('hiddenMoments'), (ids) => hiddenMoments = ids);
    _watch(me.collection('mutedUsers'), (ids) => mutedUsers = ids);

    me.get().then((snap) {
      if (!mounted) return;
      setState(() => myCountry = '${snap.data()?['countryCode'] ?? ''}');
    }).catchError((Object _) {});
  }

  /// İzlədiyim adamların izlədiklərini toplayır.
  ///
  /// Hər biri üçün ayrıca sorğu gedir, ona görə say məhdudlaşdırılıb:
  /// tövsiyə lenti bir siqnala görə onlarla sorğu göndərməməlidir.
  Future<void> _loadFriendsOfFriends(Set<String> ids) async {
    final sample = ids.take(20);
    final found = <String>{};

    for (final uid in sample) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('following')
            .limit(30)
            .get();
        found.addAll(snap.docs.map((e) => e.id));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => friendsOfFriends = found);
  }

  void _watch(
    CollectionReference<Map<String, dynamic>> ref,
    void Function(Set<String>) apply,
  ) {
    ref.snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => apply(snap.docs.map((e) => e.id).toSet()));
    }, onError: (Object _) {});
  }


  /// Tövsiyə sırası.
  ///
  /// Balın necə hesablandığı `moment_ranking.dart` faylındadır — orada
  /// hər çəkinin səbəbi yazılıb və testlərlə örtülüb.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _recommend(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();

    double score(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final d = doc.data();
      final created = d['createdAt'];

      final ageHours = created is Timestamp
          ? now.difference(created.toDate()).inMinutes / 60
          // Tarixi olmayan sənəd köhnə sayılır ki, başa keçməsin.
          : 999.0;

      final owner = '${d['ownerUid'] ?? ''}';
      final country = '${d['ownerCountry'] ?? ''}';

      int count(String key) =>
          d[key] is num ? (d[key] as num).toInt() : 0;

      return momentScore(MomentSignals(
        ageHours: ageHours,
        likes: count('likeCount'),
        comments: count('commentCount'),
        gifts: count('giftCount'),
        fromFollowed: following.contains(owner),
        friendOfFriend:
            friendsOfFriends.contains(owner) && !following.contains(owner),
        sameCountry: myCountry.isNotEmpty && country == myCountry,
      ));
    }

    final sorted = [...docs]
      ..sort((a, b) => score(b).compareTo(score(a)));

    return spreadAuthors(
      sorted,
      (doc) => '${doc.data()['ownerUid'] ?? ''}',
    );
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
                TopIconButton(
                  icon: Icons.blur_on_rounded,
                  tooltip: 'Pıçıltı — anonim səs',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WhispersPage(profile: widget.profile),
                    ),
                  ),
                ),
                TopIconButton(
                  icon: Icons.bookmark_border_rounded,
                  tooltip: 'Yadda saxlananlar',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SavedMomentsPage(profile: widget.profile),
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
                    final owner = '${doc.data()['ownerUid'] ?? ''}';
                    final mine = owner == widget.profile.uid;

                    // Gizlədilən an və səssizə alınmış adam lentdə olmur.
                    // Öz paylaşımına bu süzgəclər tətbiq edilmir.
                    if (!mine) {
                      if (hiddenMoments.contains(doc.id)) return false;
                      if (mutedUsers.contains(owner)) return false;
                    }

                    if (tab == 1) {
                      return following.contains(owner) || mine;
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

                  // Tövsiyə lenti: bal hesablanır, sonra eyni müəllifin
                  // paylaşımları arda-arda yığılmasın deyə yayılır.
                  final ordered = tab == 0 ? _recommend(docs) : docs;

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
                    itemCount: ordered.isEmpty ? 2 : ordered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _storyRow(all);
                      }

                      if (ordered.isEmpty) return _emptyFeed();

                      final doc = ordered[index - 1];
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
  /// Hekayə zolağı — canlı storilər.
  ///
  /// Əvvəl bu zolaq sadəcə son paylaşanların siyahısı idi və basanda
  /// profil açırdı. İndi həqiqi storidir: 24 saat yaşayır, baxılmamış
  /// halqa rəngli olur, basanda tam ekran açılır.
  Widget _storyRow(List<QueryDocumentSnapshot<Map<String, dynamic>>> _) {
    return SizedBox(
      height: 96,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('stories')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          final groups = snap.hasData
              ? groupStories(
                  snap.data!.docs.map((d) => Story.from(d.id, d.data())),
                  me: widget.profile.uid,
                  seen: seenStories,
                  // Stori 24 saat yaşayır. Telefonun saatı fərqlidirsə
                  // stori vaxtından əvvəl itir və ya çoxdan bitmişi
                  // qalır — ona görə serverin saatı verilir.
                  now: serverNow(),
                )
              : const <StoryGroup>[];

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _story(
                  label: 'Stori paylaş',
                  onTap: _createStory,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xff1b1430),
                      shape: BoxShape.circle,
                      border: Border.all(color: vPurple, width: 1.6),
                    ),
                    child:
                        const Icon(Icons.add_rounded, color: vPink, size: 26),
                  ),
                  ring: false,
                );
              }

              final group = groups[index - 1];

              return _story(
                label: group.ownerUid == widget.profile.uid
                    ? 'Sən'
                    : group.ownerName,
                // Baxılmışda halqa sönük olur — nə qaldığı dərhal görünür.
                ring: !group.allSeen,
                onTap: () => _openStories(groups, index - 1),
                child: _StoryAvatar(
                  uid: group.ownerUid,
                  name: group.ownerName,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createStory() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryEditorPage(profile: widget.profile),
        ),
      );

  Future<void> _openStories(List<StoryGroup> groups, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewer(
          groups: groups,
          startIndex: index,
          profile: widget.profile,
        ),
      ),
    );

    // Qayıdanda halqalar yenilənsin.
    if (mounted) _loadSeenStories();
  }

  /// Baxılmış storilərin siyahısı.
  ///
  /// Hər stori üçün ayrıca sorğu getməsin deyə bir dəfə oxunur və
  /// baxışdan qayıdanda təzələnir.
  Future<void> _loadSeenStories() async {
    try {
      final snap = await db
          .collectionGroup('views')
          .where('uid', isEqualTo: widget.profile.uid)
          .limit(200)
          .get();

      if (!mounted) return;

      setState(() {
        seenStories
          ..clear()
          ..addAll(snap.docs.map((d) => d.reference.parent.parent!.id));
      });
    } catch (_) {
      // İndeks hazır deyilsə halqalar sadəcə rəngli qalır.
    }
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
    final diff = sinceServer(at.toDate());
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
    final repostOf = '${widget.data['repostOf'] ?? ''}'.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      if (repostOf.isNotEmpty) _repostBanner(ownerName),
      IntrinsicHeight(
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
                    // @ad profilə, #söz hashtag lentinə, link brauzerə.
                    RichPostText(
                      caption,
                      onMention: (name) =>
                          openMention(context, widget.profile, name),
                      onHashtag: (tag) =>
                          openHashtag(context, widget.profile, tag),
                      onLink: (url) => openPostLink(context, url),
                    ),
                  ],
                  if (widget.data['quoted'] is Map) ...[
                    const SizedBox(height: 10),
                    _quotedBox(
                      Map<String, dynamic>.from(
                        widget.data['quoted'] as Map,
                      ),
                    ),
                  ],
                  if ('${widget.data['audioUrl'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    MomentVoice(
                      url: '${widget.data['audioUrl']}',
                      durationMs:
                          int.tryParse('${widget.data['audioMs'] ?? 0}') ?? 0,
                      waveform: waveformFromData(widget.data['audioWave']),
                      name: ownerName,
                    ),
                  ],
                  if (videoUrl.isNotEmpty || photos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _media(videoUrl, photos, ownerName),
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
        ],
      ),
    );
  }


  // ----------------------------------------------------------
  // YENİDƏN PAYLAŞIM
  // ----------------------------------------------------------

  /// Kartın başındakı "yenidən paylaşdı" sətri.
  Widget _repostBanner(String ownerName) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Row(
          children: [
            const Icon(Icons.repeat_rounded, size: 13, color: vMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$ownerName yenidən paylaşdı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: vMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  /// Sitat gətirilən anın kiçik görünüşü.
  ///
  /// Orijinal sənədə ayrıca sorğu getmir: lazım olan sahələr sitat
  /// yaradılanda köçürülür. An sonradan silinsə də sitat oxunaqlı qalır.
  Widget _quotedBox(Map<String, dynamic> quoted) {
    final name = '${quoted['ownerName'] ?? 'VIBE'}';
    final text = '${quoted['caption'] ?? ''}'.trim();
    final thumb = '${quoted['thumbUrl'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff17122a),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff2d2540)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thumb.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image.network(thumb, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: vMuted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRepostMenu(String ownerName, String caption) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Yenidən paylaşım',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.format_quote_rounded, color: vBlue),
              title: const Text('Sitat gətir',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Öz sözünü əlavə et',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                _quote(ownerName, caption);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded, color: vMint),
              title: const Text('Olduğu kimi paylaş',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Söz əlavə etmədən',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                _repost(ownerName);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Olduğu kimi yenidən paylaşır.
  ///
  /// Media orijinaldan köçürülür — belə olanda lent kartı göstərmək üçün
  /// ikinci sorğu göndərmir və orijinal silinsə də paylaşım sınmır.
  Future<void> _repost(String ownerName) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final id = db.collection('moments').doc().id;

      await db.collection('moments').doc(id).set({
        'id': id,
        'ownerUid': widget.profile.uid,
        'ownerName': widget.profile.name,
        'caption': '${widget.data['caption'] ?? ''}',
        if (widget.data['images'] != null) 'images': widget.data['images'],
        if (widget.data['thumbs'] != null) 'thumbs': widget.data['thumbs'],
        if (widget.data['imageUrl'] != null)
          'imageUrl': widget.data['imageUrl'],
        if (widget.data['thumbUrl'] != null)
          'thumbUrl': widget.data['thumbUrl'],
        if (widget.data['videoUrl'] != null)
          'videoUrl': widget.data['videoUrl'],
        'repostOf': widget.momentId,
        'repostOwnerName': ownerName,
        'visibility': 'public',
        'createdAt': Timestamp.now(),
      });

      await moment.set(
        {'repostCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('Yenidən paylaşıldı.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Alınmadı. Bağlantını yoxla.')),
      );
    }
  }

  /// Sitat gətirir — öz sözünü yazmaq üçün pəncərə açır.
  Future<void> _quote(String ownerName, String caption) async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Sitat gətir',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 200,
          style: const TextStyle(color: Colors.white),
          cursorColor: vPink,
          decoration: const InputDecoration(
            hintText: 'Nə demək istəyirsən?',
            hintStyle: TextStyle(color: vMuted),
            counterStyle: TextStyle(color: vMuted, fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('İmtina', style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text(
              'Paylaş',
              style: TextStyle(color: vPink, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (text == null || text.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final id = db.collection('moments').doc().id;

      await db.collection('moments').doc(id).set({
        'id': id,
        'ownerUid': widget.profile.uid,
        'ownerName': widget.profile.name,
        'caption': text,
        // Orijinalın kiçik nüsxəsi — ayrıca sorğu getməsin deyə.
        'quoted': {
          'momentId': widget.momentId,
          'ownerName': ownerName,
          'caption': caption,
          'thumbUrl':
              '${widget.data['thumbUrl'] ?? widget.data['imageUrl'] ?? ''}',
        },
        'visibility': 'public',
        'createdAt': Timestamp.now(),
      });

      await moment.set(
        {'repostCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      messenger.showSnackBar(const SnackBar(content: Text('Paylaşıldı.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Alınmadı. Bağlantını yoxla.')),
      );
    }
  }


  /// Video və şəkillər bir karuseldə.
  ///
  /// Əvvəl ya video, ya şəkil göstərilirdi və ikisini birlikdə paylaşmaq
  /// qadağan idi. İndi video birinci səhifədə, şəkillər onun ardınca gəlir —
  /// istifadəçi barmağı ilə keçir.
  Widget _media(String videoUrl, List<String> photos, String ownerName) {
    final total = (videoUrl.isEmpty ? 0 : 1) + photos.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              itemCount: total,
              onPageChanged: (i) => setState(() => page = i),
              itemBuilder: (context, i) {
                // Birinci səhifə video, qalanları şəkil.
                if (videoUrl.isNotEmpty && i == 0) {
                  return MomentVideo(url: videoUrl);
                }

                final index = videoUrl.isEmpty ? i : i - 1;

                return GestureDetector(
                  onTap: _openDetail,
                  onDoubleTap: _toggleLike,
                  child: VibePhoto(url: photos[index], name: ownerName),
                );
              },
            ),
            if (total > 1)
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
                    '${page + 1}/$total',
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
            onTap: () => _openMenu(ownerName),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              // Barmaq üçün kifayət qədər sahə: ikonun özü 18 pikseldir.
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(Icons.more_horiz_rounded, color: vMuted, size: 18),
            ),
          ),
        ],
      );

  /// Üç nöqtə menyusu.
  ///
  /// Əvvəl bu düymə sadəcə anın səhifəsini açırdı — silmək, arxivləmək,
  /// şikayət etmək kimi heç nə yox idi.
  Future<void> _openMenu(String ownerName) async {
    final ownerUid = '${widget.data['ownerUid'] ?? ''}';
    final mine = ownerUid == widget.profile.uid;

    // Bir sorğu: etiket "Yadda saxla" yoxsa "Yaddaşdan çıxar" olmalıdır.
    var saved = false;
    try {
      saved = (await _savedRef.get()).exists;
    } catch (_) {}

    if (!mounted) return;

    final pinned = widget.data['pinned'] == true;
    final archived = '${widget.data['visibility'] ?? ''}' == 'archived';
    final hidden = widget.data['hideCounts'] == true;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(
              sheet,
              icon: Icons.link_rounded,
              label: 'Bağlantını kopyala',
              onTap: () => _copyLink(ownerName),
            ),
            _menuItem(
              sheet,
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: saved ? 'Yaddaşdan çıxar' : 'Yadda saxla',
              onTap: () => _toggleSave(saved, ownerName),
            ),

            // Anı öz storinə atmaq.
            //
            // Instagram-ın ən çox işlənən paylaşma yolu budur: post
            // lentdə qalır, stori isə izləyicini dərhal ora çəkir.
            _menuItem(
              sheet,
              icon: Icons.add_to_photos_rounded,
              label: 'Storinə at',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryEditorPage(
                    profile: widget.profile,
                    sharedMoment: widget.data,
                  ),
                ),
              ),
            ),

            // Cihaza endirmək.
            //
            // Flutter veb şəkli kətana çəkir — brauzerin öz "Şəkli
            // saxla" menyusu çıxmır. Düymə olmadan şəkli və videonu
            // götürmək mümkün deyildi.
            if (_downloadSource() != null)
              _menuItem(
                sheet,
                icon: Icons.download_rounded,
                label: _isVideo() ? 'Videonu endir' : 'Şəkli endir',
                onTap: _download,
              ),

            if (mine) ...[
              _menuItem(
                sheet,
                icon: pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                label: pinned
                    ? 'Profilin başından götür'
                    : 'Profilin başına sancaqla',
                onTap: () => _setField('pinned', !pinned,
                    pinned ? 'Sancaq götürüldü.' : 'Profilin başına sancaqlandı.'),
              ),
              _menuItem(
                sheet,
                icon: archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                label: archived ? 'Arxivdən çıxar' : 'Arxivlə',
                note: archived
                    ? 'Yenidən hamıya görünəcək'
                    : 'Yalnız sən görəcəksən',
                onTap: () => _setField(
                  'visibility',
                  archived ? 'public' : 'archived',
                  archived ? 'Arxivdən çıxarıldı.' : 'Arxivləndi.',
                ),
              ),
              _menuItem(
                sheet,
                icon: hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                label: hidden
                    ? 'Bəyənmə saylarını göstər'
                    : 'Bəyənmə saylarını gizlə',
                onTap: () => _setField('hideCounts', !hidden,
                    hidden ? 'Saylar göründü.' : 'Saylar gizləndi.'),
              ),
              _menuItem(
                sheet,
                icon: Icons.delete_outline_rounded,
                label: 'Sil',
                note: 'Geri qaytarmaq olmur',
                danger: true,
                onTap: _confirmDelete,
              ),
            ] else ...[
              _menuItem(
                sheet,
                icon: Icons.visibility_off_outlined,
                label: 'Maraqlandırmır',
                note: 'Bu an lentindən çıxsın',
                onTap: _notInterested,
              ),
              _menuItem(
                sheet,
                icon: Icons.volume_off_rounded,
                label: 'Səssizə al',
                note: 'Paylaşımları görünməsin, xəbəri olmasın',
                onTap: () => _mute(ownerUid, ownerName),
              ),
              _menuItem(
                sheet,
                icon: Icons.flag_outlined,
                label: 'Şikayət et',
                danger: true,
                onTap: () => _report(ownerUid),
              ),
              _menuItem(
                sheet,
                icon: Icons.block_rounded,
                label: '$ownerName-i blokla',
                note: 'Paylaşımları sənə görünməyəcək',
                onTap: () => _block(ownerUid, ownerName),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Menyu sətirləri eyni görünsün deyə tək yerdən qurulur.
  Widget _menuItem(
    BuildContext sheet, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? note,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xffff657b) : Colors.white;

    return ListTile(
      leading: Icon(icon, color: danger ? const Color(0xffff657b) : vMuted),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: danger ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: note == null
          ? null
          : Text(note, style: const TextStyle(color: vMuted, fontSize: 12)),
      onTap: () {
        Navigator.pop(sheet);
        onTap();
      },
    );
  }


  /// Bu istifadəçinin yaddaşında bu anın sənədi.
  DocumentReference<Map<String, dynamic>> get _savedRef => db
      .collection('users')
      .doc(widget.profile.uid)
      .collection('savedMoments')
      .doc(moment.id);

  Future<void> _toggleSave(bool saved, String ownerName) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (saved) {
        await _savedRef.delete();
        messenger.showSnackBar(
          const SnackBar(content: Text('Yaddaşdan çıxarıldı.')),
        );
      } else {
        // Ad və şəkil burada saxlanılır ki, siyahını göstərmək üçün
        // hər an üçün ayrıca sorğu getməsin.
        await _savedRef.set({
          'momentId': moment.id,
          'ownerUid': '${widget.data['ownerUid'] ?? ''}',
          'ownerName': ownerName,
          'caption': '${widget.data['caption'] ?? ''}',
          'thumbUrl': '${widget.data['thumbUrl'] ?? widget.data['imageUrl'] ?? ''}',
          'createdAt': Timestamp.now(),
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Yadda saxlanıldı.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }

  /// Anı yalnız bu istifadəçinin lentindən çıxarır.
  ///
  /// Şikayətdən fərqi var: heç kimə bildiriş getmir, an silinmir,
  /// sadəcə bir daha bu adamın qarşısına çıxmır.
  Future<void> _notInterested() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await db
          .collection('users')
          .doc(widget.profile.uid)
          .collection('hiddenMoments')
          .doc(moment.id)
          .set({'createdAt': Timestamp.now()});

      messenger.showSnackBar(
        const SnackBar(content: Text('Bu an bir daha göstərilməyəcək.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }

  /// Adamın paylaşımlarını lentdən çıxarır.
  ///
  /// Bloklamaqdan fərqi: qarşı tərəf bunu bilmir, yazışma da bağlanmır.
  Future<void> _mute(String ownerUid, String ownerName) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await db
          .collection('users')
          .doc(widget.profile.uid)
          .collection('mutedUsers')
          .doc(ownerUid)
          .set({'name': ownerName, 'createdAt': Timestamp.now()});

      messenger.showSnackBar(
        SnackBar(content: Text('$ownerName səssizə alındı.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }

  /// Anın mətnini və tətbiq ünvanını lövhəyə kopyalayır.
  ///
  /// Birbaşa ana aparan bağlantı hələ yoxdur — tətbiqdə dərin keçid
  /// qurulmayıb. Ona görə tətbiqin ünvanı və anın mətni kopyalanır,
  /// mövcud olmayan səhifəyə aparan saxta ünvan yazmırıq.
  /// Endirilə bilən məzmunun ünvanı.
  String? _downloadSource() {
    final video = '${widget.data['videoUrl'] ?? ''}'.trim();
    if (video.isNotEmpty) return video;

    final images = (widget.data['images'] as List?) ?? const [];
    if (images.isNotEmpty) return '${images.first}';

    final single = '${widget.data['imageUrl'] ?? ''}'.trim();
    return single.isEmpty ? null : single;
  }

  bool _isVideo() => '${widget.data['videoUrl'] ?? ''}'.trim().isNotEmpty;

  Future<void> _download() async {
    final source = _downloadSource();
    if (source == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final saved = await saveImage(
      source,
      name: _isVideo() ? 'vibe-video.mp4' : 'vibe-sekil.jpg',
    );

    messenger.showSnackBar(SnackBar(
      content: Text(saved == null
          ? 'Endirilmədi.'
          : 'Açıldı. iPhone-da uzun bas → "Şəkillərə əlavə et".'),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _copyLink(String ownerName) async {
    final messenger = ScaffoldMessenger.of(context);
    final caption = '${widget.data['caption'] ?? ''}'.trim();

    final text = [
      'VIBE · $ownerName',
      if (caption.isNotEmpty) caption,
      'https://vibe-f9d13.web.app',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(content: Text('Kopyalandı.')),
    );
  }

  /// Anın bir sahəsini dəyişir.
  Future<void> _setField(String field, Object value, String done) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await moment.set({field: value}, SetOptions(merge: true));
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Alınmadı. Bağlantını yoxla.')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Anı silmək?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Şəkillər, bəyənmələr və şərhlər də silinəcək. Geri qaytarmaq olmur.',
          style: TextStyle(color: vMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('İmtina', style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text(
              'Sil',
              style: TextStyle(
                color: Color(0xffff657b),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;
    await _delete();
  }

  /// Anı və ona bağlı hər şeyi silir.
  ///
  /// Firestore alt kolleksiyaları özü silmir — bəyənmə və şərhlər sənəd
  /// gedəndən sonra da qalır və yer tutur, ona görə əvvəlcə onlar təmizlənir.
  /// Şəkillər Supabase-dədir, onlar da silinməlidir ki, anbar dolmasın.
  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      for (final name in ['likes', 'comments']) {
        final docs = await moment.collection(name).get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      await moment.delete();

      // Fayllar sənəddən sonra silinir: sənəd getdisə an onsuz da görünmür.
      final urls = <String>[
        for (final key in ['images', 'thumbs'])
          ...((widget.data[key] as List?) ?? const []).map((e) => e.toString()),
        '${widget.data['videoUrl'] ?? ''}',
      ].where((u) => u.trim().isNotEmpty).toList();

      for (final url in urls) {
        try {
          await MediaUpload.deleteByUrl(url.trim());
        } catch (_) {}
      }

      messenger.showSnackBar(const SnackBar(content: Text('An silindi.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Silinmədi. Bağlantını yoxla.')),
      );
    }
  }

  Future<void> _report(String ownerUid) async {
    const reasons = [
      'Spam',
      'Uyğunsuz məzmun',
      'Təhqir və ya zorakılıq',
      'Saxta profil',
      'Digər',
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Anı şikayət et',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final reason in reasons)
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: Color(0xffff657b)),
                title:
                    Text(reason, style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheet);

                  try {
                    await db.collection('reports').add({
                      'type': 'moment',
                      'momentId': moment.id,
                      'ownerUid': ownerUid,
                      'reporterUid': widget.profile.uid,
                      'reason': reason,
                      'status': 'new',
                      'createdAt': Timestamp.now(),
                    });
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Şikayət göndərildi.')),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Şikayət göndərilmədi.')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _block(String ownerUid, String ownerName) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await blockUser(
        myUid: widget.profile.uid,
        myName: widget.profile.name,
        targetUid: ownerUid,
        targetName: ownerName,
        database: db,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('$ownerName bloklandı.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Bloklanmadı.')));
    }
  }


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

  /// Beş düymə dar telefonda bir sıraya sığmır və daşırdı.
  /// Sol qrup üfüqi sürüşür, paylaşma düyməsi sağda sabit qalır.
  Widget _actions(String ownerName, String caption) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
      const SizedBox(width: 18),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: moment.snapshots(),
        builder: (context, snap) {
          final count =
              int.tryParse('${snap.data?.data()?['repostCount'] ?? 0}') ?? 0;

          return _pill(
            icon: Icons.repeat_rounded,
            label: count > 0 ? '$count' : '',
            color: count > 0 ? vMint : Colors.white,
            onTap: () => _openRepostMenu(ownerName, caption),
          );
        },
      ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Əvvəl bu düymə yalnız "anı aç / şərh yaz" verirdi — paylaşma
      // düyməsində gözlənilən bu deyil. İndi yönləndirmə vərəqi açılır:
      // dostlara göndər, kopyala və ya telefonun öz pəncərəsi ilə paylaş.
      _pill(
        icon: Icons.ios_share_rounded,
        label: '',
        onTap: () => showShareSheet(
          context,
          profile: widget.profile,
          title: 'VIBE · $ownerName',
          body: '${widget.data['caption'] ?? ''}',
          database: widget.database,
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


/// Yadda saxlanılan anlar.
///
/// Menyudakı "Yadda saxla" buraya yazır. Siyahı öz sənədindəki nüsxədən
/// qurulur — hər sətir üçün ayrıca ana sorğu getmir, çünki an silinmiş də
/// ola bilər və o zaman sorğu boşa gedərdi.
class SavedMomentsPage extends StatelessWidget {
  const SavedMomentsPage({
    super.key,
    required this.profile,
    this.database,
  });

  final UserProfile profile;
  final FirebaseFirestore? database;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final saved = db
        .collection('users')
        .doc(profile.uid)
        .collection('savedMoments')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0b0711),
        title: const Text(
          'Yadda saxlananlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: saved.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text(
                'Siyahı yüklənmədi.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: vPink));
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Hələ heç nə saxlamamısan.\n'
                  'Anın üç nöqtəsinə basıb "Yadda saxla" seç.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vMuted, height: 1.5),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final thumb = '${data['thumbUrl'] ?? ''}';
              final caption = '${data['caption'] ?? ''}'.trim();

              return Container(
                decoration: BoxDecoration(
                  color: vPanel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: vLine),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: thumb.isEmpty
                          ? const ColoredBox(
                              color: vPanelHigh,
                              child: Icon(Icons.image_outlined, color: vMuted),
                            )
                          : Image.network(thumb, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text(
                    '${data['ownerName'] ?? 'VIBE'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    caption.isEmpty ? 'Şəkil' : caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: vMuted, fontSize: 12.5),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.bookmark_remove_outlined,
                        color: vMuted),
                    tooltip: 'Yaddaşdan çıxar',
                    onPressed: () => docs[index].reference.delete(),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MomentDetailPage(
                        momentId: '${data['momentId'] ?? docs[index].id}',
                        profile: profile,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
