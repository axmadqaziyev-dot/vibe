/// Ailə (klan) sistemi — model və hesablamalar.
///
/// Ailə bir neçə adamı bir ad altında birləşdirir: birlikdə xəzinə yığır,
/// səviyyə qazanır və reytinqdə yarışırlar. Otaqlarda tək-tək gəzən adamı
/// tətbiqdə saxlayan ən güclü şey məhz belə qruplardır.
///
/// Hesablamalar burada ayrıca saxlanılır ki, ekrandan asılı olmadan
/// yoxlanıla bilsin.
library;

/// Ailə yaratmağın qiyməti.
///
/// Qəsdən bahadır: hər kəs ailə açsa siyahı yüzlərlə ölü qrupla dolar.
/// Bu qiymət təxminən bir neçə günlük fəallığın qarşılığıdır.
const int familyCreateCost = 5000;

/// Bir ailədə ən çox neçə nəfər ola bilər.
const int familyMaxMembers = 100;

/// Ailənin yönü — siyahıda süzgəc kimi işlənir.
enum FamilyKind { country, wealth, fans, duel, social }

extension FamilyKindInfo on FamilyKind {
  String get id => name;

  String get label => switch (this) {
        FamilyKind.country => 'Ölkə',
        FamilyKind.wealth => 'Sərvət',
        FamilyKind.fans => 'Fanlar',
        FamilyKind.duel => 'Düello',
        FamilyKind.social => 'Sosial',
      };

  String get emoji => switch (this) {
        FamilyKind.country => '🌍',
        FamilyKind.wealth => '💎',
        FamilyKind.fans => '⭐',
        FamilyKind.duel => '⚔️',
        FamilyKind.social => '💬',
      };
}

/// Mətn açarından yönü tapır; tanınmasa sosial sayılır.
FamilyKind familyKindFrom(Object? value) {
  final id = '$value';
  for (final kind in FamilyKind.values) {
    if (kind.id == id) return kind;
  }
  return FamilyKind.social;
}

/// Səviyyə üçün lazım olan xəzinə həddi.
///
/// Hər səviyyə əvvəlkindən təxminən iki dəfə çətindir — belə olanda
/// yüksək səviyyə həqiqətən nadir qalır.
const List<int> familyLevels = [
  0,
  10000,
  25000,
  60000,
  150000,
  400000,
  1000000,
];

/// Xəzinəyə görə səviyyə (1-dən başlayır).
int familyLevel(int treasure) {
  var level = 1;
  for (var i = 1; i < familyLevels.length; i++) {
    if (treasure >= familyLevels[i]) level = i + 1;
  }
  return level;
}

/// Növbəti səviyyəyə qalan məsafə (0..1). Ən yuxarıda 1 qaytarır.
double familyProgress(int treasure) {
  final level = familyLevel(treasure);
  if (level >= familyLevels.length) return 1;

  final from = familyLevels[level - 1];
  final to = familyLevels[level];
  if (to <= from) return 1;

  return ((treasure - from) / (to - from)).clamp(0.0, 1.0);
}

/// Növbəti səviyyəyə neçə sikkə qalıb. Ən yuxarıda 0.
int familyToNextLevel(int treasure) {
  final level = familyLevel(treasure);
  if (level >= familyLevels.length) return 0;
  return familyLevels[level] - treasure;
}

/// Ailə adının yoxlanışı.
///
/// Boş və ya bir hərflik ad siyahıda tanınmır; həddindən artıq uzun ad
/// kartı dağıdır. Yalnız boşluqdan ibarət ad da qəbul edilmir.
String? familyNameError(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Ailənin adını yaz.';
  if (trimmed.length < 3) return 'Ad ən azı 3 hərf olmalıdır.';
  if (trimmed.length > 20) return 'Ad 20 hərfdən uzun ola bilməz.';
  return null;
}

/// Ailə haqqında yazının yoxlanışı.
String? familyAboutError(String about) {
  if (about.trim().length > 200) return 'Təsvir 200 hərfdən uzun ola bilməz.';
  return null;
}
