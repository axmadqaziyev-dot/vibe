import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// OTAQDA MUSİQİ.
///
/// Host bir mahnı seçir, fayl Supabase-ə yüklənir və otaq sənədinə
/// `music` sahəsi yazılır. Hər iştirakçı həmin faylı öz cihazında oynadır,
/// amma **eyni saniyədən** başlayır: başlanğıc vaxtı sənəddə saxlanılır,
/// hər kəs `indi - başlanğıc` qədər irəli sarır. Beləcə musiqi mikrofondan
/// keçmir — səs təmiz qalır və trafik artmır.
class RoomMusic {
  RoomMusic({required this.roomId, FirebaseFirestore? database})
      : db = database ?? FirebaseFirestore.instance;

  final String roomId;
  final FirebaseFirestore db;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  String? _currentUrl;
  bool _closed = false;

  /// UI üçün: hazırda nə çalınır.
  final ValueNotifier<RoomTrack?> track = ValueNotifier<RoomTrack?>(null);

  DocumentReference<Map<String, dynamic>> get _room =>
      db.collection('partyRooms').doc(roomId);

  /// Otağın musiqisini izləməyə başlayır.
  void start() {
    _sub = _room.snapshots().listen((snapshot) async {
      if (_closed) return;

      final raw = snapshot.data()?['music'];
      if (raw is! Map) {
        await _stop();
        return;
      }

      final data = Map<String, dynamic>.from(raw);
      final url = '${data['url'] ?? ''}';
      final playing = data['playing'] == true;
      final startedAt = data['startedAt'];

      if (url.isEmpty || !playing) {
        await _stop();
        return;
      }

      track.value = RoomTrack(
        url: url,
        title: '${data['title'] ?? 'Mahnı'}',
        by: '${data['by'] ?? ''}',
      );

      // Eyni mahnıdırsa yenidən başlatmırıq.
      if (_currentUrl == url && _player.playing) return;

      try {
        _currentUrl = url;
        await _player.setUrl(url);

        // Hamı eyni yerdən davam etsin.
        if (startedAt is Timestamp) {
          final elapsed = DateTime.now().difference(startedAt.toDate());
          if (elapsed.inSeconds > 1 && elapsed < const Duration(hours: 1)) {
            await _player.seek(elapsed);
          }
        }

        await _player.setVolume(.55);
        await _player.play();
      } catch (_) {
        // Fayl açılmasa səssizcə keçirik — söhbət pozulmasın.
        track.value = null;
      }
    });
  }

  Future<void> _stop() async {
    _currentUrl = null;
    track.value = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Musiqinin səsi (0..1). Söhbət eşidilsin deyə standart 0.55-dir.
  Future<void> setVolume(double value) async {
    try {
      await _player.setVolume(value.clamp(0, 1));
    } catch (_) {}
  }

  /// Host yeni mahnı qoyur.
  Future<void> play({
    required String url,
    required String title,
    required String by,
  }) async {
    await _room.set({
      'music': {
        'url': url,
        'title': title,
        'by': by,
        'playing': true,
        'startedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  /// Host musiqini dayandırır.
  Future<void> stopForEveryone() async {
    await _room.set({
      'music': {'playing': false},
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    _closed = true;
    await _sub?.cancel();
    try {
      await _player.dispose();
    } catch (_) {}
    track.dispose();
  }
}

/// Otaqda çalınan mahnı.
class RoomTrack {
  const RoomTrack({required this.url, required this.title, required this.by});

  final String url;
  final String title;
  final String by;
}
