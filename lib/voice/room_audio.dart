import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'ice_servers.dart';

/// Səsli otaqlarda CANLI SƏS.
///
/// Qrup səsi üçün adətən pullu SFU (Agora, LiveKit) istifadə olunur.
/// Burada isə əlavə xidmət və ödəniş olmadan işləyən "mesh" quruluşu var:
/// hər iştirakçı digəri ilə birbaşa WebRTC bağlantısı qurur, siqnallaşma
/// isə Firestore üzərindən gedir.
///
/// Mesh kiçik otaqlar üçün nəzərdə tutulub — ona görə eyni anda qoşulan
/// iştirakçı sayı [maxPeers] ilə məhdudlaşdırılır. Otaq böyüyəndə SFU-ya
/// keçmək lazım gələcək; o zaman yalnız bu fayl dəyişəcək.
class RoomAudio {
  RoomAudio({
    required this.roomId,
    required this.uid,
    FirebaseFirestore? database,
  }) : db = database ?? FirebaseFirestore.instance;

  final String roomId;
  final String uid;
  final FirebaseFirestore db;

  /// Eyni anda neçə nəfərlə birbaşa bağlantı saxlanılır.
  static const int maxPeers = 8;

  /// STUN + TURN — `ice_servers.dart`-da ortaq siyahı.
  Map<String, dynamic> get _iceConfig => vibeIceConfig;

  final Map<String, _Peer> _peers = {};
  MediaStream? _microphone;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;

  bool _publishing = false;
  bool _muted = false;
  bool _closed = false;

  /// Otaq görüntülüdürsə kamera da yayımlanır.
  bool _video = false;
  bool _cameraOff = false;

  /// Öz kameramın görüntüsü.
  RTCVideoRenderer? localView;

  /// Video otaqda mesh daha ağırdır — limit kiçikdir.
  static const int maxVideoPeers = 4;

  /// Vəziyyət dəyişəndə UI-ni yeniləmək üçün.
  final ValueNotifier<RoomAudioState> state =
      ValueNotifier<RoomAudioState>(const RoomAudioState());

  CollectionReference<Map<String, dynamic>> get _members =>
      db.collection('partyRooms').doc(roomId).collection('members');

  CollectionReference<Map<String, dynamic>> get _signals =>
      db.collection('partyRooms').doc(roomId).collection('rtc');

  /// Otağa qoşulur.
  ///
  /// [publishing] — mikrofon yerindədirsə `true`.
  /// [video] — görüntülü otaqdırsa kamera da açılır.
  Future<void> join({required bool publishing, bool video = false}) async {
    if (_closed) return;
    _publishing = publishing;
    _video = video;

    try {
      if (publishing) await _openMicrophone();
    } on Object catch (error) {
      state.value = state.value.copyWith(
        error: 'Mikrofona icazə verilmədi',
        connecting: false,
      );
      debugPrint('room audio mic: $error');
      _publishing = false;
    }

    await _announce();
    _watchMembers();
  }

  /// Mikrofon yerinə çıxdı / yerdən düşdü.
  Future<void> setPublishing(bool publishing) async {
    if (_closed || publishing == _publishing) return;
    _publishing = publishing;

    if (publishing) {
      try {
        await _openMicrophone();
      } catch (_) {
        _publishing = false;
        state.value = state.value.copyWith(error: 'Mikrofona icazə verilmədi');
        return;
      }
    } else {
      await _closeMicrophone();
    }

    // Yayım vəziyyəti dəyişdi — bağlantılar yenidən qurulur.
    await _dropAllPeers();
    await _announce();
  }

  /// Səs dinamikdən, yoxsa qulaqlıqdan çıxsın.
  ///
  /// Telefonu qulağına tutub danışmaq istəyəndə dinamik söndürülür —
  /// ətrafdakılar söhbəti eşitmir.
  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
      state.value = state.value.copyWith(speaker: on);
    } catch (_) {
      // Veb və masaüstündə səs çıxışını tətbiq idarə etmir.
    }
  }

  /// Susdurma — bağlantı saxlanılır, yalnız treк söndürülür.
  void setMuted(bool muted) {
    _muted = muted;
    for (final track in _microphone?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
    }
    state.value = state.value.copyWith(muted: muted);
  }

  Future<void> leave() async {
    if (_closed) return;
    _closed = true;

    await _membersSub?.cancel();
    await _dropAllPeers();
    await _closeMicrophone();

    try {
      await _members.doc(uid).set(
        {'audio': false, 'rtcReady': false},
        SetOptions(merge: true),
      );
    } catch (_) {}

    state.dispose();
  }

  // ----------------------------------------------------------
  // MİKROFON
  // ----------------------------------------------------------

  Future<void> _openMicrophone() async {
    if (_microphone != null) return;

    _microphone = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': _video
          ? {
              'facingMode': 'user',
              // Mesh-də hər əlavə axın trafik deməkdir — ölçünü saxlayırıq.
              'width': {'ideal': 480},
              'height': {'ideal': 640},
              'frameRate': {'ideal': 24},
            }
          : false,
    });

    if (_video) {
      final view = RTCVideoRenderer();
      await view.initialize();
      view.srcObject = _microphone;
      localView = view;
      setCameraOff(_cameraOff);
    }

    setMuted(_muted);
  }

  /// Kameranı söndürüb-yandırır (bağlantı qırılmır).
  void setCameraOff(bool off) {
    _cameraOff = off;
    for (final track in _microphone?.getVideoTracks() ?? const []) {
      track.enabled = !off;
    }
    state.value = state.value.copyWith(cameraOff: off);
  }

  /// Ön/arxa kamera dəyişimi.
  Future<void> switchCamera() async {
    final tracks = _microphone?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (_) {}
  }

  /// Qarşı tərəfin görüntüsü (video otaqda).
  RTCVideoRenderer? viewFor(String peerUid) => _peers[peerUid]?.renderer;

  /// Hazırda bağlı olanların siyahısı.
  List<String> get peerUids => _peers.keys.toList();

  Future<void> _closeMicrophone() async {
    final view = localView;
    localView = null;
    if (view != null) {
      view.srcObject = null;
      try {
        await view.dispose();
      } catch (_) {}
    }

    final stream = _microphone;
    _microphone = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  // ----------------------------------------------------------
  // İŞTİRAKÇILAR
  // ----------------------------------------------------------

  Future<void> _announce() async {
    try {
      await _members.doc(uid).set({
        'audio': _publishing,
        'rtcReady': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _watchMembers() {
    _membersSub?.cancel();
    _membersSub = _members.snapshots().listen((snapshot) {
      if (_closed) return;

      // Kimlərlə bağlantı lazımdır:
      //  • mən danışıramsa — hamı məni eşitməlidir
      //  • mən dinləyicəmsə — yalnız danışanlara qoşuluram
      final wanted = <String>[];
      for (final doc in snapshot.docs) {
        if (doc.id == uid) continue;
        if (doc.data()['rtcReady'] != true) continue;
        final theyPublish = doc.data()['audio'] == true;
        if (_publishing || theyPublish) wanted.add(doc.id);
        if (wanted.length >= (_video ? maxVideoPeers : maxPeers)) break;
      }

      for (final peerUid in wanted) {
        if (!_peers.containsKey(peerUid)) _connect(peerUid);
      }
      for (final existing in _peers.keys.toList()) {
        if (!wanted.contains(existing)) _drop(existing);
      }

      state.value = state.value.copyWith(
        peers: _peers.length,
        connecting: _peers.values.any((p) => !p.connected),
      );
    });
  }

  // ----------------------------------------------------------
  // BAĞLANTI
  // ----------------------------------------------------------

  /// Cüt üçün sabit sənəd adı — hər iki tərəf eyni sənədi tapır.
  String _pairId(String other) {
    final ids = [uid, other]..sort();
    return '${ids[0]}__${ids[1]}';
  }

  /// Kiçik uid təklifi (offer) yazır — hər iki tərəf eyni qərara gəlir.
  bool _isCaller(String other) => uid.compareTo(other) < 0;

  Future<void> _connect(String other) async {
    if (_peers.containsKey(other) || _closed) return;

    final peer = _Peer(other);
    _peers[other] = peer;

    try {
      final connection = await createPeerConnection(_iceConfig);
      peer.connection = connection;

      // Dinləyici mikrofon açmadan yalnız qulaq asır.
      if (_publishing && _microphone != null) {
        for (final track in _microphone!.getTracks()) {
          await connection.addTrack(track, _microphone!);
        }
      } else {
        await connection.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.RecvOnly,
          ),
        );
        if (_video) {
          await connection.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(
              direction: TransceiverDirection.RecvOnly,
            ),
          );
        }
      }

      // Gələn səs: web-də səsin çalınması üçün renderer lazımdır.
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      peer.renderer = renderer;

      connection.onTrack = (event) {
        if (event.streams.isEmpty) return;
        peer.renderer?.srcObject = event.streams.first;
        // Video otaqda görüntü gələn kimi şəbəkə yenilənməlidir.
        if (!_closed) {
          state.value = state.value.copyWith(revision: state.value.revision + 1);
        }
      };

      connection.onConnectionState = (status) {
        peer.connected =
            status == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
        if (!_closed) {
          state.value = state.value.copyWith(
            peers: _peers.length,
            connecting: _peers.values.any((p) => !p.connected),
          );
        }
        if (status == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _drop(other);
        }
      };

      final doc = _signals.doc(_pairId(other));
      final caller = _isCaller(other);
      final myCandidates = doc.collection(caller ? 'a' : 'b');
      final theirCandidates = doc.collection(caller ? 'b' : 'a');

      connection.onIceCandidate = (candidate) async {
        if (candidate.candidate == null) return;
        try {
          await myCandidates.add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        } catch (_) {
          // Namizəd yazılmasa bağlantı digər namizədlərlə qurulur.
        }
      };

      peer.candidateSub = theirCandidates.snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null) continue;
          peer.connection?.addCandidate(RTCIceCandidate(
            '${data['candidate']}',
            data['sdpMid'] as String?,
            (data['sdpMLineIndex'] as num?)?.toInt(),
          ));
        }
      });

      if (caller) {
        final offer = await connection.createOffer();
        await connection.setLocalDescription(offer);
        await doc.set({
          'offer': {'sdp': offer.sdp, 'type': offer.type},
          'callerUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        peer.docSub = doc.snapshots().listen((snapshot) async {
          final answer = snapshot.data()?['answer'];
          if (answer == null || peer.remoteSet) return;
          peer.remoteSet = true;
          await peer.connection?.setRemoteDescription(
            RTCSessionDescription('${answer['sdp']}', '${answer['type']}'),
          );
        });
      } else {
        peer.docSub = doc.snapshots().listen((snapshot) async {
          final offer = snapshot.data()?['offer'];
          if (offer == null || peer.remoteSet) return;
          peer.remoteSet = true;

          await peer.connection?.setRemoteDescription(
            RTCSessionDescription('${offer['sdp']}', '${offer['type']}'),
          );
          final answer = await peer.connection?.createAnswer();
          if (answer == null) return;
          await peer.connection?.setLocalDescription(answer);
          await doc.set({
            'answer': {'sdp': answer.sdp, 'type': answer.type},
          }, SetOptions(merge: true));
        });
      }
    } catch (error) {
      debugPrint('room audio connect: $error');
      await _drop(other);
    }
  }

  Future<void> _drop(String other) async {
    final peer = _peers.remove(other);
    if (peer == null) return;
    await peer.dispose();

    // Təklifi yazan tərəf siqnal sənədini də təmizləyir.
    if (_isCaller(other)) {
      try {
        await _signals.doc(_pairId(other)).delete();
      } catch (_) {}
    }
  }

  Future<void> _dropAllPeers() async {
    for (final other in _peers.keys.toList()) {
      await _drop(other);
    }
  }
}

class _Peer {
  _Peer(this.uid);

  final String uid;
  RTCPeerConnection? connection;
  RTCVideoRenderer? renderer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? candidateSub;
  bool connected = false;
  bool remoteSet = false;

  Future<void> dispose() async {
    await docSub?.cancel();
    await candidateSub?.cancel();
    try {
      await connection?.close();
    } catch (_) {}
    try {
      renderer?.srcObject = null;
      await renderer?.dispose();
    } catch (_) {}
  }
}

/// Səs bağlantısının hazırkı vəziyyəti.
class RoomAudioState {
  const RoomAudioState({
    this.peers = 0,
    this.connecting = false,
    this.muted = false,
    this.speaker = true,
    this.cameraOff = false,
    this.revision = 0,
    this.error,
  });

  final int peers;
  final bool connecting;
  final bool muted;

  /// Səs dinamikdən çıxır (false = qulaqlıqdan).
  final bool speaker;

  /// Kamera söndürülüb.
  final bool cameraOff;

  /// Görüntü axınları dəyişəndə artır — UI yenilənsin deyə.
  final int revision;
  final String? error;

  RoomAudioState copyWith({
    int? peers,
    bool? connecting,
    bool? muted,
    bool? speaker,
    bool? cameraOff,
    int? revision,
    String? error,
  }) =>
      RoomAudioState(
        peers: peers ?? this.peers,
        connecting: connecting ?? this.connecting,
        muted: muted ?? this.muted,
        speaker: speaker ?? this.speaker,
        cameraOff: cameraOff ?? this.cameraOff,
        revision: revision ?? this.revision,
        error: error ?? this.error,
      );
}
