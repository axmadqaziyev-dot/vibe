import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'main.dart' show RealChatPage, PersonPage, isReallyOnline;
import 'user_profile.dart';
import 'preferences.dart';
import 'admin_panel.dart';
import 'party_rooms.dart';
import 'instant_match.dart';
import 'notifications_center.dart';
import 'game_center.dart';
import 'vibe_levels.dart';

const ink = Color(0xfff7f3ff);
const mutedInk = Color(0xffa89fbd);
const vibePink = Color(0xffff2bd6);
const vibePurple = Color(0xff8b5cff);
const vibeBlue = Color(0xff22a7ff);
const vibeBg = Color(0xff070510);
const vibePanel = Color(0xff121020);

class SocialSurface extends StatelessWidget {
  const SocialSurface({
    super.key,
    required this.child,
    this.color = const Color(0xff120b22),
  });
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff140827), Color(0xff090611), Color(0xff05040b)],
      ),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: SafeArea(bottom: false, child: child),
    ),
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
      color: vibePanel.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xff2d2540)),
      boxShadow: const [
        BoxShadow(color: Color(0x331c0b34), blurRadius: 24, offset: Offset(0, 10)),
      ],
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
    this.imageUrl = '',
  });
  final String name, symbol, imageUrl;
  final double size;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffff3bd4), Color(0xff814dff), Color(0xff1d9fff)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .8), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x66ff2bd6), blurRadius: 16)],
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(color: Color(0xff171323), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: imageUrl.trim().isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        symbol.isNotEmpty
                            ? symbol
                            : (name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase()),
                        style: TextStyle(fontSize: size * .36, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  )
                : Text(
                    symbol.isNotEmpty
                        ? symbol
                        : (name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase()),
                    style: TextStyle(
                      fontSize: size * .36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xff2de28a),
                shape: BoxShape.circle,
                border: Border.all(color: vibeBg, width: 3),
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
    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xffff4bdb), Color(0xff9b62ff), Color(0xff32a8ff)],
                ).createShader(r),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                    color: Colors.white,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(subtitle!, style: const TextStyle(color: mutedInk, fontSize: 13)),
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
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xff8b5cff), Color(0xffff2bd6)]),
            boxShadow: const [BoxShadow(color: Color(0x55ff2bd6), blurRadius: 20)],
          ),
          child: Icon(icon, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: Colors.white)),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(color: mutedInk, height: 1.5)),
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
  int topTab = 0;
  int category = 0;
  bool searching = false;
  Timer? timer;
  final Set<String> favorites = <String>{};
  final Set<String> blockedIds = <String>{};

  late final stream = (widget.database ?? FirebaseFirestore.instance)
      .collection('users')
      .snapshots();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadBlocked();
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
        _topBar(),
        _tabs(),
        if (searching) _searchBox(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptySocial('İnsanlar yüklənmədi', 'Bağlantını yoxlayıb yenidən aç.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: vibePink));
              }

              final users = snapshot.data!.docs.where((doc) {
                final d = doc.data();
                if (doc.id == widget.profile.uid) return false;
                if (blockedIds.contains(doc.id)) return false;
                final q = '${d['name']} ${d['city']} ${d['about']}'.toLowerCase();
                if (!q.contains(query)) return false;
                if (topTab == 1 && widget.profile.city.trim().isNotEmpty) {
                  if ('${d['city'] ?? ''}'.trim().toLowerCase() != widget.profile.city.trim().toLowerCase()) return false;
                }
                if (topTab == 2 && !isReallyOnline(d)) return false;
                if (topTab == 3) {
                  final created = d['createdAt'];
                  if (created is! Timestamp) return false;
                  if (DateTime.now().difference(created.toDate()).inDays > 30) return false;
                }
                final gender = '${d['gender'] ?? d['sex'] ?? ''}'.toLowerCase();
                if (category == 1 && !(gender.contains('qız') || gender.contains('qadin') || gender.contains('female') || gender == 'f')) return false;
                if (category == 2 && !(gender.contains('oğlan') || gender.contains('kisi') || gender.contains('male') || gender == 'm')) return false;
                if (category == 3 && !isReallyOnline(d)) return false;
                if (category == 4 && !(d['vip'] == true || d['isVip'] == true || d['premium'] == true)) return false;
                return true;
              }).toList();

              users.sort((a, b) {
                final ao = isReallyOnline(a.data());
                final bo = isReallyOnline(b.data());
                if (ao != bo) return ao ? -1 : 1;
                return '${a.data()['name'] ?? ''}'.compareTo('${b.data()['name'] ?? ''}');
              });

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
                children: [
                  _hero(),
                  const SizedBox(height: 18),
                  _categories(),
                  const SizedBox(height: 22),
                  _sectionTitle('Sənin üçün ✨', '${users.length} profil'),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    const EmptySocial('Hələ heç kim görünmür', 'Axtarışı və ya filtri dəyiş, sonra yenidən bax.')
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final count = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 620 ? 3 : 2);
                        final ratio = c.maxWidth >= 620 ? .78 : .72;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: users.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: count,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: ratio,
                          ),
                          itemBuilder: (context, index) {
                            final doc = users[index];
                            return _profileCard(doc.id, doc.data());
                          },
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _loadBlocked() async {
    try {
      final snap = await (widget.database ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(widget.profile.uid)
          .collection('blocked')
          .get();
      if (!mounted) return;
      setState(() {
        blockedIds
          ..clear()
          ..addAll(snap.docs.map((e) => e.id));
      });
    } catch (_) {}
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('vibe_favorites_${widget.profile.uid}') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      favorites
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> _toggleFavorite(String uid) async {
    setState(() => favorites.contains(uid) ? favorites.remove(uid) : favorites.add(uid));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vibe_favorites_${widget.profile.uid}', favorites.toList());
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationCenterPage(profile: widget.profile),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
    child: Row(
      children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [vibeBlue, vibePurple, vibePink]).createShader(r),
          child: const Text('VIBE', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
        ),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xffffd458), Color(0xffff8a3d)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xff4c2600)),
            SizedBox(width: 3),
            Text('VIP', style: TextStyle(color: Color(0xff4c2600), fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Axtar',
          onPressed: () => setState(() => searching = !searching),
          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
        ),
        NotificationBadge(
          profile: widget.profile,
          onPressed: _openNotifications,
        ),
      ],
    ),
  );

  Widget _tabs() {
    const labels = ['Kəşf et', 'Şəhərim', 'Online', 'Yeni'];
    return SizedBox(
      height: 43,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => topTab = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(labels[i], style: TextStyle(color: topTab == i ? Colors.white : mutedInk, fontWeight: topTab == i ? FontWeight.w800 : FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 44,
                  decoration: BoxDecoration(
                    color: topTab == i ? vibePink : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: topTab == i ? const [BoxShadow(color: Color(0xaaff2bd6), blurRadius: 8)] : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBox() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
    child: TextField(
      autofocus: true,
      onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Ad, şəhər və ya maraq axtar',
        hintStyle: const TextStyle(color: mutedInk),
        prefixIcon: const Icon(Icons.search, color: vibePurple),
        filled: true,
        fillColor: vibePanel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _hero() => Container(
    height: 165,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff24104a), Color(0xff4b1764), Color(0xff9b1d86)],
      ),
      border: Border.all(color: const Color(0xff6f3e87)),
      boxShadow: const [BoxShadow(color: Color(0x44ff2bd6), blurRadius: 28, offset: Offset(0, 10))],
    ),
    child: Stack(
      children: [
        Positioned(right: -20, top: -28, child: Icon(Icons.favorite_rounded, color: Colors.white.withValues(alpha: .07), size: 180)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Real insanlar\nReal söhbətlər\nReal VIBE 💜', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.12, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [vibeBlue, vibePurple, vibePink]),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => topTab = 2),
                            child: const Text('Kəşf et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                          Container(width: 1, height: 22, color: Colors.white24),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InstantMatchPage(profile: widget.profile),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                            label: const Text('Instant Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.auto_awesome_rounded, color: Color(0xffffb8ef), size: 74),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _categories() {
    final items = <(String, IconData)>[
      ('Hamısı', Icons.grid_view_rounded),
      ('Qızlar', Icons.female_rounded),
      ('Oğlanlar', Icons.male_rounded),
      ('Online', Icons.circle),
      ('VIP', Icons.workspace_premium_rounded),
    ];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 15),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => setState(() => category = i),
          child: SizedBox(
            width: 64,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: category == i ? const LinearGradient(colors: [vibePurple, vibePink]) : null,
                    color: category == i ? null : const Color(0xff191426),
                    border: Border.all(color: category == i ? const Color(0xffff83e8) : const Color(0xff302742)),
                    boxShadow: category == i ? const [BoxShadow(color: Color(0x66ff2bd6), blurRadius: 14)] : null,
                  ),
                  child: Icon(items[i].$2, color: Colors.white, size: i == 3 ? 14 : 23),
                ),
                const SizedBox(height: 6),
                Text(items[i].$1, overflow: TextOverflow.ellipsis, style: TextStyle(color: category == i ? Colors.white : mutedInk, fontSize: 11, fontWeight: category == i ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String right) => Row(
    children: [
      Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
      Text(right, style: const TextStyle(color: vibePink, fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  );

  Widget _profileCard(String uid, Map<String, dynamic> d) {
    final name = '${d['name'] ?? 'İstifadəçi'}';
    final city = '${d['city'] ?? ''}';
    final age = '${d['age'] ?? ''}';
    final online = isReallyOnline(d);
    final symbol = '${d['avatarEmoji'] ?? ''}';
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PersonPage(currentProfile: widget.profile, targetUid: uid)),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: vibePanel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: online ? const Color(0xff6a4b88) : const Color(0xff2d2638)),
          boxShadow: online ? const [BoxShadow(color: Color(0x332de28a), blurRadius: 14)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SocialAvatar(name: name, symbol: symbol, imageUrl: '${d['photoUrl'] ?? ''}', online: online, size: 76),
                Positioned(
                  right: -15,
                  top: -12,
                  child: IconButton.filledTonal(
                    tooltip: favorites.contains(uid) ? 'Favoridən çıxar' : 'Favoriyə əlavə et',
                    onPressed: () => _toggleFavorite(uid),
                    icon: Icon(favorites.contains(uid) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: favorites.contains(uid) ? vibePink : Colors.white70, size: 19),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text([age, city].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: mutedInk, fontSize: 11)),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xff6d50ff), Color(0xffff2bd6)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextButton(
                  onPressed: () => openChat(context, widget.profile, uid, name),
                  child: const Text('Salam 💜', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final Set<String> blockedIds = <String>{};
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
    _loadBlocked();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBlocked() async {
    try {
      final snap = await (widget.database ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(widget.profile.uid)
          .collection('blocked')
          .get();
      if (!mounted) return;
      setState(() {
        blockedIds
          ..clear()
          ..addAll(snap.docs.map((e) => e.id));
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => SocialSurface(
    color: const Color(0xff150a26),
    child: Column(
      children: [
        PageHeading(
          'Mesajlar',
          subtitle: 'Online dostlar, yeni mesajlar və real söhbətlər',
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
                      if (peer != null && blockedIds.contains(peer)) return false;
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
                          () => widget.navigate(3),
                        ),
                        _shortcut(
                          'Anlar',
                          'Dostların nə paylaşır?',
                          Icons.auto_awesome_outlined,
                          const Color(0xffbd85f4),
                          () => widget.navigate(2),
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
                                    imageUrl: '${p['photoUrl'] ?? ''}',
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


class VibeWalletCard extends StatelessWidget {
  const VibeWalletCard({super.key, required this.profile});
  final UserProfile profile;

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _dailyGift(BuildContext context) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(profile.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final today = _todayKey();
        if ('${data['lastDailyGift'] ?? ''}' == today) {
          throw StateError('already');
        }
        tx.set(ref, {
          'coins': FieldValue.increment(25),
          'lastDailyGift': today,
        }, SetOptions(merge: true));
      });
      if (context.mounted) notifySocial(context, '+25 VIBE Coin hesabına əlavə olundu ✨');
    } on StateError {
      if (context.mounted) notifySocial(context, 'Bugünkü hədiyyəni artıq götürmüsən.');
    } catch (_) {
      if (context.mounted) notifySocial(context, 'Coin hədiyyəsi alınmadı. Yenidən sına.');
    }
  }

  Future<void> _buyVip(BuildContext context, int coins) async {
    if (coins < 200) {
      notifySocial(context, 'VIP üçün 200 coin lazımdır.');
      return;
    }
    final ref = FirebaseFirestore.instance.collection('users').doc(profile.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final current = (data['coins'] as num?)?.toInt() ?? 0;
        if (current < 200) throw StateError('coins');
        final now = DateTime.now();
        final existing = data['vipUntil'];
        final base = existing is Timestamp && existing.toDate().isAfter(now)
            ? existing.toDate()
            : now;
        tx.set(ref, {
          'coins': current - 200,
          'vip': true,
          'vipUntil': Timestamp.fromDate(base.add(const Duration(days: 30))),
        }, SetOptions(merge: true));
      });
      if (context.mounted) notifySocial(context, 'VIP 30 gün aktiv edildi 👑');
    } on StateError {
      if (context.mounted) notifySocial(context, 'Coin balansı kifayət deyil.');
    } catch (_) {
      if (context.mounted) notifySocial(context, 'VIP aktiv edilmədi. Yenidən sına.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(profile.uid).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final coins = (d['coins'] as num?)?.toInt() ?? 0;
        final vipUntil = d['vipUntil'];
        final vipActive = d['vip'] == true &&
            vipUntil is Timestamp &&
            vipUntil.toDate().isAfter(DateTime.now());

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff21103a), Color(0xff151020), Color(0xff30112c)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xff4b2b66)),
            boxShadow: const [BoxShadow(color: Color(0x332f0b54), blurRadius: 24)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [vibePurple, vibePink]),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('VIBE Wallet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          if (vipActive) ...[
                            const SizedBox(width: 7),
                            const Text('VIP', style: TextStyle(color: Color(0xffffd76b), fontWeight: FontWeight.w900)),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text('$coins coin', style: const TextStyle(color: Color(0xffc9bdd9), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.diamond_rounded, color: Color(0xffffd76b)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _dailyGift(context),
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label: const Text('Gündəlik +25'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff6f4cff),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: vipActive ? null : () => _buyVip(context, coins),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(vipActive ? 'VIP aktivdir' : 'VIP · 200'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffffd76b),
                        side: const BorderSide(color: Color(0xff6b4c72)),
                        minimumSize: const Size(0, 46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileGalleryCard extends StatefulWidget {
  const ProfileGalleryCard({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<ProfileGalleryCard> createState() => _ProfileGalleryCardState();
}

class _ProfileGalleryCardState extends State<ProfileGalleryCard> {
  bool uploading = false;

  Future<void> _addPhoto() async {
    if (uploading) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_media/${widget.profile.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).set({
        'gallery': FieldValue.arrayUnion([url]),
      }, SetOptions(merge: true));
      if (mounted) notifySocial(context, 'Şəkil qalereyaya əlavə olundu.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Şəkil yüklənmədi. Storage qaydalarını yoxla.');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _setProfilePhoto(String url) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).set({
        'photoUrl': url,
      }, SetOptions(merge: true));
      if (mounted) notifySocial(context, 'Profil şəkli dəyişdirildi.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Profil şəkli dəyişmədi.');
    }
  }

  Future<void> _removePhoto(String url) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).set({
        'gallery': FieldValue.arrayRemove([url]),
      }, SetOptions(merge: true));
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
      if (mounted) notifySocial(context, 'Şəkil silindi.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Şəkil silinmədi.');
    }
  }

  void _photoMenu(String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_rounded, color: vibePink),
              title: const Text('Profil şəkli et', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                _setProfilePhoto(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xffff6b7d)),
              title: const Text('Şəkli sil', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheet);
                _removePhoto(url);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.profile.uid).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final gallery = ((d['gallery'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff121020),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xff332444)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto qalereya', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Şəkilə basıb profil şəkli edə bilərsən', style: TextStyle(color: mutedInk, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: uploading ? null : _addPhoto,
                    style: IconButton.styleFrom(backgroundColor: const Color(0xff2b1740)),
                    icon: uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_a_photo_rounded),
                  ),
                ],
              ),
              if (gallery.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xff0d0a15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xff2c2039)),
                  ),
                  child: const Text('Hələ şəkil əlavə edilməyib', style: TextStyle(color: mutedInk)),
                ),
              ] else ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _photoMenu(gallery[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          gallery[i],
                          width: 92,
                          height: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 92,
                            color: const Color(0xff21162f),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined, color: mutedInk),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
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
    color: const Color(0xff170923),
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
                  Container(
                    padding: EdgeInsets.all(d['vip'] == true ? 3 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: d['vip'] == true
                          ? const LinearGradient(
                              colors: [
                                Color(0xffffd86b),
                                Color(0xffff2bd6),
                                Color(0xff8b5cff),
                              ],
                            )
                          : null,
                      boxShadow: d['vip'] == true
                          ? const [
                              BoxShadow(
                                color: Color(0x55ffd86b),
                                blurRadius: 22,
                              ),
                            ]
                          : null,
                    ),
                    child: SocialAvatar(
                      name: name,
                      size: 88,
                      symbol: '${d['avatarEmoji'] ?? ''}',
                      imageUrl: '${d['photoUrl'] ?? ''}',
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (d['vip'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.workspace_premium_rounded,
                                color: Color(0xffffd86b),
                                size: 22,
                              ),
                            ],
                          ],
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: (database ?? FirebaseFirestore.instance)
                    .collection('users')
                    .doc(profile.uid)
                    .collection('followers')
                    .snapshots(),
                builder: (_, snap) => _ProfileStatCard(
                  label: 'İzləyici',
                  value: '${snap.data?.docs.length ?? 0}',
                  icon: Icons.people_alt_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: (database ?? FirebaseFirestore.instance)
                    .collection('users')
                    .doc(profile.uid)
                    .collection('following')
                    .snapshots(),
                builder: (_, snap) => _ProfileStatCard(
                  label: 'İzlənilən',
                  value: '${snap.data?.docs.length ?? 0}',
                  icon: Icons.person_add_alt_1_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: (database ?? FirebaseFirestore.instance)
                    .collection('users')
                    .doc(profile.uid)
                    .snapshots(),
                builder: (_, snap) {
                  final data = snap.data?.data() ?? const <String, dynamic>{};
                  final gallery = (data['gallery'] as List?) ?? const [];
                  return _ProfileStatCard(
                    label: 'Media',
                    value: '${gallery.length}',
                    icon: Icons.photo_library_rounded,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: (database ?? FirebaseFirestore.instance).collection('users').doc(profile.uid).snapshots(),
          builder: (context, adminSnap) {
            final d = adminSnap.data?.data() ?? const <String, dynamic>{};
            if (d['isAdmin'] != true && d['role'] != 'admin') return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xff26163f), Color(0xff42152f)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xff704a8f)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xff8b5cff),
                    child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  ),
                  title: const Text('Admin panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  subtitle: const Text('Şikayətləri yoxla və idarə et', style: TextStyle(color: mutedInk)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VibeAdminPanel())),
                ),
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: _ProfileShortcut(
                icon: Icons.sports_esports_rounded,
                title: 'Oyunlar',
                colors: const [Color(0xff8b5cff), Color(0xffff2bd6)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeGameCenterPage(profile: profile),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileShortcut(
                icon: Icons.military_tech_rounded,
                title: 'Level',
                colors: const [Color(0xffffb347), Color(0xffffd86b)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeLevelsPage(profile: profile),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        VibeWalletCard(profile: profile),
        const SizedBox(height: 14),
        ProfileGalleryCard(profile: profile),
        const SizedBox(height: 20),
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
                      const Color(0xff3a2a12),
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
                      const Color(0xff25193f),
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
                    const Color(0xff132a46),
                    () => navigate(4),
                  ),
                  _quick(
                    'Anlar',
                    Icons.auto_awesome_outlined,
                    const Color(0xff3a1730),
                    () => navigate(2),
                  ),
                  _quick(
                    'Otaqlar',
                    Icons.meeting_room_outlined,
                    const Color(0xff153421),
                    () => navigate(3),
                  ),
                  _quick(
                    'Ayarlar',
                    Icons.tune,
                    const Color(0xff2b1839),
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



class _ProfileShortcut extends StatelessWidget {
  const _ProfileShortcut({
    required this.icon,
    required this.title,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x3320002e), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xff151020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff342743)),
      ),
      child: Column(
        children: [
          Icon(icon, color: vibePurple, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedInk, fontSize: 10),
          ),
        ],
      ),
    );
  }
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

  Future<void> _toggleMomentLike(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) async {
    final likes = (data['likes'] as List?)?.map((e) => '$e').toSet() ?? <String>{};
    final liked = likes.contains(widget.profile.uid);
    try {
      await ref.set({
        'likes': liked ? FieldValue.arrayRemove([widget.profile.uid]) : FieldValue.arrayUnion([widget.profile.uid]),
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted) notifySocial(context, 'Like saxlanmadı. Yenidən sına.');
    }
  }

  Future<void> _shareMoment(String text) async {
    await Clipboard.setData(ClipboardData(text: 'VIBE · $text'));
    if (mounted) notifySocial(context, 'Paylaşım mətni kopyalandı.');
  }

  void _openMomentComments(DocumentReference<Map<String, dynamic>> ref) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff120d1d),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.viewInsetsOf(sheetContext).bottom + 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: Column(
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 14),
              const Text('Şərhlər', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ref.collection('comments').orderBy('createdAt', descending: true).limit(100).snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: vibePink));
                    if (snap.data!.docs.isEmpty) return const Center(child: Text('İlk şərhi sən yaz 💜', style: TextStyle(color: mutedInk)));
                    return ListView.builder(
                      reverse: true,
                      itemCount: snap.data!.docs.length,
                      itemBuilder: (_, i) {
                        final d = snap.data!.docs[i].data();
                        return ListTile(
                          leading: SocialAvatar(name: '${d['name'] ?? 'V'}', imageUrl: '${d['photoUrl'] ?? ''}', size: 38),
                          title: Text('${d['name'] ?? 'VIBE'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          subtitle: Text('${d['text'] ?? ''}', style: const TextStyle(color: Color(0xffd8d0e7))),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Şərh yaz...'))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      try {
                        await ref.collection('comments').add({
                          'uid': widget.profile.uid,
                          'name': widget.profile.name,
                          'text': text,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        controller.clear();
                      } catch (_) {
                        if (sheetContext.mounted) notifySocial(sheetContext, 'Şərh göndərilmədi.');
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rooms) {
      return PartyRoomsPage(profile: widget.profile);
    }
    return SocialSurface(
      color: const Color(0xff120817),
    child: Column(
      children: [
        PageHeading(
          widget.rooms ? 'Otaqlar' : 'Anlar',
          subtitle: widget.rooms
              ? 'Canlı səsli otaqlara qoşul və söhbət et'
              : 'Şəkil, fikir və anlarını dostlarınla paylaş',
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
                          if (!widget.rooms) ...[
                            const SizedBox(height: 14),
                            Builder(builder: (context) {
                              final likes = (doc.data()['likes'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
                              final liked = likes.contains(widget.profile.uid);
                              return Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _toggleMomentLike(doc.reference, doc.data()),
                                    icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? vibePink : mutedInk),
                                    label: Text('${likes.length}', style: const TextStyle(color: Colors.white70)),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _openMomentComments(doc.reference),
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: mutedInk),
                                    label: const Text('Şərh', style: TextStyle(color: Colors.white70)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Paylaş',
                                    onPressed: () => _shareMoment('${doc.data()['text'] ?? ''}'),
                                    icon: const Icon(Icons.ios_share_rounded, color: mutedInk),
                                  ),
                                ],
                              );
                            }),
                          ],
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
                              ? const Color(0xff2a1c43)
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
