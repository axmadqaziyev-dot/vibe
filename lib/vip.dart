import 'package:flutter/material.dart';

/// VIP PİLLƏLƏRİ VƏ MEDALLAR.
///
/// Bir fayl — bir həqiqət mənbəyi: pillələrin hesablanması, adları, rəngləri
/// və qazanılan medallar burada müəyyən olunur. Profil, otaq, söhbət — hamısı
/// bu funksiyaları çağırır ki, hər yerdə eyni nəticə çıxsın.

/// Bir VIP pilləsi.
class VipTier {
  const VipTier({
    required this.level,
    required this.name,
    required this.minScore,
    required this.colors,
    required this.perks,
  });

  final int level;
  final String name;

  /// Bu pilləyə çatmaq üçün lazım olan xal.
  final int minScore;

  final List<Color> colors;

  /// Pillənin verdiyi imkanlar.
  final List<String> perks;

  Color get color => colors.first;
}

/// Pillələr — xal artdıqca yuxarı qalxır.
const List<VipTier> vipTiers = [
  VipTier(
    level: 0,
    name: 'Yeni',
    minScore: 0,
    colors: [Color(0xff9d94ae), Color(0xff6f6a90)],
    perks: ['Otaqlara qoşul', 'Hədiyyə göndər'],
  ),
  VipTier(
    level: 1,
    name: 'Bürünc',
    minScore: 300,
    colors: [Color(0xffcd7f32), Color(0xff8a5220)],
    perks: ['Adının yanında nişan', 'Otağa giriş lenti'],
  ),
  VipTier(
    level: 2,
    name: 'Gümüş',
    minScore: 1500,
    colors: [Color(0xffc0c6d4), Color(0xff8a91a3)],
    perks: ['Gümüş nişan', 'Kəşf lentində daha yuxarı'],
  ),
  VipTier(
    level: 3,
    name: 'Qızıl',
    minScore: 5000,
    colors: [Color(0xffffd458), Color(0xffe0951f)],
    perks: ['Qızıl giriş effekti', 'Profil çərçivəsi'],
  ),
  VipTier(
    level: 4,
    name: 'Platin',
    minScore: 15000,
    colors: [Color(0xff8fd4ff), Color(0xff22a7ff)],
    perks: ['Xüsusi hədiyyə animasiyası', 'Kəşfdə üstünlük'],
  ),
  VipTier(
    level: 5,
    name: 'Almaz',
    minScore: 40000,
    colors: [Color(0xffb794ff), Color(0xff8b5cff)],
    perks: ['Almaz nişan', 'Otaqda fərqlənən ad'],
  ),
  VipTier(
    level: 6,
    name: 'Kral',
    minScore: 100000,
    colors: [Color(0xffff2bd6), Color(0xffff657b)],
    perks: ['Ən yüksək pillə', 'Bütün effektlər'],
  ),
];

/// İstifadəçinin VIP xalı.
///
/// Göndərilən və alınan hədiyyələrin cəmi. Göndərmək aktivliyi,
/// almaq isə populyarlığı göstərir — ikisi birlikdə ədalətli ölçüdür.
int vipScore(Map<String, dynamic> data) {
  final sent = int.tryParse('${data['giftSent'] ?? 0}') ?? 0;
  final received = int.tryParse('${data['giftReceived'] ?? 0}') ?? 0;
  return sent + received;
}

/// Xala uyğun pilləni qaytarır.
VipTier tierForScore(int score) {
  var result = vipTiers.first;
  for (final tier in vipTiers) {
    if (score >= tier.minScore) result = tier;
  }
  return result;
}

VipTier tierOf(Map<String, dynamic> data) => tierForScore(vipScore(data));

/// Növbəti pilləyə nə qədər qalıb (0..1). Ən yuxarıdadırsa 1.
double tierProgress(int score) {
  final current = tierForScore(score);
  final next = vipTiers.firstWhere(
    (t) => t.minScore > current.minScore,
    orElse: () => current,
  );
  if (next.minScore == current.minScore) return 1;
  final span = next.minScore - current.minScore;
  return ((score - current.minScore) / span).clamp(0.0, 1.0);
}

/// Növbəti pillə; ən yuxarıdadırsa `null`.
VipTier? nextTier(int score) {
  final current = tierForScore(score);
  for (final tier in vipTiers) {
    if (tier.minScore > current.minScore) return tier;
  }
  return null;
}

// ============================================================
// MEDALLAR
// ============================================================

/// Qazanılan nişan.
class Medal {
  const Medal({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.check,
  });

  final String id;
  final String title;
  final String emoji;
  final String description;

  /// Profil məlumatına baxıb qazanılıb-qazanılmadığını deyir.
  final bool Function(Map<String, dynamic> data) check;
}

int _num(Map<String, dynamic> data, String key) =>
    int.tryParse('${data[key] ?? 0}') ?? 0;

/// Bütün medallar.
const List<Medal> allMedals = [
  Medal(
    id: 'welcome',
    title: 'Xoş gəldin',
    emoji: '🎉',
    description: 'VIBE-a qoşuldun',
    check: _always,
  ),
  Medal(
    id: 'photo',
    title: 'Simalı',
    emoji: '📸',
    description: 'Profil şəkli qoydun',
    check: _hasPhoto,
  ),
  Medal(
    id: 'first_gift',
    title: 'Əliaçıq',
    emoji: '🎁',
    description: 'İlk hədiyyəni göndərdin',
    check: _sentGift,
  ),
  Medal(
    id: 'loved',
    title: 'Sevilən',
    emoji: '💖',
    description: '1000 xallıq hədiyyə aldın',
    check: _loved,
  ),
  Medal(
    id: 'host',
    title: 'Ev sahibi',
    emoji: '🎤',
    description: 'Öz otağını açdın',
    check: _host,
  ),
  Medal(
    id: 'social',
    title: 'Populyar',
    emoji: '🌟',
    description: '10 izləyici topladın',
    check: _popular,
  ),
  Medal(
    id: 'storyteller',
    title: 'Paylaşan',
    emoji: '✨',
    description: 'İlk anını paylaşdın',
    check: _sharedMoment,
  ),
  Medal(
    id: 'gamer',
    title: 'Oyunçu',
    emoji: '🎲',
    description: 'Oyunda uddun',
    check: _gamer,
  ),
];

bool _always(Map<String, dynamic> data) => true;

bool _hasPhoto(Map<String, dynamic> data) =>
    '${data['photoUrl'] ?? ''}'.trim().isNotEmpty;

bool _sentGift(Map<String, dynamic> data) => _num(data, 'giftSent') > 0;

bool _loved(Map<String, dynamic> data) => _num(data, 'giftReceived') >= 1000;

bool _host(Map<String, dynamic> data) => _num(data, 'roomsCreated') > 0;

bool _popular(Map<String, dynamic> data) => _num(data, 'followersCount') >= 10;

bool _sharedMoment(Map<String, dynamic> data) => _num(data, 'momentCount') > 0;

bool _gamer(Map<String, dynamic> data) => _num(data, 'gameWins') > 0;

/// Qazanılan medallar.
List<Medal> earnedMedals(Map<String, dynamic> data) =>
    allMedals.where((m) => m.check(data)).toList();

// ============================================================
// GÖRÜNÜŞ
// ============================================================

/// Adın yanında görünən VIP nişanı.
class VipBadge extends StatelessWidget {
  const VipBadge({super.key, required this.tier, this.fontSize = 10});

  final VipTier tier;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Ən aşağı pillədə nişan göstərmirik — ekranı qarışdırmasın.
    if (tier.level == 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * .65, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tier.colors),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: .45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: fontSize + 2, color: Colors.white),
          SizedBox(width: fontSize * .25),
          Text(
            tier.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Medal dairəsi.
class MedalChip extends StatelessWidget {
  const MedalChip({
    super.key,
    required this.medal,
    required this.earned,
    this.size = 62,
  });

  final Medal medal;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: earned
                ? const Color(0xff2a2140)
                : const Color(0xff17131f),
            border: Border.all(
              color: earned ? const Color(0xffffd458) : const Color(0xff2d2540),
              width: earned ? 1.6 : 1,
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: earned ? 1 : .28,
              child: Text(
                medal.emoji,
                style: TextStyle(fontSize: size * .42),
              ),
            ),
          ),
        ),
        SizedBox(height: size * .12),
        SizedBox(
          width: size + 12,
          child: Text(
            medal.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: earned
                  ? Colors.white
                  : const Color(0xffa89fbd).withValues(alpha: .6),
              fontSize: size * .17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
