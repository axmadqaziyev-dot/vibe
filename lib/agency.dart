/// Agentlik sistemi.
///
/// SUGO-nun otaqlarını dolduran şey tətbiq deyil — agentliklərdir.
/// Agentlik yayımçı yığır, onlara otaq və izləyici gətirir, qazancdan
/// pay alır. Yayımçı tək başına qalsa, otağı doldura bilmir və gedir.
///
/// Quruluş sadədir:
///
/// * **Agentlik sahibi** — agentliyi quran, yayımçı qəbul edən.
/// * **Yayımçı** — agentliyə qoşulan. Aldığı hədiyyədən pay agentliyə
///   yazılır.
/// * **Kod** — agentliyə qoşulmaq üçün altı simvollu açar. Açıq
///   siyahı olmadan da dəvət etmək mümkün olsun deyə.
///
/// Pay bölgüsü **yayımçının qazancını azaltmır**. Agentliyin payı
/// ayrıca hesablanır və tətbiqin payından çıxır. Əks halda yayımçı
/// agentliyə qoşulmaqdan zərər görərdi və sistem işləməzdi.
library;

import 'dart:math';

/// Agentliyə düşən pay.
///
/// Yayımçının aldığı hədiyyənin bu faizi agentliyin hesabına yazılır.
const double agencyShare = 0.10;

/// Agentlikdə ən çox neçə yayımçı ola bilər.
const int maxAgencyHosts = 200;

/// Hədiyyədən agentliyə düşən məbləğ.
int agencyCut(int giftAmount) {
  if (giftAmount <= 0) return 0;
  return (giftAmount * agencyShare).floor();
}

/// Qoşulma kodu yaradır.
///
/// Səhv oxunan simvollar (0/O, 1/I) çıxarılıb: kod ağızdan-ağıza və
/// ekran şəkli ilə paylaşılır.
String newAgencyCode({Random? random}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random();

  return List.generate(
    6,
    (_) => alphabet[rng.nextInt(alphabet.length)],
  ).join();
}

/// Yazılan kodu təmizləyir: boşluq və kiçik hərf qəbul olunur.
String cleanAgencyCode(String raw) =>
    raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool isValidAgencyCode(String raw) => cleanAgencyCode(raw).length == 6;

/// Agentlikdəki rol.
enum AgencyRole { owner, host, outsider }

class Agency {
  const Agency({
    required this.id,
    required this.name,
    this.logo = '',
    this.about = '',
    this.code = '',
    this.ownerUid = '',
    this.hosts = const [],
    this.earned = 0,
  });

  final String id;
  final String name;
  final String logo;
  final String about;
  final String code;
  final String ownerUid;

  /// Yayımçıların uid-ləri (sahib də daxildir).
  final List<String> hosts;

  /// Agentliyin indiyə qədər topladığı pay.
  final int earned;

  int get hostCount => hosts.length;

  bool get isFull => hosts.length >= maxAgencyHosts;

  AgencyRole roleOf(String uid) {
    if (uid.isEmpty) return AgencyRole.outsider;
    if (uid == ownerUid) return AgencyRole.owner;
    return hosts.contains(uid) ? AgencyRole.host : AgencyRole.outsider;
  }

  bool canManage(String uid) => uid == ownerUid;

  /// Yayımçını çıxara bilərmi?
  bool canRemove(String actor, String target) =>
      actor == ownerUid && target != ownerUid && hosts.contains(target);

  /// Agentlikdən çıxa bilərmi? Sahib çıxa bilmir.
  bool canLeave(String uid) => hosts.contains(uid) && uid != ownerUid;

  static Agency from(String id, Map<String, dynamic> data) {
    int number(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? 0}') ?? 0;

    return Agency(
      id: id,
      name: '${data['name'] ?? 'Agentlik'}',
      logo: '${data['logo'] ?? ''}',
      about: '${data['about'] ?? ''}',
      code: '${data['code'] ?? ''}',
      ownerUid: '${data['ownerUid'] ?? ''}',
      hosts: [
        for (final value in (data['hosts'] as List?) ?? const []) '$value',
      ],
      earned: number(data['earned']),
    );
  }
}

/// Agentliyin adını təmizləyir.
String cleanAgencyName(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Yeni agentlik';
  return value.length > 30 ? value.substring(0, 30) : value;
}
