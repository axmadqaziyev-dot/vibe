/// Qrup söhbətinin qaydaları.
///
/// İki nəfərlik söhbətdə "kim nə edə bilər" sualı yoxdur — hər iki
/// tərəf bərabərdir. Qrupda isə hər şey bu suala bağlıdır: kim yaza
/// bilər, kim üzv çıxara bilər, kim adı dəyişə bilər.
///
/// Qaydalar burada, ekrandan ayrı saxlanılır. Səbəbi budur ki, icazə
/// səhvi ən bahalı səhvdir: adi istifadəçi qrupun sahibini çıxara
/// bilsə, qrup oğurlanır. Ayrı fayl həm sınana bilir, həm də bir
/// yerdən idarə olunur.
///
/// Üç rol var:
///
/// * **Sahib** — qrupu quran. Silinə bilməz, çıxarıla bilməz.
/// * **Admin** — sahibin təyin etdiyi. Üzv əlavə edir, çıxarır,
///   susdurur. Başqa admini çıxara bilməz — yoxsa adminlər bir-birini
///   təmizləyərdi.
/// * **Üzv** — yazır və oxuyur.
library;

/// Qrupdakı rol.
enum GroupRole { owner, admin, member, outsider }

class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.name,
    this.photo = '',
    this.ownerUid = '',
    this.members = const [],
    this.admins = const [],
    this.muted = const [],
    this.onlyAdminsWrite = false,
  });

  final String id;
  final String name;
  final String photo;
  final String ownerUid;

  final List<String> members;
  final List<String> admins;

  /// Susdurulmuş üzvlər — oxuyur, yaza bilmir.
  final List<String> muted;

  /// Yalnız adminlər yaza bilər (elan rejimi).
  final bool onlyAdminsWrite;

  static List<String> _ids(Object? raw) => [
        for (final value in (raw as List?) ?? const []) '$value',
      ];

  static GroupInfo from(String id, Map<String, dynamic> data) => GroupInfo(
        id: id,
        name: '${data['name'] ?? 'Qrup'}',
        photo: '${data['photo'] ?? ''}',
        ownerUid: '${data['ownerUid'] ?? ''}',
        members: _ids(data['members']),
        admins: _ids(data['admins']),
        muted: _ids(data['muted']),
        onlyAdminsWrite: data['onlyAdminsWrite'] == true,
      );

  GroupRole roleOf(String uid) {
    if (uid.isEmpty || !members.contains(uid)) return GroupRole.outsider;
    if (uid == ownerUid) return GroupRole.owner;
    if (admins.contains(uid)) return GroupRole.admin;
    return GroupRole.member;
  }

  bool isManager(String uid) {
    final role = roleOf(uid);
    return role == GroupRole.owner || role == GroupRole.admin;
  }

  /// Yaza bilərmi?
  bool canWrite(String uid) {
    if (roleOf(uid) == GroupRole.outsider) return false;
    if (muted.contains(uid)) return false;
    if (onlyAdminsWrite && !isManager(uid)) return false;
    return true;
  }

  /// Yaza bilmirsə səbəbi.
  String? writeBlockReason(String uid) {
    if (roleOf(uid) == GroupRole.outsider) return 'Qrupda deyilsən.';
    if (muted.contains(uid)) return 'Bu qrupda yazmağın dayandırılıb.';
    if (onlyAdminsWrite && !isManager(uid)) {
      return 'Bu qrupda yalnız adminlər yaza bilər.';
    }
    return null;
  }

  /// [actor] adamı [target]-i qrupdan çıxara bilərmi?
  bool canRemove(String actor, String target) {
    if (actor == target) return false;
    if (target == ownerUid) return false;
    if (!isManager(actor)) return false;

    // Admini yalnız sahib çıxarır — yoxsa adminlər bir-birini
    // təmizləyərdi.
    if (admins.contains(target)) return actor == ownerUid;

    return true;
  }

  /// Susdura bilərmi?
  bool canMute(String actor, String target) => canRemove(actor, target);

  /// Admin təyin etmək yalnız sahibin işidir.
  bool canPromote(String actor, String target) =>
      actor == ownerUid &&
      target != ownerUid &&
      members.contains(target);

  /// Qrupun adını və şəklini dəyişmək.
  bool canEdit(String uid) => isManager(uid);

  /// Üzv əlavə etmək.
  bool canInvite(String uid) => isManager(uid);

  /// Qrupdan çıxmaq. Sahib çıxa bilmir — əvvəlcə sahibliyi ötürməlidir.
  bool canLeave(String uid) =>
      members.contains(uid) && uid != ownerUid;
}

/// Qrupun adı boş qala bilməz.
String cleanGroupName(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Yeni qrup';
  return value.length > 40 ? value.substring(0, 40) : value;
}

/// Üzv sayı həddi.
///
/// Mesh səs və bildiriş yükünə görə məhdudlaşdırılıb; böyük icma
/// üçün otaqlar var.
const int maxGroupMembers = 50;
