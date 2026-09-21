// ANA SƏHİFƏ — Kəşf et.
// Maket: üst panel (VIBE · axtarış · VIP), altı xətli tablar,
// hero banner, filtr pilləri və 3 sütunlu foto profil şəbəkəsi.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show PersonPage, isReallyOnline;
import 'social_ui.dart' show SocialSurface, openChat;
import 'blocking.dart';
import 'instant_match.dart';
import 'vibe_levels.dart';
import 'vibe_status.dart';
import 'tonight.dart';
import 'tonight_card.dart';
import 'countries.dart';
import 'country_picker.dart';
import 'user_profile.dart';
import 'vip.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';

class SocialHome extends StatefulWidget {
  const SocialHome({super.key, required this.profile, this.database});

  final FirebaseFirestore? database;
  final UserProfile profile;

  @override
  State<SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends State<SocialHome> {
  static const topLabels = ['Kəşf et', 'Yaxınlıq', 'Online', 'Popular'];
  // "Online" yuxarıdakı sekmələrdə var idi, burada təkrarlanırdı —
  // eyni süzgəcin iki yeri istifadəçini çaşdırır.
  static const pillLabels = ['Hamısı', 'Qızlar', 'Oğlanlar'];

  String query = '';
  int topTab = 0;
  int pill = 0;
  String moodFilter = '';

  /// Boş = bütün ölkələr.
  String countryFilter = '';

  /// Mənim bu axşamkı niyyətim — siyahını ona görə sıralayırıq.
  Tonight? myTonight;
  bool searching = false;
  Timer? timer;

  final Set<String> favorites = <String>{};
  final Set<String> blockedIds = <String>{};
  StreamSubscription<Set<String>>? blockSub;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  // Şəkillər sənədin içində saxlanıldığı üçün siyahı hədsiz böyüməməlidir.
  late final stream = db.collection('users').limit(300).snapshots();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _watchBlocked();
    // "online" statusu vaxta görə hesablanır — hər 15 saniyədə yenilə.
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

  /// Həm mənim bloklamağım, həm də məni bloklayanlar gizlədilir.
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

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final values =
        prefs.getStringList('vibe_favorites_${widget.profile.uid}') ??
        const <String>[];
    if (!mounted) return;
    setState(() {
      favorites
        ..clear()
        ..addAll(values);
    });
  }

  Future<void> _toggleFavorite(String uid) async {
    setState(
      () => favorites.contains(uid) ? favorites.remove(uid) : favorites.add(uid),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'vibe_favorites_${widget.profile.uid}',
      favorites.toList(),
    );
  }

  /// Axtarış: ad, şəhər, haqqında, maraqlar, ID və əhval mətni.
  /// Azərbaycan hərfləri latın qarşılığı ilə də tapılsın deyə normallaşdırılır.
  bool _matchesQuery(String uid, Map<String, dynamic> d, String query) {
    final tags = ((d['tags'] as List?) ?? (d['interests'] as List?) ?? const [])
        .map((e) => '$e')
        .join(' ');
    final status = VibeStatus.from(d);

    final haystack = _normalize([
      '${d['name'] ?? ''}',
      '${d['city'] ?? ''}',
      '${d['country'] ?? ''}',
      '${d['about'] ?? ''}',
      tags,
      status == null ? '' : '${status.mood.label} ${status.note}',
      uid,
    ].join(' '));

    // Hər söz ayrı-ayrılıqda axtarılır: "baki musiqi" → ikisi də olmalıdır.
    for (final word in _normalize(query).split(' ')) {
      if (word.isEmpty) continue;
      if (!haystack.contains(word)) return false;
    }
    return true;
  }

  static const _letters = {
    'ə': 'e', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o',
    'ş': 's', 'ü': 'u', 'ç': 'c',
  };

  String _normalize(String value) {
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().characters) {
      buffer.write(_letters[char] ?? char);
    }
    return buffer.toString();
  }

  /// Populyarlıq — profil sənədində saxlanan real göstəricilər.
  ///
  /// VIP pilləsi də nəzərə alınır: yuxarı pillədəkilər lentdə daha
  /// qabaqda görünür (rəqib tətbiqlərdəki "priority in discovery").
  num _popularity(Map<String, dynamic> d) {
    num number(Object? value) => value is num ? value : 0;
    return number(d['giftReceived']) / 100 +
        number(d['level']) * 2 +
        number(d['followersCount']) * 3 +
        tierOf(d).level * 6;
  }

  @override
  Widget build(BuildContext context) => SocialSurface(
    child: Column(
      children: [
        VibeTopBar(
          actions: [
            TopIconButton(
              icon: searching ? Icons.close_rounded : Icons.search_rounded,
              tooltip: 'Axtar',
              onTap: () => setState(() {
                searching = !searching;
                if (!searching) query = '';
              }),
            ),
            VipCrown(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VibeLevelsPage(profile: widget.profile),
                ),
              ),
            ),
          ],
        ),
        UnderlineTabs(
          labels: topLabels,
          index: topTab,
          onChanged: (i) => setState(() => topTab = i),
        ),
        if (searching) _searchField(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _HomeError();
              }
              if (!snapshot.hasData) {
                return _skeleton();
              }

              final me = snapshot.data!.docs
                  .where((doc) => doc.id == widget.profile.uid)
                  .map((doc) => doc.data())
                  .firstOrNull ??
                  const <String, dynamic>{};

              final people = snapshot.data!.docs.where((doc) {
                if (doc.id == widget.profile.uid) return false;
                if (blockedIds.contains(doc.id)) return false;

                final d = doc.data();

                if (query.isNotEmpty && !_matchesQuery(doc.id, d, query)) {
                  return false;
                }

                // üst tablar
                if (topTab == 2 && !isReallyOnline(d)) return false;

                // filtr pilləri
                final gender = genderCode(d);
                if (pill == 1 && gender != 1) return false;
                if (pill == 2 && gender != 2) return false;

                if (countryFilter.isNotEmpty &&
                    '${d['countryCode'] ?? ''}' != countryFilter) {
                  return false;
                }

                if (moodFilter.isNotEmpty &&
                    VibeStatus.from(d)?.mood.id != moodFilter) {
                  return false;
                }
                return true;
              }).toList();

              people.sort((a, b) {
                final da = a.data();
                final dbb = b.data();

                // Niyyət seçilibsə uyğunluq hər şeydən öncə gəlir:
                // adam nə istədiyini deyibsə, siyahı ona cavab verməlidir.
                if (myTonight != null) {
                  final ta = tonightOf(da['tonight']);
                  final tb = tonightOf(dbb['tonight']);

                  final ma = ta == null ? -1.0 : tonightMatch(myTonight!, ta);
                  final mb = tb == null ? -1.0 : tonightMatch(myTonight!, tb);

                  if (ma != mb) return mb.compareTo(ma);
                }

                if (topTab == 1) {
                  final ka = distanceKm(me, da);
                  final kb = distanceKm(me, dbb);
                  if (ka != null && kb != null) return ka.compareTo(kb);
                  if (ka != null) return -1;
                  if (kb != null) return 1;
                  // koordinat yoxdursa: eyni şəhər öndə
                  final city = widget.profile.city.trim().toLowerCase();
                  final ca = '${da['city'] ?? ''}'.trim().toLowerCase() == city;
                  final cb = '${dbb['city'] ?? ''}'.trim().toLowerCase() == city;
                  if (ca != cb) return ca ? -1 : 1;
                } else if (topTab == 3) {
                  final pa = _popularity(da);
                  final pb = _popularity(dbb);
                  if (pa != pb) return pb.compareTo(pa);
                }

                final oa = isReallyOnline(da);
                final ob = isReallyOnline(dbb);
                if (oa != ob) return oa ? -1 : 1;
                return '${da['name'] ?? ''}'.compareTo('${dbb['name'] ?? ''}');
              });

              return RefreshIndicator(
                color: vPink,
                backgroundColor: vPanel,
                onRefresh: () async {
                  if (mounted) setState(() {});
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _hero(),
                    const SizedBox(height: 16),
                    // Əhval və niyyət eyni işi görür — ekranda iki böyük
                    // kart kimi durmaları lazımsız yer tuturdu.
                    Row(
                      children: [
                        Expanded(
                          child: MyVibeCard(
                            uid: widget.profile.uid,
                            database: widget.database,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TonightCard(
                            uid: widget.profile.uid,
                            database: widget.database,
                            compact: true,
                            onChanged: (value) =>
                                setState(() => myTonight = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PillTabs(
                      labels: pillLabels,
                      index: pill,
                      onChanged: (i) => setState(() => pill = i),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 14),
                    _moodRow(),
                    const SizedBox(height: 16),
                    if (people.isEmpty)
                      EmptyDiscover(
                        filtered: topTab != 0 ||
                            pill != 0 ||
                            countryFilter.isNotEmpty ||
                            moodFilter.isNotEmpty ||
                            query.isNotEmpty,
                        onReset: () => setState(() {
                          topTab = 0;
                          pill = 0;
                          moodFilter = '';
                          countryFilter = '';
                          query = '';
                          searching = false;
                        }),
                        onInvite: _invite,
                      )
                    else
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth >= 900
                              ? 5
                              : (c.maxWidth >= 620 ? 4 : 3);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: people.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: .74,
                                ),
                            itemBuilder: (context, index) {
                              final doc = people[index];
                              final theirs = tonightOf(doc.data()['tonight']);

                              return DiscoverCard(
                                data: doc.data(),
                                me: me,
                                matched: myTonight != null &&
                                    theirs != null &&
                                    tonightMatch(myTonight!, theirs) >= 1,
                                favorite: favorites.contains(doc.id),
                                onFavorite: () => _toggleFavorite(doc.id),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonPage(
                                      currentProfile: widget.profile,
                                      targetUid: doc.id,
                                    ),
                                  ),
                                ),
                                onChat: () => openChat(
                                  context,
                                  widget.profile,
                                  doc.id,
                                  '${doc.data()['name'] ?? 'İstifadəçi'}',
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  /// Dəvət mətnini panoya kopyalayır.
  void _invite() {
    Clipboard.setData(
      const ClipboardData(
        text: 'VIBE-ə qoşul! Yeni dostlar, səsli otaqlar və canlı söhbətlər. '
            'Məni orada tap 💜',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dəvət mətni kopyalandı — dostuna göndər.')),
    );
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: TextField(
      autofocus: true,
      onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
      style: const TextStyle(color: Colors.white),
      cursorColor: vPink,
      decoration: InputDecoration(
        hintText: 'Ad, şəhər, maraq, ID və ya əhval axtar',
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
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: const [
      VibeShimmer(height: 150, radius: 22),
      SizedBox(height: 16),
      VibeShimmer(height: 84, radius: 22),
      SizedBox(height: 16),
      VibeShimmer(height: 34, radius: 17),
      SizedBox(height: 16),
      VibeCardSkeleton(count: 6),
    ],
  );

  Widget _hero() => Container(
    constraints: const BoxConstraints(minHeight: 150),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xff2b0f52), Color(0xff5c1670), Color(0xff9c1d80)],
      ),
      boxShadow: [
        BoxShadow(
          color: vPink.withValues(alpha: .28),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -34,
            child: Icon(
              Icons.favorite_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 58,
              color: Colors.white.withValues(alpha: .35),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Yeni dostlar\nYeni hekayələr\nVIBE-də ❤️',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: 'İndi kəşf et  →',
                  expand: false,
                  height: 36,
                  fontSize: 13,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstantMatchPage(profile: widget.profile),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// Ölkəyə görə süzgəc.
  Widget _countryChip() {
    final selected = countryByCode(countryFilter);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: VibeChip(
        label: selected?.name ?? 'Ölkə',
        emoji: selected?.flag ?? '🌍',
        color: const Color(0xff22a7ff),
        selected: countryFilter.isNotEmpty,
        onTap: () async {
          if (countryFilter.isNotEmpty) {
            setState(() => countryFilter = '');
            return;
          }
          final picked = await pickCountry(context);
          if (picked != null && mounted) {
            setState(() => countryFilter = picked.code);
          }
        },
      ),
    );
  }

  /// Əhvala görə süzgəc (VIBE statusu).
  ///
  /// Zolaq ekranın kənarına qədər uzanır. Əvvəl ana siyahının 16 px
  /// kənarının içində qalırdı: sonuncu çip boşluqda yarımçıq kəsilirdi
  /// və sürüşdürülə bildiyi bilinmirdi. `OverflowBox` həmin kənarı
  /// keçir — çip ekranın öz kənarında kəsilir, bu isə hər kəsə tanış
  /// "sürüşdür" işarəsidir.
  ///
  /// Hündürlük 34-dən 40-a qaldırıldı: seçilmiş çipin işığı və
  /// haşiyəsi 34-də kəsilirdi.
  Widget _moodRow() => SizedBox(
    height: 40,
    child: OverflowBox(
      maxWidth: MediaQuery.sizeOf(context).width,
      child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: vibeMoods.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _countryChip();
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: VibeChip(
              label: 'Hər əhval',
              emoji: '🌐',
              selected: moodFilter.isEmpty,
              onTap: () => setState(() => moodFilter = ''),
            ),
          );
        }
        final mood = vibeMoods[index - 2];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: VibeChip(
            label: mood.label,
            emoji: mood.emoji,
            color: mood.color,
            selected: moodFilter == mood.id,
            onTap: () => setState(
              () => moodFilter = moodFilter == mood.id ? '' : mood.id,
            ),
          ),
        );
      },
    ),
    ),
  );
}

// ============================================================
// PROFİL KARTI
// ============================================================

class DiscoverCard extends StatelessWidget {
  const DiscoverCard({
    super.key,
    required this.data,
    required this.me,
    required this.onTap,
    required this.onChat,
    this.favorite = false,
    this.onFavorite,
    this.matched = false,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic> me;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final bool favorite;
  final VoidCallback? onFavorite;

  /// Bu axşamkı niyyətim onunkuna tam uyğun gəlirsə kart işıqlanır.
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final name = '${data['name'] ?? 'İstifadəçi'}';
    final online = isReallyOnline(data);
    final status = VibeStatus.from(data);
    final place = placeLabel(me, data);
    final gender = genderCode(data);
    final age = '${data['age'] ?? ''}'.trim();

    return PressableScale(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: matched
                ? const Color(0xffffd458)
                : online
                    ? const Color(0xff3ddc97).withValues(alpha: .45)
                    : const Color(0xff2a2340),
            width: matched ? 1.4 : 1,
          ),
          boxShadow: matched
              ? [
                  BoxShadow(
                    color: const Color(0xffffd458).withValues(alpha: .22),
                    blurRadius: 16,
                  ),
                ]
              : online
                  ? [
                      BoxShadow(
                        color: const Color(0xff2de28a).withValues(alpha: .14),
                        blurRadius: 14,
                      ),
                    ]
                  : const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 10),
                    ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VibePhoto(
              url: '${data['photoUrl'] ?? ''}',
              name: name,
              emoji: '${data['avatarEmoji'] ?? ''}',
            ),

            // Asagidan yuxari qaralma.
            //
            // Evvel kartin tam ortasindan baslayirdi ve herf
            // avatarlarinda keskin serhed gorunurdu. Indi uc
            // dayanacaqla yumsaq kecir.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x14000000),
                    Color(0x8f000000),
                    Color(0xe8000000),
                  ],
                  stops: [0, .44, .76, 1],
                ),
              ),
            ),

            // Ust sira: solda veziyyet, sagda favorit.
            //
            // Evvel urek kartin ortasindan sagda tek dayanirdi ve
            // hec neye baglanmirdi.
            Positioned(
              left: 7,
              right: 6,
              top: 7,
              child: Row(
                children: [
                  if (online) const _OnlineDot(),
                  if (status != null) ...[
                    if (online) const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: status.mood.color.withValues(alpha: .92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: status.mood.color.withValues(alpha: .45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        status.mood.emoji,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onFavorite != null)
                    PressableScale(
                      onTap: onFavorite,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .34),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: favorite ? vPink : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Alt sira: ad, yas/yer ve sohbet duymesi.
            Positioned(
              left: 10,
              right: 8,
              bottom: 9,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (gender != 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  gender == 1
                                      ? Icons.female_rounded
                                      : Icons.male_rounded,
                                  size: 11,
                                  color: gender == 1 ? vPink : vBlue,
                                ),
                              ),
                            if (age.isNotEmpty) ...[
                              Text(
                                age,
                                style: const TextStyle(
                                  color: Color(0xffe2dcee),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            // Uc sutunlu sebekede kart ~110 px enindedir.
                            // Ayirici noqte ve boyuk olcu seher adini
                            // "Ba..." halina salirdi — yer mena dasiyir,
                            // ona gore bosluq ona verilir.
                            Flexible(
                              child: PlaceLabel(
                                text: place,
                                fontSize: 9.5,
                                showIcon: false,
                                color: const Color(0xffb9b1cb),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  PressableScale(
                    onTap: onChat,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: vHot,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: vPink.withValues(alpha: .38),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onlayn nişanı.
///
/// Əvvəl bu, içində "online" yazısı olan qutu idi. Üç sütunlu
/// şəbəkədə kart 88 px enində olur — qutu, əhval nişanı və ürək bir
/// sıraya sığmırdı və dar telefonda sıra daşırdı.
///
/// Yazı onsuz da təkrar idi: onlayn adamın kartı yaşıl haşiyə və
/// yaşıl işıq alır. İndi yalnız işıqlı nöqtə qalır.
class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .34),
      shape: BoxShape.circle,
    ),
    child: Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xff2de28a),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0xaa2de28a), blurRadius: 6)],
      ),
    ),
  );
}

class EmptyDiscover extends StatelessWidget {
  const EmptyDiscover({
    super.key,
    this.filtered = false,
    this.onReset,
    this.onInvite,
  });

  /// Filtr səbəbindən boşdur, yoxsa ümumiyyətlə istifadəçi yoxdur?
  final bool filtered;
  final VoidCallback? onReset;
  final VoidCallback? onInvite;

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
            filtered ? Icons.filter_alt_off_rounded : Icons.group_add_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          filtered ? 'Bu filtrə uyğun kimsə yoxdur' : 'Hələ başqa istifadəçi yoxdur',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          filtered
              ? 'Filtri təmizlə və bütün profillərə bax.'
              : 'Dostunu dəvət et — VIBE birlikdə daha maraqlıdır.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: vMuted, height: 1.45),
        ),
        const SizedBox(height: 20),
        if (filtered && onReset != null)
          GradientButton(
            label: 'Filtri təmizlə',
            icon: Icons.refresh_rounded,
            expand: false,
            height: 44,
            onPressed: onReset,
          )
        else if (onInvite != null)
          GradientButton(
            label: 'Dostunu dəvət et',
            icon: Icons.ios_share_rounded,
            expand: false,
            height: 44,
            onPressed: onInvite,
          ),
      ],
    ),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError();

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
            'İnsanlar yüklənmədi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Bağlantını yoxlayıb yenidən aç.',
            style: TextStyle(color: vMuted),
          ),
        ],
      ),
    ),
  );
}
