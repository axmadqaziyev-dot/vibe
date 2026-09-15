import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_file.dart';

String voiceTime(int milliseconds) {
  final seconds = (milliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class VoicePlayer extends StatefulWidget {
  const VoicePlayer({
    super.key,
    required this.load,
    required this.durationMs,
    this.mine = false,
  });
  final Future<Uint8List> Function() load;
  final int durationMs;
  final bool mine;
  static Future<void> pauseActive() async {
    await _VoicePlayerState.active?.pause();
  }

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> with WidgetsBindingObserver {
  static AudioPlayer? active;
  final player = AudioPlayer();
  String? localUrl;
  bool loading = false;
  bool loaded = false;
  String? error;
  StreamSubscription<PlayerException>? errors;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    errors = player.errorStream.listen((_) {
      if (mounted)
        setState(() {
          loaded = false;
          error = 'Səs açılmadı. Yenidən sına.';
        });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(player.pause());
  }

  Future<void> toggle() async {
    if (loading) return;
    if (player.playing) {
      await player.pause();
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (active != player) await active?.pause();
      active = player;
      if (!loaded) {
        final bytes = await widget.load();
        if (!mounted) return;
        final url = await playableAudio(bytes);
        if (!mounted) {
          await releaseAudio(url);
          return;
        }
        if (localUrl != null) await releaseAudio(localUrl!);
        localUrl = url;
        await player.setUrl(url);
        loaded = true;
      }
      if (!mounted) return;
      if (player.processingState == ProcessingState.completed)
        await player.seek(Duration.zero);
      // play completes when playback finishes; controls must remain interactive.
      unawaited(
        player.play().catchError((Object _) {
          if (mounted)
            setState(() {
              error = 'Səs səslənmədi. Yenidən sına.';
            });
        }),
      );
    } catch (_) {
      if (mounted)
        setState(() {
          loaded = false;
          error = 'Səs yüklənmədi. İnterneti yoxla və yenidən sına.';
        });
    } finally {
      if (mounted)
        setState(() {
          loading = false;
        });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    errors?.cancel();
    if (active == player) active = null;
    final url = localUrl;
    unawaited(
      player
          .dispose()
          .then((_) async {
            if (url != null) await releaseAudio(url);
          })
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mine ? Colors.white : const Color(0xff7c3aed);
    return SizedBox(
      width: 246,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, state) {
              final playing =
                  state.data?.playing == true &&
                  state.data?.processingState != ProcessingState.completed;
              return Row(
                children: [
                  IconButton(
                    onPressed: loading ? null : toggle,
                    tooltip: playing ? 'Dayandır' : 'Səsi dinlə',
                    color: color,
                    icon: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 30,
                          ),
                  ),
                  Expanded(
                    child: StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snapshot) {
                        final max =
                            (player.duration?.inMilliseconds ??
                                    widget.durationMs)
                                .clamp(1, 600000);
                        final at = (snapshot.data?.inMilliseconds ?? 0).clamp(
                          0,
                          max,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: SliderComponentShape.noOverlay,
                              ),
                              child: Slider(
                                value: at.toDouble(),
                                max: max.toDouble(),
                                activeColor: color,
                                onChanged: loaded
                                    ? (v) => player.seek(
                                        Duration(milliseconds: v.round()),
                                      )
                                    : null,
                              ),
                            ),
                            Text(
                              '${voiceTime(at)} / ${voiceTime(widget.durationMs)}',
                              style: TextStyle(color: color, fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Icon(Icons.mic_rounded, size: 18, color: color),
                ],
              );
            },
          ),
          if (error != null)
            Text(error!, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
