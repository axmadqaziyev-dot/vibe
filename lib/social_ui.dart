import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'main.dart' show UserProfile, RealChatPage, PersonPage, isReallyOnline;
import 'preferences.dart';

const ink = Color(0xff302e38);
const mutedInk = Color(0xff99969f);

class SocialSurface extends StatelessWidget {
  const SocialSurface({
    super.key,
    required this.child,
    this.color = const Color(0xffe7dfff),
  });
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, .32, 1],
        colors: [color, const Color(0xfffafafa), const Color(0xfffafafa)],
      ),
    ),
    child: Material(type: MaterialType.transparency, child: SafeArea(bottom: false, child: child)),
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.name,
    this.size = 64,
    this.online = false,
    this.symbol = '',
  });
  final String name, symbol;
  final double size;
  final bool online;
  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xffe7dfff),
      Color(0xffffdfeb),
      Color(0xffd8f4e7),
      Color(0xffffedc7),
    ];
    final color =
        colors[name.runes.fold<int>(0, (a, b) => a + b) % colors.length];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: .45)],
            ),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Text(
            symbol.isNotEmpty
                ? symbol
                : (name.isEmpty
                      ? '?'
                      : String.fromCharCode(name.runes.first).toUpperCase()),
            style: TextStyle(
              fontSize: size * .37,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        if (online)
          Positioned(
            right: 1,
            top: 4,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xff3ed47b),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
      ],
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  color: ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(color: mutedInk, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class EmptySocial extends StatelessWidget {
  const EmptySocial(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.chat_bubble_outline_rounded,
  });
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    child: Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: const Color(0xffeee8ff),
          child: Icon(icon, size: 34, color: const Color(0xff8b70f8)),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: mutedInk, height: 1.5),
        ),
      ],
    ),
  );
}

class SocialHome extends StatefulWidget {
  const SocialHome({super.key, required this.profile, this.database});
  final FirebaseFirestore? database;
  final UserProfile profile;
  @override
  State<SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends State<SocialHome> {
  String query = '';
  int filter = 0;
  bool searching = false;
  Timer? timer;
  late final stream = (widget.database ?? FirebaseFirestore.instance)
      .collection('users')
      .snapshots();
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SocialSurface(
    child: Column(
      children: [
        PageHeading(
          'Kəşf et',
          subtitle: 'Sənin insanlarını tap ✨',
          action: IconButton(
            tooltip: 'İnsan axtar',
            onPressed: () => setState(() => searching = !searching),
            icon: const Icon(Icons.search_rounded, size: 29),
          ),
        ),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
              decoration: const InputDecoration(
                hintText: 'Ad və ya şəhər axtar',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Wrap(
            children: [
              for (final item in ['Tövsiyə', 'Aktiv', 'Yeni'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item),
                    selected:
                        filter == ['Tövsiyə', 'Aktiv', 'Yeni'].indexOf(item),
                    onSelected: (_) => setState(
                      () => filter = ['Tövsiyə', 'Aktiv', 'Yeni'].indexOf(item),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptySocial(
                  'İnsanlar yüklənmədi',
                  'Bağlantını yoxlayıb yenidən aç.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!.docs.where((doc) {
                final d = doc.data();
                return doc.id != widget.profile.uid &&
                    (filter != 1 || isReallyOnline(d)) &&
                    '${d['name']} ${d['city']}'.toLowerCase().contains(query);
              }).toList();
              users.sort((a, b) {
                if (filter == 2) {
                  return ((b.data()['createdAt'] as Timestamp?)?.seconds ?? 0)
                      .compareTo(
                        (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0,
                      );
                }
                return (isReallyOnline(b.data()) ? 1 : 0).compareTo(
                  isReallyOnline(a.data()) ? 1 : 0,
                );
              });
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              colors: [Color(0xffffeaa1), Color(0xffffe1cd)],
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bir salamla başlasın',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff85552b),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Yeni dostlar, səmimi söhbətlər',
                                      style: TextStyle(
                                        color: Color(0xff9d744e),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.waving_hand_rounded,
                                size: 44,
                                color: Color(0xffefb840),
                              ),
                            ],
                          ),
                        ),
                        if (users.isEmpty)
                          const EmptySocial(
                            'Hələ heç kim görünmür',
                            'Dostunu dəvət et və ya axtarış filtrini dəyiş.',
                          ),
                      ],
                    );
                  }
                  final doc = users[index - 1];
                  final d = doc.data();
                  final name = '${d['name'] ?? 'İstifadəçi'}';
                  return SoftCard(
                    padding: const EdgeInsets.all(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonPage(
                            currentProfile: widget.profile,
                            targetUid: doc.id,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SocialAvatar(
                            name: name,
                            online: isReallyOnline(d),
                            symbol: '${d['avatarEmoji'] ?? ''}',
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffffe7f3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${d['age'] ?? ''} · ${d['city'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xffd770a9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${d['about'] ?? ''}'.isEmpty
                                      ? 'Tanış olmağa hazıram ✨'
                                      : '${d['about']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: mutedInk,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xffffeaf5),
                              foregroundColor: const Color(0xffe96cb2),
                              minimumSize: const Size(60, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                              ),
                            ),
                            onPressed: () =>
                                openChat(context, widget.profile, doc.id, name),
                            child: const Text(
                              '♥ Salam',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
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

void openChat(
  BuildContext context,
  UserProfile profile,
  String uid,
  String name,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RealChatPage(
        currentProfile: profile,
        targetUid: uid,
        targetName: name,
      ),
    ),
  );
}

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
  int filter = 0;
  String query = '';
  bool searching = false;
  Timer? timer;
  late final users = (widget.database ?? FirebaseFirestore.instance)
      .collection('users')
      .snapshots();
  late final chats = (widget.database ?? FirebaseFirestore.instance)
      .collection('chats')
      .where('members', arrayContains: widget.profile.uid)
      .snapshots();
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SocialSurface(
    color: const Color(0xffffe6d3),
    child: Column(
      children: [
        PageHeading(
          'Mesajlar',
          subtitle: 'Yaxşı söhbət həmişə yaxındadır',
          action: IconButton(
            tooltip: 'Mesaj axtar',
            onPressed: () => setState(() => searching = !searching),
            icon: const Icon(Icons.search_rounded, size: 29),
          ),
        ),
        if (searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: TextField(
              onChanged: (v) => setState(() => query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Ad və ya mesaj axtar',
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (final (i, label) in ['Hamısı', 'Aktiv', 'Oxunmamış'].indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: filter == i,
                    onSelected: (_) => setState(() => filter = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: users,
            builder: (context, people) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: chats,
                  builder: (context, snapshot) {
                    if (snapshot.hasError || people.hasError) {
                      return const EmptySocial(
                        'Mesajlar yüklənmədi',
                        'İnternet bağlantını yoxla.',
                      );
                    }
                    if (!snapshot.hasData || !people.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final profiles = {
                      for (final d in people.data!.docs) d.id: d.data(),
                    };
                    final list = snapshot.data!.docs.toList()
                      ..sort(
                        (a, b) =>
                            ((b.data()['updatedAt'] as Timestamp?)?.seconds ??
                                    0)
                                .compareTo(
                                  (a.data()['updatedAt'] as Timestamp?)
                                          ?.seconds ??
                                      0,
                                ),
                      );
                    final visible = list.where((doc) {
                      final d = doc.data();
                      final peer = (List<String>.from(
                        d['members'] ?? [],
                      )..remove(widget.profile.uid)).firstOrNull;
                      final p = profiles[peer] ?? {};
                      final unread = isUnread(d, widget.profile.uid);
                      return (filter != 1 || isReallyOnline(p)) &&
                          (filter != 2 || unread) &&
                          '${p['name']} ${d['lastMessage']}'
                              .toLowerCase()
                              .contains(query);
                    }).toList();
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        _shortcut(
                          'Söhbət otaqları',
                          'Mövzunu seç, söhbətə qoşul',
                          Icons.meeting_room_outlined,
                          const Color(0xff55cf89),
                          () => widget.navigate(2),
                        ),
                        _shortcut(
                          'Anlar',
                          'Dostların nə paylaşır?',
                          Icons.auto_awesome_outlined,
                          const Color(0xffbd85f4),
                          () => widget.navigate(1),
                        ),
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          const EmptySocial(
                            'Söhbətlər burada başlayır',
                            'Ana səhifədə birinə salam ver. Mesajların burada görünəcək.',
                          ),
                        for (final doc in visible)
                          Builder(
                            builder: (context) {
                              final d = doc.data();
                              final peers = List<String>.from(
                                d['members'] ?? [],
                              )..remove(widget.profile.uid);
                              if (peers.isEmpty) return const SizedBox.shrink();
                              final uid = peers.first;
                              final p = profiles[uid] ?? {};
                              final name = '${p['name'] ?? 'İstifadəçi'}';
                              final at = (d['updatedAt'] as Timestamp?)
                                  ?.toDate();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: SocialAvatar(
                                    name: name,
                                    size: 58,
                                    online: isReallyOnline(p),
                                    symbol: '${p['avatarEmoji'] ?? ''}',
                                  ),
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${d['lastMessage'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: mutedInk),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        at == null
                                            ? ''
                                            : '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: mutedInk,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      if (isUnread(d, widget.profile.uid))
                                        const Badge(
                                          backgroundColor: Color(0xffff7865),
                                        ),
                                    ],
                                  ),
                                  onTap: () => openChat(
                                    context,
                                    widget.profile,
                                    uid,
                                    name,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
          ),
        ),
      ],
    ),
  );
  Widget _shortcut(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback tap,
  ) => ListTile(
    onTap: tap,
    contentPadding: const EdgeInsets.symmetric(vertical: 5),
    leading: CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 29),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: mutedInk, fontSize: 13),
    ),
  );
}

bool isUnread(Map<String, dynamic> data, String uid) {
  if (data['lastSenderId'] == null || data['lastSenderId'] == uid) return false;
  final updated = data['updatedAt'];
  final read = (data['readAt'] as Map?)?[uid];
  return updated is Timestamp &&
      (read is! Timestamp || updated.compareTo(read) > 0);
}

class SocialProfile extends StatelessWidget {
  const SocialProfile({
    super.key,
    this.database,
    required this.profile,
    required this.navigate,
  });
  final FirebaseFirestore? database;
  final UserProfile profile;
  final ValueChanged<int> navigate;
  @override
  Widget build(BuildContext context) => SocialSurface(
    color: const Color(0xfffff2c7),
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mən',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Ayarlar',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SocialSettings(profile: profile),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: 25),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (database ?? FirebaseFirestore.instance)
              .collection('users')
              .doc(profile.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final d = snapshot.data?.data() ?? {};
            final name = '${d['name'] ?? profile.name}';
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditSocialProfile(profile: profile, data: d),
                ),
              ),
              child: Row(
                children: [
                  SocialAvatar(
                    name: name,
                    size: 88,
                    symbol: '${d['avatarEmoji'] ?? ''}',
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Profili görüntülə və düzəlt',
                          style: TextStyle(color: mutedInk, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: mutedInk),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Öz rəngini seç',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Profilin də sənin kimi özəl olsun',
                style: TextStyle(color: mutedInk, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _decorTile(
                      context,
                      'Profil dekoru',
                      'Səni ifadə et',
                      Icons.auto_awesome,
                      const Color(0xffffe6a5),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditSocialProfile(
                            profile: profile,
                            data: const {},
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _decorTile(
                      context,
                      'Görünüş',
                      'Rəngini dəyiş',
                      Icons.palette_outlined,
                      const Color(0xffe8dcff),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocialSettings(profile: profile),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tez keçidlər',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 23),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quick(
                    'Mesajlar',
                    Icons.chat_bubble_outline,
                    const Color(0xffddeaff),
                    () => navigate(3),
                  ),
                  _quick(
                    'Anlar',
                    Icons.auto_awesome_outlined,
                    const Color(0xffffe0ed),
                    () => navigate(1),
                  ),
                  _quick(
                    'Otaqlar',
                    Icons.meeting_room_outlined,
                    const Color(0xffddf9df),
                    () => navigate(2),
                  ),
                  _quick(
                    'Ayarlar',
                    Icons.tune,
                    const Color(0xffefdefc),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SocialSettings(profile: profile),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Haqqımda'),
                subtitle: Text(
                  profile.about.isEmpty
                      ? 'Özün haqqında bir az danış'
                      : profile.about,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditSocialProfile(profile: profile, data: const {}),
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16, height: 1),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(profile.city),
                subtitle: const Text('Şəhər'),
              ),
            ],
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'VIBE · Bir salamla başlasın',
              style: TextStyle(color: mutedInk, fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _quick(String title, IconData icon, Color color, VoidCallback tap) =>
      InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: ink),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
  Widget _decorTile(
    BuildContext context,
    String title,
    String sub,
    IconData icon,
    Color color,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: .45)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: ink),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 12, color: mutedInk)),
        ],
      ),
    ),
  );
}

class EditSocialProfile extends StatefulWidget {
  const EditSocialProfile({
    super.key,
    required this.profile,
    required this.data,
  });
  final UserProfile profile;
  final Map<String, dynamic> data;
  @override
  State<EditSocialProfile> createState() => _EditSocialProfileState();
}

class _EditSocialProfileState extends State<EditSocialProfile> {
  late final name = TextEditingController(text: widget.profile.name);
  late final city = TextEditingController(text: widget.profile.city);
  late final about = TextEditingController(text: widget.profile.about);
  String symbol = '';
  bool saving = false, loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d =
          (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.profile.uid)
                  .get())
              .data() ??
          widget.data;
      if (!mounted) return;
      name.text = '${d['name'] ?? widget.profile.name}';
      city.text = '${d['city'] ?? widget.profile.city}';
      about.text = '${d['about'] ?? widget.profile.about}';
      setState(() {
        symbol = '${d['avatarEmoji'] ?? ''}';
        loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loaded = true);
        notifySocial(context, 'Profil yüklənmədi. Bağlantını yoxla.');
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    about.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || city.text.trim().isEmpty) {
      notifySocial(context, 'Ad və şəhəri doldur.');
      return;
    }
    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .update({
            'name': name.text.trim(),
            'city': city.text.trim(),
            'about': about.text.trim(),
            'avatarEmoji': symbol,
          });
      if (mounted) {
        notifySocial(context, 'Profil yadda saxlandı');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) notifySocial(context, 'Profil saxlanmadı. Yenidən sına.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profili düzəlt')),
    body: !loaded
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Center(
                child: SocialAvatar(name: name.text, symbol: symbol, size: 100),
              ),
              const SizedBox(height: 24),
              const Text(
                'Profil dekoru',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in [
                    '',
                    '🌸',
                    '🦋',
                    '🌙',
                    '🧸',
                    '🎮',
                    '🌿',
                    '✨',
                  ])
                    ChoiceChip(
                      label: Text(emoji.isEmpty ? 'Baş hərf' : emoji),
                      selected: symbol == emoji,
                      onSelected: (_) => setState(() => symbol = emoji),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: city,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Şəhər'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: about,
                maxLength: 240,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Haqqımda'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saxlanır…' : 'Yadda saxla'),
              ),
            ],
          ),
  );
}

void notifySocial(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class SocialSettings extends StatefulWidget {
  const SocialSettings({super.key, required this.profile});
  final UserProfile profile;
  @override
  State<SocialSettings> createState() => _SocialSettingsState();
}

class _SocialSettingsState extends State<SocialSettings> {
  bool remember = true, busy = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => remember = LoginMemory(p).remember);
    });
  }

  Future<void> changeRemember(bool value) async {
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          value ? Persistence.LOCAL : Persistence.SESSION,
        );
      }
      await LoginMemory(
        await SharedPreferences.getInstance(),
      ).save(value, widget.profile.email);
      if (mounted) setState(() => remember = value);
    } catch (_) {
      if (mounted) {
        notifySocial(
          context,
          'Seçim saxlanmadı. Brauzerin yaddaş icazəsini yoxla.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabdan çıxılsın?'),
        content: const Text('Yenidən daxil olmaq üçün şifrən lazım olacaq.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıxış'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .update({'online': false, 'lastSeen': FieldValue.serverTimestamp()})
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        notifySocial(context, 'Çıxış alınmadı. Yenidən sına.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ayarlar')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Görünüş',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: appearance,
                builder: (context, selected, _) => Wrap(
                  spacing: 10,
                  children: [
                    for (var i = 0; i < accentColors.length; i++)
                      ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: accentColors[i],
                          radius: 8,
                        ),
                        label: Text(['Lavanda', 'Çəhrayı', 'Nanə'][i]),
                        selected: i == selected,
                        onSelected: (_) async {
                          appearance.value = i;
                          await (await SharedPreferences.getInstance()).setInt(
                            'appearance',
                            i,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SoftCard(
          padding: const EdgeInsets.all(6),
          child: SwitchListTile(
            title: const Text('Yadda saxla'),
            subtitle: const Text(
              'Brauzeri bağlayıb açanda hesabın açıq qalsın.',
            ),
            value: remember,
            onChanged: busy ? null : changeRemember,
          ),
        ),
        SoftCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Hesab'),
                subtitle: Text(widget.profile.email),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.language),
                title: Text('Dil'),
                subtitle: Text('Azərbaycan dili'),
              ),
            ],
          ),
        ),
        SoftCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zəng icazələri',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'Səsli zəng üçün mikrofon, video zəng üçün kamera icazəsi ver. İcazəni brauzerin ünvan sətrindəki sayt ayarlarından dəyişə bilərsən.',
                style: TextStyle(color: mutedInk, height: 1.5),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : logout,
          icon: const Icon(Icons.logout),
          label: const Text('Hesabdan çıxış'),
        ),
      ],
    ),
  );
}

class SocialFeed extends StatefulWidget {
  const SocialFeed({super.key, required this.profile, this.rooms = false});
  final UserProfile profile;
  final bool rooms;
  @override
  State<SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends State<SocialFeed> {
  late final collection = FirebaseFirestore.instance.collection(
    widget.rooms ? 'socialRooms' : 'moments',
  );
  late final stream = collection
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();
  Future<void> create() async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => ComposeSocial(room: widget.rooms),
    );
    if (text == null || !mounted) return;
    try {
      await collection.add({
        'owner': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) notifySocial(context, 'Paylaşım saxlanmadı. Yenidən sına.');
    }
  }

  @override
  Widget build(BuildContext context) => SocialSurface(
    color: widget.rooms ? const Color(0xffdef5e9) : const Color(0xfff0dfff),
    child: Column(
      children: [
        PageHeading(
          widget.rooms ? 'Otaqlar' : 'Anlar',
          subtitle: widget.rooms
              ? 'Bir mövzu, çox söhbət'
              : 'Günün kiçik, gözəl anları',
          action: IconButton.filled(
            tooltip: widget.rooms ? 'Otaq yarat' : 'An paylaş',
            onPressed: create,
            icon: const Icon(Icons.add),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptySocial(
                  'Yüklənmədi',
                  'Bağlantını yoxlayıb yenidən aç.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return ListView(
                  children: [
                    EmptySocial(
                      widget.rooms
                          ? 'İlk otağı sən yarat'
                          : 'İlk anı sən paylaş',
                      widget.rooms
                          ? 'Yuxarıdakı + ilə mövzu aç və dostlarınla yazış.'
                          : 'Yuxarıdakı + ilə günündən bir fikir paylaş.',
                      icon: widget.rooms
                          ? Icons.meeting_room_outlined
                          : Icons.auto_awesome_outlined,
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  for (final doc in snapshot.data!.docs)
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SocialAvatar(
                                name: '${doc.data()['name']}',
                                size: 44,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${doc.data()['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!widget.rooms &&
                                  doc.data()['owner'] == widget.profile.uid)
                                IconButton(
                                  tooltip: 'Paylaşımı sil',
                                  onPressed: () async {
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Paylaşım silinsin?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Ləğv et'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Sil'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (yes == true) {
                                      try {
                                        await doc.reference.delete();
                                      } catch (_) {
                                        if (context.mounted) {
                                          notifySocial(
                                            context,
                                            'Silinmədi. Yenidən sına.',
                                          );
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${doc.data()['text']}',
                            style: const TextStyle(fontSize: 17, height: 1.5),
                          ),
                          if (widget.rooms) ...[
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SocialRoomChat(
                                    profile: widget.profile,
                                    room: doc.reference,
                                    title: '${doc.data()['text']}',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Söhbətə qoşul'),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ComposeSocial extends StatefulWidget {
  const ComposeSocial({super.key, required this.room});
  final bool room;
  @override
  State<ComposeSocial> createState() => _ComposeSocialState();
}

class _ComposeSocialState extends State<ComposeSocial> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.room ? 'Otaq yarat' : 'Bir an paylaş'),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: widget.room ? 80 : 500,
      maxLines: widget.room ? 2 : 5,
      decoration: InputDecoration(
        hintText: widget.room ? 'Nədən danışaq?' : 'Bu gün nə düşünürsən?',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Ləğv et'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isNotEmpty) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const Text('Paylaş'),
      ),
    ],
  );
}

class SocialRoomChat extends StatefulWidget {
  const SocialRoomChat({
    super.key,
    required this.profile,
    required this.room,
    required this.title,
  });
  final UserProfile profile;
  final DocumentReference<Map<String, dynamic>> room;
  final String title;
  @override
  State<SocialRoomChat> createState() => _SocialRoomChatState();
}

class _SocialRoomChatState extends State<SocialRoomChat> {
  final controller = TextEditingController();
  bool sending = false;
  late final stream = widget.room
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.room.collection('messages').add({
        'senderId': widget.profile.uid,
        'name': widget.profile.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (controller.text.trim() == text) controller.clear();
    } catch (_) {
      if (mounted) notifySocial(context, 'Mesaj göndərilmədi. Yenidən sına.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, s) {
              if (s.hasError) {
                return const EmptySocial(
                  'Mesajlar yüklənmədi',
                  'Bağlantını yoxla.',
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.data!.docs.isEmpty) {
                return const EmptySocial(
                  'Söhbəti sən başlat',
                  'Otaqdakı hər kəs mesajını görə bilər.',
                );
              }
              return ListView(
                reverse: true,
                padding: const EdgeInsets.all(18),
                children: [
                  for (final d in s.data!.docs)
                    Align(
                      alignment: d.data()['senderId'] == widget.profile.uid
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: d.data()['senderId'] == widget.profile.uid
                              ? const Color(0xffe9e0ff)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.data()['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('${d.data()['text']}'),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yaz…',
                      counterText: '',
                    ),
                    onSubmitted: (_) => send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
// ============================================================
// VIBE VIDEO / SƏNİN ÜÇÜN
// ============================================================

class VibeVideoFeed extends StatefulWidget {
  const VibeVideoFeed({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<VibeVideoFeed> createState() => _VibeVideoFeedState();
}

class _VibeVideoFeedState extends State<VibeVideoFeed> {
  final PageController pageController = PageController();
  int activeIndex = 0;
  bool followingTab = false;
  Set<String> followingCreators = <String>{};

  final List<Map<String, dynamic>> videos = const [
    {
      'id': 'vibe_welcome',
      'name': 'VIBE',
      'text': 'VIBE Video-ya xoş gəldin 🔥',
      'likes': 128,
      'comments': 24,
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    },
    {
      'id': 'ehmed_video_1',
      'name': 'Əhməd',
      'text': 'Yuxarı sürüşdür və növbəti videoya keç 🎬',
      'likes': 86,
      'comments': 12,
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  Future<void> _loadFollowing() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).get();
      final data = snap.data();
      final list = (data?['followingVideoCreators'] as List?) ?? const [];
      if (mounted) {
        setState(() => followingCreators = list.map((e) => '$e').toSet());
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow(String creator) async {
    final willFollow = !followingCreators.contains(creator);
    setState(() {
      if (willFollow) {
        followingCreators.add(creator);
      } else {
        followingCreators.remove(creator);
      }
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).set({
        'followingVideoCreators': willFollow
            ? FieldValue.arrayUnion([creator])
            : FieldValue.arrayRemove([creator]),
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İzləmə yadda saxlanmadı. İnterneti yoxla.')),
      );
    }
  }

  List<Map<String, dynamic>> get visibleVideos {
    if (!followingTab) return videos;
    return videos.where((v) => followingCreators.contains('${v['name']}')).toList();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void showComingSoon(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$text növbəti mərhələdə işlək olacaq.')),
    );
  }

  void _selectTab(bool following) {
    setState(() {
      followingTab = following;
      activeIndex = 0;
    });
    if (pageController.hasClients) pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final feed = visibleVideos;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (feed.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, color: Colors.white70, size: 58),
                    const SizedBox(height: 16),
                    const Text('Hələ heç kimi izləmirsən', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('“Sənin üçün” bölməsindən bir profilin + düyməsinə bas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 14)),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: () => _selectTab(false), child: const Text('Sənin üçün')),
                  ],
                ),
              ),
            )
          else
            PageView.builder(
              key: ValueKey(followingTab),
              controller: pageController,
              scrollDirection: Axis.vertical,
              itemCount: feed.length,
              onPageChanged: (index) => setState(() => activeIndex = index),
              itemBuilder: (context, index) {
                final video = feed[index];
                final name = '${video['name']}';
                return _VibeVideoCard(
                  key: ValueKey('${video['id']}_${followingTab}_$index'),
                  profile: widget.profile,
                  videoId: '${video['id']}',
                  name: name,
                  text: '${video['text']}',
                  likes: video['likes'] as int,
                  comments: video['comments'] as int,
                  videoUrl: '${video['url']}',
                  active: index == activeIndex,
                  followed: followingCreators.contains(name),
                  onFollow: () => _toggleFollow(name),
                  onComment: () => showComingSoon('Şərh'),
                  onProfile: () => showComingSoon('Profil'),
                );
              },
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                child: Row(
                  children: [
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _selectTab(true),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('İzlənilən', style: TextStyle(color: followingTab ? Colors.white : Colors.white60, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          SizedBox(width: 34, height: 2, child: ColoredBox(color: followingTab ? Colors.white : Colors.transparent)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 22),
                    GestureDetector(
                      onTap: () => _selectTab(false),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Sənin üçün', style: TextStyle(color: !followingTab ? Colors.white : Colors.white60, fontSize: 17, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          SizedBox(width: 34, height: 2, child: ColoredBox(color: !followingTab ? Colors.white : Colors.transparent)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Video əlavə et',
                      onPressed: () => showComingSoon('Video yükləmə'),
                      icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 29),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeVideoCard extends StatefulWidget {
  const _VibeVideoCard({
    super.key,
    required this.profile,
    required this.videoId,
    required this.name,
    required this.text,
    required this.likes,
    required this.comments,
    required this.videoUrl,
    required this.active,
    required this.followed,
    required this.onFollow,
    required this.onComment,
    required this.onProfile,
  });

  final UserProfile profile;
  final String videoId;
  final String name;
  final String text;
  final int likes;
  final int comments;
  final String videoUrl;
  final bool active;
  final bool followed;
  final VoidCallback onFollow;
  final VoidCallback onComment;
  final VoidCallback onProfile;

  @override
  State<_VibeVideoCard> createState() => _VibeVideoCardState();
}

class _VibeVideoCardState extends State<_VibeVideoCard> {
  late final VideoPlayerController controller;
  bool liked = false;
  bool saved = false;
  bool showPlay = false;
  bool failed = false;
  bool muted = false;
  bool stateLoaded = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _loadState();
    _prepare();
  }

  Future<void> _loadState() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).get();
      final data = snap.data();
      final likedIds = ((data?['likedVideoIds'] as List?) ?? const []).map((e) => '$e').toSet();
      final savedIds = ((data?['savedVideoIds'] as List?) ?? const []).map((e) => '$e').toSet();
      if (mounted) {
        setState(() {
          liked = likedIds.contains(widget.videoId);
          saved = savedIds.contains(widget.videoId);
          stateLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => stateLoaded = true);
    }
  }

  Future<void> _prepare() async {
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (widget.active) {
        try {
          await controller.play();
        } catch (_) {
          muted = true;
          await controller.setVolume(0);
          await controller.play();
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _VibeVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!controller.value.isInitialized) return;
    if (widget.active && !oldWidget.active) {
      controller.play();
    } else if (!widget.active && oldWidget.active) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (!controller.value.isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        showPlay = true;
      } else {
        controller.play();
        showPlay = false;
      }
    });
  }

  Future<void> _toggleSound() async {
    if (!controller.value.isInitialized) return;
    muted = !muted;
    await controller.setVolume(muted ? 0 : 1);
    if (!controller.value.isPlaying) await controller.play();
    if (mounted) setState(() => showPlay = false);
  }

  Future<void> _toggleLike() async {
    final newValue = !liked;
    setState(() => liked = newValue);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).set({
        'likedVideoIds': newValue
            ? FieldValue.arrayUnion([widget.videoId])
            : FieldValue.arrayRemove([widget.videoId]),
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted) setState(() => liked = !newValue);
    }
  }

  Future<void> _toggleSave() async {
    final newValue = !saved;
    setState(() => saved = newValue);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).set({
        'savedVideoIds': newValue
            ? FieldValue.arrayUnion([widget.videoId])
            : FieldValue.arrayRemove([widget.videoId]),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newValue ? 'Video “Yadda saxlanılanlar” bazasına əlavə edildi' : 'Video yadda saxlanılanlardan çıxarıldı')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => saved = !newValue);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yadda saxlamaq alınmadı')));
      }
    }
  }

  void _showShareSheet() {
    final link = 'https://vibe-f9d13.web.app/video/${widget.videoId}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        Widget shareItem(IconData icon, String label, VoidCallback onTap) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 82,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 27, backgroundColor: const Color(0xfff2f2f4), child: Icon(icon, color: const Color(0xff302e38))),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        void copyAndClose(String message) {
          Clipboard.setData(ClipboardData(text: link));
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paylaş', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      shareItem(Icons.link_rounded, 'Linki kopyala', () => copyAndClose('Video linki kopyalandı')),
                      const SizedBox(width: 10),
                      shareItem(Icons.chat_bubble_rounded, 'Mesajla göndər', () => copyAndClose('Link kopyalandı — Mesajlar bölməsində göndərə bilərsən')),
                      const SizedBox(width: 10),
                      shareItem(Icons.send_rounded, 'Dostuna göndər', () => copyAndClose('Paylaşım linki kopyalandı')),
                      const SizedBox(width: 10),
                      shareItem(Icons.more_horiz_rounded, 'Daha çox', () => copyAndClose('Video linki kopyalandı')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLikes = widget.likes + (liked ? 1 : 0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: togglePlay,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              Center(
                child: failed
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.white70, size: 55),
                          SizedBox(height: 12),
                          Text('Video açıla bilmədi', style: TextStyle(color: Colors.white70)),
                        ],
                      )
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            if (showPlay)
              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 76)),
            Positioned(
              top: 72,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: IconButton.filledTonal(
                  tooltip: muted ? 'Səsi aç' : 'Səsi bağla',
                  onPressed: _toggleSound,
                  icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 90,
              bottom: 30,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onProfile,
                      child: Text('@${widget.name}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 10),
                    Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 13),
                    const Row(
                      children: [
                        Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Expanded(child: Text('VIBE original səs', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 28,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: widget.onFollow,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xff6d28d9),
                              child: Text(widget.name.isEmpty ? '?' : widget.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                            ),
                          ),
                          Positioned(
                            bottom: -7,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: widget.followed ? const Color(0xff22c55e) : const Color(0xffef4444),
                              child: Icon(widget.followed ? Icons.check : Icons.add, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _VideoAction(
                      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      text: '$currentLikes',
                      active: liked,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 22),
                    _VideoAction(icon: Icons.mode_comment_outlined, text: '${widget.comments}', onTap: widget.onComment),
                    const SizedBox(height: 22),
                    _VideoAction(
                      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      text: saved ? 'Saxlanıb' : 'Yadda saxla',
                      active: saved,
                      onTap: _toggleSave,
                    ),
                    const SizedBox(height: 22),
                    _VideoAction(icon: Icons.reply_rounded, text: 'Paylaş', onTap: _showShareSheet),
                    const SizedBox(height: 25),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade900, border: Border.all(color: Colors.white24, width: 2)),
                      child: const Icon(Icons.music_note_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({required this.icon, required this.text, required this.onTap, this.active = false});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Icon(icon, color: active ? const Color(0xffff375f) : Colors.white, size: 34),
            const SizedBox(height: 5),
            Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

