// MESAJLAR — söhbətlər və insanlar.
// Maket: "Mesajlar · İnsanlar" tabları, filtr pilləri,
// üç sürətli keçid sətri və söhbət siyahısı.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'main.dart' show PersonPage, isReallyOnline;
import 'social_ui.dart' show SocialSurface, openChat, isUnread;
import 'suggest_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'families_page.dart';
import 'blocking.dart';
import 'notifications_center.dart';
import 'user_profile.dart';
import 'vibe_status.dart';
import 'invite.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

class SocialMessages extends StatefulWidget {
  const SocialMessages({
    super.key,
    this.database,
    required this.profile,
    required this.navigate,
  });

  final FirebaseFirestore? database;
  final UserProfile profile;
  final ValueChanged<int> navigate;

  @override
  State<SocialMessages> createState() => _SocialMessagesState();
}

class _SocialMessagesState extends State<SocialMessages> {
  static const filters = [
    'Hamısı',
    'Online',
    'Oxunmamış',
    'İzlədiklərim',
    'Ən çox yazışılan',
  ];

  /// İnsanlar sekməsinin alt bölmələri.
  static const peopleTabs = ['Hamısı', 'İzlədiklərim', 'İzləyicilər', 'Dostlar'];

  int tab = 0; // 0 = Mesajlar, 1 = İnsanlar
  int filter = 0;
  int peopleTab = 0;

  /// Toplu silmə rejimi.
  bool selecting = false;
  final Set<String> selected = <String>{};

  /// Tövsiyə pəncərəsi bir açılışda yalnız bir dəfə çıxsın.
  bool suggestChecked = false;
  String query = '';
  bool searching = false;
  Timer? timer;

  final Set<String> blockedIds = <String>{};
  Set<String> following = <String>{};
  Set<String> followers = <String>{};
  StreamSubscription<Set<String>>? blockSub;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  // Bütün istifadəçiləri çəkmək miqyaslanmır; yalnız görünən söhbətlərin
  // qarşı tərəfi ayrıca oxunur (ChatAvatar/_PeerTile canlı dinləyir).
  late final users = db.collection('users').limit(300).snapshots();
  late final chats = db
      .collection('chats')
      .where('members', arrayContains: widget.profile.uid)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _watchBlocked();
    final me = db.collection('users').doc(widget.profile.uid);

    me.collection('following').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => following = snap.docs.map((e) => e.id).toSet());
    }, onError: (Object _) {});

    me.collection('followers').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => followers = snap.docs.map((e) => e.id).toSet());
    }, onError: (Object _) {});

    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    blockSub?.cancel();
    super.dispose();
  }

  /// Bloklanmışlar + məni bloklayanlar siyahıdan çıxır.
  void _watchBlocked() {
    blockSub = watchHiddenUids(widget.profile.uid, database: widget.database).listen((ids) {
      if (!mounted) return;
      setState(() {
        blockedIds
          ..clear()
          ..addAll(ids);
      });
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) => SocialSurface(
    child: Column(
      children: [
        _header(),
        if (searching) _searchField(),
        const SizedBox(height: 4),
        PillTabs(
          labels: tab == 0 ? filters : peopleTabs,
          index: tab == 0 ? filter : peopleTab,
          onChanged: (i) => setState(() {
            if (tab == 0) {
              filter = i;
            } else {
              peopleTab = i;
            }
          }),
        ),
        if (selecting) _selectionBar(),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: users,
            builder: (context, people) {
              if (!people.hasData) return _skeleton();

              final profiles = {
                for (final doc in people.data!.docs) doc.id: doc.data(),
              };

              return tab == 0
                  ? _chatsView(profiles)
                  : _peopleView(profiles);
            },
          ),
        ),
      ],
    ),
  );

  // ----------------------------------------------------------
  // BAŞLIQ
  // ----------------------------------------------------------

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 10, 2),
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(child: _headerTab('Mesajlar', 0)),
              const SizedBox(width: 20),
              Flexible(child: _headerTab('İnsanlar', 1)),
            ],
          ),
        ),
        TopIconButton(
          icon: searching ? Icons.close_rounded : Icons.search_rounded,
          tooltip: 'Axtar',
          onTap: () => setState(() {
            searching = !searching;
            if (!searching) query = '';
          }),
        ),
        TopIconButton(
          icon: Icons.add_circle_outline_rounded,
          tooltip: 'Yeni söhbət',
          onTap: () => setState(() => tab = 1),
        ),
        TopIconButton(
          icon: Icons.menu_rounded,
          tooltip: 'Daha çox',
          onTap: _openTools,
        ),
      ],
    ),
  );

  Widget _headerTab(String label, int index) {
    final selected = tab == index;
    return PressableScale(
      onTap: () => setState(() => tab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : vMuted,
              fontSize: selected ? 23 : 19,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: selected ? 24 : 0,
            decoration: BoxDecoration(
              color: vPink,
              borderRadius: BorderRadius.circular(3),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0xaaff2bd6), blurRadius: 9)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
    child: TextField(
      autofocus: true,
      onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
      style: const TextStyle(color: Colors.white),
      cursorColor: vPink,
      decoration: InputDecoration(
        hintText: 'Ad və ya mesaj axtar',
        hintStyle: const TextStyle(color: vMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: vPurple),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        filled: true,
        fillColor: const Color(0xff17122a),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    children: const [
      VibeShimmer(height: 62, radius: 18),
      SizedBox(height: 12),
      VibeShimmer(height: 62, radius: 18),
      SizedBox(height: 12),
      VibeShimmer(height: 62, radius: 18),
      SizedBox(height: 22),
      VibeShimmer(height: 54, radius: 16),
      SizedBox(height: 14),
      VibeShimmer(height: 54, radius: 16),
    ],
  );

  // ----------------------------------------------------------
  // SÖHBƏTLƏR
  // ----------------------------------------------------------

  Widget _chatsView(Map<String, Map<String, dynamic>> profiles) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _MessagesError();
          }
          if (!snapshot.hasData) return _skeleton();

          final list = snapshot.data!.docs.toList()
            ..sort((a, b) {
              // "Ən çox yazışılan" sekməsində mesaj sayına, qalanında vaxta.
              if (filter == 4) {
                int count(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    doc.data()['messageCount'] is num
                        ? (doc.data()['messageCount'] as num).toInt()
                        : 0;
                final diff = count(b).compareTo(count(a));
                if (diff != 0) return diff;
              }

              final ta = (a.data()['updatedAt'] as Timestamp?)?.seconds ?? 0;
              final tb = (b.data()['updatedAt'] as Timestamp?)?.seconds ?? 0;
              return tb.compareTo(ta);
            });

          final visible = list.where((doc) {
            final d = doc.data();
            final peer = (List<String>.from(d['members'] ?? const [])
                  ..remove(widget.profile.uid))
                .firstOrNull;
            if (peer == null || blockedIds.contains(peer)) return false;

            final p = profiles[peer] ?? const <String, dynamic>{};
            final unread = isUnread(d, widget.profile.uid);

            if (filter == 1 && !isReallyOnline(p)) return false;
            if (filter == 2 && !unread) return false;
            if (filter == 3 && !following.contains(peer)) return false;
            // 4 = ən çox yazışılan: süzgəc deyil, sıralamadır (aşağıda).

            if (query.isNotEmpty) {
              final haystack = '${p['name']} ${d['lastMessage']}'.toLowerCase();
              if (!haystack.contains(query)) return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _shortcut(
                icon: Icons.notifications_rounded,
                colors: const [Color(0xff8b5cff), Color(0xff5c3bd6)],
                title: 'Bildirişlər',
                subtitle: 'Yeni fəaliyyətlər',
                badge: _NotificationBadgeCount(
                  uid: widget.profile.uid,
                  database: db,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationCenterPage(profile: widget.profile),
                  ),
                ),
              ),
              _shortcut(
                icon: Icons.mic_rounded,
                colors: const [Color(0xff2ecc8f), Color(0xff1aa06e)],
                title: 'Söhbət otağı',
                subtitle: 'Otağa gir və dostlarınla danış',
                onTap: () => widget.navigate(2),
              ),
              _shortcut(
                icon: Icons.shield_rounded,
                colors: const [Color(0xff22a7ff), Color(0xff1b6fd6)],
                title: 'Ailələr',
                subtitle: 'Ailəyə qoşul, birlikdə xəzinə yığ',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FamiliesPage(
                      profile: widget.profile,
                      database: widget.database,
                    ),
                  ),
                ),
              ),
              _shortcut(
                icon: Icons.auto_awesome_rounded,
                colors: const [Color(0xffff2bd6), Color(0xffb84dff)],
                title: 'Anlar',
                subtitle: 'Düşüncələrini paylaş',
                onTap: () => widget.navigate(1),
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xff221a33), height: 24),
              if (visible.isEmpty)
                Builder(builder: (context) {
                  _maybeSuggest();
                  return const SizedBox.shrink();
                }),
              if (visible.isEmpty)
                _EmptyMessages(
                    onAction: () => setState(() => tab = 1),
                    inviteName: widget.profile.name,
                    inviteUid: widget.profile.uid)
              else
                for (final doc in visible)
                  _chatTile(doc, profiles),
            ],
          );
        },
      );



  /// Söhbət siyahısı boş olanda tövsiyə pəncərəsini bir dəfə açır.
  ///
  /// Gündə bir dəfədən çox çıxmır: hər açılışda pəncərə ilə qarşılaşmaq
  /// bezdirici olardı. Tarix cihazda saxlanılır.
  Future<void> _maybeSuggest() async {
    if (suggestChecked) return;
    suggestChecked = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (prefs.getString('suggestShownOn') == today) return;

      final people = await loadSuggestions(
        profile: widget.profile,
        database: widget.database,
      );

      if (!mounted || people.isEmpty) return;

      await prefs.setString('suggestShownOn', today);
      if (!mounted) return;

      await showSuggestionsDialog(
        context,
        profile: widget.profile,
        people: people,
        database: widget.database,
      );
    } catch (_) {
      // Tövsiyə göstərilməsə də ekran normal işləməlidir.
    }
  }

  /// Menyudan əl ilə açılanda — tarix yoxlaması olmadan.
  Future<void> _openSuggestions() async {
    final messenger = ScaffoldMessenger.of(context);

    final people = await loadSuggestions(
      profile: widget.profile,
      database: widget.database,
    );

    if (!mounted) return;

    if (people.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Hazırda yeni tövsiyə yoxdur.')),
      );
      return;
    }

    await showSuggestionsDialog(
      context,
      profile: widget.profile,
      people: people,
      database: widget.database,
    );
  }

  // ----------------------------------------------------------
  // ALƏTLƏR
  // ----------------------------------------------------------

  /// Başlıqdakı ☰ menyusu.
  void _openTools() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded,
                  color: vMuted),
              title: const Text('Yeni söhbət',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('İnsanlar siyahısından seç',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                setState(() => tab = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: vPink),
              title: const Text('Tanış ol',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Sənə uyğun adamlara salam de',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                _openSuggestions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read_outlined,
                  color: vMuted),
              title: const Text('Hamısını oxunmuş et',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                _markAllRead();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined,
                  color: Color(0xffff657b)),
              title: const Text(
                'Toplu silmə',
                style: TextStyle(
                  color: Color(0xffff657b),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text('Bir neçə söhbəti seçib sil',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheet);
                setState(() {
                  tab = 0;
                  selecting = true;
                  selected.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Seçim rejimindəki üst zolaq.
  Widget _selectionBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          decoration: BoxDecoration(
            color: vPink.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: vPink.withValues(alpha: .45)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected.isEmpty
                      ? 'Silmək üçün söhbət seç'
                      : '${selected.length} söhbət seçildi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: _deleteSelected,
                  child: const Text(
                    'Sil',
                    style: TextStyle(
                      color: Color(0xffff657b),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() {
                  selecting = false;
                  selected.clear();
                }),
                child: const Text('İmtina', style: TextStyle(color: vMuted)),
              ),
            ],
          ),
        ),
      );

  /// Bütün söhbətləri oxunmuş sayır.
  ///
  /// Oxunma vəziyyəti söhbət sənədindəki `readAt` xəritəsindədir; hər
  /// söhbət üçün öz açarımızı indiki vaxta qoyuruq.
  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final snap = await db
          .collection('chats')
          .where('members', arrayContains: widget.profile.uid)
          .get();

      final batch = db.batch();
      for (final doc in snap.docs) {
        batch.set(doc.reference, {
          'readAt': {widget.profile.uid: Timestamp.now()},
        }, SetOptions(merge: true));
      }
      await batch.commit();

      messenger.showSnackBar(
        const SnackBar(content: Text('Hamısı oxunmuş sayıldı.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Alınmadı.')));
    }
  }

  /// Seçilmiş söhbətləri silir.
  ///
  /// Söhbət sənədi tamamilə silinmir — qarşı tərəfin yazışması da itərdi.
  /// Bunun əvəzinə özümüzü üzvlükdən çıxarırıq: söhbət bizim siyahıdan
  /// gedir, qarşı tərəfdə qalır.
  Future<void> _deleteSelected() async {
    final ids = selected.toList();
    if (ids.isEmpty) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: Text(
          '${ids.length} söhbət silinsin?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Söhbətlər sənin siyahından gedəcək. Qarşı tərəfdə qalacaq.',
          style: TextStyle(color: vMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('İmtina', style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text(
              'Sil',
              style: TextStyle(
                color: Color(0xffff657b),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (yes != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final batch = db.batch();
      for (final id in ids) {
        batch.set(db.collection('chats').doc(id), {
          'members': FieldValue.arrayRemove([widget.profile.uid]),
        }, SetOptions(merge: true));
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        selecting = false;
        selected.clear();
      });

      messenger.showSnackBar(
        SnackBar(content: Text('${ids.length} söhbət silindi.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Silinmədi.')));
    }
  }

  Widget _chatTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> profiles,
  ) {
    final d = doc.data();
    final peers = List<String>.from(d['members'] ?? const [])
      ..remove(widget.profile.uid);
    if (peers.isEmpty) return const SizedBox.shrink();

    final uid = peers.first;

    // Profil siyahıda yoxdursa (çox istifadəçi olanda), ayrıca oxunur —
    // ad və şəkil həmişə düzgün görünsün.
    return _PeerData(
      uid: uid,
      initial: profiles[uid] ?? const <String, dynamic>{},
      database: widget.database,
      builder: (p) => _chatTileBody(doc, d, uid, p),
    );
  }

  Widget _chatTileBody(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> d,
    String uid,
    Map<String, dynamic> p,
  ) {
    final name = '${p['name'] ?? 'İstifadəçi'}';
    final unread = isUnread(d, widget.profile.uid);
    final at = (d['updatedAt'] as Timestamp?)?.toDate();

    final typing = d['typing'];
    final typingAt = d['typingAt'];
    final isTyping = typing is Map &&
        typing[uid] == true &&
        typingAt is Map &&
        typingAt[uid] is Timestamp &&
        DateTime.now()
                .difference((typingAt[uid] as Timestamp).toDate())
                .inSeconds
                .abs() <
            8;

    final picked = selected.contains(doc.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PressableScale(
        onTap: selecting
            ? () => setState(() {
                  picked ? selected.remove(doc.id) : selected.add(doc.id);
                })
            : () => openChat(context, widget.profile, uid, name),
        // Uzun basmaq seçim rejimini açır — telefonlarda gözlənilən davranış.
        onLongPress: () => setState(() {
          selecting = true;
          selected.add(doc.id);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  picked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: picked ? vPink : vMuted,
                  size: 22,
                ),
                const SizedBox(width: 10),
              ],
              ChatAvatar(data: p, name: name, size: 52),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isTyping ? 'yazır…' : '${d['lastMessage'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isTyping
                            ? vPink
                            : (unread ? const Color(0xffd8d0e7) : vMuted),
                        fontSize: 12.5,
                        fontWeight: isTyping || unread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeLabel(at),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: unread ? vPink : vMuted,
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (unread)
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xffff4d5e),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(at.year, at.month, at.day);
    final days = today.difference(that).inDays;

    if (days == 0) {
      return '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
    }
    if (days == 1) return 'Dünən';
    if (days < 7) {
      const names = ['B.e', 'Ç.a', 'Ç', 'C.a', 'C', 'Ş', 'B'];
      return names[at.weekday - 1];
    }
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}';
  }

  Widget _shortcut({
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? badge,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: colors.last.withValues(alpha: .35), blurRadius: 14),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: vMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (badge != null) badge,
            const Icon(Icons.chevron_right_rounded, color: Color(0xff6f6786)),
          ],
        ),
      ),
    ),
  );

  // ----------------------------------------------------------
  // İNSANLAR
  // ----------------------------------------------------------

  Widget _peopleView(Map<String, Map<String, dynamic>> profiles) {
    final entries = profiles.entries.where((entry) {
      if (entry.key == widget.profile.uid) return false;
      if (blockedIds.contains(entry.key)) return false;

      final d = entry.value;

      // Alt sekmələr: izlədiklərim / izləyicilər / qarşılıqlı (dostlar).
      if (peopleTab == 1 && !following.contains(entry.key)) return false;
      if (peopleTab == 2 && !followers.contains(entry.key)) return false;
      if (peopleTab == 3 &&
          !(following.contains(entry.key) && followers.contains(entry.key))) {
        return false;
      }
      if (query.isNotEmpty &&
          !'${d['name']} ${d['city']}'.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    entries.sort((a, b) {
      final oa = isReallyOnline(a.value);
      final ob = isReallyOnline(b.value);
      if (oa != ob) return oa ? -1 : 1;
      return '${a.value['name'] ?? ''}'.compareTo('${b.value['name'] ?? ''}');
    });

    if (entries.isEmpty) {
      return _EmptyMessages(
        people: true,
        inviteName: widget.profile.name,
        inviteUid: widget.profile.uid,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final uid = entries[index].key;
        final d = entries[index].value;
        final name = '${d['name'] ?? 'İstifadəçi'}';
        final status = VibeStatus.from(d);

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: PressableScale(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonPage(
                  currentProfile: widget.profile,
                  targetUid: uid,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ChatAvatar(data: d, name: name, size: 50),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GenderAgeChip(
                              gender: genderCode(d),
                              age: '${d['age'] ?? ''}'.trim(),
                              fontSize: 9,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (status != null)
                          Text(
                            '${status.mood.emoji} ${status.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: status.mood.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          PlaceLabel(text: '${d['city'] ?? ''}'),
                      ],
                    ),
                  ),
                  GradientButton(
                    label: 'Mesaj',
                    expand: false,
                    height: 32,
                    fontSize: 11.5,
                    onPressed: () => openChat(context, widget.profile, uid, name),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// KÖMƏKÇİ WIDGET-LƏR
// ============================================================

/// Bir istifadəçinin profilini canlı gətirir; gəlməyənə qədər `initial` göstərir.
class _PeerData extends StatelessWidget {
  const _PeerData({
    required this.uid,
    required this.initial,
    required this.builder,
    this.database,
  });

  final String uid;
  final Map<String, dynamic> initial;
  final Widget Function(Map<String, dynamic> data) builder;
  final FirebaseFirestore? database;

  @override
  Widget build(BuildContext context) {
    // Siyahıda onsuz da varsa, əlavə dinləyici açmırıq.
    if (initial.isNotEmpty) return builder(initial);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: (database ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) =>
          builder(snapshot.data?.data() ?? initial),
    );
  }
}

/// Avatar + online nöqtəsi + əhval nişanı.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.data,
    required this.name,
    this.size = 52,
  });

  final Map<String, dynamic> data;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final status = VibeStatus.from(data);
    final online = isReallyOnline(data);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: online
                    ? const [Color(0xff2de28a), Color(0xff22a7ff)]
                    : const [Color(0xff3a2d52), Color(0xff2a2140)],
              ),
            ),
            child: ClipOval(
              child: VibePhoto(
                url: '${data['photoUrl'] ?? ''}',
                name: name,
                emoji: '${data['avatarEmoji'] ?? ''}',
              ),
            ),
          ),
          // Onlayn nişanı: halqa özü kifayət etmirdi, çünki əhval
          // nişanı gələndə diqqəti çəkir və halqa gözdən qaçır.
          if (online)
            Positioned(
              right: 0,
              top: 1,
              child: Container(
                width: size * .26,
                height: size * .26,
                decoration: BoxDecoration(
                  color: const Color(0xff2de28a),
                  shape: BoxShape.circle,
                  border: Border.all(color: vBg, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x662de28a), blurRadius: 6),
                  ],
                ),
              ),
            ),

          if (status != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: status.mood.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: vBg, width: 2),
                ),
                child: Text(
                  status.mood.emoji,
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Oxunmamış bildiriş sayı.
class _NotificationBadgeCount extends StatelessWidget {
  const _NotificationBadgeCount({required this.uid, this.database});

  final String uid;
  final FirebaseFirestore? database;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: (database ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          if (count == 0) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xffff4d5e),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        },
      );
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({
    this.people = false,
    this.onAction,
    this.inviteName,
    this.inviteUid,
  });

  final bool people;
  final VoidCallback? onAction;

  /// Verilsə, boş ekranda dəvət düyməsi də göstərilir.
  final String? inviteName;
  final String? inviteUid;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: vHot),
          child: Icon(
            people ? Icons.people_alt_rounded : Icons.forum_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          people ? 'Bu filtrdə kimsə yoxdur' : 'Söhbətlər burada başlayır',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          people
              ? 'Filtri dəyiş və ya axtarışı təmizlə.'
              : 'Kimsə ilə söhbətə başla — mesajların burada görünəcək.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: vMuted, height: 1.45),
        ),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          GradientButton(
            label: 'İnsanlara bax',
            icon: Icons.people_alt_rounded,
            expand: false,
            height: 44,
            onPressed: onAction,
          ),
        ],
        if (inviteName != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => showInviteSheet(
              context,
              name: inviteName!,
              referrerUid: inviteUid,
            ),
            icon: const Icon(Icons.group_add_rounded, color: vPink, size: 18),
            label: const Text(
              'Dostlarını dəvət et',
              style: TextStyle(color: vPink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    ),
  );
}

class _MessagesError extends StatelessWidget {
  const _MessagesError();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 46, color: vMuted),
          SizedBox(height: 14),
          Text(
            'Mesajlar yüklənmədi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text('İnternet bağlantını yoxla.', style: TextStyle(color: vMuted)),
        ],
      ),
    ),
  );
}
