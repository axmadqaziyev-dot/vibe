import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';
import 'rankings.dart';
import 'vibe_ranking.dart';
import 'game_center.dart';
import 'gifts.dart';
import 'games/domino_page.dart';
import 'package:flutter/services.dart';

import 'coin_wallet.dart';
import 'invite.dart';
import 'room_profile_card.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show RTCVideoRenderer, RTCVideoView, RTCVideoViewObjectFit;
import 'package:image_picker/image_picker.dart';

import 'media_upload.dart';
import 'voice/room_audio.dart';
import 'voice/room_music.dart';
import 'legal.dart';
import 'blocking.dart';
import 'main.dart' show PersonPage;
import 'ui/vibe_design.dart';
import 'ui/room_effects.dart';
import 'ui/vibe_chrome.dart';

const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);
const _blue = Color(0xff22a7ff);
const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _muted = Color(0xffa89fbd);

// PK komandalarının rəngləri — otaqdakı digər maviyə qarışmasın deyə
// ayrıca saxlanılır.
const _pkBlue = Color(0xff2f7bff);
const _pkRed = Color(0xffff3b6b);

/// Kürsünü PK komandasına bölür: soldakı yarı mavi (0), sağdakı yarı qırmızı (1).
///
/// Cüt/tək bölgü də mümkün idi, amma o zaman komanda yoldaşları şəbəkədə
/// bir-birindən aralı düşür və ekrana baxanda kimin kiminlə olduğu bilinmir.
/// Yarıya bölmək TikTok-dakı "sol tərəf / sağ tərəf" görünüşünü verir.
///
/// Tək sayda kürsü olanda artıq bir nəfər mavi tərəfə düşür.
int pkTeamOf(int seatIndex, int seatCount) =>
    seatIndex < (seatCount / 2).ceil() ? 0 : 1;

/// Otaq mövzuları.
///
/// İstifadəçi otağa girməzdən əvvəl onun nə üçün olduğunu görür —
/// rəqib tətbiqlərdə bu, otaq seçimini xeyli asanlaşdırır.
class RoomTheme {
  const RoomTheme({
    required this.id,
    required this.title,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String title;
  final String emoji;
  final Color color;
}

const List<RoomTheme> roomThemes = [
  RoomTheme(id: 'chat', title: 'Söhbət', emoji: '💬', color: Color(0xff8b5cff)),
  RoomTheme(id: 'music', title: 'Musiqi', emoji: '🎵', color: Color(0xff22a7ff)),
  RoomTheme(id: 'game', title: 'Oyun', emoji: '🎮', color: Color(0xff2de28a)),
  RoomTheme(id: 'birthday', title: 'Ad günü', emoji: '🎂', color: Color(0xffff2bd6)),
  RoomTheme(id: 'love', title: 'Tanışlıq', emoji: '💘', color: Color(0xffff657b)),
  RoomTheme(id: 'quiet', title: 'Sakit', emoji: '🌙', color: Color(0xff9d94ae)),
];

RoomTheme themeOf(Map<String, dynamic> roomData) {
  final id = '${roomData['theme'] ?? 'chat'}';
  return roomThemes.firstWhere(
    (t) => t.id == id,
    orElse: () => roomThemes.first,
  );
}

class PartyRoomsPage extends StatefulWidget {
  const PartyRoomsPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<PartyRoomsPage> createState() => _PartyRoomsPageState();
}

class _PartyRoomsPageState extends State<PartyRoomsPage> {
  final rooms = FirebaseFirestore.instance
      .collection('partyRooms')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  Future<void> _createRoom() async {
    final result = await showDialog<_RoomDraft>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final ref = FirebaseFirestore.instance.collection('partyRooms').doc();
      await ref.set({
        'title': result.title,
        'topic': result.topic,
        'hostId': widget.profile.uid,
        'hostName': widget.profile.name,
        'locked': result.locked,
        'password': result.locked ? result.password : '',
        'memberCount': 1,
        'giftTotal': 0,
        'seatCount': result.seatCount,
        'video': result.video,
        'theme': result.theme,
        'moderators': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'seats': {
          '0': {
            'uid': widget.profile.uid,
            'name': widget.profile.name,
            'muted': false,
            'locked': false,
          },
          for (int i = 1; i < result.seatCount; i++)
            '$i': {'uid': '', 'name': '', 'muted': false, 'locked': false},
        },
      });
      // "Ev sahibi" medalı üçün sayğac.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .set({'roomsCreated': FieldValue.increment(1)},
                SetOptions(merge: true));
      } catch (_) {}

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PartyRoomPage(profile: widget.profile, roomId: ref.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Otaq yaradılmadı: $e')),
        );
      }
    }
  }

  /// Otağa necə girmək istədiyini soruşur.
  ///
  /// Adamların əksəriyyəti otağa girməyə çəkinir, çünki girən kimi
  /// siyahıda görünür. Gizli dinləmə həmin maneəni götürür.
  void _roomEntryMenu(DocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.login_rounded, color: _pink),
              title: const Text('Otağa gir',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Siyahıda görünürsən, danışa bilərsən',
                  style: TextStyle(color: _muted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                _openRoom(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.headphones_rounded, color: _blue),
              title: const Text('Gizli qulaq as',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Heç kim səni görmür, sonra üzə çıxa bilərsən',
                  style: TextStyle(color: _muted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                _openRoom(doc, listenOnly: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRoom(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool listenOnly = false,
  }) async {
    final data = doc.data() ?? {};
    if (data['locked'] == true && data['hostId'] != widget.profile.uid) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _PasswordDialog(password: '${data['password'] ?? ''}'),
      );
      if (ok != true || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyRoomPage(
          profile: widget.profile,
          roomId: doc.id,
          listenOnly: listenOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIBE Party',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Səsli otaqlar · oyunlar · hədiyyələr',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_purple, _pink]),
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: IconButton(
                      tooltip: 'Otaq yarat',
                      onPressed: _createRoom,
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: rooms,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Otaqlar yüklənmədi.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _pink),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: _pink,
                            size: 58,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'İlk party otağını sən yarat 💜',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Yerlərin sayını özün seç, host sənsən — '
                            'hədiyyələr və oyunlar hazırdır.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _createRoom,
                            icon: const Icon(Icons.add),
                            label: const Text('Otaq yarat'),
                          ),
                          TextButton.icon(
                            onPressed: () => showInviteSheet(
                              context,
                              name: widget.profile.name,
                              referrerUid: widget.profile.uid,
                            ),
                            icon: const Icon(Icons.group_add_rounded,
                                color: _pink, size: 18),
                            label: const Text(
                              'Dostlarını dəvət et',
                              style: TextStyle(
                                color: _pink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _openRoom(doc),
                      // Uzun basmaq gizli dinləməni təklif edir.
                      onLongPress: () => _roomEntryMenu(doc),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xff372447)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x331b0d2e),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    themeOf(d).color,
                                    Color.lerp(
                                      themeOf(d).color,
                                      Colors.black,
                                      .45,
                                    )!,
                                  ],
                                ),
                              ),
                              child: Text(
                                themeOf(d).emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${d['title'] ?? 'VIBE Room'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (d['video'] == true) ...[
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 6),
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _pink.withValues(alpha: .2),
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            border: Border.all(
                                              color:
                                                  _pink.withValues(alpha: .6),
                                            ),
                                          ),
                                          child: const Text(
                                            'VİDEO',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (d['locked'] == true)
                                        const Icon(
                                          Icons.lock_rounded,
                                          size: 16,
                                          color: _muted,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${d['topic'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: _muted),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      _mini(
                                        Icons.person_rounded,
                                        '${d['hostName'] ?? 'Host'}',
                                      ),
                                      _mini(
                                        Icons.group_rounded,
                                        '${d['memberCount'] ?? 1}',
                                      ),
                                      _mini(
                                        Icons.card_giftcard_rounded,
                                        '${d['giftTotal'] ?? 0}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _purple),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      );
}

class PartyRoomPage extends StatefulWidget {
  const PartyRoomPage({
    super.key,
    required this.profile,
    required this.roomId,
    this.listenOnly = false,
  });

  final UserProfile profile;
  final String roomId;

  /// Gizli dinləmə.
  ///
  /// Adamların əksəriyyəti otağa girməyə çəkinir, çünki girən kimi
  /// siyahıda görünür. Bu rejimdə adın heç yerdə çıxmır, mikrofon
  /// bağlıdır — sadəcə qulaq asırsan. İstəyəndə üzə çıxa bilirsən.
  final bool listenOnly;

  @override
  State<PartyRoomPage> createState() => _PartyRoomPageState();
}

class _PartyRoomPageState extends State<PartyRoomPage> {
  final message = TextEditingController();

  /// Hazırda gizli dinləyirikmi.
  late bool hidden = widget.listenOnly;

  /// Uçan ürəklər üçün vəziyyət.
  final List<int> flyingHearts = <int>[];
  int heartSeed = 0;
  int lastHearts = -1;

  late final DocumentReference<Map<String, dynamic>> room =
      FirebaseFirestore.instance.collection('partyRooms').doc(widget.roomId);

  DocumentReference<Map<String, dynamic>> get me =>
      FirebaseFirestore.instance.collection('users').doc(widget.profile.uid);

  Timer? heartbeat;
  Timer? ticker;

  /// Otağın canlı səsi — WebRTC mesh.
  RoomAudio? audio;

  /// Otaqda çalınan musiqi.
  RoomMusic? music;

  /// Blokladığım (və məni bloklayanların) siyahısı — onların
  /// otaq söhbətindəki mesajları mənə görünmür.
  Set<String> hiddenUids = <String>{};
  StreamSubscription<Set<String>>? hiddenSub;
  bool? lastPublishing;
  bool? lastMuted;

  /// PK geri sayımının işlədiyini bildirir (saniyəlik yeniləmə üçün).
  bool pkRunning = false;

  @override
  void initState() {
    super.initState();
    _joinPresence();
    _startAudio();

    music = RoomMusic(roomId: widget.roomId)..start();
    music!.track.addListener(() {
      if (mounted) setState(() {});
    });

    hiddenSub = watchHiddenUids(widget.profile.uid).listen((uids) {
      if (mounted) setState(() => hiddenUids = uids);
    });
    // PK geri sayımı üçün saniyəlik yeniləmə.
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && pkRunning) setState(() {});
    });

    // Hər 25 saniyədən bir "buradayam" siqnalı; siyahı köhnəlmir.
    heartbeat = Timer.periodic(const Duration(seconds: 25), (_) async {
      try {
        await room.collection('members').doc(widget.profile.uid).set({
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    heartbeat?.cancel();
    message.dispose();
    hiddenSub?.cancel();
    music?.dispose();
    music = null;
    audio?.leave();
    audio = null;
    _leavePresence();
    super.dispose();
  }

  /// Otaq görüntülüdürsə kamera da işə düşür.
  bool videoRoom = false;

  Future<void> _startAudio() async {
    // Otağın növünü öyrənmək üçün bir dəfə oxuyuruq.
    try {
      final snap = await room.get();
      videoRoom = snap.data()?['video'] == true;
    } catch (_) {}

    if (!mounted) return;

    final instance = RoomAudio(
      roomId: widget.roomId,
      uid: widget.profile.uid,
    );
    audio = instance;
    instance.state.addListener(() {
      if (mounted) setState(() {});
    });
    // İlk açılışda izləyici kimi qoşulur; oturacağa çıxanda kamera açılır.
    await instance.join(publishing: false, video: videoRoom);
  }

  /// Otaq sənədi dəyişəndə səs vəziyyətini ona uyğunlaşdırır.
  void _syncAudio(Map<String, dynamic> roomData) {
    final instance = audio;
    if (instance == null) return;

    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    Map<String, dynamic>? mySeat;
    for (final entry in seats.entries) {
      final seat = Map<String, dynamic>.from(entry.value ?? {});
      if (seat['uid'] == widget.profile.uid) {
        mySeat = seat;
        break;
      }
    }

    final publishing = mySeat != null;
    final muted = mySeat?['muted'] == true;

    if (publishing != lastPublishing) {
      lastPublishing = publishing;
      instance.setPublishing(publishing);
    }
    if (muted != lastMuted) {
      lastMuted = muted;
      instance.setMuted(muted);
    }
  }

  Future<void> _joinPresence() async {
    try {
      final userSnap = await me.get();
      final userData = userSnap.data() ?? {};
      final vip = userData['vip'] == true;

      await room.collection('members').doc(widget.profile.uid).set({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'vip': vip,
        'photoUrl': '${userData['photoUrl'] ?? ''}',
        // Gizli dinləyici siyahıda görünmür, yalnız sayılır.
        'hidden': hidden,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Gizli girişdə giriş effekti oynamır — gizli olmağın mənası budur.
      if (!hidden) {
        await room.collection('events').add({
          'type': vip ? 'vip_enter' : 'enter',
          'uid': widget.profile.uid,
          'name': widget.profile.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final count = await room.collection('members').count().get();
      await room.set(
        {
          'memberCount': count.count ?? 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Profildə "hazırda səsli otaqdadır" nişanı — söhbət başlığında
      // görünür və oradan birbaşa otağa keçmək olur.
      if (!hidden) {
        final roomSnap = await room.get();
        await me.set({
          'activeRoomId': widget.roomId,
          'activeRoomName': '${roomSnap.data()?['name'] ?? 'Səsli otaq'}',
          'activeRoomAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }


  /// Gizli dinləməkdən üzə çıxır.
  ///
  /// Otağa yenidən girmək lazım deyil: səs onsuz da açıqdır, yalnız
  /// görünürlük dəyişir.
  Future<void> _reveal() async {
    if (!hidden) return;

    setState(() => hidden = false);

    try {
      await room.collection('members').doc(widget.profile.uid).set(
        {'hidden': false, 'lastSeen': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      await room.collection('events').add({
        'type': 'enter',
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final roomSnap = await room.get();
      await me.set({
        'activeRoomId': widget.roomId,
        'activeRoomName': '${roomSnap.data()?['name'] ?? 'Səsli otaq'}',
        'activeRoomAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted) setState(() => hidden = true);
    }
  }

  /// Gizli rejimdə altda çıxan zolaq.
  Widget _hiddenBar() => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _blue.withValues(alpha: .45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_off_rounded, size: 17, color: _blue),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Gizli dinləyirsən — siyahıda görünmürsən',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _reveal,
              child: const Text(
                'Üzə çıx',
                style: TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _leavePresence() async {
    try {
      await room.collection('members').doc(widget.profile.uid).delete();
      final count = await room.collection('members').count().get();
      await room.set(
        {'memberCount': count.count ?? 0, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await me.set({
        'activeRoomId': FieldValue.delete(),
        'activeRoomName': FieldValue.delete(),
        'activeRoomAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _takeSeat(int index, Map<String, dynamic> roomData) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
    if (seat['locked'] == true && roomData['hostId'] != widget.profile.uid) {
      _toast('Bu mikrofon yeri kilidlidir.');
      return;
    }

    String? currentSeatKey;
    for (final entry in seats.entries) {
      final v = Map<String, dynamic>.from(entry.value ?? {});
      if (v['uid'] == widget.profile.uid) {
        currentSeatKey = entry.key;
        break;
      }
    }
    if (currentSeatKey != null) {
      final currentSeat = Map<String, dynamic>.from(seats[currentSeatKey] ?? {});
      seats[currentSeatKey] = {
        'uid': '',
        'name': '',
        'muted': false,
        'locked': currentSeat['locked'] == true,
      };
    }

    if ('${seat['uid'] ?? ''}'.isNotEmpty && roomData['hostId'] != widget.profile.uid) {
      _toast('Bu yer doludur.');
      return;
    }

    seats['$index'] = {
      'uid': widget.profile.uid,
      'name': widget.profile.name,
      'muted': false,
      'locked': seat['locked'] == true,
    };
    await room.set({'seats': seats}, SetOptions(merge: true));
  }

  Future<void> _leaveSeat(Map<String, dynamic> roomData) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    for (final key in seats.keys) {
      final seat = Map<String, dynamic>.from(seats[key] ?? {});
      if (seat['uid'] == widget.profile.uid && key != '0') {
        seats[key] = {
          'uid': '',
          'name': '',
          'muted': false,
          'locked': seat['locked'] == true,
        };
      }
    }
    await room.set({'seats': seats}, SetOptions(merge: true));
  }

  Future<void> _toggleSeatMute(int index, Map<String, dynamic> roomData) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
    seat['muted'] = seat['muted'] != true;
    seats['$index'] = seat;
    await room.set({'seats': seats}, SetOptions(merge: true));
  }

  Future<void> _toggleSeatLock(int index, Map<String, dynamic> roomData) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
    seat['locked'] = seat['locked'] != true;
    if (seat['locked'] == true && '${seat['uid'] ?? ''}'.isNotEmpty && index != 0) {
      seat['uid'] = '';
      seat['name'] = '';
      seat['muted'] = false;
    }
    seats['$index'] = seat;
    await room.set({'seats': seats}, SetOptions(merge: true));
  }

  Future<void> _kickFromSeat(int index, Map<String, dynamic> roomData) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
    if (index == 0) return;
    seats['$index'] = {
      'uid': '',
      'name': '',
      'muted': false,
      'locked': seat['locked'] == true,
    };
    await room.set({'seats': seats}, SetOptions(merge: true));
  }

  Future<void> _requestMic() async {
    await room.collection('micRequests').doc(widget.profile.uid).set({
      'uid': widget.profile.uid,
      'name': widget.profile.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _toast('Mikrofon istəyi göndərildi.');
  }

  Future<void> _approveRequest(
    QueryDocumentSnapshot<Map<String, dynamic>> req,
    Map<String, dynamic> roomData,
  ) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    String? freeKey;
    for (int i = 1; i < 8; i++) {
      final s = Map<String, dynamic>.from(seats['$i'] ?? {});
      if ('${s['uid'] ?? ''}'.isEmpty && s['locked'] != true) {
        freeKey = '$i';
        break;
      }
    }
    if (freeKey == null) {
      _toast('Boş mikrofon yeri yoxdur.');
      return;
    }
    final d = req.data();
    seats[freeKey] = {
      'uid': '${d['uid'] ?? ''}',
      'name': '${d['name'] ?? ''}',
      'muted': false,
      'locked': false,
    };
    await room.set({'seats': seats}, SetOptions(merge: true));
    await req.reference.delete();
  }

  bool _isModerator(Map<String, dynamic> roomData) {
    final mods = (roomData['moderators'] as List?)
            ?.map((e) => '$e')
            .toSet() ??
        <String>{};
    return roomData['hostId'] == widget.profile.uid ||
        mods.contains(widget.profile.uid);
  }

  Future<void> _toggleModerator(
    String uid,
    String name,
    Map<String, dynamic> roomData,
  ) async {
    final mods = (roomData['moderators'] as List?)
            ?.map((e) => '$e')
            .toList() ??
        <String>[];

    if (mods.contains(uid)) {
      mods.remove(uid);
      _toast('$name moderatorluqdan çıxarıldı.');
    } else {
      mods.add(uid);
      _toast('$name moderator oldu.');
    }

    await room.set({'moderators': mods}, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    if (!guardContent(context, text)) return;

    message.clear();
    try {
      await room.collection('messages').add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Göndərilmədisə mətn itməsin.
      if (!mounted) return;
      message.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj göndərilmədi. Yenidən sına.')),
      );
    }
  }

  /// Hədiyyəni seçilmiş oturacaqdakı istifadəçiyə göndərir.
  ///
  /// Bir tranzaksiyada: göndərənin balansı azalır, alanın `giftReceived`
  /// artır, otaq və oturacaq sayğacları yenilənir.
  Future<void> _sendGift(
    VibeGift gift,
    Map<String, dynamic> roomData, {
    required String seatKey,
    int quantity = 1,
  }) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    final seat = Map<String, dynamic>.from(seats[seatKey] ?? {});
    final targetUid = '${seat['uid'] ?? ''}';
    final targetName = '${seat['name'] ?? ''}';

    if (targetUid.isEmpty || targetUid == widget.profile.uid) return;

    final count = quantity.clamp(1, 99);
    final total = gift.price * count;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final senderSnap = await tx.get(me);
        final data = senderSnap.data() ?? {};
        final coins = int.tryParse('${data['coins'] ?? 0}') ?? 0;

        if (coins < total) throw StateError('coins');

        final sent = (int.tryParse('${data['giftSent'] ?? 0}') ?? 0) + total;
        tx.set(me, {
          'coins': coins - total,
          'giftSent': sent,
          'level': 1 + (sent ~/ 500),
        }, SetOptions(merge: true));

        final targetRef =
            FirebaseFirestore.instance.collection('users').doc(targetUid);
        final targetSnap = await tx.get(targetRef);
        final targetData = targetSnap.data() ?? {};
        final received =
            (int.tryParse('${targetData['giftReceived'] ?? 0}') ?? 0) + total;

        tx.set(targetRef, {
          'giftReceived': received,
          'level': 1 + (received ~/ 500),
        }, SetOptions(merge: true));

        // Otaq və oturacaq sayğacları (avatarın altındakı rəqəm).
        // PK gedirsə eyni hədiyyə həm də yarış xalı sayılır.
        final pkActive = _pkEndsAt(roomData) != null;

        // Yarışda kimin nə qədər dəstək verdiyini də saxlayırıq —
        // zolağın altında ilk dəstəkçilər göstərilir.
        final team = pkActive
            ? pkTeamOf(int.tryParse(seatKey) ?? 0, seatTotal(roomData))
            : 0;

        tx.set(room, {
          'giftTotal': FieldValue.increment(total),
          'seats': {
            seatKey: {
              'gifts': FieldValue.increment(total),
              if (pkActive) 'pkPoints': FieldValue.increment(total),
            },
          },
          if (pkActive)
            'pk': {
              'supporters': {
                widget.profile.uid: {
                  'name': widget.profile.name,
                  'team': team,
                  'points': FieldValue.increment(total),
                },
              },
            },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Günlük və həftəlik lövhələr — həm göndərən, həm otaq üçün.
        recordGiftInTransaction(
          tx,
          db: FirebaseFirestore.instance,
          fromUid: widget.profile.uid,
          fromName: widget.profile.name,
          fromPhoto: '${data['photoUrl'] ?? ''}',
          toUid: targetUid,
          toName: targetName,
          toPhoto: '${targetData['photoUrl'] ?? ''}',
          amount: total,
          roomId: room.id,
          roomTitle: '${roomData['title'] ?? ''}',
        );

        tx.set(room.collection('gifts').doc(), {
          'fromUid': widget.profile.uid,
          'fromName': widget.profile.name,
          'toUid': targetUid,
          'toName': targetName,
          'emoji': gift.emoji,
          'title': gift.title,
          'price': gift.price,
          'quantity': count,
          'total': total,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      // Otaq çatında görünsün.
      try {
        await room.collection('messages').add({
          'uid': widget.profile.uid,
          'name': widget.profile.name,
          'text': '${gift.emoji} $targetName-ə ${gift.title} ×$count göndərdi',
          'type': 'gift',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) _spawnHearts(count.clamp(1, 6));
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Balans çatmır — $total coin lazımdır.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hədiyyə göndərilmədi.')),
        );
      }
    }
  }

  Future<void> _startDice() async {
    final value = Random().nextInt(6) + 1;
    await room.set({
      'game': {
        'type': 'dice',
        'value': value,
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startTruthDare() async {
    const items = [
      'Həqiqət: Buradakı ən maraqlı insan kimdir?',
      'Həqiqət: Son dəfə kimə mesaj yazmısan?',
      'Cəsarət: 10 saniyə mahnı oxu 🎤',
      'Cəsarət: Bir nəfərə kompliment et 💜',
      'Həqiqət: Ən böyük arzun nədir?',
      'Cəsarət: Gülməli səs çıxart 😂',
    ];
    final text = items[Random().nextInt(items.length)];
    await room.set({
      'game': {
        'type': 'truth',
        'text': text,
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startWouldYouRather() async {
    const options = [
      ['Bir ay telefonsuz qalmaq', 'Bir ay internetsiz qalmaq'],
      ['Gələcəyi görmək', 'Keçmişə qayıtmaq'],
      ['Həmişə gecikmək', 'Həmişə 1 saat tez gəlmək'],
      ['Dənizdə yaşamaq', 'Kosmosda yaşamaq'],
    ];
    final q = options[Random().nextInt(options.length)];
    await room.set({
      'game': {
        'type': 'would',
        'left': q[0],
        'right': q[1],
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startRps() async {
    const moves = ['✊', '✋', '✌️'];
    final move = moves[Random().nextInt(moves.length)];
    await room.set({
      'game': {
        'type': 'rps',
        'move': move,
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startSpin() async {
    const tasks = [
      'Bir nəfərə kompliment et 💜',
      '10 saniyə mahnı oxu 🎤',
      'Ən gülməli xatirəni danış 😂',
      'Bir emoji ilə əhvalını göstər 😎',
      'Sürətli sual: sevgi yoxsa pul? 👀',
    ];
    final task = tasks[Random().nextInt(tasks.length)];
    await room.set({
      'game': {
        'type': 'spin',
        'text': task,
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startEmojiGuess() async {
    const puzzles = [
      ['🌞🕶️🏖️', 'Yay'],
      ['🍕❤️', 'Pizza sevgisi'],
      ['✈️🌍📸', 'Səyahət'],
      ['🎤🎶🔥', 'Mahnı'],
    ];
    final p = puzzles[Random().nextInt(puzzles.length)];
    await room.set({
      'game': {
        'type': 'emoji',
        'emoji': p[0],
        'answer': p[1],
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startWordChain() async {
    const starts = ['A', 'B', 'M', 'S', 'T', 'K'];
    final letter = starts[Random().nextInt(starts.length)];
    await room.set({
      'game': {
        'type': 'chain',
        'letter': letter,
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _startQuiz() async {
    const quizzes = [
      {
        'q': 'Azərbaycanın paytaxtı hansıdır?',
        'answers': ['Bakı', 'Gəncə', 'Şəki', 'Quba'],
        'correct': 0,
      },
      {
        'q': '7 × 8 neçə edir?',
        'answers': ['48', '54', '56', '64'],
        'correct': 2,
      },
      {
        'q': 'Dünyanın ən böyük okeanı?',
        'answers': ['Atlantik', 'Sakit', 'Hind', 'Arktika'],
        'correct': 1,
      },
    ];
    final q = quizzes[Random().nextInt(quizzes.length)];
    await room.set({
      'game': {
        'type': 'quiz',
        'question': q['q'],
        'answers': q['answers'],
        'correct': q['correct'],
        'by': widget.profile.name,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> _answerQuiz(int index, Map<String, dynamic> game) async {
    final correct = int.tryParse('${game['correct']}') ?? -1;
    await room.collection('quizAnswers').add({
      'uid': widget.profile.uid,
      'name': widget.profile.name,
      'answer': index,
      'correct': index == correct,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _toast(index == correct ? 'Düz cavab! 🎉' : 'Səhv cavab.');
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  /// Hədiyyə vərəqi: kimə, hansı hədiyyə, neçə ədəd.
  void _openGifts(Map<String, dynamic> roomData) {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});

    // Mikrofonda oturan hər kəs (özümdən başqa) alıcı ola bilər.
    final targets = <MapEntry<String, Map<String, dynamic>>>[];
    for (var i = 0; i < seatTotal(roomData); i++) {
      final seat = Map<String, dynamic>.from(seats['$i'] ?? {});
      final uid = '${seat['uid'] ?? ''}';
      if (uid.isEmpty || uid == widget.profile.uid) continue;
      targets.add(MapEntry('$i', seat));
    }

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hədiyyə göndərmək üçün mikrofonda kimsə olmalıdır.'),
        ),
      );
      return;
    }

    var seatKey = targets.first.key;
    var quantity = 1;
    VibeGift? selected;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- alıcı seçimi ----
                SizedBox(
                  height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: targets.length,
                    itemBuilder: (context, i) {
                      final entry = targets[i];
                      final uid = '${entry.value['uid'] ?? ''}';
                      final name = '${entry.value['name'] ?? ''}';
                      final chosen = seatKey == entry.key;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setSheet(() => seatKey = entry.key),
                          child: SizedBox(
                            width: 54,
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: chosen ? vHot : null,
                                    color: chosen ? null : const Color(0xff241a36),
                                  ),
                                  child: ClipOval(
                                    child: _UserPhoto(uid: uid, name: name),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: chosen ? Colors.white : _muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Color(0xff2a2140), height: 18),

                // ---- hədiyyələr ----
                Flexible(
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .82,
                    children: [
                      for (final gift in giftsFor(DateTime.now()))
                        GestureDetector(
                          onTap: () => setSheet(() => selected = gift),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xff1b1328),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected == gift
                                    ? _pink
                                    : const Color(0xff3d2a54),
                                width: selected == gift ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Text(gift.emoji,
                                        style: const TextStyle(fontSize: 28)),
                                    // Mövsümi hədiyyə fərqlənsin.
                                    if (gift.isSeasonal)
                                      Positioned(
                                        right: -10,
                                        top: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xffffd458),
                                            borderRadius:
                                                BorderRadius.circular(7),
                                          ),
                                          child: const Text(
                                            'YENİ',
                                            style: TextStyle(
                                              color: Color(0xff3a2a00),
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  gift.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${gift.price}',
                                  style: const TextStyle(color: vGold, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---- balans, say, göndər ----
                Row(
                  children: [
                    CoinBadge(uid: widget.profile.uid),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff1b1328),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xff3d2a54)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: quantity > 1
                                ? () => setSheet(() => quantity--)
                                : null,
                            icon: const Icon(Icons.remove_rounded, size: 17),
                            color: Colors.white,
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            onPressed: quantity < 99
                                ? () => setSheet(() => quantity++)
                                : null,
                            icon: const Icon(Icons.add_rounded, size: 17),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GradientButton(
                      label: 'Göndər',
                      icon: Icons.card_giftcard_rounded,
                      expand: false,
                      height: 44,
                      onPressed: selected == null
                          ? null
                          : () {
                              Navigator.pop(sheet);
                              _sendGift(
                                selected!,
                                roomData,
                                seatKey: seatKey,
                                quantity: quantity,
                              );
                            },
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

  void _openGames() {
    final games = <(String, String, Future<void> Function())>[
      ('🎲', 'Zər', _startDice),
      ('🔥', 'Truth/Dare', _startTruthDare),
      ('🧠', 'Quiz', _startQuiz),
      ('🤔', 'Would You Rather', _startWouldYouRather),
      ('✊', 'Daş-Kağız-Qayçı', _startRps),
      ('🎡', 'Spin Wheel', _startSpin),
      ('😎', 'Emoji Guess', _startEmojiGuess),
      ('🔤', 'Söz zənciri', _startWordChain),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.sports_esports_rounded, color: _pink),
                  SizedBox(width: 8),
                  Text(
                    'VIBE Game Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                itemCount: games.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                ),
                itemBuilder: (_, i) {
                  final game = games[i];
                  return _gameButton(game.$1, game.$2, game.$3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameButton(
    String emoji,
    String title,
    Future<void> Function() action,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.pop(context);
        action();
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xff1b1328),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xff3d2a54)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: room.snapshots(),
      builder: (context, roomSnap) {
        if (!roomSnap.hasData || !roomSnap.data!.exists) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator(color: _pink)),
          );
        }
        final d = roomSnap.data!.data() ?? {};

        // Otaqdan çıxarılıbsa, içəri buraxmırıq.
        if (_banned(d).contains(widget.profile.uid)) {
          return _bannedScreen();
        }

        final canModerate = _isModerator(d);
        pkRunning = _pkEndsAt(d) != null;
        final seats = Map<String, dynamic>.from(d['seats'] ?? {});
        final game = Map<String, dynamic>.from(d['game'] ?? {});

        // Oturacaq və susdurma vəziyyətini canlı səsə ötür.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncAudio(d);
        });

        // ürək sayğacı dəyişəndə uçan ürəkləri işə sal
        final hearts = d['hearts'] is num ? (d['hearts'] as num).toInt() : 0;
        if (hearts != lastHearts) {
          final diff = hearts - lastHearts;
          lastHearts = hearts;
          if (diff > 0 && diff < 12) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _spawnHearts(diff);
            });
          }
        }

        return Scaffold(
          backgroundColor: _bg,
          body: AuroraBackground(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  // Geniş ekranda oturacaqlar dağılmasın deyə
                  // məzmun telefon enində saxlanılır.
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Stack(
                children: [
                  Column(
                    children: [
                      _topBar(),
                      _roomHeader(d),
                      const SizedBox(height: 10),
                      _tagRow(d),
                      const SizedBox(height: 10),
                      _pkBanner(d),
                      _announcement(d),
                      const SizedBox(height: 4),
                      _hostBlock(d, seats),
                      const SizedBox(height: 14),
                      if (videoRoom) ...[
                        _videoGrid(seats, d, canModerate),
                        _videoControls(),
                      ] else
                        _seatGrid(seats, d, canModerate),
                      const SizedBox(height: 8),
                      _gameBanner(game),
                      _liveEventStrip(),
                      const SizedBox(height: 6),
                      _musicBar(d),
                      _seatInvite(d),
                      _listeners(d, canModerate),
                      const SizedBox(height: 4),
                      if (hidden) _hiddenBar(),
                      Expanded(child: _chat(d)),
                      _bottomBar(d),
                    ],
                  ),

                  // Gələn səs axınları.
                  //
                  // Səsin çalınması üçün axın ekranda bir elementə bağlı
                  // olmalıdır — xüsusən brauzerdə. Ona görə hər qoşulan
                  // üçün 1x1 ölçülü görünməz element saxlayırıq.
                  if (!videoRoom)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      width: 1,
                      height: 1,
                      child: IgnorePointer(
                        child: Stack(
                          children: [
                            for (final peer in audio?.peerUids ?? const <String>[])
                              if (audio?.viewFor(peer) != null)
                                SizedBox(
                                  width: 1,
                                  height: 1,
                                  child: RTCVideoView(audio!.viewFor(peer)!),
                                ),
                          ],
                        ),
                      ),
                    ),

                  // Giriş lenti və hədiyyə animasiyası.
                  Positioned.fill(
                    child: RoomEffectOverlay(roomId: widget.roomId),
                  ),

                  // uçan ürəklər
                  Positioned(
                    right: 10,
                    bottom: 86,
                    width: 70,
                    height: 260,
                    child: IgnorePointer(
                      child: Stack(
                        children: [
                          for (final heart in flyingHearts)
                            _FlyingHeart(key: ValueKey(heart), seed: heart),
                        ],
                      ),
                    ),
                  ),
                ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // BAŞLIQ
  // ----------------------------------------------------------

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 8, 2),
    child: Row(
      children: [
        PressableScale(
          onTap: _openExitSheet,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: 4),
        const VibeLogo(size: 22),
        const SizedBox(width: 8),
        _audioStatus(),
        const Spacer(),
        TopIconButton(
          icon: Icons.emoji_events_rounded,
          color: const Color(0xffffd86b),
          tooltip: 'Ranking',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VibeRankingPage(profile: widget.profile),
            ),
          ),
        ),
        TopIconButton(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'Otaq menyusu',
          onTap: () => _openRoomMenu(),
        ),
      ],
    ),
  );

  /// Otaqdan çıxış: kiçiltmək (səs davam edir) və ya tam çıxmaq.
  void _openExitSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _exitOption(
                color: const Color(0xff2de28a),
                icon: Icons.close_fullscreen_rounded,
                title: 'Küçült',
                subtitle: 'Otaqda qal, tətbiqin başqa yerinə bax',
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _exitOption(
                color: const Color(0xffff657b),
                icon: Icons.power_settings_new_rounded,
                title: 'Çıxış',
                subtitle: 'Otaqdan tam çıx, mikrofonu bağla',
                onTap: () async {
                  Navigator.pop(sheet);
                  await _leaveSeatIfAny();
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Ləğv et', style: TextStyle(color: _muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exitOption({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff141020),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Çıxarkən mikrofon yerini boşaldır.
  Future<void> _leaveSeatIfAny() async {
    try {
      final snap = await room.get();
      final data = snap.data();
      if (data != null) await _leaveSeat(data);
    } catch (_) {}
  }

  /// Canlı səsin vəziyyəti: qoşulur / eşidilir / mikrofon bağlı.
  Widget _audioStatus() {
    final instance = audio;
    if (instance == null) return const SizedBox.shrink();

    final status = instance.state.value;
    final (label, color, icon) = switch (status) {
      RoomAudioState(error: final e?) => (e, const Color(0xffff657b), Icons.mic_off_rounded),
      RoomAudioState(peers: 0) => ('Səs gözləyir', _muted, Icons.hearing_rounded),
      RoomAudioState(connecting: true) => ('Qoşulur…', const Color(0xffffd458), Icons.wifi_tethering_rounded),
      RoomAudioState(muted: true) => ('Mikrofon bağlı', _muted, Icons.mic_off_rounded),
      _ => ('Canlı səs', const Color(0xff48e08a), Icons.graphic_eq_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Otaq adı, ID, izləyici sayı.
  Widget _roomHeader(Map<String, dynamic> d) {
    final hostId = '${d['hostId'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: ClipOval(child: _UserPhoto(uid: hostId, name: '${d['hostName'] ?? ''}')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '💜 ${d['title'] ?? 'VIBE Party'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${widget.roomId.substring(0, widget.roomId.length < 6 ? widget.roomId.length : 6)}',
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (hostId.isNotEmpty && hostId != widget.profile.uid)
            _FollowHostPill(profile: widget.profile, hostId: hostId, hostName: '${d['hostName'] ?? ''}'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_rounded, size: 12, color: Color(0xff35e18b)),
                const SizedBox(width: 3),
                Text(
                  '${_takenSeats(d)}/${seatTotal(d)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 9),
                const Icon(Icons.headphones_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  compactCount(d['memberCount'] is num ? (d['memberCount'] as num) : 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TopIconButton(
            icon: Icons.more_horiz_rounded,
            color: _muted,
            tooltip: 'Daha çox',
            onTap: _openRoomMenu,
          ),
        ],
      ),
    );
  }

  /// Mövzu etiketləri.
  Widget _tagRow(Map<String, dynamic> d) {
    final topic = '${d['topic'] ?? ''}'.trim();
    final tags = <String>[
      if (topic.isNotEmpty) topic,
      'Söhbət',
      'Musiqi',
      'Əyləncə',
    ];

    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: tags.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: 7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == 0
                  ? _pink.withValues(alpha: .18)
                  : Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: i == 0
                    ? _pink.withValues(alpha: .5)
                    : Colors.white.withValues(alpha: .09),
              ),
            ),
            child: Text(
              tags[i],
              style: TextStyle(
                color: i == 0 ? Colors.white : _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Otaq sahibi — tacla birlikdə böyük avatar.
  Widget _hostBlock(Map<String, dynamic> d, Map<String, dynamic> seats) {
    final seat = Map<String, dynamic>.from(seats['0'] ?? {});
    final uid = '${seat['uid'] ?? d['hostId'] ?? ''}';
    final name = '${seat['name'] ?? d['hostName'] ?? 'Host'}';
    final muted = seat['muted'] == true;
    final empty = '${seat['uid'] ?? ''}'.isEmpty;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -16,
              child: Icon(
                Icons.workspace_premium_rounded,
                color: const Color(0xffffd86b).withValues(alpha: empty ? .35 : 1),
                size: 24,
              ),
            ),
            GestureDetector(
              onTap: empty ? () => _takeSeat(0, d) : null,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_pink, _purple, _blue]),
                  boxShadow: [
                    BoxShadow(
                      color: _pink.withValues(alpha: muted ? .15 : .45),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: empty
                      ? Container(
                          color: const Color(0xff1b1430),
                          child: const Icon(Icons.add_rounded, color: Colors.white),
                        )
                      : _UserPhoto(uid: uid, name: name),
                ),
              ),
            ),
            if (!empty)
              Positioned(
                right: 4,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: muted ? const Color(0xff5e5470) : const Color(0xff35e18b),
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2),
                  ),
                  child: Icon(
                    muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          empty ? 'Host yeri boşdur' : name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Otaq sahibi',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // OTURACAQLAR
  // ----------------------------------------------------------

  Widget _seatGrid(
    Map<String, dynamic> seats,
    Map<String, dynamic> roomData,
    bool canModerate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // 0 nömrəli yer host blokundadır, qalanları burada.
        itemCount: (seatTotal(roomData) - 1).clamp(0, 30),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: seatTotal(roomData) <= 4 ? 3 : 4,
          childAspectRatio: .84,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemBuilder: (_, position) {
          final index = position + 1; // 0 host bloklarındadır
          final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
          final uid = '${seat['uid'] ?? ''}';
          final name = '${seat['name'] ?? ''}';
          final empty = uid.isEmpty;
          final muted = seat['muted'] == true;
          final locked = seat['locked'] == true;
          final mine = uid == widget.profile.uid;
          final isMod = ((roomData['moderators'] as List?) ?? const [])
              .map((e) => '$e')
              .contains(uid);

          return GestureDetector(
            onTap: empty
                ? () => _takeSeat(index, roomData)
                : mine
                    ? () => _leaveSeat(roomData)
                    : null,
            onLongPress:
                canModerate ? () => _seatAdminSheet(index, seat, roomData) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: empty
                            ? null
                            : LinearGradient(
                                colors: mine
                                    ? const [_pink, _purple]
                                    : (muted
                                        ? const [Color(0xff3a2d52), Color(0xff2a2140)]
                                        : const [Color(0xff35e18b), Color(0xff22a7ff)]),
                              ),
                        color: empty ? const Color(0xff1a1329) : null,
                        border: empty
                            ? Border.all(
                                color: const Color(0xff33284a),
                                style: BorderStyle.solid,
                              )
                            : null,
                        boxShadow: !empty && !muted
                            ? const [
                                BoxShadow(color: Color(0x3335e18b), blurRadius: 14),
                              ]
                            : null,
                      ),
                      child: empty
                          ? Icon(
                              locked ? Icons.lock_rounded : Icons.add_rounded,
                              color: _muted,
                              size: 20,
                            )
                          : ClipOval(child: _UserPhoto(uid: uid, name: name)),
                    ),
                    if (!empty)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: muted
                                ? const Color(0xff5e5470)
                                : const Color(0xff35e18b),
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 1.6),
                          ),
                          child: Icon(
                            muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  empty ? (locked ? 'Kilidli' : 'Qonaq') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: empty ? _muted : Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!empty) ...[
                  const SizedBox(height: 3),
                  // Bu yerə göndərilmiş hədiyyələrin cəmi.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _purple.withValues(alpha: .45),
                      ),
                    ),
                    child: Text(
                      compactCount(
                        seat['gifts'] is num ? (seat['gifts'] as num) : 0,
                      ),
                      style: const TextStyle(
                        color: vGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                if (isMod && !empty)
                  const Text(
                    'MOD',
                    style: TextStyle(
                      color: Color(0xffffd86b),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // PK YARIŞI
  // ============================================================

  /// Hər komandanın topladığı xal: (mavi, qırmızı).
  (int, int) _pkScores(Map<String, dynamic> d) {
    final seats = Map<String, dynamic>.from(d['seats'] ?? {});
    final count = seatTotal(d);
    var blue = 0;
    var red = 0;

    seats.forEach((key, value) {
      if (value is! Map) return;
      final points = value['pkPoints'] is num
          ? (value['pkPoints'] as num).toInt()
          : 0;
      if (points <= 0) return;
      if (pkTeamOf(int.tryParse(key) ?? 0, count) == 0) {
        blue += points;
      } else {
        red += points;
      }
    });

    return (blue, red);
  }

  /// Komandanın ilk dəstəkçiləri — çox verəndən aza doğru.
  List<({String name, int points})> _pkSupporters(
    Map<String, dynamic> d,
    int team,
  ) {
    final pk = d['pk'];
    if (pk is! Map) return const [];
    final raw = pk['supporters'];
    if (raw is! Map) return const [];

    final list = <({String name, int points})>[];
    raw.forEach((uid, value) {
      if (value is! Map) return;
      if ((value['team'] is num ? (value['team'] as num).toInt() : 0) != team) {
        return;
      }
      final points = value['points'] is num
          ? (value['points'] as num).toInt()
          : 0;
      if (points <= 0) return;
      list.add((name: '${value['name'] ?? ''}', points: points));
    });

    list.sort((a, b) => b.points.compareTo(a.points));
    return list.take(3).toList();
  }

  /// PK aktivdirsə bitmə vaxtını qaytarır.
  DateTime? _pkEndsAt(Map<String, dynamic> d) {
    final pk = d['pk'];
    if (pk is! Map || pk['active'] != true) return null;
    final endsAt = pk['endsAt'];
    return endsAt is Timestamp ? endsAt.toDate() : null;
  }

  /// Host PK başladır — seçilən müddət ərzində hədiyyələr xal sayılır.
  Future<void> _startPk() async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'PK yarışı başlat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Mikrofondakılar iki komandaya bölünür — soldakı yarı Mavi, '
          'sağdakı yarı Qırmızı. Onlara göndərilən hədiyyələr komandanın '
          'xalıdır. Sonda çox toplayan tərəf qalib gəlir.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        actions: [
          for (final value in const [5, 10, 15])
            TextButton(
              onPressed: () => Navigator.pop(dialog, value),
              child: Text('$value dəq'),
            ),
        ],
      ),
    );

    if (minutes == null) return;

    final seats = Map<String, dynamic>.from(
      (await room.get()).data()?['seats'] ?? {},
    );

    // update() işlədirik ki, "pk" xəritəsi bütöv əvəzlənsin — set(merge)
    // olsaydı keçən yarışın dəstəkçiləri içəridə qalardı.
    // Kürsülərdə isə yalnız xalı sıfırlayırıq, ad və uid yerində qalmalıdır.
    final updates = <String, dynamic>{
      'pk': {
        'active': true,
        'startedAt': Timestamp.now(),
        'endsAt': Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: minutes)),
        ),
        'startedBy': widget.profile.uid,
      },
    };
    for (final key in seats.keys) {
      updates['seats.$key.pkPoints'] = 0;
    }

    try {
      await room.update(updates);

      await room.collection('messages').add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': '⚔️ PK başladı! $minutes dəqiqə — Mavi 🆚 Qırmızı',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PK başlamadı.')),
        );
      }
    }
  }

  /// PK-nı bitirir və qalib komandanı elan edir.
  Future<void> _endPk(Map<String, dynamic> d) async {
    final (blue, red) = _pkScores(d);

    final String result;
    if (blue == 0 && red == 0) {
      result = '⚔️ PK bitdi. Bu dəfə xal toplanmadı.';
    } else if (blue == red) {
      result = '🤝 PK bərabərə! $blue — $red';
    } else if (blue > red) {
      result = '🏆 Mavi komanda qalib! $blue — $red';
    } else {
      result = '🏆 Qırmızı komanda qalib! $red — $blue';
    }

    try {
      // Nəticə sonra da görünsün deyə xallar yazılır, yarış isə bağlanır.
      await room.update({
        'pk': {
          'active': false,
          'blue': blue,
          'red': red,
          'endedAt': Timestamp.now(),
        },
      });

      await room.collection('messages').add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': result,
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted && (blue > 0 || red > 0)) _spawnHearts(8);
    } catch (_) {}
  }

  /// Başlıqdakı PK zolağı — geri sayım və qalib göstəricisi.
  Widget _pkBanner(Map<String, dynamic> d) {
    final endsAt = _pkEndsAt(d);
    final isHost = d['hostId'] == widget.profile.uid;

    if (endsAt == null) {
      if (!isHost) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: PressableScale(
          onTap: _startPk,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _pink.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _pink.withValues(alpha: .4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_mma_rounded, size: 15, color: _pink),
                SizedBox(width: 8),
                Text(
                  'PK yarışı başlat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final left = endsAt.difference(DateTime.now());
    if (left.isNegative) {
      // Vaxt bitdi — hostun cihazı nəticəni yazır.
      if (isHost) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _endPk(d);
        });
      }
      return const SizedBox.shrink();
    }

    return _pkBattleBar(d, left, isHost);
  }

  /// TikTok-dakı PK görünüşü: iki komanda, ortada bölünən zolaq.
  ///
  /// Zolağın uzunluğu xalların nisbətini göstərir. Tam sıfıra endirmirik —
  /// uduzan tərəf də görünsün deyə ən azı onda bir yer saxlanılır.
  Widget _pkBattleBar(Map<String, dynamic> d, Duration left, bool isHost) {
    final minutes = left.inMinutes.toString().padLeft(2, '0');
    final seconds = (left.inSeconds % 60).toString().padLeft(2, '0');

    final (blue, red) = _pkScores(d);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xff17102a),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _pink.withValues(alpha: .45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _pkScore('Mavi', blue, _pkBlue, true),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$minutes:$seconds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                _pkScore('Qırmızı', red, _pkRed, false),
              ],
            ),
            const SizedBox(height: 8),
            _pkSplitBar(blue, red),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _pkSupporterList(d, 0, true)),
                const SizedBox(width: 8),
                Expanded(child: _pkSupporterList(d, 1, false)),
              ],
            ),
            if (isHost)
              Align(
                alignment: Alignment.centerRight,
                child: PressableScale(
                  onTap: () => _endPk(d),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4, left: 8),
                    child: Text(
                      'Yarışı bitir',
                      style: TextStyle(
                        color: Color(0xffffc9d3),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Komandanın adı və xalı. Sol tərəfdəki sola, sağdakı sağa yığılır.
  Widget _pkScore(String name, int points, Color color, bool onLeft) {
    final label = Column(
      crossAxisAlignment:
          onLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '$points',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    return SizedBox(width: 86, child: label);
  }

  /// Ortadan bölünən zolaq — solda mavi, sağda qırmızı.
  Widget _pkSplitBar(int blue, int red) {
    final total = blue + red;
    final share = total == 0 ? 0.5 : (blue / total).clamp(0.1, 0.9);

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;

        return SizedBox(
          height: 22,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bütöv zolaq qırmızıdır, mavi onun üstünə çəkilir.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_pkRed.withValues(alpha: .75), _pkRed],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                width: width * share,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_pkBlue, _pkBlue.withValues(alpha: .75)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              // Sərhəddəki alov.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                left: (width * share) - 13,
                top: -5,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xff17102a),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Komandanı ən çox dəstəkləyən üç nəfər.
  Widget _pkSupporterList(Map<String, dynamic> d, int team, bool onLeft) {
    final people = _pkSupporters(d, team);

    if (people.isEmpty) {
      return Text(
        'dəstək yoxdur',
        textAlign: onLeft ? TextAlign.left : TextAlign.right,
        style: const TextStyle(color: _muted, fontSize: 10.5),
      );
    }

    return Column(
      crossAxisAlignment:
          onLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final person in people)
          Text(
            '${person.name} · ${person.points}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
      ],
    );
  }

  /// Host mikrofon yerlərinin sayını sonradan dəyişə bilər.
  Future<void> _changeSeatCount(Map<String, dynamic> d) async {
    final seats = Map<String, dynamic>.from(d['seats'] ?? {});
    final current = seatTotal(d);

    // Dolu olan ən böyük yerin nömrəsi — ondan aşağı endirmək olmaz.
    var highestTaken = 0;
    seats.forEach((key, value) {
      final index = int.tryParse('$key') ?? 0;
      final uid = value is Map ? '${value['uid'] ?? ''}' : '';
      if (uid.isNotEmpty && index > highestTaken) highestTaken = index;
    });
    final minimum = (highestTaken + 1).clamp(2, 20);

    var next = current;

    final result = await showDialog<int>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => AlertDialog(
          backgroundColor: const Color(0xff151020),
          title: const Text(
            'Mikrofon yerləri',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$next nəfər',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Slider(
                value: next.toDouble(),
                min: minimum.toDouble(),
                max: 20,
                divisions: (20 - minimum) == 0 ? 1 : 20 - minimum,
                activeColor: _pink,
                onChanged: (v) => setDialog(() => next = v.round()),
              ),
              if (minimum > 2)
                Text(
                  'Dolu yerlər olduğu üçün $minimum-dan az ola bilməz.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Ləğv et'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, next),
              child: const Text('Tətbiq et'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == current) return;

    // Yeni xəritə: artanda boş yer əlavə olunur, azalanda silinir.
    final updated = <String, dynamic>{};
    for (var i = 0; i < result; i++) {
      final existing = seats['$i'];
      updated['$i'] = existing is Map
          ? Map<String, dynamic>.from(existing)
          : {'uid': '', 'name': '', 'muted': false, 'locked': false};
    }

    try {
      await room.set({
        'seatCount': result,
        'seats': updated,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mikrofon yerləri $result oldu.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dəyişiklik saxlanmadı.')),
        );
      }
    }
  }

  /// Otaq təqdimatı — host yazır, hamı görür.
  Widget _announcement(Map<String, dynamic> d) {
    final text = '${d['announcement'] ?? ''}'.trim();
    final isHost = d['hostId'] == widget.profile.uid;

    if (text.isEmpty && !isHost) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: PressableScale(
        onTap: isHost ? () => _editAnnouncement(text) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .32),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _purple.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded, size: 15, color: vGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isEmpty ? 'Otaq təqdimatı əlavə et (yalnız host)' : text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text.isEmpty ? _muted : Colors.white,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),
              if (isHost)
                const Icon(Icons.edit_rounded, size: 13, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAnnouncement(String current) async {
    final controller = TextEditingController(text: current);

    final text = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Otaq təqdimatı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          maxLength: 160,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Xoş gəlmisiniz! Qaydalar, mövzu, salamlama…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Yadda saxla'),
          ),
        ],
      ),
    );

    if (text == null) return;
    if (!mounted) return;
    if (text.isNotEmpty && !guardContent(context, text)) return;

    try {
      await room.set({'announcement': text}, SetOptions(merge: true));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Təqdimat saxlanmadı.')),
        );
      }
    }
  }

  /// Otaq alətləri — paylaş, oyunlar, ranking, təqdimat.
  void _openTools(Map<String, dynamic> d) {
    final isHost = d['hostId'] == widget.profile.uid;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Otaq alətləri',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  _tool(Icons.ios_share_rounded, 'Paylaş', const Color(0xff22a7ff), () {
                    Navigator.pop(sheet);
                    Clipboard.setData(
                      ClipboardData(
                        text: 'VIBE otağına qoşul: ${d['title'] ?? ''} '
                            '(ID: ${widget.roomId})',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dəvət kopyalandı.')),
                    );
                  }),
                  _tool(Icons.sports_esports_rounded, 'Oyunlar', _pink, () {
                    Navigator.pop(sheet);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VibeGameCenterPage(profile: widget.profile),
                      ),
                    );
                  }),
                  _tool(Icons.emoji_events_rounded, 'Ranking', const Color(0xffffd86b), () {
                    Navigator.pop(sheet);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VibeRankingPage(profile: widget.profile),
                      ),
                    );
                  }),
                  _tool(Icons.pan_tool_alt_rounded, 'Mic istəkləri', _purple, () async {
                    Navigator.pop(sheet);
                    final snap = await room.get();
                    if (!mounted) return;
                    _openMicRequests(snap.data() ?? const <String, dynamic>{});
                  }),
                  if (isHost)
                    _tool(Icons.campaign_rounded, 'Təqdimat', const Color(0xff48e08a), () {
                      Navigator.pop(sheet);
                      _editAnnouncement('${d['announcement'] ?? ''}');
                    }),
                  if (isHost)
                    _tool(Icons.event_seat_rounded, 'Mikrofon sayı', const Color(0xff22a7ff), () {
                      Navigator.pop(sheet);
                      _changeSeatCount(d);
                    }),
                  _tool(Icons.copy_rounded, 'ID kopyala', const Color(0xff9d94ae), () {
                    Navigator.pop(sheet);
                    Clipboard.setData(ClipboardData(text: widget.roomId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Otaq ID kopyalandı.')),
                    );
                  }),
                  _tool(Icons.logout_rounded, 'Çıxış', const Color(0xffff657b), () {
                    Navigator.pop(sheet);
                    Navigator.pop(context);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String label, Color color, VoidCallback onTap) =>
      PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: color.withValues(alpha: .4)),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

  /// Otaqdakı dinləyicilər — avatar zolağı + ümumi say.
  Widget _listeners(Map<String, dynamic> roomData, bool canModerate) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: room
        .collection('members')
        .orderBy('joinedAt', descending: true)
        .limit(30)
        .snapshots(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? const [];
      if (docs.isEmpty) return const SizedBox.shrink();

      // Siqnalı 3 dəqiqədən çox köhnə olanlar sayılmır.
      final live = docs.where((doc) {
        final seen = doc.data()['lastSeen'];
        if (seen is! Timestamp) return true;
        return DateTime.now().difference(seen.toDate()).inMinutes < 3;
      }).toList();

      if (live.isEmpty) return const SizedBox.shrink();

      // Gizli dinləyicilər üzdə görünmür — gizli olmağın mənası budur.
      // Amma sayılırlar: "40 qulaq asır" yazısı otağı canlı göstərir və
      // içəri girməyə cəsarət verir.
      final visible = live.where((doc) => doc.data()['hidden'] != true).toList();
      final hiddenCount = live.length - visible.length;
      final shown = visible.take(8).toList();

      return SizedBox(
        height: 38,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final uid = shown[i].id;
                  final name = '${shown[i].data()['name'] ?? ''}';

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PressableScale(
                      onTap: () => _openListenerMenu(
                        uid: uid,
                        name: name,
                        roomData: roomData,
                        canModerate: canModerate,
                      ),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: ClipOval(
                          child: _UserPhoto(uid: uid, name: name),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${live.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hiddenCount > 0) ...[
                    const SizedBox(width: 7),
                    const Icon(Icons.headphones_rounded,
                        size: 13, color: _blue),
                    const SizedBox(width: 3),
                    Text(
                      '$hiddenCount',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      );
    },
  );

  /// Dinləyiciyə toxunanda profil kartı açılır.
  void _openListenerMenu({
    required String uid,
    required String name,
    required Map<String, dynamic> roomData,
    required bool canModerate,
  }) {
    showRoomProfileCard(
      context,
      viewer: widget.profile,
      uid: uid,
      name: name,
      canModerate: canModerate && uid != widget.profile.uid,
      onInvite: () => _inviteToSeat(uid, name, roomData),
      onKick: () => _banFromRoom(uid, name, roomData),
    );
  }

  /// Dinləyicini boş mikrofon yerinə dəvət edir.
  ///
  /// Dəvəti qəbul etmək qarşı tərəfin öz qərarıdır — otaqda dəvət
  /// sənədi yaranır, həmin adam ekranında bildiriş görür.
  Future<void> _inviteToSeat(
    String uid,
    String name,
    Map<String, dynamic> roomData,
  ) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
    final total = seatTotal(roomData);

    String? freeKey;
    for (var i = 1; i < total; i++) {
      final seat = Map<String, dynamic>.from(seats['$i'] ?? {});
      if ('${seat['uid'] ?? ''}'.isEmpty && seat['locked'] != true) {
        freeKey = '$i';
        break;
      }
    }

    if (freeKey == null) {
      _toast('Boş mikrofon yeri yoxdur.');
      return;
    }

    try {
      await room.collection('seatInvites').doc(uid).set({
        'uid': uid,
        'name': name,
        'seat': freeKey,
        'byName': widget.profile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _toast('$name masaya dəvət olundu.');
    } catch (_) {
      _toast('Dəvət göndərilmədi.');
    }
  }

  /// Mənə gələn masa dəvətini göstərən zolaq.
  Widget _seatInvite(Map<String, dynamic> roomData) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: room
          .collection('seatInvites')
          .doc(widget.profile.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) return const SizedBox.shrink();

        final seat = int.tryParse('${data['seat'] ?? ''}');
        if (seat == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xff123524),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xff2de28a)),
          ),
          child: Row(
            children: [
              const Icon(Icons.record_voice_over_rounded,
                  color: Color(0xff2de28a), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${data['byName'] ?? 'Host'} səni masaya dəvət edir',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => _acceptSeatInvite(seat, roomData),
                child: const Text(
                  'Qoşul',
                  style: TextStyle(
                    color: Color(0xff2de28a),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'İmtina et',
                onPressed: () => room
                    .collection('seatInvites')
                    .doc(widget.profile.uid)
                    .delete(),
                icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptSeatInvite(
    int seat,
    Map<String, dynamic> roomData,
  ) async {
    await _takeSeat(seat, roomData);
    try {
      await room.collection('seatInvites').doc(widget.profile.uid).delete();
    } catch (_) {}
  }

  /// Dolu mikrofon yerlərinin sayı.
  int _takenSeats(Map<String, dynamic> roomData) {
    final seats = roomData['seats'];
    if (seats is! Map) return 0;
    return seats.values
        .where((seat) => seat is Map && '${seat['uid'] ?? ''}'.isNotEmpty)
        .length;
  }

  /// Otaqdakı mikrofon yerlərinin sayı (host daxil).
  int seatTotal(Map<String, dynamic> roomData) {
    final value = roomData['seatCount'];
    if (value is num && value >= 2) return value.toInt();
    // Köhnə otaqlar: `seats` xəritəsindən hesabla.
    final seats = roomData['seats'];
    if (seats is Map && seats.isNotEmpty) return seats.length;
    return 8;
  }

  /// Otaq menyusu — paylaş, çıx, mic istəkləri.
  void _openRoomMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pan_tool_alt_rounded, color: _purple),
              title: const Text('Mikrofon istəkləri',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(sheet);
                final snap = await room.get();
                if (!mounted) return;
                _openMicRequests(snap.data() ?? const <String, dynamic>{});
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: _blue),
              title: const Text('Otaq ID-sini kopyala',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                Clipboard.setData(ClipboardData(text: widget.roomId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Otaq ID kopyalandı.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xffff657b)),
              title: const Text('Otaqdan çıx',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Ürək göndər — hamının ekranında görünür.
  Future<void> _sendHeart() async {
    _spawnHearts(1);
    try {
      await room.set({'hearts': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _spawnHearts(int count) {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < count; i++) {
        flyingHearts.add(heartSeed++);
      }
    });
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() {
        if (flyingHearts.length >= count) {
          flyingHearts.removeRange(0, count);
        } else {
          flyingHearts.clear();
        }
      });
    });
  }

  void _seatAdminSheet(
    int index,
    Map<String, dynamic> seat,
    Map<String, dynamic> roomData,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                seat['muted'] == true ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: _purple,
              ),
              title: Text(
                seat['muted'] == true ? 'Mikrofonu aç' : 'Mikrofonu bağla',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleSeatMute(index, roomData);
              },
            ),
            ListTile(
              leading: Icon(
                seat['locked'] == true ? Icons.lock_open : Icons.lock,
                color: _purple,
              ),
              title: Text(
                seat['locked'] == true ? 'Yeri aç' : 'Yeri kilidlə',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleSeatLock(index, roomData);
              },
            ),
            if ('${seat['uid'] ?? ''}'.isNotEmpty &&
                roomData['hostId'] == widget.profile.uid)
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xffffd86b),
                ),
                title: Text(
                  ((roomData['moderators'] as List?) ?? const [])
                          .map((e) => '$e')
                          .contains('${seat['uid'] ?? ''}')
                      ? 'Moderatorluğu götür'
                      : 'Moderator et',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleModerator(
                    '${seat['uid'] ?? ''}',
                    '${seat['name'] ?? 'VIBE'}',
                    roomData,
                  );
                },
              ),
            if ('${seat['uid'] ?? ''}'.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                title: const Text(
                  'Mikrofondan çıxart',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _kickFromSeat(index, roomData);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _gameBanner(Map<String, dynamic> game) {
    if (game.isEmpty) return const SizedBox.shrink();
    final type = '${game['type'] ?? ''}';
    if (type == 'dice') {
      return _gameCard(
        '🎲 ${game['by'] ?? ''} zər atdı',
        'Nəticə: ${game['value'] ?? '?'}',
      );
    }
    if (type == 'truth') {
      return _gameCard('🔥 Truth or Dare', '${game['text'] ?? ''}');
    }
    if (type == 'quiz') {
      final answers = (game['answers'] as List?)?.map((e) => '$e').toList() ?? [];
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff211331), Color(0xff141020)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff56336b)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧠 VIBE Quiz',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${game['question'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < answers.length; i++)
                  OutlinedButton(
                    onPressed: () => _answerQuiz(i, game),
                    child: Text(answers[i]),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    if (type == 'would') {
      return _gameCard(
        '🤔 Would You Rather',
        '${game['left'] ?? ''}  VS  ${game['right'] ?? ''}',
      );
    }
    if (type == 'rps') {
      return _gameCard(
        '✊ Daş-Kağız-Qayçı',
        '${game['by'] ?? ''} seçdi: ${game['move'] ?? ''}',
      );
    }
    if (type == 'spin') {
      return _gameCard('🎡 Spin Wheel', '${game['text'] ?? ''}');
    }
    if (type == 'emoji') {
      return _gameCard(
        '😎 Emoji Guess',
        '${game['emoji'] ?? ''} — cavabı tap!',
      );
    }
    if (type == 'chain') {
      return _gameCard(
        '🔤 Söz zənciri',
        '"${game['letter'] ?? ''}" hərfi ilə başlayan söz de!',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _gameCard(String title, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff211331), Color(0xff141020)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff56336b)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _pink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveEventStrip() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: room
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (_, eventSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: room
              .collection('gifts')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (_, giftSnap) {
            final event = eventSnap.data?.docs.isNotEmpty == true
                ? eventSnap.data!.docs.first.data()
                : <String, dynamic>{};
            final gift = giftSnap.data?.docs.isNotEmpty == true
                ? giftSnap.data!.docs.first.data()
                : <String, dynamic>{};

            final giftTime = gift['createdAt'] is Timestamp
                ? (gift['createdAt'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final eventTime = event['createdAt'] is Timestamp
                ? (event['createdAt'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);

            final useGift = giftTime.isAfter(eventTime);
            if (useGift && gift.isNotEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff29133c), Color(0xff45144a)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xff7b3c8f)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${gift['emoji'] ?? '🎁'}',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${gift['fromName'] ?? 'VIBE'} → ${gift['title'] ?? 'Gift'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${gift['price'] ?? 0} coin',
                      style: const TextStyle(
                        color: Color(0xffffd86b),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (event.isNotEmpty) {
              final vip = event['type'] == 'vip_enter';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: vip
                        ? const [Color(0xff5b3a09), Color(0xff2a1808)]
                        : const [Color(0xff151020), Color(0xff1d1229)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: vip
                        ? const Color(0xffffd86b)
                        : const Color(0xff3d2a54),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      vip ? Icons.workspace_premium_rounded : Icons.login_rounded,
                      color: vip ? const Color(0xffffd86b) : _purple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vip
                            ? 'VIP ${event['name'] ?? 'VIBE'} otağa daxil oldu ✨'
                            : '${event['name'] ?? 'VIBE'} otağa daxil oldu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  /// Görüntülü otağın şəbəkəsi.
  ///
  /// Hər mikrofon yeri bir video xanasıdır: yerdə oturan kamerasını yayımlayır,
  /// boş yer isə "kameraya çıx" düyməsi kimi işləyir.
  Widget _videoGrid(
    Map<String, dynamic> seats,
    Map<String, dynamic> roomData,
    bool canModerate,
  ) {
    final total = seatTotal(roomData);
    final instance = audio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: total,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .78,
        ),
        itemBuilder: (context, index) {
          final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
          final uid = '${seat['uid'] ?? ''}';
          final name = '${seat['name'] ?? ''}';
          final mine = uid == widget.profile.uid;
          final muted = seat['muted'] == true;

          RTCVideoRenderer? view;
          if (mine) {
            view = instance?.localView;
          } else if (uid.isNotEmpty) {
            view = instance?.viewFor(uid);
          }

          final hasPicture = view != null &&
              view.srcObject != null &&
              !(mine && (instance?.state.value.cameraOff ?? false));

          return GestureDetector(
            onTap: () {
              if (uid.isEmpty) {
                _takeSeat(index, roomData);
              } else if (mine) {
                _leaveSeat(roomData);
              } else if (canModerate) {
                _openListenerMenu(
                  uid: uid,
                  name: name,
                  roomData: roomData,
                  canModerate: canModerate,
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff120d20),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: mine ? _pink : const Color(0xff2d2540),
                  width: mine ? 1.6 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPicture)
                    RTCVideoView(
                      view,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: mine,
                    )
                  else if (uid.isNotEmpty)
                    Center(
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: ClipOval(child: _UserPhoto(uid: uid, name: name)),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.videocam_rounded,
                          color: _muted, size: 28),
                    ),

                  // Ad və mikrofon vəziyyəti.
                  if (uid.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(9, 14, 9, 7),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xcc000000)],
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              size: 13,
                              color: muted ? _muted : const Color(0xff48e08a),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                mine ? 'Sən' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Text(
                        'Kameraya çıx',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Görüntülü otaqda kamera idarəsi.
  Widget _videoControls() {
    final instance = audio;
    if (instance == null || !videoRoom) return const SizedBox.shrink();

    final cameraOff = instance.state.value.cameraOff;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            tooltip: cameraOff ? 'Kameranı aç' : 'Kameranı söndür',
            onPressed: () => instance.setCameraOff(!cameraOff),
            icon: Icon(
              cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Kameranı çevir',
            onPressed: instance.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
    );
  }

  /// Otağa musiqi qoyur (yalnız host və moderatorlar).
  ///
  /// Fayl Supabase-ə yüklənir, sonra otaq sənədinə yazılır və
  /// bütün iştirakçılar eyni saniyədən eşidir.
  Future<void> _pickMusic(Map<String, dynamic> roomData) async {
    if (!_isModerator(roomData)) {
      _toast('Musiqini yalnız otağın sahibi qoya bilər.');
      return;
    }

    final picked = await ImagePicker().pickMedia();
    if (picked == null || !mounted) return;

    final name = picked.name;
    final lower = name.toLowerCase();
    if (!lower.endsWith('.mp3') &&
        !lower.endsWith('.m4a') &&
        !lower.endsWith('.aac') &&
        !lower.endsWith('.wav')) {
      _toast('Yalnız səs faylı seçə bilərsən (mp3, m4a, wav).');
      return;
    }

    _toast('Musiqi yüklənir…');

    try {
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
        _toast('Fayl çox böyükdür. 20 MB-a qədər olsun.');
        return;
      }

      final url = await MediaUpload.upload(
        bucket: MediaUpload.videoBucket,
        path: 'room-music/${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}-$name',
        bytes: bytes,
        contentType: 'audio/mpeg',
      );

      await music?.play(
        url: url,
        title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
        by: widget.profile.name,
      );

      await room.collection('messages').add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': 'musiqi qoydu: $name',
        'type': 'music',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on MediaBucketMissing catch (e) {
      _toast('Yaddaş hazır deyil: "${e.bucket}" bucket-i lazımdır.');
    } catch (_) {
      _toast('Musiqi yüklənmədi. Yenidən sına.');
    }
  }

  /// Çalınan mahnının zolağı.
  Widget _musicBar(Map<String, dynamic> roomData) {
    final current = music?.track.value;
    if (current == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xff1b1430),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff3d2a54)),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: _blue, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (current.by.isNotEmpty)
                  Text(
                    '${current.by} qoydu',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Səs səviyyəsi hər kəs üçün öz cihazında.
          IconButton(
            tooltip: 'Musiqini kıs',
            onPressed: () => music?.setVolume(.2),
            icon: const Icon(Icons.volume_down_rounded,
                color: _muted, size: 19),
          ),
          if (_isModerator(roomData))
            IconButton(
              tooltip: 'Musiqini dayandır',
              onPressed: () => music?.stopForEveryone(),
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Color(0xffff657b), size: 19),
            ),
        ],
      ),
    );
  }

  /// Otaqda domino başladır.
  ///
  /// Rəqib masadakı (mikrofon yerindəki) iştirakçılardan seçilir.
  /// Oyun ayrıca ekranda açılır, otağın səsi kəsilmir — geri qayıdanda
  /// söhbət davam edir.
  Future<void> _startRoomDomino(Map<String, dynamic> roomData) async {
    final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});

    // Masadakılar (mən istisna).
    final candidates = <({String uid, String name})>[];
    for (final entry in seats.entries) {
      final seat = Map<String, dynamic>.from(entry.value ?? {});
      final uid = '${seat['uid'] ?? ''}';
      if (uid.isEmpty || uid == widget.profile.uid) continue;
      candidates.add((uid: uid, name: '${seat['name'] ?? 'İstifadəçi'}'));
    }

    if (candidates.isEmpty) {
      _toast('Masada başqa kimsə yoxdur. Əvvəlcə birini masaya dəvət et.');
      return;
    }

    final opponent = await showModalBottomSheet<({String uid, String name})>(
      context: context,
      backgroundColor: const Color(0xff141020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kiminlə oynayaq?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            for (final person in candidates)
              ListTile(
                leading: SizedBox(
                  width: 38,
                  height: 38,
                  child: ClipOval(
                    child: _UserPhoto(uid: person.uid, name: person.name),
                  ),
                ),
                title: Text(person.name,
                    style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheet, person),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (opponent == null || !mounted) return;

    try {
      final matchId = await createDominoMatch(
        myUid: widget.profile.uid,
        myName: widget.profile.name,
        opponentUid: opponent.uid,
        opponentName: opponent.name,
      );

      // Otaqda hamı görsün.
      await room.collection('messages').add({
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'text': '${opponent.name} ilə domino oyununa başladı',
        'type': 'game',
        'matchId': matchId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DominoPage(
            matchId: matchId,
            profile: widget.profile,
          ),
        ),
      );
    } catch (_) {
      _toast('Oyun başlamadı. Yenidən sına.');
    }
  }

  /// Otaqdan çıxarılanlara göstərilən ekran.
  Widget _bannedScreen() => Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.do_not_disturb_on_rounded,
                      color: Color(0xffff657b), size: 58),
                  const SizedBox(height: 18),
                  const Text(
                    'Bu otaqdan çıxarılmısan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Otağın sahibi səni buradan çıxarıb. '
                    'Başqa otaqlara sərbəst qoşula bilərsən.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Geri qayıt'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  /// Otaqda söhbətdən susdurulanların siyahısı.
  Set<String> _chatMuted(Map<String, dynamic> roomData) =>
      ((roomData['chatMuted'] as List?) ?? const []).map((e) => '$e').toSet();

  /// Otaqdan qovulanların siyahısı — geri girə bilmirlər.
  Set<String> _banned(Map<String, dynamic> roomData) =>
      ((roomData['banned'] as List?) ?? const []).map((e) => '$e').toSet();

  /// Şərhə uzun basanda açılan moderasiya menyusu.
  ///
  /// Şikayət və bloklama hər kəs üçün; susdurma, atma və mesaj silmə
  /// yalnız host və moderatorlar üçün.
  void _openMessageModeration({
    required String uid,
    required String name,
    required DocumentReference<Map<String, dynamic>> messageRef,
    required Map<String, dynamic> roomData,
  }) {
    final canModerate = _isModerator(roomData);
    final muted = _chatMuted(roomData).contains(uid);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff141020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: _purple),
              title: const Text('Profilə bax',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonPage(
                      currentProfile: widget.profile,
                      targetUid: uid,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Color(0xffffb347)),
              title: const Text('Şikayət et',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Moderatorlar baxacaq',
                  style: TextStyle(color: _muted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                _reportMessage(uid, name, messageRef);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Color(0xffff657b)),
              title: const Text('Blokla',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Yazdıqlarını bir daha görməzsən',
                  style: TextStyle(color: _muted, fontSize: 12)),
              onTap: () async {
                Navigator.pop(sheet);
                await blockUser(
                  myUid: widget.profile.uid,
                  myName: widget.profile.name,
                  targetUid: uid,
                  targetName: name,
                );
                _toast('$name bloklandı.');
              },
            ),
            if (canModerate) ...[
              const Divider(height: 1, color: Color(0xff2d2540)),
              ListTile(
                leading: Icon(
                  muted ? Icons.volume_up_rounded : Icons.voice_over_off_rounded,
                  color: const Color(0xffffd458),
                ),
                title: Text(
                  muted ? 'Susdurmanı götür' : 'Söhbətdə sussun',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  muted ? 'Yenidən yaza bilsin' : 'Mesajları otaqda görünməsin',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheet);
                  _toggleChatMute(uid, name, muted);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xff9d94ae)),
                title: const Text('Mesajı sil',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(sheet);
                  try {
                    await messageRef.delete();
                    _toast('Mesaj silindi.');
                  } catch (_) {
                    _toast('Mesaj silinmədi.');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded,
                    color: Color(0xffff657b)),
                title: const Text('Otaqdan at',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Bu otağa bir daha girə bilməz',
                    style: TextStyle(color: _muted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(sheet);
                  _banFromRoom(uid, name, roomData);
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _reportMessage(
    String uid,
    String name,
    DocumentReference<Map<String, dynamic>> messageRef,
  ) async {
    try {
      final snap = await messageRef.get();
      await FirebaseFirestore.instance.collection('reports').add({
        'type': 'room_message',
        'roomId': widget.roomId,
        'targetUid': uid,
        'targetName': name,
        'text': '${snap.data()?['text'] ?? ''}',
        'reporterUid': widget.profile.uid,
        'reporterName': widget.profile.name,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _toast('Şikayət göndərildi. Baxılacaq.');
    } catch (_) {
      _toast('Şikayət göndərilmədi.');
    }
  }

  Future<void> _toggleChatMute(String uid, String name, bool muted) async {
    try {
      await room.set({
        'chatMuted': muted
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
      _toast(muted ? '$name yenidən yaza bilər.' : '$name susduruldu.');
    } catch (_) {
      _toast('Alınmadı. Yenidən sına.');
    }
  }

  /// İstifadəçini otaqdan çıxarır və qara siyahıya salır.
  Future<void> _banFromRoom(
    String uid,
    String name,
    Map<String, dynamic> roomData,
  ) async {
    try {
      // Mikrofon yerində idisə, yeri boşalt.
      final seats = Map<String, dynamic>.from(roomData['seats'] ?? {});
      var changed = false;
      for (final entry in seats.entries) {
        final seat = Map<String, dynamic>.from(entry.value ?? {});
        if (seat['uid'] == uid) {
          seats[entry.key] = {
            'uid': '',
            'name': '',
            'muted': false,
            'locked': seat['locked'] == true,
          };
          changed = true;
        }
      }

      await room.set({
        'banned': FieldValue.arrayUnion([uid]),
        if (changed) 'seats': seats,
      }, SetOptions(merge: true));

      await room.collection('members').doc(uid).delete();
      await room.collection('events').add({
        'type': 'kick',
        'uid': uid,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _toast('$name otaqdan çıxarıldı.');
    } catch (_) {
      _toast('Çıxarmaq alınmadı.');
    }
  }

  Widget _chat(Map<String, dynamic> roomData) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: room
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _purple.withValues(alpha: .18),
                      border: Border.all(color: _purple.withValues(alpha: .45)),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Otaq sakitdir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'İlk mesajı sən yaz və ya mikrofona çıx 🎤',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 84, 4),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data();
            final uid = '${d['uid'] ?? d['senderId'] ?? ''}';
            final name = '${d['name'] ?? 'VIBE'}';

            // Blokladığım və otaqda susdurulmuş istifadəçilərin
            // yazdıqları mənə görünmür.
            if (uid.isNotEmpty && hiddenUids.contains(uid)) {
              return const SizedBox.shrink();
            }
            if (uid.isNotEmpty && _chatMuted(roomData).contains(uid)) {
              return const SizedBox.shrink();
            }

            return GestureDetector(
              onLongPress: uid.isEmpty || uid == widget.profile.uid
                  ? null
                  : () => _openMessageModeration(
                        uid: uid,
                        name: name,
                        messageRef: doc.reference,
                        roomData: roomData,
                      ),
              child: Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: ClipOval(child: _UserPhoto(uid: uid, name: name)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .38),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12.5, height: 1.35),
                          children: [
                            TextSpan(
                              text: '$name  ',
                              style: const TextStyle(
                                color: Color(0xffffb6f2),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              // Söyüş ekranda ulduzla örtülür.
                              text: maskProfanity('${d['text'] ?? ''}'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _bottomBar(Map<String, dynamic> roomData) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xff0d0914),
        border: Border(top: BorderSide(color: Color(0xff2d2540))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mic istə',
            onPressed: _requestMic,
            icon: const Icon(Icons.pan_tool_alt_rounded, color: _purple),
          ),
          IconButton(
            tooltip: audio?.state.value.speaker == false
                ? 'Qulaqlıq rejimi'
                : 'Dinamik açıq',
            onPressed: () {
              final instance = audio;
              if (instance == null) return;
              instance.setSpeaker(!instance.state.value.speaker);
            },
            icon: Icon(
              audio?.state.value.speaker == false
                  ? Icons.hearing_rounded
                  : Icons.volume_up_rounded,
              color: audio?.state.value.speaker == false
                  ? _muted
                  : const Color(0xff48e08a),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Oyunlar',
            color: const Color(0xff171121),
            icon: const Icon(Icons.sports_esports_rounded, color: _blue),
            onSelected: (value) {
              if (value == 'room') {
                _openGames();
              } else if (value == 'domino') {
                _startRoomDomino(roomData);
              } else if (value == 'music') {
                _pickMusic(roomData);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeGameCenterPage(profile: widget.profile),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'domino',
                child: Text('Domino (2 nəfər)',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'music',
                child: Text('Musiqi qoy',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'room',
                child: Text('Room oyunları', style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem(
                value: 'center',
                child: Text('Game Center', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Otaq alətləri',
            onPressed: () => _openTools(roomData),
            icon: const Icon(Icons.apps_rounded, color: Color(0xff9d7dff)),
          ),
          IconButton(
            tooltip: 'Hədiyyə',
            onPressed: () => _openGifts(roomData),
            icon: const Icon(Icons.card_giftcard_rounded, color: _pink),
          ),
          Expanded(
            child: TextField(
              controller: message,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              cursorColor: _pink,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz...',
                hintStyle: const TextStyle(color: Color(0xff8f86a3), fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                filled: true,
                fillColor: const Color(0xff181121),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Ürək göndər',
            onPressed: _sendHeart,
            icon: const Icon(Icons.favorite_rounded, color: _pink),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: _pink),
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  void _openMicRequests(Map<String, dynamic> roomData) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 420,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: room
                .collection('micRequests')
                .orderBy('createdAt')
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _pink),
                );
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Mic istəyi yoxdur.',
                    style: TextStyle(color: _muted),
                  ),
                );
              }
              return ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Mikrofon istəkləri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  for (final req in docs)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: _purple,
                        child: Icon(Icons.mic_rounded, color: Colors.white),
                      ),
                      title: Text(
                        '${req.data()['name'] ?? 'VIBE'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Qəbul et',
                            onPressed: () => _approveRequest(req, roomData),
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.greenAccent,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rədd et',
                            onPressed: req.reference.delete,
                            icon: const Icon(
                              Icons.cancel_rounded,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final title = TextEditingController();
  final topic = TextEditingController();
  final password = TextEditingController();
  bool locked = false;
  bool video = false;
  String theme = 'chat';
  int seatCount = 8;

  /// Görüntülü otaqda mesh ağırdır — yer sayı məhduddur.
  int get maxSeats => video ? 4 : 20;

  @override
  void dispose() {
    title.dispose();
    topic.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff151020),
      title: const Text(
        'Yeni Party Room',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: title,
              style: const TextStyle(color: Colors.white),
              maxLength: 40,
              decoration: const InputDecoration(hintText: 'Otağın adı'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: topic,
              style: const TextStyle(color: Colors.white),
              maxLength: 80,
              decoration: const InputDecoration(hintText: 'Mövzu'),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Otağın mövzusu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in roomThemes)
                  VibeChip(
                    label: item.title,
                    emoji: item.emoji,
                    color: item.color,
                    selected: theme == item.id,
                    onTap: () => setState(() => theme = item.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: video,
              activeThumbColor: _pink,
              title: const Text(
                'Görüntülü otaq',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Kamera açıq — ən çox 4 nəfər',
                style: TextStyle(color: _muted, fontSize: 11.5),
              ),
              onChanged: (v) => setState(() {
                video = v;
                if (video && seatCount > maxSeats) seatCount = maxSeats;
              }),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                video
                    ? 'Neçə nəfər kameraya çıxsın?'
                    : 'Neçə nəfər mikrofona çıxsın?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                video
                    ? 'Qalanlar izləyici kimi qoşula bilər.'
                    : 'Dinləyici sayı məhdud deyil — istəyən qoşula bilər.',
                style: const TextStyle(color: _muted, fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: seatCount > 2
                      ? () => setState(() => seatCount--)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$seatCount nəfər',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Slider(
                        value: seatCount.toDouble().clamp(2, maxSeats.toDouble()),
                        min: 2,
                        max: maxSeats.toDouble(),
                        divisions: maxSeats - 2,
                        activeColor: _pink,
                        onChanged: (v) => setState(() => seatCount = v.round()),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: seatCount < maxSeats
                      ? () => setState(() => seatCount++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            // Seçilən sayın canlı görüntüsü
            Wrap(
              spacing: 5,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < seatCount; i++)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i == 0 ? vHot : null,
                      color: i == 0 ? null : const Color(0xff2a2140),
                      border: Border.all(color: const Color(0xff3d2a54)),
                    ),
                    child: Icon(
                      i == 0
                          ? Icons.workspace_premium_rounded
                          : (video
                              ? Icons.videocam_rounded
                              : Icons.mic_rounded),
                      size: 11,
                      color: i == 0 ? Colors.white : _muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: locked,
              activeThumbColor: _pink,
              title: const Text(
                'Şifrəli otaq',
                style: TextStyle(color: Colors.white),
              ),
              onChanged: (v) => setState(() => locked = v),
            ),
            if (locked)
              TextField(
                controller: password,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Otaq şifrəsi'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ləğv et'),
        ),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty) return;
            if (locked && password.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _RoomDraft(
                title.text.trim(),
                topic.text.trim(),
                locked,
                password.text.trim(),
                seatCount,
                video,
                theme,
              ),
            );
          },
          child: const Text('Yarat'),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.password});
  final String password;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final controller = TextEditingController();
  bool wrong = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff151020),
      title: const Text('Şifrəli otaq', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Şifrə',
          errorText: wrong ? 'Şifrə yanlışdır' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Ləğv et'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text == widget.password) {
              Navigator.pop(context, true);
            } else {
              setState(() => wrong = true);
            }
          },
          child: const Text('Daxil ol'),
        ),
      ],
    );
  }
}

class _RoomDraft {
  const _RoomDraft(
    this.title,
    this.topic,
    this.locked,
    this.password,
    this.seatCount,
    this.video,
    this.theme,
  );

  final String title;
  final String topic;
  final bool locked;
  final String password;

  /// Görüntülü otaq — iştirakçılar bir-birini görür.
  final bool video;

  /// Otağın mövzusu (söhbət, musiqi, oyun...).
  final String theme;

  /// Mikrofon yerlərinin sayı (host daxil).
  final int seatCount;
}


// ============================================================
// OTAQ KÖMƏKÇİ WIDGET-LƏRİ
// ============================================================

/// İstifadəçi şəklini canlı gətirir.
class _UserPhoto extends StatelessWidget {
  const _UserPhoto({required this.uid, required this.name});

  final String uid, name;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return VibePhoto(url: '', name: name);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final d = snapshot.data?.data() ?? const <String, dynamic>{};
        return VibePhoto(
          url: '${d['photoUrl'] ?? ''}',
          name: '${d['name'] ?? name}',
          emoji: '${d['avatarEmoji'] ?? ''}',
        );
      },
    );
  }
}

/// Otaq sahibini izləmə düyməsi.
class _FollowHostPill extends StatelessWidget {
  const _FollowHostPill({
    required this.profile,
    required this.hostId,
    required this.hostName,
  });

  final UserProfile profile;
  final String hostId, hostName;

  Future<void> _toggle(bool following) async {
    final mine = FirebaseFirestore.instance
        .collection('users')
        .doc(profile.uid)
        .collection('following')
        .doc(hostId);
    final theirs = FirebaseFirestore.instance
        .collection('users')
        .doc(hostId)
        .collection('followers')
        .doc(profile.uid);

    final batch = FirebaseFirestore.instance.batch();
    if (following) {
      batch.delete(mine);
      batch.delete(theirs);
    } else {
      batch.set(mine, {
        'uid': hostId,
        'name': hostName,
        'createdAt': Timestamp.now(),
      });
      batch.set(theirs, {
        'uid': profile.uid,
        'name': profile.name,
        'createdAt': Timestamp.now(),
      });
    }

    try {
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(profile.uid)
            .collection('following')
            .doc(hostId)
            .snapshots(),
        builder: (context, snapshot) {
          final following = snapshot.data?.exists == true;
          return PressableScale(
            onTap: () => _toggle(following),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                gradient: following ? null : vHot,
                color: following ? Colors.white.withValues(alpha: .08) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                following ? 'İzlənilir' : 'İzlə',
                style: TextStyle(
                  color: following ? _muted : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      );
}

/// Yuxarı uçan ürək.
class _FlyingHeart extends StatefulWidget {
  const _FlyingHeart({super.key, required this.seed});

  final int seed;

  @override
  State<_FlyingHeart> createState() => _FlyingHeartState();
}

class _FlyingHeartState extends State<_FlyingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  late final double drift = (Random(widget.seed).nextDouble() - .5) * 46;
  late final Color color = [
    _pink,
    _purple,
    const Color(0xffff657b),
    const Color(0xffffb347),
  ][widget.seed % 4];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final t = Curves.easeOut.transform(controller.value);
      return Positioned(
        right: 16 + drift * t,
        bottom: 230 * t,
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .6 + .6 * t,
            child: Icon(Icons.favorite_rounded, color: color, size: 24),
          ),
        ),
      );
    },
  );
}
