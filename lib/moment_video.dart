import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'ui/vibe_design.dart';

/// Anlar lentindəki video.
///
/// Səssiz avtomatik oynamır — istifadəçi toxunanda başlayır.
/// Bu həm trafikə, həm də batareyaya qənaət edir.
class MomentVideo extends StatefulWidget {
  const MomentVideo({super.key, required this.url});

  final String url;

  @override
  State<MomentVideo> createState() => _MomentVideoState();
}

class _MomentVideoState extends State<MomentVideo> {
  VideoPlayerController? controller;
  bool loading = false;
  bool failed = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final existing = controller;
    if (existing != null) {
      existing.value.isPlaying ? await existing.pause() : await existing.play();
      if (mounted) setState(() {});
      return;
    }

    setState(() => loading = true);
    try {
      final created = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await created.initialize();
      await created.setLooping(true);
      await created.play();
      if (!mounted) {
        await created.dispose();
        return;
      }
      setState(() {
        controller = created;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final ratio = player?.value.aspectRatio ?? 4 / 3;

    return GestureDetector(
      onTap: failed ? null : _start,
      child: AspectRatio(
        aspectRatio: ratio <= 0 ? 4 / 3 : ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (player != null && player.value.isInitialized)
              VideoPlayer(player)
            else
              const ColoredBox(color: Color(0xff15102a)),

            if (player == null || !player.value.isPlaying)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          failed
                              ? Icons.videocam_off_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
              ),

            if (failed)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Text(
                  'Video oynadıla bilmədi',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vMuted, fontSize: 12),
                ),
              ),

            if (player != null && player.value.isInitialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  player,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: vPink,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
