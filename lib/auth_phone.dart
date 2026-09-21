import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_social.dart';
import 'auth_tiktok.dart';
import 'ui/google_mark.dart';
import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// TELEFON NÖMRƏSİ İLƏ GİRİŞ VƏ BƏRPA.
///
/// İki yerdə işlənir:
///  • yeni istifadəçi nömrə ilə qeydiyyatdan keçir / daxil olur;
///  • şifrəsini unudan istifadəçi nömrəsinə gələn kodla girib
///    yeni şifrə təyin edir.
///
/// Nömrə ilə girişin işləməsi üçün Firebase Console-da "Phone" provayderi
/// aktiv olmalıdır. SMS-lərin gündəlik pulsuz limiti var.

/// Daxil edilən nömrəni beynəlxalq formata salır.
///
/// `0501234567` → `+994501234567`, `501234567` → `+994501234567`.
/// Başqa ölkə kodunu istifadəçi özü `+` ilə yaza bilər.
String normalizePhone(String input, {String defaultCode = '+994'}) {
  var digits = input.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('+')) return digits;
  if (digits.startsWith('00')) return '+${digits.substring(2)}';
  if (digits.startsWith('0')) digits = digits.substring(1);
  return '$defaultCode$digits';
}

/// Nömrə görünüşcə düzgündürmü?
bool isValidPhone(String input) {
  final normalized = normalizePhone(input);
  final digits = normalized.replaceAll(RegExp(r'\D'), '');
  return normalized.startsWith('+') && digits.length >= 10 && digits.length <= 15;
}

/// Firebase xətasını istifadəçi dilinə çevirir.
String describePhoneError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Nömrə düzgün deyil. Nümunə: 050 123 45 67';
      case 'too-many-requests':
        return 'Çox cəhd oldu. Bir az sonra yenidən sına.';
      case 'invalid-verification-code':
        return 'Kod yanlışdır. Yenidən yoxla.';
      case 'session-expired':
        return 'Kodun vaxtı bitdi. Yeni kod istə.';
      case 'operation-not-allowed':
        return 'Nömrə ilə giriş Firebase-də aktiv deyil.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return 'Bu nömrə başqa hesaba bağlıdır.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yoxdur.';
      case 'quota-exceeded':
        return 'Bu gün üçün SMS limiti bitib. Sabah yenidən sına.';
      case 'app-not-authorized':
      case 'captcha-check-failed':
        return 'Bu domen Firebase-də icazəli deyil. '
            'Authentication → Settings → Authorized domains bölməsinə '
            'sayt ünvanını əlavə et.';
      case 'missing-client-identifier':
        return 'Təhlükəsizlik yoxlaması keçmədi. Səhifəni yenilə və '
            'yenidən sına.';
      default:
        // Naməlum haldа kodu da göstəririk — problemi tapmaq asan olsun.
        return '${error.message ?? 'Alınmadı'} (${error.code})';
    }
  }
  return 'Alınmadı. Yenidən sına: $error';
}

/// Nömrə ilə giriş / bərpa pəncərəsini açır.
///
/// [mode] axının məqsədini müəyyən edir.
Future<bool> showPhoneAuthSheet(
  BuildContext context, {
  PhoneAuthMode mode = PhoneAuthMode.signIn,
  String initialPhone = '',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheet).viewInsets.bottom,
      ),
      child: _PhoneAuthSheet(mode: mode, initialPhone: initialPhone),
    ),
  );
  return result ?? false;
}

enum PhoneAuthMode {
  /// Nömrə ilə daxil ol və ya yeni hesab yarat.
  signIn,

  /// Mövcud hesaba nömrə bağla (sonradan bərpa üçün).
  link,

  /// Şifrəni unudub — nömrə ilə girib yenisini təyin edir.
  recover,
}

class _PhoneAuthSheet extends StatefulWidget {
  const _PhoneAuthSheet({required this.mode, this.initialPhone = ''});

  final PhoneAuthMode mode;

  /// Əvvəlki ekranda yazılmış nömrə.
  final String initialPhone;

  @override
  State<_PhoneAuthSheet> createState() => _PhoneAuthSheetState();
}

class _PhoneAuthSheetState extends State<_PhoneAuthSheet> {
  final phone = TextEditingController();
  final code = TextEditingController();
  final newPassword = TextEditingController();

  /// Mobil platformada `verifyPhoneNumber` bunu qaytarır.
  String? verificationId;

  /// Veb platformada `signInWithPhoneNumber` bunu qaytarır.
  ConfirmationResult? webConfirmation;

  bool sending = false;
  bool codeSent = false;
  String? error;

  @override
  void initState() {
    super.initState();
    phone.text = widget.initialPhone;
    // Nömrə əvvəlki ekranda yazılıbsa kodu dərhal göndəririk.
    if (widget.initialPhone.isNotEmpty && isValidPhone(widget.initialPhone)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    }
  }

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    newPassword.dispose();
    super.dispose();
  }

  String get _title => switch (widget.mode) {
        PhoneAuthMode.signIn => 'Nömrə ilə davam et',
        PhoneAuthMode.link => 'Nömrəni hesaba bağla',
        PhoneAuthMode.recover => 'Nömrə ilə bərpa et',
      };

  String get _subtitle => switch (widget.mode) {
        PhoneAuthMode.signIn =>
          'Nömrənə 6 rəqəmli kod göndərəcəyik. Şifrə lazım deyil.',
        PhoneAuthMode.link =>
          'Şifrəni unutsan, bu nömrə ilə hesabına geri qayıda biləcəksən.',
        PhoneAuthMode.recover =>
          'Hesabına bağlı nömrəni yaz — kod göndərib yeni şifrə qoymağa '
              'imkan verəcəyik.',
      };

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      error = describePhoneError(e);
      sending = false;
    });
  }

  /// Nömrəyə kod göndərir.
  Future<void> _sendCode() async {
    final number = phone.text.trim();
    if (!isValidPhone(number)) {
      setState(() => error = 'Nömrə düzgün deyil. Nümunə: 050 123 45 67');
      return;
    }

    setState(() {
      sending = true;
      error = null;
    });

    final normalized = normalizePhone(number);

    try {
      if (kIsWeb) {
        // Veb-də Firebase görünməz reCAPTCHA-nı özü idarə edir.
        final confirmation =
            await FirebaseAuth.instance.signInWithPhoneNumber(normalized);
        if (!mounted) return;
        setState(() {
          webConfirmation = confirmation;
          codeSent = true;
          sending = false;
        });
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // Android bəzən kodu özü oxuyur.
          try {
            await _finish(credential);
          } catch (e) {
            _fail(e);
          }
        },
        verificationFailed: _fail,
        codeSent: (id, _) {
          if (!mounted) return;
          setState(() {
            verificationId = id;
            codeSent = true;
            sending = false;
          });
        },
        codeAutoRetrievalTimeout: (id) => verificationId = id,
      );
    } catch (e) {
      _fail(e);
    }
  }

  /// Daxil edilən kodu yoxlayır.
  Future<void> _verifyCode() async {
    final typed = code.text.replaceAll(RegExp(r'\D'), '');
    if (typed.length < 6) {
      setState(() => error = '6 rəqəmli kodu yaz.');
      return;
    }

    setState(() {
      sending = true;
      error = null;
    });

    try {
      if (kIsWeb) {
        final confirmation = webConfirmation;
        if (confirmation == null) throw Exception('sessiya yoxdur');
        final credential = await confirmation.confirm(typed);
        await _afterSignIn(credential.user);
        return;
      }

      final id = verificationId;
      if (id == null) throw Exception('sessiya yoxdur');

      await _finish(PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: typed,
      ));
    } catch (e) {
      _fail(e);
    }
  }

  /// Girişi tamamlayır: nömrəni ya hesaba bağlayır, ya da giriş edir.
  Future<void> _finish(PhoneAuthCredential credential) async {
    final current = FirebaseAuth.instance.currentUser;

    if (widget.mode == PhoneAuthMode.link && current != null) {
      await current.linkWithCredential(credential);
      await _saveProfilePhone(current);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    final result =
        await FirebaseAuth.instance.signInWithCredential(credential);
    await _afterSignIn(result.user);
  }

  Future<void> _afterSignIn(User? user) async {
    if (user == null) return;
    await _saveProfilePhone(user);

    if (!mounted) return;

    // Bərpa axınında dərhal yeni şifrə soruşuruq.
    if (widget.mode == PhoneAuthMode.recover) {
      setState(() => sending = false);
      await _askNewPassword(user);
      return;
    }

    Navigator.pop(context, true);
  }

  /// Profil sənədini yaradır/tamamlayır.
  Future<void> _saveProfilePhone(User user) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();

      await ref.set({
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        if (!snap.exists) 'name': 'VIBE istifadəçisi',
        if (!snap.exists) 'level': 1,
        if (!snap.exists) 'coins': 100,
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'online': true,
      }, SetOptions(merge: true));
    } catch (_) {
      // Profil sonradan da tamamlana bilər.
    }
  }

  /// Bərpa axınının son addımı — yeni şifrə.
  Future<void> _askNewPassword(User user) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => _NewPasswordDialog(user: user),
    );

    if (!mounted) return;
    Navigator.pop(context, saved ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: vLine)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: vLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _title,
              style: const TextStyle(
                color: vInk,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle,
              style: const TextStyle(color: vMuted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 18),
            if (!codeSent) _phoneField() else _codeField(),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(color: vRose, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 18),
            GradientButton(
              label: sending
                  ? 'Gözlə…'
                  : (codeSent ? 'Kodu təsdiqlə' : 'Kod göndər'),
              height: 50,
              gradient: vBrand,
              onPressed:
                  sending ? null : (codeSent ? _verifyCode : _sendCode),
            ),
            if (codeSent) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => setState(() {
                              codeSent = false;
                              code.clear();
                              error = null;
                            }),
                    child: const Text(
                      'Nömrəni dəyiş',
                      style: TextStyle(color: vMuted, fontSize: 13),
                    ),
                  ),
                  const Text('·', style: TextStyle(color: vMuted)),
                  TextButton(
                    onPressed: sending ? null : _sendCode,
                    child: const Text(
                      'Kodu yenidən göndər',
                      style: TextStyle(color: vPink, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _phoneField() => TextField(
        controller: phone,
        autofocus: true,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: vInk, fontSize: 16),
        onChanged: (_) {
          if (error != null) setState(() => error = null);
        },
        decoration: _decoration(
          hint: '050 123 45 67',
          icon: Icons.phone_rounded,
        ),
      );

  Widget _codeField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${normalizePhone(phone.text)} nömrəsinə kod göndərildi',
            style: const TextStyle(color: vMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: vInk,
              fontSize: 22,
              letterSpacing: 8,
              fontWeight: FontWeight.w800,
            ),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            decoration: _decoration(
              hint: '------',
              icon: Icons.sms_rounded,
            ).copyWith(counterText: ''),
          ),
        ],
      );

  InputDecoration _decoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: vMuted, letterSpacing: 0),
      prefixIcon: Icon(icon, color: vMuted, size: 19),
      filled: true,
      fillColor: vBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: vLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: vLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: vPurple, width: 1.4),
      ),
    );
  }
}

/// Bərpadan sonra yeni şifrə təyin etmə pəncərəsi.
class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({required this.user});

  final User user;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final password = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = password.text;
    if (value.length < 6) {
      setState(() => error = 'Şifrə ən az 6 simvol olmalıdır.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await widget.user.updatePassword(value);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      setState(() {
        saving = false;
        error = e.code == 'requires-recent-login'
            ? 'Yenidən daxil ol və bir də cəhd et.'
            : (e.message ?? 'Şifrə dəyişmədi.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: vPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(t('Yeni şifrə'), style: TextStyle(color: vInk)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bundan sonra e-poçt və bu şifrə ilə də daxil ola biləcəksən.',
            style: TextStyle(color: vMuted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: password,
            autofocus: true,
            obscureText: true,
            style: const TextStyle(color: vInk),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            decoration: InputDecoration(
              hintText: t('Ən az 6 simvol'),
              hintStyle: const TextStyle(color: vMuted),
              errorText: error,
              filled: true,
              fillColor: vBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: vLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: vLine),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('İndi yox', style: TextStyle(color: vMuted)),
        ),
        TextButton(
          onPressed: saving ? null : _save,
          child: Text(
            saving ? 'Saxlanır…' : 'Yadda saxla',
            style: const TextStyle(color: vPink),
          ),
        ),
      ],
    );
  }
}


// ============================================================
// TAM EKRAN NÖMRƏ GİRİŞİ
// ============================================================

/// Ölkə kodları — ən çox istifadə olunanlar başda.
const List<({String code, String name, String flag})> phoneCountries = [
  (code: '+994', name: 'Azərbaycan', flag: 'AZ'),
  (code: '+90', name: 'Türkiyə', flag: 'TR'),
  (code: '+7', name: 'Rusiya / Qazaxıstan', flag: 'RU'),
  (code: '+995', name: 'Gürcüstan', flag: 'GE'),
  (code: '+380', name: 'Ukrayna', flag: 'UA'),
  (code: '+971', name: 'BƏƏ', flag: 'AE'),
  (code: '+44', name: 'Böyük Britaniya', flag: 'GB'),
  (code: '+49', name: 'Almaniya', flag: 'DE'),
  (code: '+1', name: 'ABŞ / Kanada', flag: 'US'),
];

/// Nömrə ilə girişin tam ekran variantı.
class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final phone = TextEditingController();
  String country = '+994';

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  bool get _ready => isValidPhone('$country${phone.text.trim()}');

  Future<void> _continue() async {
    final done = await showPhoneAuthSheet(
      context,
      initialPhone: '$country${phone.text.trim()}',
    );
    if (done && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _pickCountry() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: vPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'Ölkə kodu',
                style: TextStyle(
                  color: vInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final item in phoneCountries)
              ListTile(
                leading: Container(
                  width: 38,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: vBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: vLine),
                  ),
                  child: Text(
                    item.flag,
                    style: const TextStyle(
                      color: vInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(item.name, style: const TextStyle(color: vInk)),
                trailing: Text(
                  item.code,
                  style: TextStyle(
                    color: item.code == country ? vPink : vMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () {
                  setState(() => country = item.code);
                  Navigator.pop(sheet);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Qeydiyyatı yarımçıq qoyanda çıxan xatırlatma.
  ///
  /// Məqsəd təzyiq göstərmək deyil — istifadəçiyə başqa, daha sürətli
  /// giriş yollarının olduğunu xatırlatmaqdır.
  Future<bool> _confirmLeave() async {
    final stay = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bir addım qaldı',
              style: TextStyle(
                color: Color(0xff1f1f1f),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Qeydiyyatı bitirən kimi 100 xoş gəldin sikkəsi hesabına düşür.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xff6b6577),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xfff1ecff),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Ləğv et',
                      style: TextStyle(
                        color: Color(0xff8b5cff),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xff8b5cff),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Davam et',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xffe6e2ef))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Digər yollar',
                    style: TextStyle(color: Color(0xff9a94a8), fontSize: 12.5),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xffe6e2ef))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (appleSignInAvailable)
                  _otherWay(
                    background: const Color(0xff121212),
                    child: const Icon(Icons.apple, color: Colors.white, size: 26),
                    onTap: () async {
                      Navigator.pop(dialog, false);
                      await _quickSignIn(signInWithApple);
                    },
                  ),
                if (appleSignInAvailable) const SizedBox(width: 20),
                _otherWay(
                  background: Colors.white,
                  bordered: true,
                  child: const GoogleMark(size: 24),
                  onTap: () async {
                    Navigator.pop(dialog, false);
                    await _quickSignIn(signInWithGoogle);
                  },
                ),
                const SizedBox(width: 20),
                _otherWay(
                  background: const Color(0xff121212),
                  child: const TiktokMark(size: 26),
                  onTap: () {
                    Navigator.pop(dialog, true);
                    showTiktokNotReady(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    return stay == false;
  }

  Widget _otherWay({
    required Color background,
    required Widget child,
    required VoidCallback onTap,
    bool bordered = false,
  }) {
    return Material(
      color: background,
      shape: CircleBorder(
        side: bordered
            ? const BorderSide(color: Color(0xffe0dcea))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 52, height: 52, child: Center(child: child)),
      ),
    );
  }

  /// Dialoqdan seçilən sürətli giriş.
  Future<void> _quickSignIn(Future<dynamic> Function() action) async {
    try {
      await action();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      final message = describeAuthError(error);
      if (mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = phoneCountries.firstWhere(
      (item) => item.code == country,
      orElse: () => phoneCountries.first,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: vBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () async {
            final leave = await _confirmLeave();
            if (leave && mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: vInk, size: 19),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giriş',
                style: TextStyle(
                  color: vInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Telefon nömrəni yaz',
                style: TextStyle(color: vMuted, fontSize: 14.5),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: vPanel,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: vLine),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _pickCountry,
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Text(
                              country,
                              style: const TextStyle(
                                color: vInk,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: vMuted, size: 19),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 26, color: vLine),
                    Expanded(
                      child: TextField(
                        controller: phone,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: vInk,
                          fontSize: 17,
                          letterSpacing: .5,
                        ),
                        decoration: const InputDecoration(
                          hintText: '50 123 45 67',
                          hintStyle: TextStyle(color: vMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${selected.name} · kod SMS ilə gələcək',
                style: const TextStyle(color: vMuted, fontSize: 12.5),
              ),
              const Spacer(),
              GradientButton(
                label: t('SMS ilə davam et'),
                icon: Icons.sms_rounded,
                height: 56,
                fontSize: 16,
                gradient: vBrand,
                onPressed: _ready ? _continue : null,
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Nömrənə 6 rəqəmli kod göndəriləcək',
                  style: TextStyle(color: vMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

