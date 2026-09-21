/// Səviyyə, VIP və nişanlar.
///
/// SUGO və Falla-da adamın adının yanındakı "VIP10", "SVIP2", "Lv 34"
/// təsadüfi bəzək deyil — bütün xərcləmə mexanizmi ona bağlıdır.
/// Adam hədiyyə göndərir ki, nişanı böyüsün; nişan böyüyəndə otaqda
/// onu görürlər; göründüyü üçün daha çox göndərir.
///
/// Bizdə səviyyə yalnız bir yerdə, sadə bölmə ilə hesablanırdı
/// (`1 + alınan ~/ 500`) və heç yerdə görünmürdü. Burada bütöv sistem
/// var: səviyyə, VIP pilləsi, rəng və nişan.
///
/// İki ayrı ölçü var və qarışdırılmamalıdır:
///
/// * **Səviyyə** — nə qədər aktivsən. Göndərdiyin və aldığın
///   hədiyyələrin cəmindən çıxır; hamı üçün əlçatandır.
/// * **VIP** — nə qədər xərcləmisən. Yalnız göndərdiyindən asılıdır.
///
/// Birini o birinə qarışdırsaq, çox hədiyyə alan adam heç nə
/// xərcləmədən VIP olardı və pillənin mənası itərdi.
library;

/// Səviyyə üçün lazım olan təcrübə.
///
/// Artım sürəti qəsdən azalır: ilk səviyyələr tez gəlir (adam tərk
/// etməsin), sonrakılar çətinləşir (yüksək səviyyə dəyərini saxlasın).
int xpForLevel(int level) {
  if (level <= 1) return 0;
  // 2-ci səviyyə 100, sonra hər səviyyə əvvəlkindən 1.35 dəfə bahadır.
  var need = 100.0;
  var total = 0.0;

  for (var i = 2; i <= level; i++) {
    total += need;
    need *= 1.35;
  }

  return total.round();
}

/// Təcrübədən səviyyə.
int levelFromXp(int xp) {
  if (xp <= 0) return 1;

  var level = 1;
  // 100 səviyyə kifayətdir: ondan yuxarısı milyardlarla sikkə deməkdir.
  while (level < 100 && xp >= xpForLevel(level + 1)) {
    level++;
  }

  return level;
}

/// İstifadəçinin təcrübəsi.
///
/// Alınan hədiyyə yarım sayılır: yayımçı onsuz da hədiyyə alır, tam
/// sayılsa səviyyə yalnız yayımçılarda olardı.
int xpOf({required int giftSent, required int giftReceived}) =>
    giftSent + (giftReceived ~/ 2);

/// Səviyyənin rəngi — nişanın fonu.
int levelColor(int level) {
  if (level >= 50) return 0xffff2bd6;
  if (level >= 30) return 0xffb06ab3;
  if (level >= 20) return 0xffffd458;
  if (level >= 10) return 0xff22a7ff;
  return 0xff6f6683;
}

// ============================================================
// VIP
// ============================================================

/// VIP pilləsi: 0 = yoxdur, 1..10 = VIP, 11..13 = SVIP 1..3.
int vipFromSpent(int spent) {
  const steps = <int>[
    1000, // VIP1
    3000,
    7000,
    15000,
    30000,
    60000,
    120000,
    250000,
    500000,
    1000000, // VIP10
    2500000, // SVIP1
    6000000, // SVIP2
    15000000, // SVIP3
  ];

  var tier = 0;
  for (final need in steps) {
    if (spent >= need) {
      tier++;
    } else {
      break;
    }
  }

  return tier;
}

/// Nişanın yazısı: "VIP3", "SVIP1". Pillə yoxdursa boş.
String vipLabel(int tier) {
  if (tier <= 0) return '';
  if (tier <= 10) return 'VIP$tier';
  return 'SVIP${tier - 10}';
}

int vipColor(int tier) {
  if (tier >= 11) return 0xffff2bd6;
  if (tier >= 7) return 0xffffd458;
  if (tier >= 4) return 0xffb06ab3;
  return 0xff22a7ff;
}

/// Növbəti pilləyə nə qədər qalıb. Sonuncudadırsa `null`.
int? spentToNextVip(int spent) {
  const steps = <int>[
    1000, 3000, 7000, 15000, 30000, 60000, 120000,
    250000, 500000, 1000000, 2500000, 6000000, 15000000,
  ];

  for (final need in steps) {
    if (spent < need) return need - spent;
  }

  return null;
}

// ============================================================
// SƏNƏDDƏN OXUMAQ
// ============================================================

/// İstifadəçi sənədindən nişan məlumatı.
class VibeBadges {
  const VibeBadges({required this.level, required this.vip});

  final int level;
  final int vip;

  bool get hasVip => vip > 0;

  String get vipText => vipLabel(vip);

  static VibeBadges from(Map<String, dynamic>? data) {
    int number(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? 0}') ?? 0;

    final sent = number(data?['giftSent']);
    final received = number(data?['giftReceived']);

    return VibeBadges(
      level: levelFromXp(xpOf(giftSent: sent, giftReceived: received)),
      vip: vipFromSpent(sent),
    );
  }
}
