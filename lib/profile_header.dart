// PROFİL BAŞLIQLARI.
// Maket #6 — öz profilin: örtük şəkli, avatar, ID, nişanlar, statistika.
// Maket #7 — başqasının profili: örtük + üzən məlumat kartı.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'coin_wallet.dart';
import 'countries.dart';
import 'media_store.dart';
import 'user_profile.dart';
import 'vip.dart';
import 'vibe_status.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';
import 'app/i18n.dart';

// ============================================================
// ÖRTÜK ŞƏKLİ
// ============================================================

/// Profilin yuxarı hissəsi: örtük şəkli və ya qradiyent + şüar.
class CoverBanner extends StatelessWidget {
  const CoverBanner({
    super.key,
    required this.coverUrl,
    this.height = 190,
    this.showSlogan = true,
  });

  final String coverUrl;
  final double height;
  final bool showSlogan;

  @override
  Widget build(BuildContext context) {
    final cover = vibeImageProvider(coverUrl);

    return SizedBox(
    height: height,
    width: double.infinity,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (cover == null)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff3a1a63), Color(0xff6d2a7a), Color(0xff23103f)],
              ),
            ),
          )
        else
          Image(
            image: cover,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff3a1a63), Color(0xff23103f)],
                ),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Colors.transparent, Color(0xcc070510)],
            ),
          ),
        ),
        if (showSlogan && cover == null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Good Vibes',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .92),
                    fontSize: 26,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  'Better People',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .92),
                    fontSize: 26,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    );
  }
}

// ============================================================
// ÖZ PROFİLİM
// ============================================================

class ProfileCoverHeader extends StatefulWidget {
  const ProfileCoverHeader({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onSettings,
    required this.onShare,
    this.database,
  });

  final UserProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onSettings;
  final VoidCallback onShare;
  final FirebaseFirestore? database;

  @override
  State<ProfileCoverHeader> createState() => _ProfileCoverHeaderState();
}

class _ProfileCoverHeaderState extends State<ProfileCoverHeader> {
  bool uploading = false;
  bool uploadingPhoto = false;

  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  /// Avatara toxunanda profil şəklini dəyişir.
  Future<void> _changePhoto() async {
    if (uploadingPhoto) return;

    setState(() => uploadingPhoto = true);
    try {
      final image = await pickStoredImage();
      if (image == null) return;

      await saveProfilePhoto(
        uid: widget.profile.uid,
        image: image,
        database: widget.database,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil şəkli yeniləndi ✨')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şəkil saxlanmadı. Yenidən sına.')),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> _changeCover() async {
    if (uploading) return;

    setState(() => uploading = true);
    try {
      final image = await pickStoredImage(fullWidth: 900, thumbWidth: 360);
      if (image == null) return;

      await saveCoverPhoto(
        uid: widget.profile.uid,
        image: image,
        database: widget.database,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Örtük şəkli yeniləndi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Örtük şəkli saxlanmadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('users').doc(widget.profile.uid).snapshots(),
        builder: (context, snapshot) {
          final d = snapshot.data?.data() ?? const <String, dynamic>{};
          final name = '${d['name'] ?? widget.profile.name}';
          final about = '${d['about'] ?? widget.profile.about}'.trim();
          final level = d['level'] is num ? (d['level'] as num).toInt() : 0;
          final vip = d['vip'] == true || d['isVip'] == true || d['premium'] == true;
          final vipLevel = d['vipLevel'] is num ? (d['vipLevel'] as num).toInt() : 1;
          final tags = ((d['tags'] as List?) ?? (d['interests'] as List?) ?? const [])
              .map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          final status = VibeStatus.from(d);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- örtük + üst düymələr ----
              // Qeyd: avatar sətri Stack-in HÜDUDU DAXİLİNDƏ olmalıdır.
              // Əks halda (bottom: -34 kimi) düymə görünür, amma toxunuşu
              // qəbul etmir — Flutter hit-test sahədən kənarda işləmir.
              SizedBox(
                height: 236,
                child: Stack(
                  children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: CoverBanner(coverUrl: '${d['coverUrl'] ?? ''}'),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        TopIconButton(
                          icon: uploading
                              ? Icons.hourglass_top_rounded
                              : Icons.photo_camera_rounded,
                          tooltip: 'Örtük şəklini dəyiş',
                          onTap: _changeCover,
                        ),
                        TopIconButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: 'Profili paylaş',
                          onTap: widget.onShare,
                        ),
                        TopIconButton(
                          icon: Icons.settings_rounded,
                          tooltip: t('Ayarlar'),
                          onTap: widget.onSettings,
                        ),
                      ],
                    ),
                  ),

                  // ---- avatar + "Profili düzəlt" ----
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Stack(
                          children: [
                            PressableScale(
                              onTap: _changePhoto,
                              child: Container(
                                width: 92,
                                height: 92,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: vip
                                      ? const LinearGradient(
                                          colors: [vGold, vPink, vPurple],
                                        )
                                      : const LinearGradient(
                                          colors: [vPurple, vPink],
                                        ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (vip ? vGold : vPink).withValues(alpha: .4),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      VibePhoto(
                                        url: '${d['photoUrl'] ?? ''}',
                                        name: name,
                                        emoji: '${d['avatarEmoji'] ?? ''}',
                                      ),
                                      // Şəkli dəyişmək üçün toxun
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          height: 24,
                                          color: Colors.black.withValues(alpha: .45),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            uploadingPhoto
                                                ? Icons.hourglass_top_rounded
                                                : Icons.photo_camera_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  color: const Color(0xff2de28a),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: vBg, width: 3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 8),
                            child: PressableScale(
                              onTap: widget.onEdit,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff1b1430).withValues(alpha: .9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: vPurple),
                                ),
                                child: const Text(
                                  'Profili düzəlt',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---- ad, ID, nişanlar ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VerifiedName(
                      name: name,
                      verified: d['verified'] == true || vip,
                      fontSize: 22,
                    ),
                    const SizedBox(height: 6),
                    PressableScale(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.profile.uid),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID kopyalandı.')),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${_shortId(widget.profile.uid)}',
                            style: const TextStyle(color: vMuted, fontSize: 12),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.copy_rounded, size: 13, color: vMuted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        GenderAgeChip(
                          gender: genderCode(d),
                          age: '${d['age'] ?? widget.profile.age}'.replaceAll('0', '0'),
                          fontSize: 10.5,
                        ),
                        if (level > 0) LevelTag(level: level, fontSize: 10.5),
                        // Hədiyyə xalından hesablanan VIP pilləsi.
                        VipBadge(tier: tierOf(d), fontSize: 10.5),
                        if (vip) VipTag(level: vipLevel, fontSize: 10.5),
                        CoinBadge(
                          uid: widget.profile.uid,
                          database: widget.database,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CoinHistoryPage(uid: widget.profile.uid),
                            ),
                          ),
                        ),
                        if (status != null) VibePill(status: status, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ---- statistika ----
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ProfileStatsRow(uid: widget.profile.uid, database: db),
              ),

              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ProfileInfoSection(
                  uid: widget.profile.uid,
                  data: d,
                  editable: true,
                  database: widget.database,
                ),
              ),

              if (about.isNotEmpty || tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Haqqımda',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (about.isNotEmpty)
                        Text(
                          about,
                          style: const TextStyle(
                            color: Color(0xffd0c8de),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in tags)
                              VibeChip(label: tag, selected: false),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      );
}

String _shortId(String uid) {
  if (uid.length <= 12) return uid;
  return uid.substring(0, 12);
}

// ============================================================
// STATİSTİKA SƏTRİ
// ============================================================

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.uid,
    this.database,
    this.onFollowers,
    this.onFollowing,
  });

  final String uid;
  final FirebaseFirestore? database;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  Stream<int> _count(String collection) => db
      .collection('users')
      .doc(uid)
      .collection(collection)
      .snapshots()
      .map((snap) => snap.docs.length);

  Stream<int> _moments() => db
      .collection('moments')
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.length);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: vPanel.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: Row(
      children: [
        Expanded(child: _cell(_moments(), 'Paylaşım', null)),
        Expanded(child: _cell(_count('followers'), 'İzləyici', onFollowers)),
        Expanded(child: _cell(_count('following'), 'İzlənilən', onFollowing)),
        Expanded(child: _cell(_count('likedVideos'), 'Bəyənmə', null)),
      ],
    ),
  );

  Widget _cell(Stream<int> stream, String label, VoidCallback? onTap) =>
      StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) => StatCell(
          value: compactCount(snapshot.data ?? 0),
          label: label,
          onTap: onTap,
        ),
      );
}

// ============================================================
// BÜRC VƏ "BİLGİ" BÖLMƏSİ
// ============================================================

/// Doğum tarixindən bürc adı.
String zodiacName(DateTime date) {
  final d = date.day;
  switch (date.month) {
    case 1:
      return d <= 19 ? 'Oğlaq bürcü' : 'Dolça bürcü';
    case 2:
      return d <= 18 ? 'Dolça bürcü' : 'Balıq bürcü';
    case 3:
      return d <= 20 ? 'Balıq bürcü' : 'Qoç bürcü';
    case 4:
      return d <= 19 ? 'Qoç bürcü' : 'Buğa bürcü';
    case 5:
      return d <= 20 ? 'Buğa bürcü' : 'Əkizlər bürcü';
    case 6:
      return d <= 20 ? 'Əkizlər bürcü' : 'Xərçəng bürcü';
    case 7:
      return d <= 22 ? 'Xərçəng bürcü' : 'Şir bürcü';
    case 8:
      return d <= 22 ? 'Şir bürcü' : 'Qız bürcü';
    case 9:
      return d <= 22 ? 'Qız bürcü' : 'Tərəzi bürcü';
    case 10:
      return d <= 22 ? 'Tərəzi bürcü' : 'Əqrəb bürcü';
    case 11:
      return d <= 21 ? 'Əqrəb bürcü' : 'Oxatan bürcü';
    default:
      return d <= 21 ? 'Oxatan bürcü' : 'Oğlaq bürcü';
  }
}

/// Doğum tarixindən yaş.
int ageFromBirth(DateTime birth) {
  final now = DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  return age;
}

/// Maket #3-dəki "Bilgi" bloku: ID, doğum günü, bürc, qeydiyyat tarixi.
class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    required this.uid,
    required this.data,
    this.editable = false,
    this.database,
  });

  final String uid;
  final Map<String, dynamic> data;

  /// Öz profilindirsə doğum günü dəyişdirilə bilər.
  final bool editable;

  final FirebaseFirestore? database;

  /// Doğum gününü seçdirir və yadda saxlayır.
  ///
  /// Bürc və yaş bu tarixdən avtomatik hesablanır — ayrıca soruşmuruq.
  Future<void> _pickBirthday(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Doğum günün',
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: vPink,
            surface: vPanel,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    final years = _yearsSince(picked);
    try {
      await (database ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .set({
        'birthDate': Timestamp.fromDate(picked),
        'age': years,
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doğum günü yeniləndi.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yadda saxlanmadı. Yenidən sına.')),
        );
      }
    }
  }

  /// Tarixdən indiyə qədər neçə tam il keçib.
  int _yearsSince(DateTime date) {
    final now = DateTime.now();
    var years = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      years--;
    }
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final rawBirth = data['birthDate'];
    final birth = rawBirth is Timestamp ? rawBirth.toDate() : null;
    final rawCreated = data['createdAt'];
    final created = rawCreated is Timestamp ? rawCreated.toDate() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bilgi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _row(
          context,
          Icons.person_outline_rounded,
          'ID',
          _shortId(uid),
          onTap: () {
            Clipboard.setData(ClipboardData(text: uid));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ID kopyalandı.')),
            );
          },
          trailing: Icons.copy_rounded,
        ),
        if (countryByCode('${data['countryCode'] ?? ''}') != null)
          _row(
            context,
            Icons.public_rounded,
            'Ölkə',
            '${countryByCode('${data['countryCode'] ?? ''}')!.flag}  '
                '${countryByCode('${data['countryCode'] ?? ''}')!.name}',
          ),
        _row(
          context,
          Icons.cake_outlined,
          'Doğum günü',
          birth == null ? 'Əlavə edilməyib' : '${birth.day}/${birth.month}',
          onTap: editable ? () => _pickBirthday(context, birth) : null,
          trailing: editable ? Icons.edit_rounded : null,
        ),
        _row(
          context,
          Icons.star_border_rounded,
          'Bürc',
          birth == null ? '—' : zodiacName(birth),
        ),
        _row(
          context,
          Icons.phone_iphone_rounded,
          'Qeydiyyat zamanı',
          created == null
              ? '—'
              : '${created.year}/${created.month.toString().padLeft(2, '0')}/'
                    '${created.day.toString().padLeft(2, '0')}',
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    IconData? trailing,
  }) => PressableScale(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 19, color: vMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: vMuted, fontSize: 13.5),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Icon(trailing, size: 14, color: vMuted),
          ],
        ],
      ),
    ),
  );
}
