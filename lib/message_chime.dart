import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';

/// Yeni mesaj gələndə səs.
///
/// Tətbiq açıq olanda push bildirişi gəlmir — istifadəçi mesajı
/// görməyə bilər. Bu xidmət söhbətləri izləyir və qarşı tərəfdən
/// mesaj gələndə qısa ton çalır.
///
/// Tətbiq bağlı olanda isə push bildirişi lazımdır; o, ayrıca
/// qurulur (`push_send.dart`).
class MessageChime {
  MessageChime({FirebaseFirestore? database})
      : db = database ?? FirebaseFirestore.instance;

  final FirebaseFirestore db;
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// Xidmət başlayanda mövcud mesajlar üçün səs çalınmamalıdır.
  bool _warm = false;

  /// Hansı söhbətin hansı anını artıq eşitmişik.
  final Map<String, int> _heard = {};

  /// Ard-arda gələn mesajlarda səs yığılmasın.
  DateTime _lastPlayed = DateTime.fromMillisecondsSinceEpoch(0);

  /// Hazırda açıq olan söhbət — orada səs çalmaq mənasızdır.
  String? openChatId;

  Future<void> start(String uid) async {
    await stop();

    try {
      await _player.setAsset('assets/sounds/chime.wav');
      await _player.setVolume(0.7);
    } catch (_) {
      // Səs yüklənməsə də dinləmə davam etsin.
    }

    _sub = db
        .collection('chats')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final at = data['updatedAt'];
        if (at is! Timestamp) continue;

        final stamp = at.millisecondsSinceEpoch;
        final known = _heard[change.doc.id];
        _heard[change.doc.id] = stamp;

        // İlk yükləmədə bütün söhbətlər "yeni" görünür — səs çalmırıq.
        if (!_warm || known == null || stamp <= known) continue;

        // Öz mesajım üçün səs lazım deyil.
        if ('${data['lastSenderId'] ?? ''}' == uid) continue;

        // Açıq söhbətdə mesaj onsuz da ekrandadır.
        if (change.doc.id == openChatId) continue;

        _play();
      }

      _warm = true;
    }, onError: (Object _) {});
  }

  Future<void> _play() async {
    // İki saniyədə birdən çox çalmırıq.
    final now = DateTime.now();
    if (now.difference(_lastPlayed).inMilliseconds < 2000) return;
    _lastPlayed = now;

    try {
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {}
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _warm = false;
    _heard.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
