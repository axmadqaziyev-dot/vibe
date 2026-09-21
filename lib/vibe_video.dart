import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'user_profile.dart';
import 'video_comments.dart';
import 'video_upload.dart';
import 'video_following.dart';
import 'video_creator_profile.dart';
import 'video_social_actions.dart';
import 'video_report.dart';
import 'video_library.dart';
import 'video_search.dart';
import 'video_notifications.dart';
import 'video_edit.dart';
import 'hashtag_explorer.dart';
import 'creator_dashboard.dart';
import 'video_manage.dart';
import 'video_share.dart';
import 'ui/vibe_chrome.dart';
import 'app/i18n.dart';

class VibeVideoPage extends StatefulWidget {
  const VibeVideoPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<VibeVideoPage> createState() => _VibeVideoPageState();
}

class _VibeVideoPageState extends State<VibeVideoPage> {
  int mode = 0; // 0 = For You, 1 = Following, 2 = Saved
  final Set<String> hiddenIds = <String>{};

  /// Kompozit indeks hazır deyilsə sadə sorğuya keçirik.
  bool fallback = false;

  @override
  void initState() {
    super.initState();
    _watchHidden();
  }

  void _watchHidden() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .collection('hiddenVideos')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        hiddenIds
          ..clear()
          ..addAll(snap.docs.map((e) => e.id));
      });
    }, onError: (Object _) {});
  }

  Query<Map<String, dynamic>> get feedQuery {
    final base = FirebaseFirestore.instance.collection('videos');
    if (fallback) return base.limit(100);
    return base
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(100);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> savedStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .collection('savedVideos')
        .orderBy('savedAt', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: mode == 2
                ? _savedFeed()
                : mode == 1
                    ? _followingFeed()
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: feedQuery.snapshots(),
                    builder: (_, snap) {
                      if (snap.hasError) {
                        if (!fallback) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => fallback = true);
                          });
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xffff2bd6),
                            ),
                          );
                        }
                        return _error('${snap.error}');
                      }
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xffff2bd6),
                          ),
                        );
                      }
                      final docs = snap.data!.docs
                          .where((e) => !hiddenIds.contains(e.id))
                          .where(
                            (e) => !fallback ||
                                '${e.data()['visibility'] ?? 'public'}' == 'public',
                          )
                          .toList();
                      if (docs.isEmpty) {
                        return _empty(
                          'Hələ video yoxdur',
                          'İlk videonu sən paylaş ✨',
                          action: true,
                        );
                      }
                      return PageView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: docs.length,
                        itemBuilder: (_, i) => _VideoCard(
                          key: ValueKey(docs[i].id),
                          videoId: docs[i].id,
                          data: docs[i].data(),
                          profile: widget.profile,
                        ),
                      );
                    },
                  ),
          ),
          // ---- üst panel: geri · tablar · axtarış/menyu ----
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 4,
            right: 4,
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  _glassIcon(
                    Icons.arrow_back_rounded,
                    'Geri',
                    () => Navigator.pop(context),
                  )
                else
                  const SizedBox(width: 38),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tab('İzlənilən', mode == 1, () => setState(() => mode = 1)),
                      const SizedBox(width: 20),
                      _tab('Sənin üçün', mode == 0, () => setState(() => mode = 0)),
                    ],
                  ),
                ),
                _glassIcon(
                  Icons.search_rounded,
                  'Axtar',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoSearchPage(profile: widget.profile),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _glassIcon(Icons.menu_rounded, 'Menyu', _openMenu),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .13)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.video_call_rounded, color: Color(0xffff2bd6)),
              title: const Text('Video yüklə', style: TextStyle(color: Colors.white)),
              trailing: VideoUploadButton(profile: widget.profile),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_rounded, color: Color(0xff8b5cff)),
              title: const Text('Saxlanılanlar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                setState(() => mode = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag_rounded, color: Color(0xff22a7ff)),
              title: const Text('Hashtag kəşfi', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HashtagExplorerPage(profile: widget.profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded, color: Color(0xff48e08a)),
              title: const Text('Video kitabxanam', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoLibraryPage(profile: widget.profile),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_rounded, color: Color(0xffffb347)),
              title: const Text('Creator Studio', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatorDashboardPage(profile: widget.profile),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _followingFeed() {
    return FollowingVideoIds(
      profile: widget.profile,
      builder: (_, ids) {
        if (ids.isEmpty) {
          return _empty(
            'Hələ heç kimi izləmirsən',
            'Profil izləyəndə onların videoları burada görünəcək.',
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: feedQuery.snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xffff2bd6),
                ),
              );
            }

            final docs = snap.data!.docs
                .where((e) => ids.contains('${e.data()['ownerUid'] ?? ''}'))
                .toList();

            if (docs.isEmpty) {
              return _empty(
                'Yeni video yoxdur',
                'İzlədiyin profillər video paylaşanda burada görünəcək.',
              );
            }

            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: docs.length,
              itemBuilder: (_, i) => _VideoCard(
                key: ValueKey('following-${docs[i].id}'),
                videoId: docs[i].id,
                data: docs[i].data(),
                profile: widget.profile,
              ),
            );
          },
        );
      },
    );
  }

  Widget _savedFeed() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: savedStream(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xffff2bd6)),
          );
        }
        final saved = snap.data!.docs;
        if (saved.isEmpty) {
          return _empty('Saxlanılan video yoxdur', 'Bookmark etdiyin videolar burada olacaq.');
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: saved.length,
          itemBuilder: (_, i) {
            final id = saved[i].id;
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('videos').doc(id).get(),
              builder: (_, videoSnap) {
                if (!videoSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doc = videoSnap.data!;
                if (!doc.exists) return _empty('Video silinib', '');
                return _VideoCard(
                  key: ValueKey('saved-$id'),
                  videoId: id,
                  data: doc.data() ?? {},
                  profile: widget.profile,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _tab(String text, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white60,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  fontSize: active ? 16.5 : 15,
                  shadows: const [
                    Shadow(color: Color(0xaa000000), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 26 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xffff2bd6),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: active
                      ? const [BoxShadow(color: Color(0xaaff2bd6), blurRadius: 8)]
                      : null,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _empty(String title, String sub, {bool action = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_display_rounded, color: Colors.white38, size: 64),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              if (action) ...[
                const SizedBox(height: 20),
                VideoUploadButton(profile: widget.profile),
              ],
            ],
          ),
        ),
      );

  Widget _error(String e) => Center(
        child: Text(
          'Video xətası:\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
}

class _VideoCard extends StatefulWidget {
  const _VideoCard({
    super.key,
    required this.videoId,
    required this.data,
    required this.profile,
  });

  final String videoId;
  final Map<String, dynamic> data;
  final UserProfile profile;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? controller;
  bool ready = false;
  bool muted = false;

  late final AnimationController disc = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  DocumentReference<Map<String, dynamic>> get video =>
      FirebaseFirestore.instance.collection('videos').doc(widget.videoId);

  DocumentReference<Map<String, dynamic>> get myLike =>
      video.collection('likes').doc(widget.profile.uid);

  DocumentReference<Map<String, dynamic>> get mySave =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .collection('savedVideos')
          .doc(widget.videoId);

  @override
  void initState() {
    super.initState();
    final url = '${widget.data['videoUrl'] ?? ''}'.trim();
    if (url.isNotEmpty) {
      controller = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (!mounted) return;
          controller!
            ..setLooping(true)
            ..play();
          setState(() => ready = true);
          video.set(
            {'views': FieldValue.increment(1)},
            SetOptions(merge: true),
          ).catchError((_) {});

          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.profile.uid)
              .collection('watchHistory')
              .doc(widget.videoId)
              .set({
            'videoId': widget.videoId,
            'watchedAt': Timestamp.now(),
          }, SetOptions(merge: true)).catchError((_) {});
        }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    disc.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> toggleLike() async {
    final snap = await myLike.get();
    final likedLibrary = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .collection('likedVideos')
        .doc(widget.videoId);

    if (snap.exists) {
      await myLike.delete();
      await likedLibrary.delete();
    } else {
      await myLike.set({'createdAt': Timestamp.now()});
      await likedLibrary.set({
        'videoId': widget.videoId,
        'likedAt': Timestamp.now(),
      });

      try {
        await sendVideoNotification(
          targetUid: '${widget.data['ownerUid'] ?? ''}',
          fromUid: widget.profile.uid,
          fromName: widget.profile.name,
          type: 'video_like',
          body: 'Videonu bəyəndi ❤️',
          videoId: widget.videoId,
        );
      } catch (_) {}
    }
  }

  Future<void> toggleSave() async {
    final snap = await mySave.get();
    if (snap.exists) {
      await mySave.delete();
    } else {
      await mySave.set({
        'videoId': widget.videoId,
        'savedAt': Timestamp.now(),
      });
    }
  }

  void comments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff120d1d),
      builder: (_) => VideoCommentsSheet(
        videoId: widget.videoId,
        profile: widget.profile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return GestureDetector(
      onTap: () {
        if (c == null || !ready) return;
        setState(() => c.value.isPlaying ? c.pause() : c.play());
      },
      onDoubleTap: toggleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (ready && c != null)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xffff2bd6)),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xcc000000)],
              ),
            ),
          ),
          // ---- sol aşağı: ad, təsvir, musiqi ----
          Positioned(
            left: 16,
            right: 86,
            bottom: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _openCreator,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '@${widget.data['ownerName'] ?? 'VIBE'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Color(0xaa000000), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: Color(0xff22a7ff),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _caption('${widget.data['caption'] ?? ''}'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Orijinal səs – ${widget.data['ownerName'] ?? 'VIBE'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Color(0xaa000000), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ---- sağ panel ----
          Positioned(
            right: 10,
            bottom: 22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _creatorAvatar(),
                const SizedBox(height: 20),
                _likeButton(),
                const SizedBox(height: 18),
                _action(Icons.mode_comment_rounded, 'Şərh', comments),
                const SizedBox(height: 18),
                VideoShareButton(
                  profile: widget.profile,
                  videoId: widget.videoId,
                  ownerName: '${widget.data['ownerName'] ?? 'VIBE'}',
                  caption: '${widget.data['caption'] ?? ''}',
                ),
                const SizedBox(height: 18),
                _action(Icons.more_horiz_rounded, '', _openMore),
                const SizedBox(height: 18),
                RotationTransition(
                  turns: disc,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xff2a2140), Color(0xff0d0914)],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xffff2bd6), Color(0xff8b5cff)],
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCreator() {
    final uid = '${widget.data['ownerUid'] ?? ''}';
    if (uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCreatorProfilePage(
          currentProfile: widget.profile,
          creatorUid: uid,
          creatorName: '${widget.data['ownerName'] ?? 'VIBE'}',
        ),
      ),
    );
  }

  /// Hashtag-ləri fərqli rəngdə göstərir.
  Widget _caption(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final spans = <TextSpan>[];
    for (final word in text.split(' ')) {
      final tag = word.startsWith('#');
      spans.add(
        TextSpan(
          text: '$word ',
          style: TextStyle(
            color: tag ? const Color(0xff7ee7ff) : Colors.white,
            fontWeight: tag ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      );
    }

    return RichText(
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.4,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
        ),
        children: spans,
      ),
    );
  }

  /// Avatar + izləmə düyməsi.
  Widget _creatorAvatar() {
    final uid = '${widget.data['ownerUid'] ?? ''}';
    final name = '${widget.data['ownerName'] ?? 'VIBE'}';

    return SizedBox(
      width: 50,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          InkWell(
            onTap: _openCreator,
            child: Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xffff2bd6), Color(0xff8b5cff)],
                ),
              ),
              child: ClipOval(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: uid.isEmpty
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .snapshots(),
                  builder: (context, snapshot) {
                    final d = snapshot.data?.data() ?? const <String, dynamic>{};
                    return VibePhoto(
                      url: '${d['photoUrl'] ?? ''}',
                      name: '${d['name'] ?? name}',
                      emoji: '${d['avatarEmoji'] ?? ''}',
                    );
                  },
                ),
              ),
            ),
          ),
          if (uid.isNotEmpty && uid != widget.profile.uid)
            Positioned(
              bottom: 0,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.profile.uid)
                    .collection('following')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final following = snapshot.data?.exists == true;
                  return InkWell(
                    onTap: () => _toggleFollow(following, uid, name),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: following
                            ? const Color(0xff2de28a)
                            : const Color(0xffff2b55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26, width: 1.5),
                      ),
                      child: Icon(
                        following ? Icons.check_rounded : Icons.add_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow(bool following, String uid, String name) async {
    final mine = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .collection('following')
        .doc(uid);
    final theirs = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .doc(widget.profile.uid);

    final batch = FirebaseFirestore.instance.batch();
    if (following) {
      batch.delete(mine);
      batch.delete(theirs);
    } else {
      batch.set(mine, {
        'uid': uid,
        'name': name,
        'createdAt': Timestamp.now(),
      });
      batch.set(theirs, {
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'createdAt': Timestamp.now(),
      });
    }

    try {
      await batch.commit();
    } catch (_) {}
  }

  /// "..." menyusu: saxla, repost, səs, şikayət, düzəliş.
  void _openMore() {
    final owner = '${widget.data['ownerUid'] ?? ''}' == widget.profile.uid;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: _saveButton()),
                  Expanded(
                    child: VideoRepostButton(
                      profile: widget.profile,
                      videoId: widget.videoId,
                    ),
                  ),
                  Expanded(
                    child: _action(
                      muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      muted ? 'Səssiz' : 'Səs',
                      () {
                        final c = controller;
                        if (c == null) return;
                        setState(() {
                          muted = !muted;
                          c.setVolume(muted ? 0 : 1);
                        });
                        Navigator.pop(sheet);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xff2a2140), height: 20),
            if (owner)
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xff8b5cff)),
                title: const Text('Videonu düzəlt', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoEditPage(
                        videoId: widget.videoId,
                        data: widget.data,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: Color(0xff22a7ff)),
              title: const Text('Video seçimləri', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                showVideoManageSheet(
                  context,
                  profile: widget.profile,
                  videoId: widget.videoId,
                  data: widget.data,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Color(0xffffb24a)),
              title: Text(t('Şikayət et'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                showVideoReportSheet(
                  context,
                  profile: widget.profile,
                  videoId: widget.videoId,
                  ownerUid: '${widget.data['ownerUid'] ?? ''}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _likeButton() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myLike.snapshots(),
      builder: (_, mine) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: video.collection('likes').snapshots(),
        builder: (_, all) => _action(
          mine.data?.exists == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          '${all.data?.docs.length ?? 0}',
          toggleLike,
          active: mine.data?.exists == true,
        ),
      ),
    );
  }

  Widget _saveButton() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: mySave.snapshots(),
      builder: (_, snap) => _action(
        snap.data?.exists == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        snap.data?.exists == true ? 'Saxlanıb' : 'Saxla',
        toggleSave,
        active: snap.data?.exists == true,
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          Icon(
            icon,
            color: active ? const Color(0xffff2bd6) : Colors.white,
            size: 33,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
