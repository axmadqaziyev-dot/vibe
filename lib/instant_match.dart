import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';
import 'ui/vibe_chrome.dart';
import 'main.dart' show PersonPage, RealChatPage;
import 'calls.dart';

const _bg = Color(0xff070510);
const _panel = Color(0xff151020);
const _muted = Color(0xffa89fbd);
const _pink = Color(0xffff2bd6);
const _purple = Color(0xff8b5cff);
const _blue = Color(0xff22a7ff);

class InstantMatchPage extends StatefulWidget {
  const InstantMatchPage({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<InstantMatchPage> createState() => _InstantMatchPageState();
}

class _InstantMatchPageState extends State<InstantMatchPage>
    with SingleTickerProviderStateMixin {
  bool searching = false;
  bool videoMode = false;
  String gender = 'all';
  String city = 'all';
  DocumentSnapshot<Map<String, dynamic>>? match;
  Timer? pulseTimer;
  int pulse = 0;

  /// Axtarış edildi, amma heç kim tapılmadı.
  bool noResult = false;

  /// Tapılan adam hazırda offline-dır.
  bool matchedOffline = false;

  final Set<String> blockedIds = <String>{};

  @override
  void dispose() {
    pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _findMatch() async {
    if (searching) return;
    setState(() {
      searching = true;
      match = null;
      noResult = false;
      pulse = 0;
    });

    pulseTimer?.cancel();
    pulseTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (mounted) setState(() => pulse = (pulse + 1) % 4);
    });

    try {
      final me = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid);
      final blockedSnap = await me.collection('blocked').get();
      final blockedBySnap = await me.collection('blockedBy').get();

      blockedIds
        ..clear()
        ..addAll(blockedSnap.docs.map((e) => e.id))
        ..addAll(blockedBySnap.docs.map((e) => e.id));

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(100)
          .get();

      bool passes(QueryDocumentSnapshot<Map<String, dynamic>> doc, bool onlineOnly) {
        if (doc.id == widget.profile.uid) return false;
        if (blockedIds.contains(doc.id)) return false;
        final d = doc.data();
        if (onlineOnly && !_isOnline(d)) return false;

        if (city == 'same' && widget.profile.city.trim().isNotEmpty) {
          final targetCity = '${d['city'] ?? ''}'.trim().toLowerCase();
          if (targetCity != widget.profile.city.trim().toLowerCase()) return false;
        }

        if (gender != 'all') {
          final g = '${d['gender'] ?? d['sex'] ?? ''}'.toLowerCase();
          if (gender == 'female' &&
              !(g.contains('qız') ||
                  g.contains('qadin') ||
                  g.contains('female') ||
                  g == 'f')) {
            return false;
          }
          if (gender == 'male' &&
              !(g.contains('oğlan') ||
                  g.contains('kisi') ||
                  g.contains('male') ||
                  g == 'm')) {
            return false;
          }
        }

        return true;
      }

      // Əvvəl yalnız online; heç kim yoxdursa, offline olanlara da bax.
      var candidates = snap.docs.where((doc) => passes(doc, true)).toList();
      var offlineOnly = false;
      if (candidates.isEmpty) {
        candidates = snap.docs.where((doc) => passes(doc, false)).toList();
        offlineOnly = candidates.isNotEmpty;
      }

      candidates.shuffle();

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      final found = candidates.isEmpty ? null : candidates.first;

      if (found == null) {
        setState(() {
          match = null;
          searching = false;
          noResult = true;
        });
        return;
      }
      noResult = false;
      matchedOffline = offlineOnly;
      {
        final fd = found.data();
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.profile.uid)
              .collection('matchHistory')
              .doc(found.id)
              .set({
            'uid': found.id,
            'name': '${fd['name'] ?? 'VIBE'}',
            'photoUrl': '${fd['photoUrl'] ?? ''}',
            'city': '${fd['city'] ?? ''}',
            'matchedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      setState(() {
        match = found;
        searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        searching = false;
        noResult = true;
      });
    } finally {
      pulseTimer?.cancel();
    }
  }

  bool _isOnline(Map<String, dynamic> data) {
    final lastSeen = data['lastSeen'];
    if (data['online'] != true || lastSeen is! Timestamp) return false;
    final diff = DateTime.now().difference(lastSeen.toDate());
    return diff.inSeconds >= -10 && diff.inSeconds <= 90;
  }

  void _openChat(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealChatPage(
          currentProfile: widget.profile,
          targetUid: doc.id,
          targetName: '${d['name'] ?? 'VIBE'}',
        ),
      ),
    );
  }

  void _openProfile(DocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonPage(
          currentProfile: widget.profile,
          targetUid: doc.id,
        ),
      ),
    );
  }

  Future<void> _call(DocumentSnapshot<Map<String, dynamic>> doc, bool video) async {
    final d = doc.data() ?? {};
    await startCall(
      context,
      widget.profile.uid,
      widget.profile.name,
      doc.id,
      '${d['name'] ?? 'VIBE'}',
      video,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = match?.data() ?? {};
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Instant Match',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xff0b0711),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _filters(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: searching
                    ? _searching()
                    : match == null
                        ? (noResult ? _noResult() : _empty())
                        : _matchCard(match!, d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xff352544)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.call_rounded),
                      label: Text('Səsli'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.videocam_rounded),
                      label: Text('Video'),
                    ),
                  ],
                  selected: {videoMode},
                  onSelectionChanged: (v) => setState(() => videoMode = v.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: gender,
                  dropdownColor: const Color(0xff171121),
                  decoration: const InputDecoration(
                    labelText: 'Kim?',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Hamısı')),
                    DropdownMenuItem(value: 'female', child: Text('Qızlar')),
                    DropdownMenuItem(value: 'male', child: Text('Oğlanlar')),
                  ],
                  onChanged: (v) => setState(() => gender = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: city,
                  dropdownColor: const Color(0xff171121),
                  decoration: const InputDecoration(
                    labelText: 'Yer',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Hər yerdən')),
                    DropdownMenuItem(value: 'same', child: Text('Şəhərim')),
                  ],
                  onChanged: (v) => setState(() => city = v ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Axtarışdan sonra heç kim tapılmayanda göstərilir.
  Widget _noResult() => Center(
    key: const ValueKey('noResult'),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _purple.withValues(alpha: .18),
              border: Border.all(color: _purple.withValues(alpha: .5)),
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hazırda uyğun kimsə tapılmadı',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Filtri genişləndir (cinsiyyət / şəhər) və ya bir az sonra '
            'yenidən yoxla.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    gender = 'all';
                    city = 'all';
                  });
                  _findMatch();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Filtrsiz axtar'),
              ),
              OutlinedButton.icon(
                onPressed: _findMatch,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yenidən'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _empty() {
    return Center(
      key: const ValueKey('empty'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 126,
              height: 126,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_blue, _purple, _pink]),
                boxShadow: [
                  BoxShadow(color: Color(0x66ff2bd6), blurRadius: 35),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 58,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Yeni biri ilə tanış ol',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Online istifadəçilər arasından sənə uyğun biri tapılacaq.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 230,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [_blue, _purple, _pink],
                  ),
                ),
                child: TextButton.icon(
                  onPressed: _findMatch,
                  icon: const Icon(Icons.bolt_rounded, color: Colors.white),
                  label: const Text(
                    'İndi tap',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
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

  Widget _searching() {
    return Center(
      key: const ValueKey('searching'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 78,
            height: 78,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: _pink,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Uyğun insan axtarılır${'.' * pulse}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Online profillər yoxlanılır',
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _matchCard(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> d,
  ) {
    final name = '${d['name'] ?? 'VIBE'}';
    final cityName = '${d['city'] ?? ''}';
    final age = int.tryParse('${d['age'] ?? ''}');
    final photo = '${d['photoUrl'] ?? d['profilePhoto'] ?? ''}';

    // Online kimsə tapılmayanda offline istifadəçi göstərilir — bunu deyirik.
    final offlineNote = matchedOffline
        ? Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Hazırda online kimsə yoxdur — bu profil offline-dır',
              style: TextStyle(color: _muted, fontSize: 11.5),
            ),
          )
        : const SizedBox.shrink();

    return Center(
      key: ValueKey(doc.id),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              offlineNote,
              Container(
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xff5a3470)),
              boxShadow: const [
                BoxShadow(color: Color(0x44ff2bd6), blurRadius: 34),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(29),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 330,
                    child: vibeImageProvider(photo) != null
                        ? VibePhoto(url: photo, name: name)
                        : _fallback(name),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              age == null ? name : '$name, $age',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.circle,
                            color: Color(0xff35e18b),
                            size: 11,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Online',
                            style: TextStyle(color: Color(0xff35e18b)),
                          ),
                        ],
                      ),
                      if (cityName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: _purple,
                              size: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cityName,
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _findMatch,
                              icon: const Icon(Icons.skip_next_rounded),
                              label: const Text('Keç'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openProfile(doc),
                              icon: const Icon(Icons.person_rounded),
                              label: const Text('Profil'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _openChat(doc),
                              icon: const Icon(Icons.chat_bubble_rounded),
                              label: const Text('Mesaj'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_purple, _pink],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: TextButton.icon(
                                onPressed: () => _call(doc, videoMode),
                                icon: Icon(
                                  videoMode
                                      ? Icons.videocam_rounded
                                      : Icons.call_rounded,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  videoMode ? 'Video' : 'Səsli',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _fallback(String name) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff26103d), Color(0xff5e1d6e), Color(0xffb21d8e)],
        ),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? 'V' : name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
