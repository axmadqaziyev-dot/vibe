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

class VibeVideoPage extends StatefulWidget {
  const VibeVideoPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<VibeVideoPage> createState() => _VibeVideoPageState();
}

class _VibeVideoPageState extends State<VibeVideoPage> {
  int mode = 0; // 0 = For You, 1 = Following, 2 = Saved
  final Set<String> hiddenIds = <String>{};

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
    });
  }

  Query<Map<String, dynamic>> get feedQuery => FirebaseFirestore.instance
      .collection('videos')
      .where('visibility', isEqualTo: 'public')
      .orderBy('createdAt', descending: true)
      .limit(100);

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
                          .toList();
                      if (docs.isEmpty) {
                        return _empty('Hələ video yoxdur', 'İlk videonu sən paylaş ✨');
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tab('Sənin üçün', mode == 0, () => setState(() => mode = 0)),
                const SizedBox(width: 16),
                _tab('İzlədiklərim', mode == 1, () => setState(() => mode = 1)),
                const SizedBox(width: 16),
                _tab('Saxlanılanlar', mode == 2, () => setState(() => mode = 2)),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 12,
            child: Row(
              children: [
                IconButton.filled(
                  tooltip: 'Hashtag',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HashtagExplorerPage(profile: widget.profile),
                    ),
                  ),
                  icon: const Icon(Icons.tag_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Creator Studio',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatorDashboardPage(profile: widget.profile),
                    ),
                  ),
                  icon: const Icon(Icons.analytics_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Axtar',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoSearchPage(profile: widget.profile),
                    ),
                  ),
                  icon: const Icon(Icons.search_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Video kitabxanam',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoLibraryPage(profile: widget.profile),
                    ),
                  ),
                  icon: const Icon(Icons.video_library_rounded),
                ),
                const SizedBox(width: 8),
                VideoUploadButton(profile: widget.profile),
              ],
            ),
          ),
        ],
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
        child: Column(
          children: [
            Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 34,
              height: 2,
              color: active ? const Color(0xffff2bd6) : Colors.transparent,
            ),
          ],
        ),
      );

  Widget _empty(String title, String sub) => Center(
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

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? controller;
  bool ready = false;
  bool muted = false;

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
          Positioned(
            left: 16,
            right: 86,
            bottom: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
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
                  },
                  child: Text(
                    '@${widget.data['ownerName'] ?? 'VIBE'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                VideoFollowButton(
                  profile: widget.profile,
                  targetUid: '${widget.data['ownerUid'] ?? ''}',
                  targetName: '${widget.data['ownerName'] ?? 'VIBE'}',
                ),
                const SizedBox(height: 7),
                Text(
                  '${widget.data['caption'] ?? ''}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          Positioned(
            top: 82,
            right: 12,
            child: Column(
              children: [
                if ('${widget.data['ownerUid'] ?? ''}' == widget.profile.uid)
                  IconButton.filledTonal(
                    tooltip: 'Videonu düzəlt',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoEditPage(
                          videoId: widget.videoId,
                          data: widget.data,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                IconButton.filledTonal(
              tooltip: 'Video seçimləri',
              onPressed: () => showVideoManageSheet(
                context,
                profile: widget.profile,
                videoId: widget.videoId,
                data: widget.data,
              ),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 30,
            child: Column(
              children: [
                _likeButton(),
                const SizedBox(height: 18),
                _action(Icons.chat_bubble_rounded, 'Şərh', comments),
                const SizedBox(height: 18),
                VideoShareButton(
                  profile: widget.profile,
                  videoId: widget.videoId,
                  ownerName: '${widget.data['ownerName'] ?? 'VIBE'}',
                  caption: '${widget.data['caption'] ?? ''}',
                ),
                const SizedBox(height: 18),
                _saveButton(),
                const SizedBox(height: 12),
                VideoRepostButton(
                  profile: widget.profile,
                  videoId: widget.videoId,
                ),
                const SizedBox(height: 12),
                _action(
                  Icons.flag_outlined,
                  'Şikayət',
                  () => showVideoReportSheet(
                    context,
                    profile: widget.profile,
                    videoId: widget.videoId,
                    ownerUid: '${widget.data['ownerUid'] ?? ''}',
                  ),
                ),
                const SizedBox(height: 12),
                _action(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  muted ? 'Səssiz' : 'Səs',
                  () {
                    if (c == null) return;
                    setState(() {
                      muted = !muted;
                      c.setVolume(muted ? 0 : 1);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
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
