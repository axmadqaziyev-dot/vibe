import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'moment_video.dart';
import 'server_time.dart';
import 'stories.dart';
import 'story_overlay.dart';
import 'ui/vibe_chrome.dart';
import 'ui/vibe_design.dart';
import 'user_profile.dart';

/// Tam ekran stori baxışı.
///
/// Instagram qaydası: hər stori 5 saniyə göstərilir, sağa basmaq
/// növbətiyə keçir, sola basmaq geri qaytarır, basıb saxlamaq
/// dayandırır. Adamın bütün storiləri bitəndə növbəti adama keçir.
class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.groups,
    required this.startIndex,
    required this.profile,
    this.database,
  });

  final List<StoryGroup> groups;
  final int startIndex;
  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  static const _perStory = Duration(seconds: 5);

  late int groupIndex = widget.startIndex;
  int storyIndex = 0;

  Timer? timer;
  double progress = 0;
  bool paused = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  StoryGroup get group => widget.groups[groupIndex];
  Story get story => group.stories[storyIndex];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _markSeen();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    timer?.cancel();
    progress = 0;

    // 50 ms addım: zolaq hamar sürüşsün, amma CPU yorulmasın.
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || paused) return;

      setState(() {
        progress += 50 / _perStory.inMilliseconds;
      });

      if (progress >= 1) _next();
    });
  }

  /// Baxıldı işarəsi.
  ///
  /// Sahibinin öz storisinə baxması sayılmır — yoxsa baxış sayı
  /// yalan olardı.
  Future<void> _markSeen() async {
    if (story.ownerUid == widget.profile.uid) return;

    try {
      final ref = db.collection('stories').doc(story.id);

      await ref.collection('views').doc(widget.profile.uid).set({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'at': Timestamp.now(),
      });

      await ref.set(
        {'viewCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void _next() {
    if (storyIndex + 1 < group.stories.length) {
      setState(() => storyIndex++);
      _startTimer();
      _markSeen();
      return;
    }

    if (groupIndex + 1 < widget.groups.length) {
      setState(() {
        groupIndex++;
        storyIndex = 0;
      });
      _startTimer();
      _markSeen();
      return;
    }

    Navigator.pop(context);
  }

  void _previous() {
    if (storyIndex > 0) {
      setState(() => storyIndex--);
      _startTimer();
      return;
    }

    if (groupIndex > 0) {
      setState(() {
        groupIndex--;
        storyIndex = widget.groups[groupIndex].stories.length - 1;
      });
      _startTimer();
      return;
    }

    // Birincidəyik — yenidən başladırıq.
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          // Sol üçdə bir geri, qalanı irəli.
          if (details.globalPosition.dx < width / 3) {
            _previous();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => setState(() => paused = true),
        onLongPressEnd: (_) => setState(() => paused = false),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _media(),

            // Üstdə və altda tündləşmə — yazılar oxunsun.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xaa000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xaa000000),
                  ],
                  stops: [0, .22, .75, 1],
                ),
              ),
            ),

            // Yazı və stiker tündləşmədən SONRA çəkilir: əks halda
            // pərdə onları da tündləşdirirdi.
            _overlays(),

            SafeArea(
              child: Column(
                children: [
                  _bars(),
                  _header(),
                  const Spacer(),
                  if (story.caption.trim().isNotEmpty) _caption(),
                  if (story.ownerUid == widget.profile.uid) _viewCount(),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _media() {
    if (story.isVideo) {
      return MomentVideo(url: story.videoUrl);
    }

    final image = vibeImageProvider(story.imageUrl);

    // Şəkilsiz stori: rəngli fon. Yazı və stiker onsuz da üstdədir.
    if (image == null) {
      final background = backgroundById(story.background);

      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [for (final value in background.colors) Color(value)],
          ),
        ),
      );
    }

    return Image(
      image: image,
      fit: BoxFit.contain,
      errorBuilder: (context, _, _) => const Center(
        child: Text(
          'Stori açılmadı',
          style: TextStyle(color: vMuted),
        ),
      ),
    );
  }

  /// Storinin üstündəki yazı və stikerlər.
  ///
  /// Yer nisbi saxlanılır, ona görə hər ekran ölçüsündə eyni yerdə
  /// çıxır.
  Widget _overlays() => LayoutBuilder(
        builder: (context, box) {
          final items = StoryOverlay.listFrom(story.overlays);
          if (items.isEmpty) return const SizedBox.shrink();

          final size = box.biggest;

          return Stack(
            children: [
              for (final item in items)
                Positioned(
                  left: item.dx * size.width,
                  top: item.dy * size.height,
                  child: FractionalTranslation(
                    translation: const Offset(-.5, -.5),
                    child: item.kind == OverlayKind.emoji
                        ? Text(
                            item.value,
                            style: TextStyle(fontSize: 34 * item.scale),
                          )
                        : Text(
                            item.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(item.colorValue),
                              fontSize: 22 * item.scale,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                              shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 10),
                              ],
                            ),
                          ),
                  ),
                ),
            ],
          );
        },
      );

  /// Yuxarıdakı gedişat zolaqları — hər stori üçün bir.
  Widget _bars() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Row(
          children: [
            for (var i = 0; i < group.stories.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: i < storyIndex
                          ? 1
                          : i == storyIndex
                              ? progress.clamp(0.0, 1.0)
                              : 0,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 10, 0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: vPurple,
              backgroundImage: group.ownerPhoto.isNotEmpty
                  ? NetworkImage(group.ownerPhoto)
                  : null,
              child: group.ownerPhoto.isEmpty
                  ? Text(
                      group.ownerName.isEmpty
                          ? 'V'
                          : group.ownerName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${storyHours - story.hoursLeft(now: serverNow())}'
                    ' saat əvvəl',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      );

  Widget _caption() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Text(
          story.caption,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      );

  /// Sahibi öz storisinə baxanda neçə nəfərin gördüyünü görür.
  Widget _viewCount() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('stories').doc(story.id).snapshots(),
        builder: (context, snap) {
          final count =
              int.tryParse('${snap.data?.data()?['viewCount'] ?? 0}') ?? 0;

          return Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded,
                    size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  '$count baxış',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          );
        },
      );
}
