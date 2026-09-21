// HÜQUQİ MƏTNLƏR VƏ İCMA QAYDALARI.
//
// App Store Review Guideline 1.2 (istifadəçi məzmunu olan tətbiqlər) tələb edir:
//  • sıfır dözümlülük bildirən şərtlər və qeydiyyatda razılıq
//  • uyğunsuz məzmunu süzgəcdən keçirmə üsulu
//  • şikayət mexanizmi
//  • sui-istifadə edən istifadəçini bloklamaq imkanı
//  • tərtibatçı ilə əlaqə yolu

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// Dəstək üçün əlaqə. App Store Connect-dəki "Support URL/Email" ilə
/// eyni olmalıdır.
const supportEmail = 'asifnasrullazade@gmail.com';

/// Tətbiqin adı və hüquqi sahibinin adı (mağaza qeydiyyatı ilə uyğun olmalıdır).
const appLegalName = 'VIBE';

// ============================================================
// MƏTNLƏR
// ============================================================

const communityRules = '''
VIBE-də hamı özünü təhlükəsiz hiss etməlidir. Aşağıdakılara SIFIR DÖZÜMLÜLÜK var:

• Təhqir, hədə, təqib və nifrət nitqi
• Cinsi məzmun, çılpaqlıq və uşaqlara aid istənilən uyğunsuz məzmun
• 18 yaşdan kiçiklərin tətbiqdən istifadəsi
• Spam, saxta profil, fırıldaqçılıq və pul tələbi
• Qumar, narkotik, silah və qanunsuz fəaliyyətin təşviqi
• Başqasının şəxsi məlumatını icazəsiz paylaşmaq

Qaydaları pozan məzmun silinir, hesab isə xəbərdarlıq olmadan dayandırıla bilər.

Nə edə bilərsən:
• İstənilən profil və ya mesajı "..." menyusundan ŞİKAYƏT ET
• Səni narahat edəni BLOKLA — o səni görə və yaza bilməyəcək
• Şikayətlər 24 saat ərzində nəzərdən keçirilir
''';

const termsText = '''
1. Qəbul
VIBE-dən istifadə etməklə bu şərtləri və İcma qaydalarını qəbul edirsən.

2. Yaş həddi
Tətbiq 18 yaşdan yuxarı şəxslər üçündür. Yaşı uyğun olmayan hesablar silinir.

3. Sənin məzmunun
Paylaşdığın şəkil, video, mesaj və səs yazılarına görə sən cavabdehsən.
Uyğunsuz məzmuna görə SIFIR DÖZÜMLÜLÜK tətbiq olunur: belə məzmun silinir,
hesab dayandırılır.

4. Davranış
Başqalarını təhqir etmək, hədələmək, təqib etmək, saxta profil yaratmaq və
fırıldaqçılıq qadağandır.

5. Virtual coinlər
VIBE coin yalnız tətbiqdaxili virtual vahiddir. Real pul dəyəri yoxdur,
geri ödənilmir və başqa şəxsə satıla bilməz.

6. Hesabın dayandırılması
Qaydaların pozulması halında hesab xəbərdarlıq olmadan dayandırıla bilər.

7. Hesabın silinməsi
İstədiyin vaxt Ayarlar → "Hesabı həmişəlik sil" bölməsindən hesabını silə bilərsən.

8. Məsuliyyətin məhdudlaşdırılması
Tətbiq "olduğu kimi" təqdim olunur. İstifadəçilər arasındakı münasibətlərə
görə məsuliyyət daşımırıq.

9. Əlaqə
Sual və şikayət üçün: $supportEmail
''';

const privacyText = '''
Hansı məlumatları toplayırıq
• Hesab: ad, e-poçt, yaş/doğum tarixi, şəhər, profil şəkli
• İstifadə: mesajlar, paylaşımlar, bəyənmələr, otaq fəaliyyəti
• Texniki: son giriş vaxtı, onlayn statusu

Niyə toplayırıq
• Hesabı yaratmaq və qorumaq
• Mesaj, zəng və otaqların işləməsi
• Sui-istifadənin qarşısını almaq (şikayət və bloklama)

Harada saxlanılır
Məlumatlar Google Firebase (Firestore, Authentication, Storage) üzərində
saxlanılır və ötürülmə şifrələnir.

Kiminlə paylaşılır
Məlumatlarını reklam üçün satmırıq. Yalnız qanuni tələb olduqda və
xidmətin işləməsi üçün Firebase ilə paylaşılır.

Sənin hüquqların
• Profil məlumatlarını istənilən vaxt dəyişə bilərsən
• Hesabı və məlumatları tətbiq daxilindən tam silə bilərsən
  (Ayarlar → Hesabı həmişəlik sil)
• Sualların üçün: $supportEmail
''';

// ============================================================
// UYĞUNSUZ MƏZMUN SÜZGƏCİ
// ============================================================

/// Sadə söz süzgəci. Tam moderasiya deyil — şikayət və bloklama ilə birlikdə
/// işləyir. Siyahını genişləndirmək asandır.
const _bannedWords = <String>[
  // Azərbaycan / Türk
  'sik', 'sikim', 'sikiw', 'amcıq', 'amciq', 'orospu', 'oruspu',
  'piç', 'pic ', 'qəhbə', 'qehbe', 'göt ver', 'got ver',
  'anan', 'anani', 'ananı', 'bacını', 'bacini',
  // İngilis
  'fuck', 'bitch', 'whore', 'cunt', 'nigger', 'rape',
  // Uşaq istismarı ilə bağlı — mütləq blok
  'child porn', 'cp video', 'pedo',
];

/// Mətn qaydaları pozursa, səbəbi qaytarır; təmizdirsə `null`.
String? objectionableReason(String text) {
  final lower = text.toLowerCase();

  for (final word in _bannedWords) {
    if (lower.contains(word)) {
      return 'Mesajda qadağan olunmuş ifadə var. VIBE-də təhqir və '
          'uyğunsuz məzmuna sıfır dözümlülük var.';
    }
  }

  // Sadə spam: eyni simvolun həddindən çox təkrarı
  if (RegExp(r'(.)\1{25,}').hasMatch(text)) {
    return 'Mesaj spam kimi görünür.';
  }

  return null;
}

/// Qadağan olunmuş sözləri ulduzla örtür.
///
/// Göndərmə anındakı süzgəcdən fərqli olaraq bu, MƏTNİ GÖSTƏRƏRKƏN işləyir —
/// köhnə mesajlar və süzgəci yan keçən yazılışlar da ekranda görünmür.
String maskProfanity(String text) {
  if (text.isEmpty) return text;

  var result = text;
  for (final word in _bannedWords) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) continue;
    result = result.replaceAll(
      RegExp(RegExp.escape(trimmed), caseSensitive: false),
      '*' * trimmed.length,
    );
  }
  return result;
}

/// Mətni yoxlayır; problem varsa istifadəçiyə bildirir və `false` qaytarır.
bool guardContent(BuildContext context, String text) {
  final reason = objectionableReason(text);
  if (reason == null) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xff4a1020),
      content: Text(reason),
      duration: const Duration(seconds: 4),
    ),
  );
  return false;
}

// ============================================================
// SƏHİFƏLƏR
// ============================================================

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  static void openTerms(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const LegalPage(title: 'İstifadə şərtləri', body: termsText),
    ),
  );

  static void openPrivacy(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const LegalPage(title: 'Məxfilik siyasəti', body: privacyText),
    ),
  );

  static void openRules(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const LegalPage(title: 'İcma qaydaları', body: communityRules),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: vBg,
    appBar: AppBar(
      backgroundColor: const Color(0xff0b0711),
      foregroundColor: Colors.white,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Text(
          body.trim(),
          style: const TextStyle(color: Color(0xffd0c8de), height: 1.6, fontSize: 14),
        ),
        const SizedBox(height: 26),
        PressableScale(
          onTap: () {
            Clipboard.setData(const ClipboardData(text: supportEmail));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('E-poçt kopyalandı.'))),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: vPanel.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: vLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline_rounded, color: vPurple),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Dəstək və şikayət',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const Text(supportEmail, style: TextStyle(color: vMuted, fontSize: 12)),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 15, color: vMuted),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
