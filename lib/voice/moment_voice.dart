import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../ui/vibe_design.dart';
import 'waveform.dart';

/// Səsli anın oynadıcısı.
///
/// Dalğa şəkli sənəddə saxlanılan həqiqi amplitudalardan çəkilir —
/// sükut alçaq, qışqırıq hündür görünür. Bu, faylı endirmədən mümkündür.
///
/// Fayl axınla oxunur: lentdə on səsli an olsa da hamısı endirilmir,
/// yalnız basdığın çalınır.
class MomentVoice extends StatefulWidget {
  const MomentVoice({
    super.key,
    required this.url,
    required this.durationMs,
    required this.waveform,
    this.name = '',
  });

  final String url;
  final int durationMs;
  final List<int> waveform;

  /// Sahibinin adı — oxunmayan fayl üçün mesajda işlənir.
  final String name;

  @override
  State<MomentVoice> createState() => _MomentVoiceState();
}

class _MomentVoiceState extends State<MomentVoice> {
  /// Eyni anda yalnız bir səs çalınsın.
  static _MomentVoiceState? _active;

  final player = AudioPlayer();

  StreamSubscription<Duration>? positionSub;
  StreamSubscription<PlayerState>? stateSub;

  Duration position = Duration.zero;
  bool playing = false;
  bool busy = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();

    positionSub = player.positionStream.listen((value) {
      if (mounted) setState(() => position = value);
    });

    stateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() => playing = state.playing);

      if (state.processingState == ProcessingState.completed) {
        player.seek(Duration.zero);
        player.pause();
      }
    });
  }

  @override
  void dispose() {
    positionSub?.cancel();
    stateSub?.cancel();
    player.dispose();
    if (_active == this) _active = null;
    super.dispose();
  }

  Duration get _total => player.duration ??
      Duration(milliseconds: widget.durationMs.clamp(1, 600000));

  double get _progress {
    final total = _total.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Future<void> _toggle() async {
    if (busy) return;

    if (playing) {
      await player.pause();
      return;
    }

    // Başqa an çalınırsa onu dayandırırıq.
    if (_active != null && _active != this) {
      await _active!.player.pause();
    }
    _active = this;

    setState(() {
      busy = true;
      failed = false;
    });

    try {
      if (player.audioSource == null) {
        await player.setUrl(widget.url);
      }
      await player.play();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _seek(double fraction) async {
    if (player.audioSource == null) return;
    await player.seek(_total * fraction.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final bars = waveformFromData(widget.waveform);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff241a44), Color(0xff17122a)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: vPurple.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          _button(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 34,
                  child: LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _seek(details.localPosition.dx / box.maxWidth),
                      onHorizontalDragUpdate: (details) =>
                          _seek(details.localPosition.dx / box.maxWidth),
                      child: CustomPaint(
                        size: Size(box.maxWidth, 34),
                        painter: _WavePainter(
                          bars: bars,
                          progress: _progress,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      failed
                          ? 'Səs açılmadı'
                          : voiceTimeLabel(
                              playing || position > Duration.zero
                                  ? position.inMilliseconds
                                  : _total.inMilliseconds,
                            ),
                      style: TextStyle(
                        color: failed ? const Color(0xffff657b) : vMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.graphic_eq_rounded,
                        size: 13, color: vMuted),
                    const SizedBox(width: 5),
                    const Text(
                      'Səsli an',
                      style: TextStyle(color: vMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button() => GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: vHot,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: vPink.withValues(alpha: playing ? .45 : .2),
                blurRadius: playing ? 18 : 10,
              ),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
        ),
      );
}

/// 0:07 formatı.
String voiceTimeLabel(int milliseconds) {
  final seconds = (milliseconds / 1000).round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Dalğa sütunları.
///
/// Çalınmış hissə parlaq, qalanı sönükdür — beləcə harada olduğun
/// rəqəmə baxmadan görünür.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.bars, required this.progress});

  final List<int> bars;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) {
      // Dalğa yoxdursa (köhnə sənəd) sadə xətt çəkilir.
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        Paint()
          ..color = vMuted.withValues(alpha: .4)
          ..strokeWidth = 2,
      );
      return;
    }

    final gap = 2.0;
    final width = (size.width - gap * (bars.length - 1)) / bars.length;
    if (width <= 0) return;

    final played = size.width * progress;

    for (var i = 0; i < bars.length; i++) {
      final x = i * (width + gap);

      // Ən kiçik sütun da görünsün deyə alt hədd qoyulur.
      final height = (size.height * (bars[i] / 100)).clamp(3.0, size.height);
      final top = (size.height - height) / 2;

      final passed = x + width / 2 <= played;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, width, height),
          Radius.circular(width / 2),
        ),
        Paint()
          ..color = passed
              ? vPink
              : Colors.white.withValues(alpha: .22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.bars != bars;
}
