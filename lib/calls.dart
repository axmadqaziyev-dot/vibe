import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';

bool callOpen = false;

// ============================================================
// ZƏNG TARİXÇƏSİNİ CHATA YAZ
// ============================================================

Future<void> _saveCallHistory({
  required DocumentReference<Map<String, dynamic>> callRef,
  required String callerUid,
  required String callerName,
  required String calleeUid,
  required String calleeName,
  required bool video,
}) async {
  try {
    final callSnapshot = await callRef.get();

    if (!callSnapshot.exists || callSnapshot.data() == null) {
      return;
    }

    final data = callSnapshot.data()!;

    final status = '${data['status'] ?? 'ended'}';

    final durationValue = data['durationSeconds'];

    final durationSeconds =
        durationValue is num ? durationValue.toInt() : 0;

    final accepted =
        data['acceptedAt'] != null ||
        data['answer'] != null ||
        durationSeconds > 0;

    String callStatus;
    String text;

    if (status == 'declined') {
      callStatus = 'declined';

      text = video
          ? '📹 Video zəng · Rədd edildi'
          : '📞 Səsli zəng · Rədd edildi';
    } else if (status == 'busy') {
      callStatus = 'busy';

      text = video
          ? '📹 Video zəng · Məşğul'
          : '📞 Səsli zəng · Məşğul';
    } else if (!accepted) {
      callStatus = 'missed';

      text = video
          ? '📹 Cavabsız video zəng'
          : '📞 Cavabsız zəng';
    } else {
      callStatus = 'answered';

      final durationText =
          _formatDuration(durationSeconds);

      text = video
          ? '📹 Video zəng · $durationText'
          : '📞 Səsli zəng · $durationText';
    }

    final ids = [
      callerUid,
      calleeUid,
    ]..sort();

    final chatId =
        '${ids[0]}_${ids[1]}';

    final firestore =
        FirebaseFirestore.instance;

    final chatRef =
        firestore.collection('chats').doc(chatId);

    final messageRef = chatRef
        .collection('messages')
        .doc('call_${callRef.id}');

    final existing =
        await messageRef.get();

    if (existing.exists) {
      return;
    }

    await chatRef.set(
      {
        'members': [
          callerUid,
          calleeUid,
        ],
        'memberNames': {
          callerUid: callerName,
          calleeUid: calleeName,
        },
        'lastMessage': text,
        'lastMessageAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await messageRef.set({
      'senderId': callerUid,
      'senderName': callerName,
      'recipientId': calleeUid,
      'recipientName': calleeName,
      'type': 'call',
      'text': text,
      'callId': callRef.id,
      'callType':
          video ? 'video' : 'audio',
      'callStatus': callStatus,
      'durationSeconds':
          durationSeconds,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint(
      'Zəng tarixçəsi yazılmadı: $e',
    );
  }
}

String _formatDuration(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '00:00';
  }

  final hours =
      totalSeconds ~/ 3600;

  final minutes =
      (totalSeconds % 3600) ~/ 60;

  final seconds =
      totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

// ============================================================
// ZƏNG BAŞLAT
// ============================================================

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
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Zəng artıq açıqdır. Bir neçə saniyə sonra yenidən yoxla.',
          ),
        ),
      );
    }

    return;
  }

  callOpen = true;

  final ref = FirebaseFirestore
      .instance
      .collection('calls')
      .doc();

  bool callCreated = false;

  try {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            video
                ? 'Video zəng başladılır…'
                : 'Səsli zəng başladılır…',
          ),
          duration:
              const Duration(seconds: 2),
        ),
      );
    }

    await ref.set({
      'caller': uid,
      'callerName': name,
      'callee': peer,
      'calleeName': peerName,
      'members': [
        uid,
        peer,
      ],
      'video': video,
      'status': 'ringing',
      'createdAt':
          FieldValue.serverTimestamp(),
      'durationSeconds': 0,
    });

    callCreated = true;

    if (!context.mounted) {
      await ref.update({
        'status': 'ended',
        'endedAt':
            FieldValue.serverTimestamp(),
      });

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          ref: ref,
          caller: true,
          video: video,
          name: peerName,
        ),
      ),
    );
  } on FirebaseException catch (error) {
    if (context.mounted) {
      final message =
          switch (error.code) {
        'permission-denied' =>
          'Firebase zəngə icazə vermir.',
        'unauthenticated' =>
          'Hesab girişində problem var.',
        'unavailable' =>
          'Firebase bağlantısı yoxdur.',
        _ =>
          'Firebase xətası: ${error.code}',
      };

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
          duration:
              const Duration(seconds: 8),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Zəng açılmadı: $error',
          ),
        ),
      );
    }
  } finally {
    if (callCreated) {
      await _saveCallHistory(
        callRef: ref,
        callerUid: uid,
        callerName: name,
        calleeUid: peer,
        calleeName: peerName,
        video: video,
      );
    }

    callOpen = false;
  }
}

// ============================================================
// GƏLƏN ZƏNGLƏR
// ============================================================

class IncomingCalls
    extends StatefulWidget {
  const IncomingCalls({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<IncomingCalls>
      createState() =>
          _IncomingCallsState();
}

class _IncomingCallsState
    extends State<IncomingCalls> {
  StreamSubscription? subscription;

  final seen = <String>{};

  final AudioPlayer ringtone =
      AudioPlayer();

  @override
  void initState() {
    super.initState();

    subscription =
        FirebaseFirestore.instance
            .collection('calls')
            .where(
              'callee',
              isEqualTo: widget.uid,
            )
            .snapshots()
            .listen(
      (snapshot) async {
        for (final doc
            in snapshot.docs) {
          final data = doc.data();

          final at =
              data['createdAt'];

          if (data['status'] !=
                  'ringing' ||
              seen.contains(doc.id)) {
            continue;
          }

          if (at is Timestamp &&
              DateTime.now()
                      .difference(
                        at.toDate(),
                      )
                      .inSeconds >
                  90) {
            continue;
          }

          seen.add(doc.id);

          if (callOpen) {
            try {
              await doc.reference
                  .update({
                'status': 'busy',
                'endedAt':
                    FieldValue
                        .serverTimestamp(),
              });
            } catch (_) {}

            continue;
          }

          if (!mounted) {
            return;
          }

          callOpen = true;

          final callerName =
              data['callerName']
                      as String? ??
                  'İstifadəçi';

          final isVideo =
              data['video'] == true;

          try {
            await _startRingtone();

            if (!mounted) {
              return;
            }

            final accepted =
                await Navigator.of(
              context,
            ).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    _IncomingCallScreen(
                  callerName:
                      callerName,
                  video: isVideo,
                  onDecline:
                      () async {
                    try {
                      await doc
                          .reference
                          .update({
                        'status':
                            'declined',
                        'endedAt':
                            FieldValue
                                .serverTimestamp(),
                      });
                    } catch (_) {}

                    if (context
                        .mounted) {
                      Navigator.of(
                        context,
                      ).pop(false);
                    }
                  },
                  onAccept:
                      () async {
                    try {
                      await doc
                          .reference
                          .update({
                        'acceptedAt':
                            FieldValue
                                .serverTimestamp(),
                      });
                    } catch (_) {}

                    if (context
                        .mounted) {
                      Navigator.of(
                        context,
                      ).pop(true);
                    }
                  },
                ),
              ),
            );

            await _stopRingtone();

            if (accepted == true &&
                mounted) {
              await Navigator.of(
                context,
              ).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CallPage(
                    ref:
                        doc.reference,
                    caller: false,
                    video: isVideo,
                    name:
                        callerName,
                    autoStart: true,
                  ),
                ),
              );
            }
          } finally {
            await _stopRingtone();

            callOpen = false;
          }
        }
      },
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
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

  Future<void>
      _startRingtone() async {
    // Safari bəzi hallarda avtomatik
    // səsi bloklaya bilər.
    // Gələn zəng ekranı yenə açılır.
    try {
      await ringtone.stop();

      await ringtone.setVolume(
        0.85,
      );
    } catch (_) {}
  }

  Future<void>
      _stopRingtone() async {
    try {
      await ringtone.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    subscription?.cancel();

    unawaited(
      ringtone.dispose(),
    );

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) =>
      widget.child;
}

// ============================================================
// GƏLƏN ZƏNG EKRANI
// ============================================================

class _IncomingCallScreen
    extends StatelessWidget {
  const _IncomingCallScreen({
    required this.callerName,
    required this.video,
    required this.onDecline,
    required this.onAccept,
  });

  final String callerName;
  final bool video;

  final Future<void> Function()
      onDecline;

  final Future<void> Function()
      onAccept;

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            const Color(
          0xff0b141a,
        ),
        body: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              24,
              56,
              24,
              34,
            ),
            child: Column(
              children: [
                const Spacer(),

                const CircleAvatar(
                  radius: 58,
                  backgroundColor:
                      Color(
                    0xff2f80ed,
                  ),
                  child: Icon(
                    Icons
                        .person_rounded,
                    size: 66,
                    color:
                        Colors.white,
                  ),
                ),

                const SizedBox(
                  height: 26,
                ),

                Text(
                  callerName,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 30,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Text(
                  video
                      ? 'VIBE video zəngi gəlir…'
                      : 'VIBE səsli zəngi gəlir…',
                  style:
                      const TextStyle(
                    color: Colors
                        .white70,
                    fontSize: 17,
                  ),
                ),

                const Spacer(),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceEvenly,
                  children: [
                    Column(
                      children: [
                        FloatingActionButton
                            .large(
                          heroTag:
                              'decline_incoming',
                          backgroundColor:
                              Colors
                                  .redAccent,
                          onPressed:
                              () async {
                            await onDecline();
                          },
                          child:
                              const Icon(
                            Icons
                                .call_end_rounded,
                            color:
                                Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        const Text(
                          'Rədd et',
                          style:
                              TextStyle(
                            color: Colors
                                .white70,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        FloatingActionButton
                            .large(
                          heroTag:
                              'accept_incoming',
                          backgroundColor:
                              Colors.green,
                          onPressed:
                              () async {
                            await onAccept();
                          },
                          child: Icon(
                            video
                                ? Icons
                                    .videocam_rounded
                                : Icons
                                    .call_rounded,
                            color:
                                Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        const Text(
                          'Qəbul et',
                          style:
                              TextStyle(
                            color: Colors
                                .white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ƏSAS ZƏNG SƏHİFƏSİ
// ============================================================

class CallPage
    extends StatefulWidget {
  const CallPage({
    super.key,
    required this.ref,
    required this.caller,
    required this.video,
    required this.name,
    this.autoStart = false,
  });

  final DocumentReference<
      Map<String, dynamic>> ref;

  final bool caller;
  final bool video;
  final String name;
  final bool autoStart;

  @override
  State<CallPage> createState() =>
      _CallPageState();
}

class _CallPageState
    extends State<CallPage> {
  final local =
      RTCVideoRenderer();

  final remote =
      RTCVideoRenderer();

  RTCPeerConnection? connection;

  MediaStream? media;

  StreamSubscription? signaling;

  StreamSubscription? candidates;

  Timer? timeout;

  Timer? durationTimer;

  DateTime? connectedAt;

  Duration callDuration =
      Duration.zero;

  bool speakerOn = false;

  bool ready = false;

  bool started = false;

  bool muted = false;

  bool camera = true;

  bool remoteSet = false;

  bool applying = false;

  bool ended = false;

  final pending =
      <RTCIceCandidate>[];

  String status = 'Zəng gəlir';

  @override
  void initState() {
    super.initState();

    signaling =
        widget.ref.snapshots().listen(
      (doc) async {
        final data = doc.data();

        if (data == null ||
            ended) {
          return;
        }

        if ([
          'ended',
          'declined',
          'busy',
        ].contains(
          data['status'],
        )) {
          await finish(
            write: false,
          );

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
              Map<String, dynamic>.from(
                data['answer'],
              ),
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
        if (!ended) {
          finish();
        }
      },
    );

    if (widget.caller ||
        widget.autoStart) {
      begin();
    }
  }

  void fail() {
    if (!mounted || ended) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Zəng alınmadı. İnterneti və mikrofon/kamera icazəsini yoxla.',
        ),
      ),
    );

    finish();
  }

  Future<void> setRemote(
    Map<String, dynamic> sdp,
  ) async {
    await connection!
        .setRemoteDescription(
      RTCSessionDescription(
        sdp['sdp'],
        sdp['type'],
      ),
    );

    remoteSet = true;

    for (final candidate
        in pending) {
      await connection!
          .addCandidate(
        candidate,
      );
    }

    pending.clear();
  }

  Future<void> begin() async {
    if (started) {
      return;
    }

    setState(() {
      started = true;
      status = 'Bağlanır…';
    });

    try {
      await local.initialize();

      await remote.initialize();

      media = await navigator
          .mediaDevices
          .getUserMedia({
        'audio': true,
        'video': widget.video
            ? {
                'facingMode':
                    'user',
              }
            : false,
      });

      speakerOn =
          widget.video;

      try {
        await Helper
            .setSpeakerphoneOn(
          speakerOn,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {});
      }

      if (ended || !mounted) {
        await release();

        return;
      }

      local.srcObject = media;

      const turn =
          String.fromEnvironment(
        'TURN_URL',
      );

      connection =
          await createPeerConnection({
        'iceServers': [
          {
            'urls':
                'stun:stun.l.google.com:19302',
          },
          if (turn.isNotEmpty)
            {
              'urls': turn,
              'username':
                  const String
                      .fromEnvironment(
                'TURN_USERNAME',
              ),
              'credential':
                  const String
                      .fromEnvironment(
                'TURN_CREDENTIAL',
              ),
            },
        ],
      });

      if (ended) {
        await release();

        return;
      }

      connection!.onTrack =
          (event) {
        if (event.streams
            .isNotEmpty) {
          remote.srcObject =
              event.streams.first;
        }
      };

      connection!
              .onConnectionState =
          (state) {
        if (!mounted || ended) {
          return;
        }

        if (state ==
            RTCPeerConnectionState
                .RTCPeerConnectionStateConnected) {
          timeout?.cancel();

          if (connectedAt ==
              null) {
            connectedAt =
                DateTime.now();

            durationTimer
                ?.cancel();

            durationTimer =
                Timer.periodic(
              const Duration(
                seconds: 1,
              ),
              (_) {
                if (!mounted ||
                    ended ||
                    connectedAt ==
                        null) {
                  return;
                }

                setState(() {
                  callDuration =
                      DateTime.now()
                          .difference(
                    connectedAt!,
                  );
                });
              },
            );
          }

          setState(() {
            status =
                'Zəng davam edir';
          });
        } else if (state ==
            RTCPeerConnectionState
                .RTCPeerConnectionStateFailed) {
          fail();
        }
      };

      final own = widget.caller
          ? 'callerCandidates'
          : 'calleeCandidates';

      final other = widget.caller
          ? 'calleeCandidates'
          : 'callerCandidates';

      connection!
              .onIceCandidate =
          (candidate) async {
        if (!ended &&
            candidate.candidate !=
                null) {
          try {
            await widget.ref
                .collection(own)
                .add(
                  candidate.toMap(),
                );
          } catch (_) {
            fail();
          }
        }
      };

      for (final track
          in media!.getTracks()) {
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
            for (final change
                in snapshot
                    .docChanges) {
              if (change.type !=
                      DocumentChangeType
                          .added ||
                  ended) {
                continue;
              }

              final data =
                  change.doc.data()!;

              final candidate =
                  RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data[
                    'sdpMLineIndex'],
              );

              if (remoteSet) {
                await connection!
                    .addCandidate(
                  candidate,
                );
              } else {
                pending.add(
                  candidate,
                );
              }
            }
          } catch (_) {
            fail();
          }
        },
        onError:
            (Object error) {
          fail();
        },
      );

      if (widget.caller) {
        final offer =
            await connection!
                .createOffer();

        await connection!
            .setLocalDescription(
          offer,
        );

        await widget.ref.update({
          'offer':
              offer.toMap(),
        });
      } else {
        final doc = await widget.ref
            .snapshots()
            .firstWhere(
              (doc) =>
                  doc.data()?[
                          'offer'] !=
                      null ||
                  doc.data()?[
                          'status'] !=
                      'ringing',
            )
            .timeout(
              const Duration(
                seconds: 45,
              ),
            );

        if (ended) {
          return;
        }

        final offer =
            doc.data()?['offer'];

        if (offer == null) {
          throw StateError(
            'Offer unavailable',
          );
        }

        await setRemote(
          Map<String, dynamic>.from(
            offer,
          ),
        );

        final answer =
            await connection!
                .createAnswer();

        await connection!
            .setLocalDescription(
          answer,
        );

        await widget.ref.update({
          'answer':
              answer.toMap(),
          'status': 'accepted',
          'acceptedAt':
              FieldValue
                  .serverTimestamp(),
        });
      }

      if (mounted && !ended) {
        setState(() {
          ready = true;

          status =
              'Qarşı tərəfə bağlanır…';
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
        in stream?.getTracks() ??
            <MediaStreamTrack>[]) {
      await track.stop();
    }

    await stream?.dispose();

    await peer?.close();
  }

  Future<void> finish({
    bool write = true,
  }) async {
    if (ended) {
      return;
    }

    ended = true;

    timeout?.cancel();

    durationTimer?.cancel();

    final endedAt =
        DateTime.now();

    final seconds =
        connectedAt == null
            ? 0
            : endedAt
                .difference(
                  connectedAt!,
                )
                .inSeconds;

    await release();

    if (write) {
      try {
        await widget.ref.update({
          'status': started
              ? 'ended'
              : 'declined',
          'endedAt':
              FieldValue
                  .serverTimestamp(),
          'durationSeconds':
              seconds,
        });
      } catch (_) {}
    } else {
      // Qarşı tərəf bitiribsə də
      // öz hesabladığımız müddəti
      // saxlamağa çalışırıq.
      if (seconds > 0) {
        try {
          await widget.ref.update({
            'durationSeconds':
                seconds,
          });
        } catch (_) {}
      }
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
    final total =
        callDuration.inSeconds;

    final minutes =
        (total ~/ 60)
            .toString()
            .padLeft(
              2,
              '0',
            );

    final seconds =
        (total % 60)
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$minutes:$seconds';
  }

  Future<void>
      toggleSpeaker() async {
    speakerOn = !speakerOn;

    try {
      await Helper
          .setSpeakerphoneOn(
        speakerOn,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult:
          (
        didPop,
        result,
      ) {
        if (!didPop) {
          finish();
        }
      },
      child: Scaffold(
        backgroundColor:
            const Color(
          0xff17102e,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (ready &&
                  widget.video)
                Positioned.fill(
                  child:
                      RTCVideoView(
                    remote,
                    objectFit:
                        RTCVideoViewObjectFit
                            .RTCVideoViewObjectFitCover,
                  ),
                ),

              if (!ready ||
                  !widget.video)
                const Center(
                  child:
                      CircleAvatar(
                    radius: 54,
                    backgroundColor:
                        Color(
                      0xff2f80ed,
                    ),
                    child: Icon(
                      Icons
                          .person_rounded,
                      size: 60,
                      color:
                          Colors.white,
                    ),
                  ),
                ),

              Positioned(
                top: 18,
                left: 20,
                right:
                    widget.video &&
                            ready
                        ? 150
                        : 20,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 24,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      connectedAt !=
                              null
                          ? '${widget.video ? 'Video zəng' : 'Səsli zəng'} · $durationText'
                          : '${widget.video ? 'Video zəng' : 'Səsli zəng'} · $status',
                      style:
                          const TextStyle(
                        color: Colors
                            .white70,
                        fontSize: 15,
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
                        BorderRadius
                            .circular(
                      20,
                    ),
                    child:
                        RTCVideoView(
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
                        heroTag:
                            'accept',
                        backgroundColor:
                            Colors.green,
                        onPressed:
                            begin,
                        child:
                            const Icon(
                          Icons.call,
                          color: Colors
                              .white,
                        ),
                      ),

                    if (ready)
                      IconButton.filled(
                        tooltip:
                            'Mikrofon',
                        onPressed: () {
                          setState(() {
                            muted =
                                !muted;
                          });

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

                    if (ready &&
                        widget.video)
                      IconButton.filled(
                        tooltip:
                            'Kamera',
                        onPressed: () {
                          setState(() {
                            camera =
                                !camera;
                          });

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
                          Colors
                              .redAccent,
                      tooltip:
                          'Zəngi bitir',
                      onPressed:
                          finish,
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
}