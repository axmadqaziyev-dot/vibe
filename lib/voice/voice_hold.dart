/// Səsli mesaj — bir toxunuşla.
///
/// Əvvəl iki yanlış yol sınandı:
///
/// 1. Ayrıca panel: bas, panel gəlsin, yaz, dayandır, göndər —
///    dörd toxunuş.
/// 2. Basıb saxlamaq: barmağını ekranda saxlamalısan, uzun danışanda
///    əl yorulur, sürüşdürmə qaydalarını isə heç kim bilmir.
///
/// Instagram-ın yolu sadədir və seçilən budur: mikrofona **basırsan**,
/// yazı başlayır; ekranda yalnız üç şey qalır — **sil**, **dayandır**,
/// **göndər**. Barmağını saxlamaq lazım deyil, nə edəcəyin isə
/// baxan kimi bəllidir.
///
/// Yazma paneli `Overlay` ilə göstərilir: mesaj sırasının quruluşuna
/// toxunmaq lazım gəlmir.
library;

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'audio_file.dart';
import 'mic_keepalive.dart';
import 'voice_message_service.dart';
import 'voice_player.dart';

/// Bundan qısa yazı göndərilmir.
const int minVoiceMs = 600;

/// Saniyəni "0:07" şəklinə salır.
String holdTimer(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Yazının hansı mərhələdə olduğu.
enum VoiceStage {
  /// Yazılmır.
  idle,

  /// Danışır.
  recording,

  /// Dayandırılıb, göndərilməyi gözləyir.
  ready,
}

/// Göndər düyməsi hansı halda işləkdir.
///
/// Ayrıca funksiyadır ki, ekranı açmadan sınana bilsin.
bool canSendVoice(VoiceStage stage, int elapsedMs) {
  if (stage == VoiceStage.idle) return false;
  return elapsedMs >= minVoiceMs;
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

  /// Dayandırıldıqdan sonra hazır olan yazı.
  VoiceDraft? draft;

  final notifier = ValueNotifier<_BarView>(const _BarView());

  VoiceStage stage = VoiceStage.idle;
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
    if (state != AppLifecycleState.resumed) {
      if (stage != VoiceStage.idle) unawaited(_discard());

      // Mikrofon açıq qalmasın: iOS ekranda narıncı nöqtə göstərir.
      releaseMic();
    }
  }

  void _refresh() {
    notifier.value = _BarView(
      stage: stage,
      elapsed: clock.elapsedMilliseconds,
    );
  }

  // ----------------------------------------------------------
  // YAZI
  // ----------------------------------------------------------

  Future<void> _start() async {
    if (stage != VoiceStage.idle || busy || !widget.enabled) return;
    busy = true;

    try {
      await VoicePlayer.pauseActive();

      // İcazə pəncərəsi ilə iki ayrı mübarizə var.
      //
      // BİRİNCİ: `hasPermission()` qəsdən çağırılmır. O, əvvəlcə
      // brauzerin icazə sorğusuna baxır; iOS Safari bu sorğunu
      // mikrofon üçün dəstəkləmir, ona görə paket birbaşa
      // `getUserMedia` çağırır — yəni pəncərə açılır. Sonra `start()`
      // bir də açırdı.
      //
      // İKİNCİ: brauzer icazəni yalnız AÇIQ AXIN varkən qüvvədə
      // saxlayır. Paket yazını bitirəndə axını bağlayır və növbəti
      // dəfə hər şey sıfırdan başlayır. Öz axınımızı açıq saxlayırıq
      // (trek söndürülü) — paketin sorğusu pəncərəsiz keçir.
      await warmMic();

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

      stage = VoiceStage.recording;
      HapticFeedback.mediumImpact();

      _showOverlay();
      _refresh();

      ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        _refresh();

        // Hədd doldu — özü dayanır, göndərmək istifadəçinin işidir.
        if (clock.elapsedMilliseconds >= maxVoiceSeconds * 1000) {
          unawaited(_stop());
        }
      });
    } catch (error) {
      // İcazə verilməyibsə brauzer "NotAllowedError" atır.
      final denied = '$error'.contains('NotAllowed') ||
          '$error'.contains('Permission');

      _toast(denied
          ? 'Mikrofona icazə verilmədi.'
          : 'Səs yazılmadı. Mikrofonu yoxla.');
    } finally {
      busy = false;
    }
  }

  /// Dayandırır, amma göndərmir.
  Future<void> _stop() async {
    if (stage != VoiceStage.recording) return;

    ticker?.cancel();
    clock.stop();

    try {
      final path = await recorder.stop();
      if (path == null) {
        await _discard();
        return;
      }

      final file = XFile(path);
      final bytes = await file.readAsBytes();

      try {
        await releaseAudio(path);
      } catch (_) {}

      if (bytes.length <= 44 || clock.elapsedMilliseconds < minVoiceMs) {
        _toast('Səs çox qısadır.');
        await _discard();
        return;
      }

      if (bytes.lengthInBytes > maxVoiceBytes) {
        _toast('Səs çox böyükdür.');
        await _discard();
        return;
      }

      draft = VoiceDraft(
        id: widget.newId(),
        bytes: bytes,
        durationMs: clock.elapsedMilliseconds
            .clamp(minVoiceMs, maxVoiceSeconds * 1000),
      );

      stage = VoiceStage.ready;
      HapticFeedback.selectionClick();
      _refresh();
    } catch (_) {
      await _discard();
    }
  }

  /// Göndərir. Hələ yazılırsa əvvəlcə dayandırır.
  Future<void> _send() async {
    if (busy) return;

    if (stage == VoiceStage.recording) await _stop();
    if (stage != VoiceStage.ready || draft == null) return;

    busy = true;
    final ready = draft!;

    stage = VoiceStage.idle;
    draft = null;
    _removeOverlay();

    try {
      HapticFeedback.lightImpact();
      await widget.send(ready);
    } catch (_) {
      _toast('Səs göndərilmədi.');
    } finally {
      busy = false;
    }
  }

  /// Atır.
  Future<void> _discard() async {
    ticker?.cancel();
    clock.stop();

    final wasRecording = stage == VoiceStage.recording;

    stage = VoiceStage.idle;
    draft = null;
    _removeOverlay();

    if (wasRecording) {
      HapticFeedback.heavyImpact();
      try {
        await recorder.cancel();
      } catch (_) {}
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // ----------------------------------------------------------
  // EKRAN
  // ----------------------------------------------------------

  void _showOverlay() {
    _removeOverlay();

    overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: ValueListenableBuilder<_BarView>(
            valueListenable: notifier,
            builder: (context, view, _) => _RecordBar(
              view: view,
              onStop: () => unawaited(_stop()),
              onDiscard: () => unawaited(_discard()),
              onSend: () => unawaited(_send()),
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
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Səsli mesaj',
        onPressed: widget.enabled ? () => unawaited(_start()) : null,
        icon: Icon(
          Icons.mic_none_rounded,
          color: widget.enabled
              ? const Color(0xff9d7dff)
              : const Color(0xff4a4160),
        ),
      );
}

class _BarView {
  const _BarView({this.stage = VoiceStage.idle, this.elapsed = 0});

  final VoiceStage stage;
  final int elapsed;
}

/// Yazma paneli.
///
/// Üç düymə: sil, dayandır/davam, göndər. Artıq heç nə yoxdur —
/// panelin bütün məqsədi seçimi sadə saxlamaqdır.
class _RecordBar extends StatelessWidget {
  const _RecordBar({
    required this.view,
    required this.onStop,
    required this.onDiscard,
    required this.onSend,
  });

  final _BarView view;
  final VoidCallback onStop;
  final VoidCallback onDiscard;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final recording = view.stage == VoiceStage.recording;
    final ready = canSendVoice(view.stage, view.elapsed);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Color(0xff0d0917),
          border: Border(top: BorderSide(color: Color(0xff2a1a3b))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bənövşəyi zolaq: solda dayandır, sağda saniyə.
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff7b3cff), Color(0xffff2bd6)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: recording ? onStop : null,
                    child: Icon(
                      recording
                          ? Icons.stop_rounded
                          : Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _Wave(active: recording)),
                  const SizedBox(width: 12),
                  Text(
                    holdTimer(view.elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xffb9b1cb)),
                ),
                Expanded(
                  child: Text(
                    recording ? 'Danış…' : 'Hazırdır — göndər',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xff9d94ae),
                      fontSize: 12.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: ready ? onSend : null,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: ready
                          ? const LinearGradient(
                              colors: [Color(0xff7b3cff), Color(0xffff2bd6)],
                            )
                          : null,
                      color: ready ? null : const Color(0xff241b36),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: ready ? Colors.white : const Color(0xff6f6683),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Zolağın içindəki hərəkətli dalğa.
class _Wave extends StatefulWidget {
  const _Wave({required this.active});

  final bool active;

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          size: const Size(double.infinity, 20),
          painter: _WavePainter(
            phase: widget.active ? controller.value : 0,
            active: widget.active,
          ),
        ),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.phase, required this.active});

  final double phase;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: active ? .85 : .4)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    const gap = 6.0;
    final count = (size.width / gap).floor();

    for (var i = 0; i < count; i++) {
      // Sabit "təsadüfi" hündürlük: hər çəkilişdə eyni olsun, yoxsa
      // dalğa titrəyərdi.
      final seed = ((i * 53) % 17) / 17;
      final wave = active
          ? (0.35 + 0.65 * (1 - (((i / count) + phase) % 1 - .5).abs() * 2))
          : .45;

      final height = (4 + seed * 12) * wave;
      final x = i * gap + gap / 2;

      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.active != active;
}
