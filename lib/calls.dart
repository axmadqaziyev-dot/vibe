import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import 'party_rooms.dart' show PartyRoomPage;
import 'user_profile.dart';
import 'voice/ice_servers.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

bool callOpen = false;

Future<void> startCall(
  BuildContext context,
  String uid,
  String name,
  String peer,
  String peerName,
  bool video,
) async {
  if (callOpen) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Zəng artıq açıq görünür. Bir neçə saniyə sonra yenidən yoxla.',
          ),
        ),
      );
    }
    return;
  }

  callOpen = true;
  final ref = FirebaseFirestore.instance.collection('calls').doc();

  try {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            video ? 'VIBE video zəngi başladılır…' : 'VIBE səsli zəngi başladılır…',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await ref.set({
      'caller': uid,
      'callerName': name,
      'callee': peer,
      'members': [uid, peer],
      'video': video,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) {
      await ref.update({'status': 'ended'});
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CallPage(ref: ref, caller: true, video: video, name: peerName),
      ),
    );
  } on FirebaseException catch (error) {
    if (context.mounted) {
      final message = switch (error.code) {
        'permission-denied' =>
          'Firebase zəngə icazə vermir. Firestore qaydalarında calls icazəsi lazımdır.',
        'unauthenticated' =>
          'Hesab girişində problem var. Hesabdan çıxıb yenidən daxil ol.',
        'unavailable' => 'Firebase-ə bağlantı yoxdur. İnterneti yoxla.',
        _ => 'Firebase xətası: ${error.code}',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zəng açılmadı: $error'),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  } finally {
    callOpen = false;
  }
}

class IncomingCalls extends StatefulWidget {
  const IncomingCalls({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<IncomingCalls> createState() => _IncomingCallsState();
}

class _IncomingCallsState extends State<IncomingCalls> {
  StreamSubscription? subscription;
  final seen = <String>{};
  final AudioPlayer ringtone = AudioPlayer();

  static const String _ringtoneData =
      'data:audio/wav;base64,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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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WBN3DBsGBQKZ/8T8z/fu8LXqEukx7239SRBEIUEpmyOOELb1TtzIzQfQ5OIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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';

  @override
  void initState() {
    super.initState();

    subscription = FirebaseFirestore.instance
        .collection('calls')
        .where('callee', isEqualTo: widget.uid)
        .snapshots()
        .listen(
      (snapshot) async {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final at = data['createdAt'];

          if (data['status'] != 'ringing' ||
              seen.contains(doc.id)) {
            continue;
          }

          // Server timestamp gecikərsə zəngi itirmə.
          if (at is Timestamp &&
              DateTime.now().difference(at.toDate()).inSeconds > 90) {
            continue;
          }

          seen.add(doc.id);

          if (callOpen) {
            try {
              await doc.reference.update({'status': 'busy'});
            } catch (_) {}
            continue;
          }

          if (!mounted) return;

          callOpen = true;

          final callerName =
              data['callerName'] as String? ?? 'İstifadəçi';
          final isVideo = data['video'] == true;

          try {
            await _startRingtone();

            if (!mounted) return;

            final accepted = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => _IncomingCallScreen(
                  callerName: callerName,
                  callerUid: '${data['caller'] ?? ''}',
                  video: isVideo,
                  onDecline: () async {
                    try {
                      await doc.reference.update({
                        'status': 'declined',
                        'endedAt': FieldValue.serverTimestamp(),
                      });
                    } catch (_) {}

                    if (context.mounted) {
                      Navigator.of(context).pop(false);
                    }
                  },
                  onAccept: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ),
            );

            await _stopRingtone();

            if (accepted == true && mounted) {
              // Qrup zəngi: çağırış otağa aiddirsə birbaşa ora keçirik.
              final roomId = '${data['roomId'] ?? ''}';

              if (roomId.isNotEmpty) {
                try {
                  await doc.reference.update({'status': 'accepted'});
                } catch (_) {}

                Map<String, dynamic> mine = const {};
                try {
                  final snap = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.uid)
                      .get();
                  mine = snap.data() ?? const {};
                } catch (_) {}

                if (!mounted) return;

                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PartyRoomPage(
                      profile:
                          UserProfile.fromMap({...mine, 'uid': widget.uid}),
                      roomId: roomId,
                    ),
                  ),
                );
              } else {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CallPage(
                      ref: doc.reference,
                      caller: false,
                      video: isVideo,
                      name: callerName,
                      // Qəbul düyməsinə artıq basılıb.
                      autoStart: true,
                    ),
                  ),
                );
              }
            }
          } finally {
            await _stopRingtone();
            callOpen = false;
          }
        }
      },
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gələn zəng xətası: $error',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _startRingtone() async {
    try {
      await ringtone.stop();
      await ringtone.setLoopMode(LoopMode.one);
      await ringtone.setUrl(_ringtoneData);
      await ringtone.setVolume(0.85);
      unawaited(ringtone.play());
    } catch (_) {
      // iPhone Safari autoplay-u bloklaya bilər; ekran yenə açılacaq.
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await ringtone.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    subscription?.cancel();
    unawaited(ringtone.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingCallScreen extends StatefulWidget {
  const _IncomingCallScreen({
    required this.callerName,
    required this.callerUid,
    required this.video,
    required this.onDecline,
    required this.onAccept,
  });

  final String callerName;
  final String callerUid;
  final bool video;
  final Future<void> Function() onDecline;
  final VoidCallback onAccept;

  @override
  State<_IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<_IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: vBg,
        body: AuroraBackground(
          strength: 1.3,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
              child: Column(
                children: [
                  const Center(child: VibeLogo(size: 30)),
                  const Spacer(flex: 2),

                  // ---- avatar + nəbz halqası ----
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: widget.callerUid.isEmpty
                        ? const Stream.empty()
                        : FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.callerUid)
                              .snapshots(),
                    builder: (context, snapshot) {
                      final d = snapshot.data?.data() ?? const <String, dynamic>{};
                      return AnimatedBuilder(
                        animation: pulse,
                        builder: (context, child) {
                          final t = pulse.value;
                          return SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 150 + 50 * t,
                                  height: 150 + 50 * t,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: vPink.withValues(alpha: (1 - t) * .5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child!,
                              ],
                            ),
                          );
                        },
                        child: Container(
                          width: 148,
                          height: 148,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [vPink, vPurple, vBlue],
                            ),
                            boxShadow: [
                              BoxShadow(color: Color(0x66ff2bd6), blurRadius: 34),
                            ],
                          ),
                          child: ClipOval(
                            child: VibePhoto(
                              url: '${d['photoUrl'] ?? ''}',
                              name: widget.callerName,
                              emoji: '${d['avatarEmoji'] ?? ''}',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),

                  Text(
                    widget.callerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video ? 'Video zəng gəlir...' : 'Səsli zəng gəlir...',
                    style: const TextStyle(color: vMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 22),

                  _Waveform(controller: pulse),
                  const Spacer(flex: 2),

                  // ---- kiçik əməliyyatlar ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _smallAction(
                        Icons.chat_bubble_outline_rounded,
                        'Mesaj',
                        () => _quickReply(),
                      ),
                      const SizedBox(width: 44),
                      _smallAction(
                        Icons.alarm_rounded,
                        'Xatırlat',
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${widget.callerName} sonra geri zəng siyahısına əlavə edildi.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ---- əsas düymələr ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _bigButton(
                        color: const Color(0xffff3b4e),
                        icon: Icons.call_end_rounded,
                        label: 'Rədd et',
                        onTap: () async => widget.onDecline(),
                      ),
                      _bigButton(
                        color: const Color(0xff22c55e),
                        icon: widget.video
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        label: 'Cavab ver',
                        onTap: widget.onAccept,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _quickReply() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tez cavab',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            for (final text in const [
              'İndi danışa bilmirəm, sonra zəng edim?',
              'Yoldayam, 10 dəqiqəyə zəng edirəm.',
              'Mesajla yaza bilərsən 💬',
            ])
              ListTile(
                leading: const Icon(Icons.send_rounded, color: vPurple),
                title: Text(text, style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(sheet);
                  await _sendQuickReply(text);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendQuickReply(String text) async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || widget.callerUid.isEmpty) return;

    final ids = [me, widget.callerUid]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    final chat = FirebaseFirestore.instance.collection('chats').doc(chatId);

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chat, {
        'members': [me, widget.callerUid],
        'lastMessage': text,
        'lastSenderId': me,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      batch.set(chat.collection('messages').doc(), {
        'senderId': me,
        'text': text,
        'type': 'text',
        'createdAt': Timestamp.now(),
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cavab göndərildi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cavab göndərilmədi.')),
        );
      }
    }
  }

  Widget _smallAction(IconData icon, String label, VoidCallback onTap) =>
      PressableScale(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: vMuted, fontSize: 12)),
          ],
        ),
      );

  Widget _bigButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => PressableScale(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .45), blurRadius: 24),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 31),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Zəng ekranındakı səs dalğası animasiyası.
class _Waveform extends StatelessWidget {
  const _Waveform({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final t = controller.value;
      return SizedBox(
        height: 34,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 17; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Container(
                  width: 3,
                  height: 6 +
                      24 *
                          (0.5 +
                              0.5 *
                                  math.sin(
                                    (t * 2 * math.pi) + i * 0.7,
                                  )).abs(),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [vPink, vPurple],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
class CallPage extends StatefulWidget {
  const CallPage({
    super.key,
    required this.ref,
    required this.caller,
    required this.video,
    required this.name,
    this.autoStart = false,
  });

  final DocumentReference<Map<String, dynamic>> ref;
  final bool caller;
  final bool video;
  final String name;

  /// Zəng artıq qəbul edilib — yaşıl düyməni bir daha gözləmə.
  ///
  /// Əvvəl gələn zəngdə istifadəçi yaşıl düyməyə iki dəfə basırdı:
  /// biri "zəng gəlir" ekranında, biri də bu səhifədə. İkinci basış
  /// heç nə demirdi — sadəcə mikrofon icazəsini gecikdirirdi.
  final bool autoStart;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final local = RTCVideoRenderer();
  final remote = RTCVideoRenderer();

  RTCPeerConnection? connection;
  MediaStream? media;

  StreamSubscription? signaling;
  StreamSubscription? candidates;

  Timer? timeout;
  Timer? durationTimer;

  DateTime? connectedAt;

  Duration callDuration = Duration.zero;

  bool speakerOn = false;
  bool ready = false;
  bool started = false;
  bool muted = false;
  bool camera = true;

  bool remoteSet = false;
  bool applying = false;
  bool ended = false;
  bool movingToRoom = false;

  final pending = <RTCIceCandidate>[];

  String status = 'Zəng gəlir';

  @override
  void initState() {
    super.initState();

    // Qəbul edilmiş zəng dərhal başlayır: icazə pəncərəsi bir dəfə
    // çıxır və zəng qurulur.
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) begin();
      });
    }

    signaling = widget.ref.snapshots().listen(
      (doc) async {
        final data = doc.data();

        if (data == null || ended) return;

        if (['ended', 'declined', 'busy'].contains(data['status'])) {
          await finish(write: false);
          return;
        }

        // Zəng səsli otağa çevrilib — hər iki tərəf otağa keçir.
        final moveTo = '${data['moveToRoom'] ?? ''}';
        if (moveTo.isNotEmpty && !movingToRoom) {
          movingToRoom = true;
          await _openRoom(moveTo);
          return;
        }

        if (widget.caller &&
            connection != null &&
            data['answer'] != null &&
            !remoteSet &&
            !applying) {
          applying = true;

          try {
            await setRemote(
              Map<String, dynamic>.from(data['answer']),
            );
          } catch (_) {
            fail();
          } finally {
            applying = false;
          }
        }
      },
      onError: (Object error) {
        fail();
      },
    );

    timeout = Timer(
      const Duration(seconds: 60),
      () {
        if (!ended) finish();
      },
    );

    if (widget.caller) {
      begin();
    }
  }

  void fail() {
    if (!mounted || ended) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Zəng alınmadı. Bağlantını və mikrofon/kamera icazəsini yoxlayın.',
        ),
      ),
    );

    finish();
  }

  Future<void> setRemote(
    Map<String, dynamic> sdp,
  ) async {
    await connection!.setRemoteDescription(
      RTCSessionDescription(
        sdp['sdp'],
        sdp['type'],
      ),
    );

    remoteSet = true;

    for (final candidate in pending) {
      await connection!.addCandidate(candidate);
    }

    pending.clear();
  }

  Future<void> begin() async {
    if (started) return;

    setState(() {
      started = true;
      status = 'Bağlanır…';
    });

    try {
      await local.initialize();
      await remote.initialize();

      // Səs emalı açıq olmalıdır.
      //
      // Əvvəl burada sadəcə `'audio': true` yazılmışdı — brauzer əks-səda
      // ləğvini və küy azaltmanı öz istəyi ilə seçirdi. Telefon
      // dinamikdə danışanda qarşı tərəf öz səsini geri eşidirdi.
      //
      // Görüntü üçün ölçü tələb olunur: göstəriş olmayanda brauzer
      // çox vaxt 320x240 verir, ekran isə ondan qat-qat böyükdür —
      // görüntü buna görə "zəif" görünürdü.
      media = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': widget.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : false,
      });

      // Səsli zəng: dinamik bağlı. Video zəng: dinamik açıq.
      speakerOn = widget.video;

      try {
        await Helper.setSpeakerphoneOn(speakerOn);
      } catch (_) {}

      if (mounted) {
        setState(() {});
      }

      if (ended || !mounted) {
        await release();
        return;
      }

      local.srcObject = media;

      // STUN + TURN. TURN olmadan mobil şəbəkələrdə zəng qoşulmur.
      connection = await createPeerConnection(vibeIceConfig);

      if (ended) {
        await release();
        return;
      }

      connection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remote.srcObject = event.streams.first;
        }
      };

      connection!.onConnectionState = (state) {
        if (!mounted || ended) return;

        if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          timeout?.cancel();

          if (connectedAt == null) {
            connectedAt = DateTime.now();

            durationTimer?.cancel();

            durationTimer = Timer.periodic(
              const Duration(seconds: 1),
              (_) {
                if (!mounted || ended || connectedAt == null) return;

                setState(() {
                  callDuration =
                      DateTime.now().difference(connectedAt!);
                });
              },
            );
          }

          setState(() {
            status = 'Zəng davam edir';
          });
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          fail();
        }
      };

      final own = widget.caller
          ? 'callerCandidates'
          : 'calleeCandidates';

      final other = widget.caller
          ? 'calleeCandidates'
          : 'callerCandidates';

      connection!.onIceCandidate = (candidate) async {
        if (!ended && candidate.candidate != null) {
          try {
            await widget.ref
                .collection(own)
                .add(candidate.toMap());
          } catch (_) {
            fail();
          }
        }
      };

      for (final track in media!.getTracks()) {
        await connection!.addTrack(
          track,
          media!,
        );
      }

      candidates = widget.ref
          .collection(other)
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added ||
                  ended) {
                continue;
              }

              final data = change.doc.data()!;

              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              );

              if (remoteSet) {
                await connection!.addCandidate(candidate);
              } else {
                pending.add(candidate);
              }
            }
          } catch (_) {
            fail();
          }
        },
        onError: (Object error) {
          fail();
        },
      );

      if (widget.caller) {
        final offer = await connection!.createOffer();

        await connection!.setLocalDescription(
          offer,
        );

        await widget.ref.update({
          'offer': offer.toMap(),
        });
      } else {
        final doc = await widget.ref
            .snapshots()
            .firstWhere(
              (doc) =>
                  doc.data()?['offer'] != null ||
                  doc.data()?['status'] != 'ringing',
            )
            .timeout(
              const Duration(seconds: 45),
            );

        if (ended) return;

        final offer = doc.data()?['offer'];

        if (offer == null) {
          throw StateError(
            'Offer unavailable',
          );
        }

        await setRemote(
          Map<String, dynamic>.from(offer),
        );

        final answer =
            await connection!.createAnswer();

        await connection!.setLocalDescription(
          answer,
        );

        await widget.ref.update({
          'answer': answer.toMap(),
          'status': 'accepted',
        });
      }

      if (mounted && !ended) {
        setState(() {
          ready = true;
          status = 'Qarşı tərəfə bağlanır…';
        });
      }
    } catch (_) {
      fail();
    }
  }

  Future<void> release() async {
    final stream = media;
    final peer = connection;

    media = null;
    connection = null;

    for (final track
        in stream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }

    await stream?.dispose();
    await peer?.close();
  }

  Future<void> finish({
    bool write = true,
  }) async {
    if (ended) return;

    ended = true;

    timeout?.cancel();
    durationTimer?.cancel();

    final endedAt = DateTime.now();

    final seconds = connectedAt == null
        ? 0
        : endedAt.difference(connectedAt!).inSeconds;

    await release();

    if (write) {
      try {
        await widget.ref.update({
          'status':
              started ? 'ended' : 'declined',
          'endedAt':
              FieldValue.serverTimestamp(),
          'durationSeconds': seconds,
        });
      } catch (_) {}
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    ended = true;

    timeout?.cancel();
    durationTimer?.cancel();

    signaling?.cancel();
    candidates?.cancel();

    release().whenComplete(() {
      local.dispose();
      remote.dispose();
    });

    super.dispose();
  }

  String get durationText {
    final total = callDuration.inSeconds;

    final minutes =
        (total ~/ 60).toString().padLeft(2, '0');

    final seconds =
        (total % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  /// Zəngi qrup zənginə çevirir.
  ///
  /// 1-ə-1 zəngə üçüncü adamı birbaşa qoşmaq mümkün deyil — qrup üçün
  /// otaq quruluşu lazımdır. Amma bu otaq **gizlidir**: siyahıda
  /// görünmür, adı "Qrup zəngi"dir və içindəkilər üçün adi zəng kimi
  /// davranır. Əvvəl açıq party otağı yaradılırdı və hamı içəri girə
  /// bilirdi — zəng gizli söhbətdir, belə olmamalıdır.
  Future<void> _convertToRoom() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || movingToRoom) return;

    movingToRoom = true;
    try {
      final profileSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final myName = '${profileSnap.data()?['name'] ?? 'VIBE'}';

      final roomRef = FirebaseFirestore.instance.collection('partyRooms').doc();
      await roomRef.set({
        'name': 'Qrup zəngi',
        'title': 'Qrup zəngi',
        'hostId': me.uid,
        'hostName': myName,
        'seatCount': 6,
        'memberCount': 0,
        // Gizli otaq: otaqlar siyahısında görünmür.
        'private': true,
        'isCall': true,
        'seats': {
          '0': {'uid': me.uid, 'name': myName, 'muted': false, 'locked': false},
          for (var i = 1; i < 6; i++)
            '$i': {'uid': '', 'name': '', 'muted': false, 'locked': false},
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Qarşı tərəf də eyni otağa keçsin.
      await widget.ref.update({'moveToRoom': roomRef.id});

      await _openRoom(roomRef.id);
    } catch (_) {
      movingToRoom = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Otaq yaradılmadı. Yenidən sına.')),
        );
      }
    }
  }

  /// Zəngi bağlayıb otağı açır.
  Future<void> _openRoom(String roomId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final navigator = Navigator.of(context);
    Map<String, dynamic> data = const {};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      data = snap.data() ?? const {};
    } catch (_) {}

    await finish(write: true);
    if (!mounted) return;

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => PartyRoomPage(
          profile: UserProfile.fromMap({...data, 'uid': me.uid}),
          roomId: roomId,
        ),
      ),
    );
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;

    try {
      await Helper.setSpeakerphoneOn(
        speakerOn,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (
          didPop,
          result,
        ) {
          if (!didPop) {
            finish();
          }
        },
        child: Scaffold(
          backgroundColor:
              const Color(0xff070510),
          body: SafeArea(
            child: Stack(
              children: [
                if (ready)
                  Positioned.fill(
                    child: RTCVideoView(
                      remote,
                      objectFit:
                          RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitCover,
                    ),
                  ),

                if (!ready || !widget.video)
                  Center(
                    child: const CircleAvatar(
                      radius: 54,
                      backgroundColor:
                          Color(0xffff2bd6),
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),

                Positioned(
                  top: 18,
                  left: 20,
                  right:
                      widget.video && ready
                          ? 150
                          : 20,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color:
                                  Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        connectedAt != null
                            ? '${widget.video ? 'Video zəng' : 'Səsli zəng'} · $durationText'
                            : '${widget.video ? 'Video zəng' : 'Səsli zəng'} · $status',
                        style:
                            const TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 15,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color:
                                  Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (ready &&
                    widget.video)
                  Positioned(
                    top: 20,
                    right: 20,
                    width: 110,
                    height: 160,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      child: RTCVideoView(
                        local,
                        mirror: true,
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 36,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceEvenly,
                    children: [
                      if (!started)
                        FloatingActionButton(
                          heroTag: 'accept',
                          backgroundColor:
                              Colors.green,
                          tooltip:
                              'Qəbul et',
                          onPressed: begin,
                          child:
                              const Icon(
                            Icons.call,
                          ),
                        ),

                      if (ready)
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: const Color(0xff21142f), foregroundColor: Colors.white),
                          tooltip:
                              'Mikrofon',
                          onPressed: () {
                            setState(
                              () =>
                                  muted =
                                      !muted,
                            );

                            for (final t
                                in media!
                                    .getAudioTracks()) {
                              t.enabled =
                                  !muted;
                            }
                          },
                          icon: Icon(
                            muted
                                ? Icons
                                    .mic_off
                                : Icons.mic,
                          ),
                        ),

                      if (ready)
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: const Color(0xff21142f), foregroundColor: Colors.white),
                          tooltip:
                              speakerOn
                                  ? 'Dinamik söndür'
                                  : 'Dinamik',
                          onPressed:
                              toggleSpeaker,
                          icon: Icon(
                            speakerOn
                                ? Icons
                                    .volume_up
                                : Icons
                                    .hearing,
                          ),
                        ),

                      if (ready)
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xff21142f),
                            foregroundColor: Colors.white,
                          ),
                          tooltip: 'Dostu əlavə et',
                          onPressed: movingToRoom ? null : _convertToRoom,
                          icon: const Icon(Icons.group_add_rounded),
                        ),

                      if (ready &&
                          widget.video)
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: const Color(0xff21142f), foregroundColor: Colors.white),
                          tooltip:
                              'Kamera',
                          onPressed: () {
                            setState(
                              () =>
                                  camera =
                                      !camera,
                            );

                            for (final t
                                in media!
                                    .getVideoTracks()) {
                              t.enabled =
                                  camera;
                            }
                          },
                          icon: Icon(
                            camera
                                ? Icons
                                    .videocam
                                : Icons
                                    .videocam_off,
                          ),
                        ),

                      FloatingActionButton(
                        heroTag: 'end',
                        backgroundColor:
                            Colors.redAccent,
                        tooltip:
                            'Zəngi bitir',
                        onPressed: finish,
                        child:
                            const Icon(
                          Icons.call_end,
                          color:
                              Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Gizli otağa (qrup zənginə) adam çağırır.
///
/// Adi dəvətdən fərqi: qarşı tərəfdə **zəng çalır**. WhatsApp-da da belədir —
/// əlavə edilən adam bildiriş yox, zəng alır və qəbul edəndə birbaşa
/// söhbətin içinə düşür.
Future<void> ringToRoom({
  required String roomId,
  required String fromUid,
  required String fromName,
  required String toUid,
  bool video = false,
}) async {
  await FirebaseFirestore.instance.collection('calls').add({
    'caller': fromUid,
    'callerName': fromName,
    'callee': toUid,
    'members': [fromUid, toUid],
    'video': video,
    'status': 'ringing',
    // Bu sahə olanda qəbul edən CallPage yox, otağa keçir.
    'roomId': roomId,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

