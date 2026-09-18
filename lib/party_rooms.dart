import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';
import 'vibe_ranking.dart';
import 'game_center.dart';

const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);
const _blue = Color(0xff22a7ff);
const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _muted = Color(0xffa89fbd);

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
          for (int i = 1; i < 8; i++)
            '$i': {'uid': '', 'name': '', 'muted': false, 'locked': false},
        },
      });
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

  Future<void> _openRoom(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
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
        builder: (_) => PartyRoomPage(profile: widget.profile, roomId: doc.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff160926), Color(0xff090611), Color(0xff05040b)],
        ),
      ),
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
                            '8 mikrofon yeri, host idarəsi, hədiyyələr və oyunlar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _createRoom,
                            icon: const Icon(Icons.add),
                            label: const Text('Otaq yarat'),
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
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [_blue, _purple, _pink],
                                ),
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
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
  });

  final UserProfile profile;
  final String roomId;

  @override
  State<PartyRoomPage> createState() => _PartyRoomPageState();
}

class _PartyRoomPageState extends State<PartyRoomPage> {
  final message = TextEditingController();
  late final DocumentReference<Map<String, dynamic>> room =
      FirebaseFirestore.instance.collection('partyRooms').doc(widget.roomId);

  DocumentReference<Map<String, dynamic>> get me =>
      FirebaseFirestore.instance.collection('users').doc(widget.profile.uid);

  @override
  void initState() {
    super.initState();
    _joinPresence();
  }

  @override
  void dispose() {
    message.dispose();
    _leavePresence();
    super.dispose();
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
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await room.collection('events').add({
        'type': vip ? 'vip_enter' : 'enter',
        'uid': widget.profile.uid,
        'name': widget.profile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final count = await room.collection('members').count().get();
      await room.set(
        {
          'memberCount': count.count ?? 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> _leavePresence() async {
    try {
      await room.collection('members').doc(widget.profile.uid).delete();
      final count = await room.collection('members').count().get();
      await room.set(
        {'memberCount': count.count ?? 0, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
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
    message.clear();
    await room.collection('messages').add({
      'uid': widget.profile.uid,
      'name': widget.profile.name,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendGift(_Gift gift, Map<String, dynamic> roomData) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final userSnap = await tx.get(me);
        final data = userSnap.data() ?? {};
        final coins = int.tryParse('${data['coins'] ?? 0}') ?? 0;
        if (coins < gift.price) {
          throw Exception('Coin kifayət etmir');
        }
        final senderGiftSent =
            int.tryParse('${data['giftSent'] ?? 0}') ?? 0;
        final newGiftSent = senderGiftSent + gift.price;
        final senderLevel = 1 + (newGiftSent ~/ 500);

        tx.set(
          me,
          {
            'coins': coins - gift.price,
            'giftSent': newGiftSent,
            'level': senderLevel,
          },
          SetOptions(merge: true),
        );

        final hostId = '${roomData['hostId'] ?? ''}';
        if (hostId.isNotEmpty) {
          final hostRef =
              FirebaseFirestore.instance.collection('users').doc(hostId);
          final hostSnap = await tx.get(hostRef);
          final hostData = hostSnap.data() ?? {};
          final hostGiftReceived =
              int.tryParse('${hostData['giftReceived'] ?? 0}') ?? 0;
          final newReceived = hostGiftReceived + gift.price;
          final hostLevel = 1 + (newReceived ~/ 500);

          tx.set(
            hostRef,
            {
              'giftReceived': newReceived,
              'level': hostLevel,
            },
            SetOptions(merge: true),
          );
        }

        tx.set(
          room,
          {
            'giftTotal': FieldValue.increment(gift.price),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        final giftRef = room.collection('gifts').doc();
        tx.set(giftRef, {
          'fromUid': widget.profile.uid,
          'fromName': widget.profile.name,
          'emoji': gift.emoji,
          'title': gift.title,
          'price': gift.price,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      _toast('${gift.emoji} ${gift.title} göndərildi!');
    } catch (_) {
      _toast('Coin kifayət etmir.');
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

  void _openGifts(Map<String, dynamic> roomData) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hədiyyə göndər',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final gift in _gifts)
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(context);
                        _sendGift(gift, roomData);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xff1b1328),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xff3d2a54)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(gift.emoji, style: const TextStyle(fontSize: 30)),
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
                              '${gift.price} coin',
                              style: const TextStyle(color: _muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
        final isHost = d['hostId'] == widget.profile.uid;
        final canModerate = _isModerator(d);
        final seats = Map<String, dynamic>.from(d['seats'] ?? {});
        final game = Map<String, dynamic>.from(d['game'] ?? {});

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: const Color(0xff0b0711),
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d['title'] ?? 'VIBE Party'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${d['memberCount'] ?? 1} nəfər · host ${d['hostName'] ?? ''}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Ranking',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VibeRankingPage(profile: widget.profile),
                    ),
                  );
                },
                icon: const Icon(Icons.emoji_events_rounded, color: Color(0xffffd86b)),
              ),
              if (canModerate)
                IconButton(
                  tooltip: 'Mic istəkləri',
                  onPressed: () => _openMicRequests(d),
                  icon: const Icon(Icons.pan_tool_alt_rounded),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if ('${d['topic'] ?? ''}'.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff151020),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xff38244d)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag_rounded, color: _purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${d['topic']}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _seatGrid(seats, d, canModerate),
                const SizedBox(height: 8),
                _gameBanner(game),
                const SizedBox(height: 8),
                _liveEventStrip(),
                const SizedBox(height: 6),
                Expanded(child: _chat()),
                _bottomBar(d),
              ],
            ),
          ),
        );
      },
    );
  }

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
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: .82,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (_, index) {
          final seat = Map<String, dynamic>.from(seats['$index'] ?? {});
          final uid = '${seat['uid'] ?? ''}';
          final name = '${seat['name'] ?? ''}';
          final empty = uid.isEmpty;
          final muted = seat['muted'] == true;
          final locked = seat['locked'] == true;
          final mine = uid == widget.profile.uid;

          return GestureDetector(
            onTap: empty
                ? () => _takeSeat(index, roomData)
                : mine
                    ? () => _leaveSeat(roomData)
                    : null,
            onLongPress: canModerate && index != 0
                ? () => _seatAdminSheet(index, seat, roomData)
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff151020),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: mine
                      ? _pink
                      : (!empty && !muted
                          ? const Color(0xff35e18b)
                          : const Color(0xff342743)),
                  width: mine || (!empty && !muted) ? 1.6 : 1,
                ),
                boxShadow: !empty && !muted
                    ? const [
                        BoxShadow(
                          color: Color(0x4435e18b),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: empty
                              ? null
                              : const LinearGradient(
                                  colors: [_blue, _purple, _pink],
                                ),
                          color: empty ? const Color(0xff21172c) : null,
                        ),
                        child: Icon(
                          locked
                              ? Icons.lock_rounded
                              : empty
                                  ? Icons.add_rounded
                                  : muted
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_rounded,
                          color: empty ? _muted : Colors.white,
                        ),
                      ),
                      if (!empty && !muted)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(0xff35e18b),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    index == 0
                        ? (empty ? 'HOST' : name)
                        : (empty ? (locked ? 'Kilidli' : 'Mic ${index + 1}') : name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: empty ? _muted : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!empty &&
                      index != 0 &&
                      ((roomData['moderators'] as List?) ?? const [])
                          .map((e) => '$e')
                          .contains(uid))
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'MOD',
                        style: TextStyle(
                          color: Color(0xffffd86b),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
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

  Widget _chat() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: room
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.35),
                  children: [
                    TextSpan(
                      text: '${d['name'] ?? 'VIBE'}  ',
                      style: const TextStyle(
                        color: _purple,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: '${d['text'] ?? ''}',
                      style: const TextStyle(color: Colors.white70),
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
          PopupMenuButton<String>(
            tooltip: 'Oyunlar',
            color: const Color(0xff171121),
            icon: const Icon(Icons.sports_esports_rounded, color: _blue),
            onSelected: (value) {
              if (value == 'room') {
                _openGames();
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
            tooltip: 'Hədiyyə',
            onPressed: () => _openGifts(roomData),
            icon: const Icon(Icons.card_giftcard_rounded, color: _pink),
          ),
          Expanded(
            child: TextField(
              controller: message,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Otağa mesaj yaz...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_rounded),
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
  const _RoomDraft(this.title, this.topic, this.locked, this.password);
  final String title;
  final String topic;
  final bool locked;
  final String password;
}

class _Gift {
  const _Gift(this.emoji, this.title, this.price);
  final String emoji;
  final String title;
  final int price;
}

const _gifts = <_Gift>[
  _Gift('🌹', 'Gül', 10),
  _Gift('💜', 'Ürək', 25),
  _Gift('👑', 'Tac', 100),
  _Gift('🚗', 'Maşın', 250),
  _Gift('🚀', 'Raket', 500),
  _Gift('💎', 'Diamond', 1000),
  _Gift('🏰', 'Qala', 2500),
  _Gift('🛥️', 'Yaxta', 5000),
];
