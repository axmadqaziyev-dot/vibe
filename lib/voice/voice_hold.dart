/// Basıb saxla — səsli mesaj.
///
/// Əvvəl mikrofon düyməsi ayrıca panel açırdı: bas, panel gəlsin,
/// yaz, dayandır, sonra göndər. Dörd toxunuş. WhatsApp-da isə bir
/// hərəkətdir — barmağını basıb saxlayırsan, danışırsan, buraxırsan
/// və mesaj gedir. Sola sürüşdürsən ləğv olunur, yuxarı sürüşdürsən
/// kilidlənir və barmağını götürə bilirsən.
///
/// Yazının özü bu pəncərənin içindədir, üst ekrana heç nə ötürülmür:
/// yazma vəziyyəti `Overlay` ilə göstərilir, ona görə mesaj sırasının
/// quruluşuna toxunmaq lazım gəlmir.
library;

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'audio_file.dart';
import 'voice_message_service.dart';
import 'voice_player.dart';

/// Sola bu qədər sürüşdürsən ləğv olunur.
const double cancelDistance = 90;

/// Yuxarı bu qədər sürüşdürsən kilidlənir.
const double lockDistance = 70;

/// Bundan qısa yazı göndərilmir.
const int minVoiceMs = 600;

/// Sürüşdürmə hansı nəticəyə aparır.
enum HoldGesture { recording, willCancel, willLock }

/// Barmağın yerinə görə nəticəni hesablayır.
///
/// Ayrıca funksiyadır ki, jest məntiqi ekranı açmadan sınana bilsin.
HoldGesture gestureFor(Offset move) {
  // Yuxarı sürüşmə üstünlük təşkil edir: kilidləmək istəyən adam
  // barmağını azca sola da apara bilər.
  if (-move.dy >= lockDistance) return HoldGesture.willLock;
  if (-move.dx >= cancelDistance) return HoldGesture.willCancel;
  return HoldGesture.recording;
}

/// Saniyəni "0:07" şəklinə salır.
String holdTimer(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class VoiceHoldButton extends StatefulWidget {
  const VoiceHoldButton({
    super.key,
    required this.newId,
    required this.send,
    this.enabled = true,
  });

  final String Function() newId;
  final Future<void> Function(VoiceDraft) send;
  final bool enabled;

  @override
  State<VoiceHoldButton> createState() => _VoiceHoldButtonState();
}

class _VoiceHoldButtonState extends State<VoiceHoldButton>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  final clock = Stopwatch();

  Timer? ticker;
  OverlayEntry? overlay;
  String? recordingFile;

  /// Ekranın yenilənməsi üçün — `setState` overlay-i təzələmir.
  final notifier = ValueNotifier<_HoldView>(const _HoldView());

  bool recording = false;
  bool locked = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    _removeOverlay();
    notifier.dispose();
    recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tətbiq arxa plana keçdi — yarımçıq yazını saxlamırıq.
    if (state != AppLifecycleState.resumed && recording) {
      unawaited(_cancel());
    }
  }

  // ----------------------------------------------------------
  // YAZI
  // ----------------------------------------------------------

  Future<void> _start() async {
    if (recording || busy || !widget.enabled) return;
    busy = true;

    try {
      await VoicePlayer.pauseActive();

      if (!await recorder.hasPermission()) {
        _toast('Mikrofona icazə verilmədi.');
        return;
      }

      recordingFile = await newRecordingPath();

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: recordingFile!,
      );

      if (!mounted) {
        await recorder.cancel();
        return;
      }

      clock
        ..reset()
        ..start();

      recording = true;
      locked = false;

      HapticFeedback.mediumImpact();
      _showOverlay();

      ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;

        notifier.value = notifier.value.copyWith(
          elapsed: clock.elapsedMilliseconds,
        );

        // Hədd doldu — özü göndərilir.
        if (clock.elapsedMilliseconds >= maxVoiceSeconds * 1000) {
          unawaited(_finish());
        }
      });
    } catch (_) {
      _toast('Səs yazılmadı. Mikrofonu yoxla.');
    } finally {
      busy = false;
    }
  }

  /// Yazını bitirir və göndərir.
  Future<void> _finish() async {
    if (!recording) return;
    recording = false;

    ticker?.cancel();
    clock.stop();
    _removeOverlay();

    final tooShort = clock.elapsedMilliseconds < minVoiceMs;
    String? path;

    try {
      path = await recorder.stop();

      if (tooShort) {
        _toast('Basıb saxla və danış.');
        return;
      }

      if (path == null) return;

      final file = XFile(path);
      if (await file.length() > maxVoiceBytes) {
        _toast('Səs çox böyükdür.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.length <= 44) return;

      HapticFeedback.lightImpact();

      await widget.send(VoiceDraft(
        id: widget.newId(),
        bytes: bytes,
        durationMs: clock.elapsedMilliseconds
            .clamp(minVoiceMs, maxVoiceSeconds * 1000),
      ));
    } catch (_) {
      _toast('Səs göndərilmədi.');
    } finally {
      if (path != null) {
        try {
          await releaseAudio(path);
        } catch (_) {}
      }
      locked = false;
    }
  }

  /// Yazını atır.
  Future<void> _cancel() async {
    if (!recording) return;
    recording = false;
    locked = false;

    ticker?.cancel();
    clock.stop();
    _removeOverlay();

    HapticFeedback.heavyImpact();

    try {
      await recorder.cancel();
    } catch (_) {}
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // ----------------------------------------------------------
  // JESTLƏR
  // ----------------------------------------------------------

  void _onMove(Offset move) {
    if (!recording || locked) return;

    final gesture = gestureFor(move);

    if (gesture != notifier.value.gesture) {
      HapticFeedback.selectionClick();
    }

    notifier.value = notifier.value.copyWith(gesture: gesture, move: move);

    // Kilid barmağı buraxmadan işə düşür — WhatsApp-da da belədir.
    if (gesture == HoldGesture.willLock) {
      locked = true;
      notifier.value = notifier.value.copyWith(locked: true);
    }
  }

  void _onRelease() {
    if (!recording) return;

    // Kilidlidirsə barmağın buraxılması heç nə etmir — yazı davam edir.
    if (locked) return;

    if (notifier.value.gesture == HoldGesture.willCancel) {
      unawaited(_cancel());
    } else {
      unawaited(_finish());
    }
  }

  // ----------------------------------------------------------
  // EKRAN
  // ----------------------------------------------------------

  void _showOverlay() {
    _removeOverlay();

    notifier.value = const _HoldView();

    overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: ValueListenableBuilder<_HoldView>(
            valueListenable: notifier,
            builder: (context, view, _) => _HoldPanel(
              view: view,
              onCancel: () => unawaited(_cancel()),
              onSend: () => unawaited(_finish()),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay!);
  }

  void _removeOverlay() {
    overlay?.remove();
    overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => unawaited(_start()),
      onLongPressMoveUpdate: (details) => _onMove(details.offsetFromOrigin),
      onLongPressEnd: (_) => _onRelease(),
      onLongPressCancel: _onRelease,
      // Qısa toxunuş: adam nə etməli olduğunu bilmir.
      onTap: () => _toast('Mikrofonu basıb saxla və danış.'),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          Icons.mic_none_rounded,
          color: widget.enabled
              ? const Color(0xff9d7dff)
              : const Color(0xff4a4160),
          size: 24,
        ),
      ),
    );
  }
}

/// Overlay-in göstərdiyi vəziyyət.
class _HoldView {
  const _HoldView({
    this.elapsed = 0,
    this.gesture = HoldGesture.recording,
    this.move = Offset.zero,
    this.locked = false,
  });

  final int elapsed;
  final HoldGesture gesture;
  final Offset move;
  final bool locked;

  _HoldView copyWith({
    int? elapsed,
    HoldGesture? gesture,
    Offset? move,
    bool? locked,
  }) =>
      _HoldView(
        elapsed: elapsed ?? this.elapsed,
        gesture: gesture ?? this.gesture,
        move: move ?? this.move,
        locked: locked ?? this.locked,
      );
}

class _HoldPanel extends StatelessWidget {
  const _HoldPanel({
    required this.view,
    required this.onCancel,
    required this.onSend,
  });

  final _HoldView view;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cancelling = view.gesture == HoldGesture.willCancel;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xff140f1f),
          border: const Border(top: BorderSide(color: Color(0xff2a1a3b))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .4),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!view.locked)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  cancelling
                      ? 'Buraxsan silinəcək'
                      : 'Yuxarı sürüşdür — əlini burax  ↑',
                  style: TextStyle(
                    color: cancelling
                        ? const Color(0xffff8a9b)
                        : const Color(0xff9d94ae),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Row(
              children: [
                _RecordDot(cancelling: cancelling),
                const SizedBox(width: 10),
                Text(
                  holdTimer(view.elapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: view.locked
                      ? const Text(
                          'Kilidləndi — danış, sonra göndər',
                          style: TextStyle(
                            color: Color(0xff9d94ae),
                            fontSize: 12,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              Icons.keyboard_double_arrow_left_rounded,
                              size: 17,
                              color: cancelling
                                  ? const Color(0xffff8a9b)
                                  : const Color(0xff6f6683),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sürüşdür — ləğv et',
                              style: TextStyle(
                                color: cancelling
                                    ? const Color(0xffff8a9b)
                                    : const Color(0xff6f6683),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                if (view.locked) ...[
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Ləğv et',
                      style: TextStyle(color: Color(0xffff8a9b)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onSend,
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff7b3cff), Color(0xffff2bd6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yanıb-sönən qırmızı nöqtə.
class _RecordDot extends StatefulWidget {
  const _RecordDot({required this.cancelling});

  final bool cancelling;

  @override
  State<_RecordDot> createState() => _RecordDotState();
}

class _RecordDotState extends State<_RecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: controller.drive(Tween(begin: .35, end: 1)),
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: widget.cancelling
                ? const Color(0xff6f6683)
                : const Color(0xffff4d5e),
            shape: BoxShape.circle,
          ),
        ),
      );
}
