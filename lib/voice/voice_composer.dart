import 'dart:async';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'audio_file.dart';
import 'voice_message_service.dart';
import 'voice_player.dart';

class VoiceComposer extends StatefulWidget {
  const VoiceComposer({
    super.key,
    required this.newId,
    required this.send,
    required this.onClose,
  });

  final String Function() newId;
  final Future<void> Function(VoiceDraft) send;
  final VoidCallback onClose;

  @override
  State<VoiceComposer> createState() => _VoiceComposerState();
}

class _VoiceComposerState extends State<VoiceComposer>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  final clock = Stopwatch();

  Timer? ticker;
  VoiceDraft? draft;
  String? error;
  String? recordingFile;

  bool recording = false;
  bool busy = false;
  int elapsed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && recording && !busy) {
      unawaited(stop());
    }
  }

  Future<void> start() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      await VoicePlayer.pauseActive();

      if (!await recorder.hasPermission()) {
        throw StateError(
          'Mikrofona icazə verilməyib. Brauzer və ya telefon parametrlərindən icazə ver.',
        );
      }

      if (!mounted) return;

      recordingFile = await newRecordingPath();

      await recorder.start(
        RecordConfig(
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

      clock.reset();
      clock.start();

      setState(() {
        recording = true;
        elapsed = 0;
      });

      ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;

        setState(() {
          elapsed = clock.elapsedMilliseconds;
        });

        if (elapsed >= maxVoiceSeconds * 1000 && !busy) {
          unawaited(stop());
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError
              ? e.message.toString()
              : 'Səs yazılmadı. Mikrofon icazəsini yoxla. Saytı HTTPS və ya localhost üzərindən aç.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> stop() async {
    if (!recording || busy) return;

    setState(() {
      busy = true;
    });

    ticker?.cancel();
    clock.stop();

    String? path;

    try {
      path = await recorder.stop();

      if (path == null) {
        throw StateError('Səs faylı yaranmadı.');
      }

      final file = XFile(path);

      if (await file.length() > maxVoiceBytes) {
        throw StateError('Səs faylı çox böyükdür. Daha qısa səs yaz.');
      }

      final bytes = await file.readAsBytes();

      if (clock.elapsedMilliseconds < 500 || bytes.length <= 44) {
        throw StateError('Səs çox qısadır. Ən azı bir saniyə danış.');
      }

      if (!mounted) return;

      setState(() {
        draft = VoiceDraft(
          id: widget.newId(),
          bytes: bytes,
          durationMs: clock.elapsedMilliseconds.clamp(
            500,
            maxVoiceSeconds * 1000,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError
              ? e.message.toString()
              : 'Səs saxlanmadı. Yenidən sına.';
        });
      }
    } finally {
      if (path != null) {
        try {
          await releaseAudio(path);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
        });
      }
    }
  }

  Future<void> send() async {
    if (busy || draft == null) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await VoicePlayer.pauseActive();
      await widget.send(draft!);

      if (mounted) {
        widget.onClose();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Səs göndərilmədi. Səsin burada saxlanıb; bağlantını yoxla və yenidən göndər.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();

    final file = recordingFile;

    unawaited(() async {
      try {
        await recorder.cancel();
        await recorder.dispose();

        if (file != null) {
          await releaseAudio(file);
        }
      } catch (_) {}
    }());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Səsi ləğv et',
                    onPressed: busy ? null : widget.onClose,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  Expanded(
                    child: draft != null
                        ? VoicePlayer(
                            key: ValueKey(draft!.id),
                            load: () async => draft!.bytes,
                            durationMs: draft!.durationMs,
                          )
                        : Text(
                            recording
                                ? '● Yazılır ${voiceTime(elapsed)} / 1:00'
                                : 'Səsli mesaj',
                            style: TextStyle(
                              color: recording ? Colors.red : null,
                            ),
                          ),
                  ),
                  if (recording)
                    IconButton.filled(
                      tooltip: 'Yazmanı bitir',
                      onPressed: busy ? null : stop,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else if (draft != null)
                    IconButton.filled(
                      tooltip: 'Səsi göndər',
                      onPressed: busy ? null : send,
                      icon: const Icon(Icons.send_rounded),
                    )
                  else
                    IconButton.filled(
                      tooltip: 'Yenidən yaz',
                      onPressed: busy ? null : start,
                      icon: const Icon(Icons.mic_rounded),
                    ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (draft != null && error == null)
                const Text(
                  'Dinlə, sonra göndər və ya ləğv et.',
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      );
}
