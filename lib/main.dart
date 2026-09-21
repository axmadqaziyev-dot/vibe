import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'call_log.dart';
import 'calls.dart';
import 'social_ui.dart';
import 'preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'voice/voice_composer.dart';
import 'voice/voice_hold.dart';
import 'voice/voice_message_service.dart';
import 'voice/voice_player.dart';
import 'user_profile.dart';
import 'vibe_video.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'media_store.dart';
import 'games/domino_page.dart';
import 'moments.dart';
import 'party_rooms.dart' show PartyRoomPage;
import 'vibe_status.dart';
import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';
import 'ui/welcome_art.dart';
import 'ui/welcome_backdrop.dart';
import 'blocking.dart';
import 'email_verify.dart';
import 'onboarding.dart';
import 'auth_social.dart';
import 'auth_tiktok.dart';
import 'auth_phone.dart';
import 'coin_wallet.dart';
import 'daily_reward.dart';
import 'chat_themes.dart';
import 'chat_filter.dart';
import 'chat_lock.dart';
import 'message_chime.dart';
import 'whats_new.dart';
import 'legal.dart';
import 'push_notifications.dart';
import 'server_time.dart';
import 'push_send.dart';
import 'moment_create.dart';
import 'photo_pick.dart';
import 'app/i18n.dart';
import 'telemetry.dart';
import 'home_discover.dart';
import 'install_app.dart';
import 'messages_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Çökmələri və hadisələri toplamağa başla — gözləmədən.
  Telemetry.start();

  // Push: arxa plan handler-i runApp-dan ƏVVƏL qeydə alınmalıdır.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  // Media anbarı — video və səsli mesajlar burada saxlanılır.
  // Bu açar açıqdır (hər istifadəçinin cihazında olur); gizli açar deyil.
  // Supabase hazırda yalnız fayl saxlamaq üçündür (şəkil, video, səs).
  // Məlumat bazası Firebase-dədir.
  //
  // Supabase cədvəllərinə keçmək istəsək, buraya accessToken əlavə olunmalıdır
  // ki, Firebase girişi Supabase tərəfdə tanınsın — şərtlər SUPABASE_KECID.md-də.
  // O parametri vaxtından əvvəl əlavə etmək olmaz: Supabase tanımadığı tokeni
  // rədd edir və fayl yükləmə dayanır.
  await Supabase.initialize(
    url: 'https://txjqqohqownpfcokscep.supabase.co',
    publishableKey: 'sb_publishable_P6hJ0hoQXAz_rZ6lWBwTLA_dLT-edZB',
  );

  final prefs = await SharedPreferences.getInstance();

  // Vebdə setPersistence yalnız istifadəçi "məni xatırla"nı söndürəndə
  // çağırılır.
  //
  // Əvvəl hər açılışda çağırılırdı — həmçinin LOCAL üçün, halbuki LOCAL
  // onsuz da standartdır. O çağırış giriş vəziyyəti bərpa olunmamış işə
  // düşür və istifadəçini çıxara bilir: yeni versiya gələndə səhifə
  // yenilənir və adam özünü giriş ekranında tapır.
  //
  // İndi standart hal heç nəyə toxunmur; yalnız "xatırlama" seçimi
  // söndürüləndə sessiya rejiminə keçirilir.
  if (kIsWeb && prefs.getBool('rememberMe') == false) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

  if (!kIsWeb && prefs.getBool('rememberMe') == false) {
    await FirebaseAuth.instance.signOut();
  }

  appearance.value = (prefs.getInt('appearance') ?? 0).clamp(
    0,
    accentColors.length - 1,
  );

  await loadLanguage(prefs);

  runApp(const VibeApp());

  // Google/Apple yönləndirməsindən qayıdıbsa, girişi tamamla.
  //
  // Bu, tətbiq işə düşəndən SONRA və gözləmədən çağırılır: əks halda
  // sorğu ləngiyəndə ekran boş qalır.
  unawaited(
    handleRedirectSignIn().timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    ),
  );

  // İlk kadr çəkiləndə HTML açılış ekranını söndür.
  WidgetsBinding.instance.addPostFrameCallback((_) => hideStartupSplash());
}

// ============================================================
// VIBE APP
// ============================================================

class VibeApp extends StatelessWidget {
  const VibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLanguage,
      builder: (context, language, __) => ValueListenableBuilder<int>(
      valueListenable: appearance,
      builder: (context, accent, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'VIBE',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentColors[accent],
              brightness: Brightness.dark,
              surface: const Color(0xff100b18),
            ),
            scaffoldBackgroundColor: const Color(0xff070510),
            canvasColor: const Color(0xff0d0914),
            cardColor: const Color(0xff151020),
            dividerColor: const Color(0xff2d2540),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Color(0xfff7f3ff)),
              bodyMedium: TextStyle(color: Color(0xfff7f3ff)),
              bodySmall: TextStyle(color: Color(0xffa89fbd)),
              titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              titleSmall: TextStyle(color: Color(0xffd8d0e7)),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xff0b0711),
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xff1a1225),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              behavior: SnackBarBehavior.floating,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xff151020),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xff120d1d),
              modalBackgroundColor: Color(0xff120d1d),
              surfaceTintColor: Colors.transparent,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xff171121),
              hintStyle: const TextStyle(color: Color(0xff8f879f)),
              labelStyle: const TextStyle(color: Color(0xffb8afc9)),
              prefixIconColor: const Color(0xffa98cff),
              suffixIconColor: const Color(0xffb8afc9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xff342743)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xffff2bd6), width: 1.4),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
            chipTheme: ChipThemeData(
              side: const BorderSide(color: Color(0xff342743)),
              backgroundColor: const Color(0xff171121),
              selectedColor: accentColors[accent].withValues(alpha: .32),
              labelStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: const Color(0xff09060f),
              indicatorColor: accentColors[accent].withValues(alpha: .24),
              labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                color: states.contains(WidgetState.selected) ? Colors.white : const Color(0xff8f879f),
                fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              )),
              iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? const Color(0xffff2bd6) : const Color(0xff8f879f),
              )),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: accentColors[accent],
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xff62437f)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          builder: (context, child) {
            return child ?? const SizedBox.shrink();
          },
          home: const AuthGate(),
        );
      },
      ),
    );
  }
}


// ============================================================
// ONLINE / LAST SEEN
// ============================================================

bool isReallyOnline(Map<String, dynamic> data) {
  final lastSeen = data['lastSeen'];

  if (data['online'] != true || lastSeen is! Timestamp) {
    return false;
  }

  // Serverin saatı ilə ölçülür. Telefonun saatı ilə ölçülsəydi,
  // bir dəqiqəlik fərq kifayət edərdi ki, heç kim onlayn
  // görünməsin — pəncərə cəmi 45 saniyədir.
  final difference = sinceServer(lastSeen.toDate());

  return difference.inSeconds >= -5 && difference.inSeconds <= 45;
}

String activityText(Map<String, dynamic> data) {
  final lastSeen = data['lastSeen'];

  if (lastSeen is! Timestamp) {
    return 'Son görülmə bilinmir';
  }

  final time = lastSeen.toDate();
  final difference = sinceServer(time);

  if (isReallyOnline(data)) {
    return 'İndi aktivdir';
  }

  if (difference.inMinutes < 1) {
    return 'Son görülmə: indi';
  }

  if (difference.inMinutes < 60) {
    return 'Son görülmə: ${difference.inMinutes} dəqiqə əvvəl';
  }

  if (difference.inHours < 24) {
    return 'Son görülmə: ${difference.inHours} saat əvvəl';
  }

  if (difference.inDays == 1) {
    return 'Son görülmə: dünən '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  return 'Son görülmə: '
      '${time.day.toString().padLeft(2, '0')}.'
      '${time.month.toString().padLeft(2, '0')}.'
      '${time.year} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

DateTime? _lastSeenDate(Map<String, dynamic> data) {
  final value = data['lastSeen'];

  if (value is Timestamp) {
    return value.toDate();
  }

  return null;
}

int compareUsersByActivity(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final aData = a.data();
  final bData = b.data();

  final aOnline = isReallyOnline(aData);
  final bOnline = isReallyOnline(bData);

  if (aOnline != bOnline) {
    return aOnline ? -1 : 1;
  }

  final aLastSeen = _lastSeenDate(aData);
  final bLastSeen = _lastSeenDate(bData);

  if (aLastSeen == null && bLastSeen == null) {
    return 0;
  }

  if (aLastSeen == null) {
    return 1;
  }

  if (bLastSeen == null) {
    return -1;
  }

  return bLastSeen.compareTo(aLastSeen);
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingPage();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const WelcomePage();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorPage(text: 'Profil xətası:\n${snapshot.error}');
            }

            if (!snapshot.hasData) {
              return const LoadingPage();
            }

            if (!snapshot.data!.exists || snapshot.data!.data() == null) {
              return MissingProfilePage(user: user);
            }

            final data = snapshot.data!.data()!;

            // Moderasiya: dayandırılmış hesab tətbiqə girə bilməz.
            if (data['suspended'] == true) {
              return SuspendedPage(
                reason: '${data['suspendedReason'] ?? ''}',
              );
            }

            // Profil yarımçıqdırsa, əvvəlcə onu tamamlayır.
            if (needsOnboarding(data)) {
              return OnboardingPage(uid: user.uid, data: data);
            }

            return MainScreen(profile: UserProfile.fromMap(data));
          },
        );
      },
    );
  }
}

/// Dayandırılmış hesab üçün ekran.
class SuspendedPage extends StatelessWidget {
  const SuspendedPage({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: vBg,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: vRose.withValues(alpha: .18),
                border: Border.all(color: vRose.withValues(alpha: .5)),
              ),
              child: const Icon(Icons.gavel_rounded, color: vRose, size: 38),
            ),
            const SizedBox(height: 22),
            const Text(
              'Hesabın dayandırılıb',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reason.isEmpty
                  ? 'İcma qaydalarının pozulması səbəbindən hesabın müvəqqəti '
                        'dayandırılıb.'
                  : 'Səbəb: $reason',
              textAlign: TextAlign.center,
              style: const TextStyle(color: vMuted, height: 1.5),
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Dəstəyə yaz',
              icon: Icons.mail_outline_rounded,
              expand: false,
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: supportEmail));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-poçt kopyalandı.')),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text(
                'Çıxış et',
                style: TextStyle(color: vMuted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ErrorPage extends StatelessWidget {
  final String text;

  const ErrorPage({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

/// Hesab var, amma Firestore-da profil sənədi yoxdur — məsələn ilk yazma
/// şəbəkə xətası ilə kəsilib. Çıxış etdirmək əvəzinə profili burada yaradırıq.
class MissingProfilePage extends StatelessWidget {
  const MissingProfilePage({super.key, required this.user});

  final User user;

  Future<void> _create() async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : 'VIBE istifadəçisi',
      'email': user.email ?? '',
      if ((user.photoURL ?? '').isNotEmpty) 'photoUrl': user.photoURL,
      'level': 1,
      'coins': 100,
      'online': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      body: AuroraBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_alt_1_rounded,
                    color: vPink, size: 56),
                const SizedBox(height: 18),
                const Text(
                  'Profilin hazır deyil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: vInk,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hesabın var, amma profil məlumatların yazılmayıb. '
                  'Bir toxunuşla tamamlayaq.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vMuted, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 22),
                GradientButton(
                  label: 'Profili yarat',
                  expand: false,
                  gradient: vBrand,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _create();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Alınmadı: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Çıxış et',
                      style: TextStyle(color: vMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WELCOME
// ============================================================

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String lang = 'AZ';
  int guestTab = 0;

  /// Giriş əməliyyatı gedir — düymələr bağlanır.
  bool authBusy = false;

  static const Map<String, Map<String, String>> t = {
    'AZ': {
      'home': 'Ana səhifə', 'discover': 'Kəşf et', 'live': 'Canlı',
      'messages': 'Mesajlar', 'login': 'Daxil ol',
      'people': 'Real People', 'connections': 'Real Connections',
      'desc': 'Yeni insanlarla tanış ol,\nsöhbət et, dostluq qur və\nhəyatına yeni rəng qat!',
      'start': 'Başla  →', 'create': 'Yeni hesab yarat',
      'f1': 'Real insanlar', 's1': 'Dünya üzrə',
      'f2': 'Real söhbətlər', 's2': 'Səmimi ünsiyyət',
      'f3': 'Real əlaqələr', 's3': 'Yeni imkanlar',
      'f4': 'Sərhədsiz tanışlıq', 's4': 'Hər yerdən, hər zaman',
    },
    'TR': {
      'home': 'Ana sayfa', 'discover': 'Keşfet', 'live': 'Canlı',
      'messages': 'Mesajlar', 'login': 'Giriş yap',
      'people': 'Gerçek İnsanlar', 'connections': 'Gerçek Bağlantılar',
      'desc': 'Yeni insanlarla tanış,\nsohbet et, arkadaşlık kur ve\nhayatına yeni renk kat!',
      'start': 'Başla  →', 'create': 'Yeni hesap oluştur',
      'f1': 'Gerçek insanlar', 's1': 'Dünya çapında',
      'f2': 'Gerçek sohbetler', 's2': 'Samimi iletişim',
      'f3': 'Gerçek bağlantılar', 's3': 'Yeni fırsatlar',
      'f4': 'Sınırsız tanışma', 's4': 'Her yerde, her zaman',
    },
    'EN': {
      'home': 'Home', 'discover': 'Discover', 'live': 'Live',
      'messages': 'Messages', 'login': 'Log in',
      'people': 'Real People', 'connections': 'Real Connections',
      'desc': 'Meet new people,\nchat, make friends and\nadd new colors to your life!',
      'start': 'Start  →', 'create': 'Create account',
      'f1': 'Real people', 's1': 'Worldwide',
      'f2': 'Real conversations', 's2': 'Genuine communication',
      'f3': 'Real connections', 's3': 'New possibilities',
      'f4': 'No boundaries', 's4': 'Anywhere, anytime',
    },
    'RU': {
      'home': 'Главная', 'discover': 'Знакомства', 'live': 'Эфир',
      'messages': 'Сообщения', 'login': 'Войти',
      'people': 'Настоящие люди', 'connections': 'Настоящие связи',
      'desc': 'Знакомься с новыми людьми,\nобщайся, находи друзей и\nдобавляй ярких красок в жизнь!',
      'start': 'Начать  →', 'create': 'Создать аккаунт',
      'f1': 'Настоящие люди', 's1': 'По всему миру',
      'f2': 'Живое общение', 's2': 'Искренние разговоры',
      'f3': 'Настоящие связи', 's3': 'Новые возможности',
      'f4': 'Без границ', 's4': 'Везде и всегда',
    },
  };

  String x(String key) => t[lang]![key]!;

  void openSection(int index) {
    setState(() => guestTab = index);
  }

  void openPage(Widget page) {
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => ColoredBox(
        color: const Color(0xff05030d),
        child: page,
      ),
      transitionsBuilder: (_, __, ___, child) => child,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 760;
    return Scaffold(
      backgroundColor: const Color(0xff05030d),
      body: mobile ? _mobile() : _desktop(),
    );
  }

  Widget _desktop() {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Arxa fon şəkli — heç bir qara container/maska yoxdur.
          // VIBE fonu — şəkil faylı tələb etmir.
          const ColoredBox(color: Color(0xff05030d)),
          // Dekorativ neon işıq və böyük ürək çıxarıldı.
          // Yuxarı menyu.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 82,
            child: Container(
              color: const Color(0xff080613).withValues(alpha: .94),
              padding: EdgeInsets.symmetric(horizontal: w * .038),
              child: Row(
                children: [
                  _logo(32),
                  SizedBox(width: w * .065),
                  _nav(x('home'), active: guestTab == 0, onTap: () => openSection(0)),
                  SizedBox(width: w * .038),
                  _nav(x('discover'), active: guestTab == 1, onTap: () => openSection(1)),
                  SizedBox(width: w * .038),
                  _nav(x('live'), active: guestTab == 2, onTap: () => openSection(2)),
                  SizedBox(width: w * .038),
                  _nav(x('messages'), active: guestTab == 3, onTap: () => openSection(3)),
                  const Spacer(),
                  const Icon(
                    Icons.language_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: lang,
                      dropdownColor: const Color(0xff151022),
                      iconEnabledColor: Colors.white70,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      items: const {
                        'AZ': '🇦🇿  AZ',
                        'TR': '🇹🇷  TR',
                        'EN': '🇬🇧  EN',
                        'RU': '🇷🇺  RU',
                      }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => lang = v ?? lang),
                    ),
                  ),
                  const SizedBox(width: 28),
                  OutlinedButton(
                    onPressed: () => openPage(const LoginPage()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xffff31db),
                        width: 1.2,
                      ),
                      minimumSize: const Size(128, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      x('login'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sol tərəfdə yalnız Ana səhifədə görünən əsas yazılar və düymə.
          if (guestTab == 0)
            Positioned(
            left: w * .055,
            top: h * .17,
            width: w * .30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _logo((w * .075).clamp(58, 112).toDouble()),
                SizedBox(height: h * .012),
                Text(
                  '${x('people')}\n${x('connections')}',
                  style: TextStyle(
                    color: const Color(0xffff43d7),
                    fontSize: (w * .021).clamp(27, 39).toDouble(),
                    height: 1.15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: h * .03),
                Text(
                  x('desc'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .76),
                    fontSize: (w * .014).clamp(17, 25).toDouble(),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: h * .032),
                SizedBox(
                  width: w * .255,
                  height: 62,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(40)),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xff13b9ff),
                          Color(0xff7657ff),
                          Color(0xffff10c8),
                        ],
                      ),
                    ),
                    child: TextButton(
                      onPressed: () => openPage(const LoginPage()),
                      child: Text(
                        x('start'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: w * .255,
                  child: TextButton(
                    onPressed: () => openPage(const RegisterPage()),
                    child: Text(
                      x('create'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sağ tərəfdə illüstrasiya — yalnız Ana səhifədə.
          if (guestTab == 0)
            Positioned(
              right: w * .045,
              top: h * .13,
              width: (w * .44).clamp(320.0, 720.0).toDouble(),
              height: (h * .68).clamp(260.0, 620.0).toDouble(),
              child: const VibeWelcomeArt(height: double.infinity),
            ),

          if (guestTab != 0)
            Positioned(
              left: w * .055,
              right: w * .055,
              top: 110,
              bottom: 125,
              child: _guestPreview(w, h),
            ),

          // Aşağıdakı 4 xüsusiyyət — ayrıca qara panel YOXDUR.
          Positioned(
            left: w * .045,
            right: w * .045,
            bottom: 28,
            height: 82,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => openSection(1),
                    borderRadius: BorderRadius.circular(18),
                    child: _feature(
                      Icons.group_outlined,
                      x('f1'),
                      x('s1'),
                    ),
                  ),
                ),
                _divider(),
                Expanded(
                  child: InkWell(
                    onTap: () => openSection(3),
                    borderRadius: BorderRadius.circular(18),
                    child: _feature(
                      Icons.chat_bubble_outline_rounded,
                      x('f2'),
                      x('s2'),
                    ),
                  ),
                ),
                _divider(),
                Expanded(
                  child: InkWell(
                    onTap: () => openSection(1),
                    borderRadius: BorderRadius.circular(18),
                    child: _feature(
                      Icons.favorite_border_rounded,
                      x('f3'),
                      x('s3'),
                    ),
                  ),
                ),
                _divider(),
                Expanded(
                  child: InkWell(
                    onTap: () => openSection(1),
                    borderRadius: BorderRadius.circular(18),
                    child: _feature(
                      Icons.language_rounded,
                      x('f4'),
                      x('s4'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _guestPreview(double w, double h) {
    if (guestTab == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kəşf et',
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'VIBE-də yeni insanları kəşf et',
            style: TextStyle(color: Color(0xffaaa3c5), fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                _guestCard(Icons.person_rounded, 'Yeni insanlar', 'Yeni qoşulan profillərə bax'),
                const SizedBox(width: 18),
                _guestCard(Icons.bolt_rounded, 'İndi aktiv', 'Hazırda aktiv olanları kəşf et'),
                const SizedBox(width: 18),
                _guestCard(Icons.location_on_outlined, 'Yaxınlıqda', 'Sənə yaxın insanları tap'),
              ],
            ),
          ),
        ],
      );
    }

    if (guestTab == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Canlı',
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Canlı otaqlara bax və VIBE atmosferini gör',
            style: TextStyle(color: Color(0xffaaa3c5), fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                _guestCard(Icons.mic_none_rounded, 'Söhbət otaqları', 'Canlı söhbətlərə bax'),
                const SizedBox(width: 18),
                _guestCard(Icons.videocam_outlined, 'Video canlı', 'Canlı yayımları kəşf et'),
                const SizedBox(width: 18),
                _guestCard(Icons.groups_2_outlined, 'Populyar otaqlar', 'Ən aktiv otaqları gör'),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mesajlar',
          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'VIBE söhbətlərinin necə işlədiyini gör',
          style: TextStyle(color: Color(0xffaaa3c5), fontSize: 16),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            children: [
              _guestCard(Icons.chat_bubble_outline_rounded, 'Real söhbətlər', 'Sürətli və rahat mesajlaşma'),
              const SizedBox(width: 18),
              _guestCard(Icons.emoji_emotions_outlined, 'Emoji və stiker', 'Söhbətlərini daha əyləncəli et'),
              const SizedBox(width: 18),
              _guestCard(Icons.lock_outline_rounded, 'Şəxsi mesajlar', 'Real ünsiyyət üçün hesabına daxil ol'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guestCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: InkWell(
        onTap: () => openPage(const LoginPage()),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xff0d0a18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xff2d2440)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xffff32d7), size: 56),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xffaaa3c5), fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobile() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const VibeWelcomeBackdrop(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _langPill(),
                    const Spacer(),
                    _supportButton(),
                  ],
                ),
                const SizedBox(height: 6),
                _logo(44),
                const Spacer(),
                Text(
                  '${x('people')} · ${x('connections')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xffe6dcff),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                // Apple yuxarıda, Google altda — mağaza tətbiqlərindəki sıra.
                if (appleSignInAvailable) ...[
                  WelcomeAuthButton(
                    label: 'Apple ilə davam et',
                    icon: const Icon(Icons.apple, size: 26, color: Colors.black),
                    onPressed: authBusy ? null : _welcomeApple,
                  ),
                  const SizedBox(height: 12),
                ],
                WelcomeAuthButton(
                  label: 'Google ilə davam et',
                  icon: _googleMark(),
                  onPressed: authBusy ? null : _welcomeGoogle,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WelcomeMiniButton(
                      icon: Icons.phone_iphone_rounded,
                      color: const Color(0xffd9ccff),
                      tooltip: 'Nömrə ilə',
                      onPressed:
                          authBusy ? null : () => openPage(const PhoneAuthPage()),
                    ),
                    const SizedBox(width: 16),
                    WelcomeMiniButton(
                      icon: Icons.mail_outline_rounded,
                      color: const Color(0xff9fe4ff),
                      tooltip: 'E-poçt ilə',
                      onPressed:
                          authBusy ? null : () => openPage(const LoginPage()),
                    ),
                    const SizedBox(width: 16),
                    WelcomeMiniButton(
                      icon: Icons.more_horiz_rounded,
                      color: const Color(0xffffd9a0),
                      tooltip: 'Digər',
                      onPressed: authBusy ? null : _openMoreWays,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _termsNote(),
                if (authBusy) ...[
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Davam etməklə qaydaların qəbulu — App Store tələbidir.
  Widget _termsNote() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 15, color: vMint),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Color(0xff9d95b8),
                  fontSize: 11.5,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: 'Davam etməklə '),
                  TextSpan(
                    text: 'İstifadə şərtlərini',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LegalPage.openTerms(context),
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: 'Məxfilik siyasətini',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LegalPage.openPrivacy(context),
                  ),
                  const TextSpan(text: ' və '),
                  TextSpan(
                    text: 'İcma qaydalarını',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LegalPage.openRules(context),
                  ),
                  const TextSpan(text: ' qəbul etmiş olursan.'),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _supportButton() => WelcomeMiniButton(
        icon: Icons.headset_mic_rounded,
        color: const Color(0xffd9ccff),
        tooltip: 'Dəstək',
        onPressed: () {
          Clipboard.setData(const ClipboardData(text: supportEmail));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dəstək e-poçtu kopyalandı.')),
          );
        },
      );

  Widget _googleMark() => SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _GoogleGLogoPainter()),
      );

  /// Üç nöqtə: digər giriş yolları.
  ///
  /// SUGO-dakı kimi — yuvarlaq provayder ikonları bir sıra ilə.
  void _openMoreWays() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bununla giriş et',
                style: TextStyle(
                  color: Color(0xff1f1f1f),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wayButton(
                    label: 'TikTok',
                    background: const Color(0xff121212),
                    child: const TiktokMark(size: 30),
                    onTap: () {
                      Navigator.pop(sheet);
                      if (tiktokReady) {
                        // Açarlar hazır olanda buradan TikTok axını başlayır.
                        return;
                      }
                      showTiktokNotReady(context);
                    },
                  ),
                  const SizedBox(width: 26),
                  _wayButton(
                    label: 'Nömrə',
                    background: const Color(0xff8b5cff),
                    child: const Icon(Icons.phone_iphone_rounded,
                        color: Colors.white, size: 27),
                    onTap: () {
                      Navigator.pop(sheet);
                      openPage(const PhoneAuthPage());
                    },
                  ),
                  const SizedBox(width: 26),
                  _wayButton(
                    label: 'E-poçt',
                    background: const Color(0xff22a7ff),
                    child: const Icon(Icons.mail_rounded,
                        color: Colors.white, size: 26),
                    onTap: () {
                      Navigator.pop(sheet);
                      openPage(const LoginPage());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Divider(height: 1, color: Color(0xffe6e2ef)),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  openPage(const RegisterPage());
                },
                child: const Text(
                  'Yeni hesab yarat',
                  style: TextStyle(
                    color: Color(0xff8b5cff),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Yuvarlaq provayder düyməsi.
  Widget _wayButton({
    required String label,
    required Color background,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: 58, height: 58, child: Center(child: child)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xff555160),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _welcomeGoogle() => _runAuth(signInWithGoogle);

  Future<void> _welcomeApple() => _runAuth(signInWithApple);

  /// Giriş axını: yüklənmə, xəta mətni, uğurda ekranı bağlamaq.
  Future<void> _runAuth(Future<UserCredential> Function() action) async {
    if (authBusy) return;
    setState(() => authBusy = true);
    try {
      await action();
      // AuthGate özü əsas ekrana keçirir.
    } catch (error) {
      final message = describeAuthError(error);
      if (mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => authBusy = false);
    }
  }

  Widget _langPill() => Container(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: vLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, color: vInk, size: 16),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: lang,
                isDense: true,
                dropdownColor: vPanelHigh,
                iconEnabledColor: vMuted,
                style: const TextStyle(
                  color: vInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                items: const ['AZ', 'TR', 'EN', 'RU']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => lang = v ?? lang),
              ),
            ),
          ],
        ),
      );

  Widget _logo(double size) => ShaderMask(
    shaderCallback: (r) => const LinearGradient(colors: [Color(0xff18b9ff), Color(0xff8b5cff), Color(0xffff22c7)]).createShader(r),
    child: Text('VIBE', style: TextStyle(color: Colors.white, fontSize: size, height: .95, fontWeight: FontWeight.w900, letterSpacing: -2)),
  );

  Widget _nav(String text, {bool active = false, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withValues(alpha: .05),
        child: SizedBox(
          height: 82,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Container(
                height: 2,
                width: 72,
                color: active
                    ? const Color(0xffff32da)
                    : Colors.transparent,
              ),
            ],
          ),
        ),
      );

  Widget _feature(IconData icon, String title, String sub) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: const Color(0xffff36d5), size: 44),
      const SizedBox(width: 18),
      Flexible(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(sub, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xffaaa3c5), fontSize: 14)),
      ])),
    ],
  );

  Widget _divider() => Container(width: 1, height: 55, color: const Color(0x334f466d));
}

// ============================================================
// LOGIN
// ============================================================


class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final arcRect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    void arc(Color color, double start, double sweep) {
      paint.color = color;
      canvas.drawArc(arcRect, start, sweep, false, paint);
    }

    // Google G rəngləri
    arc(const Color(0xff4285F4), -0.78, 2.20);
    arc(const Color(0xff34A853), 1.42, 1.20);
    arc(const Color(0xffFBBC05), 2.62, .88);
    arc(const Color(0xffEA4335), 3.50, 1.25);

    final blue = Paint()
      ..color = const Color(0xff4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(size.width * .50, size.height * .43,
          size.width * .43, stroke),
      blue,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .72, size.height * .43,
          stroke, size.height * .29),
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  bool rememberMe = true;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;

      setState(() {
        rememberMe = LoginMemory(prefs).remember;
        emailController.text = LoginMemory(prefs).email;
      });
    });
  }

  Future<void> login() async {
    if (loading) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email və şifrəni yaz.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await LoginMemory(prefs).save(rememberMe, email);

      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
            'online': true,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      TextInput.finishAutofillContext();

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      // Hesab Google/Apple ilə açılıbsa, onun ayrıca şifrəsi olmur.
      // Firebase isə "yanlış şifrə" ilə "şifrə yoxdur" halını fərqləndirmir
      // (e-poçt sorğusu təhlükəsizlik üçün bağlıdır), ona görə hər iki
      // ehtimalı istifadəçiyə özümüz izah edirik.
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        _showWrongPasswordHelp();
      } else {
        showMessage('Giriş xətası: ${e.message}');
      }
    } catch (e) {
      showMessage('Xəta: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Şifrə tutmayanda çıxan izah.
  ///
  /// Snackbar əvəzinə pəncərə göstəririk: adam çox vaxt hesabını Google ilə
  /// açıb, sonra e-poçt və şifrə ilə girməyə çalışır. "Şifrə yanlışdır"
  /// mətni bunu izah etmir və adam dövrə vurur — şifrə bərpası da işləmir,
  /// çünki bərpa ediləcək şifrə yoxdur.
  void _showWrongPasswordHelp() {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: const Text(
          'Giriş alınmadı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'E-poçt və ya şifrə yanlışdır.\n\n'
          'Hesabını Google və ya Apple ilə açmısansa, onun ayrıca şifrəsi '
          'yoxdur. Bu halda şifrə bərpası da işləmir — aşağıdakı düymə ilə gir.',
          style: TextStyle(color: Color(0xffa89fbd), height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              _resetPassword();
            },
            child: const Text(
              'Şifrəni unutdum',
              style: TextStyle(color: Color(0xffa89fbd)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              _signInWithGoogle();
            },
            child: const Text(
              'Google ilə gir',
              style: TextStyle(
                color: Color(0xffff2bd6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nömrə ilə giriş — SMS kodu ilə.
  Future<void> _signInWithPhone() async {
    if (loading) return;
    final done = await showPhoneAuthSheet(context);
    if (done && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Şifrəni unudanlar üçün bərpa: e-poçt linki və ya SMS kodu.
  Future<void> _resetPassword() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: vPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Şifrəni necə bərpa edək?',
                  style: TextStyle(
                    color: vInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: vBlue),
              title: const Text('E-poçta link göndər',
                  style: TextStyle(color: vInk)),
              subtitle: const Text('Gmail və digər e-poçt ünvanları üçün',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () => Navigator.pop(sheet, 'email'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_rounded, color: vMint),
              title: const Text('Nömrəyə SMS kod göndər',
                  style: TextStyle(color: vInk)),
              subtitle: const Text('Hesabına nömrə bağlıdırsa',
                  style: TextStyle(color: vMuted, fontSize: 12)),
              onTap: () => Navigator.pop(sheet, 'phone'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'phone') {
      final done = await showPhoneAuthSheet(
        context,
        mode: PhoneAuthMode.recover,
      );
      if (done && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    await _resetByEmail();
  }

  /// E-poçt ünvanına bərpa linki.
  Future<void> _resetByEmail() async {
    final typed = emailController.text.trim();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ResetPasswordDialog(initialEmail: typed),
    );
    if (email == null || !mounted) return;

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showMessage('$email ünvanına bərpa linki göndərildi. Poçtunu yoxla.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // `user-not-found` cavabını gizlədirik: kimin hesabı olduğunu açmamalıyıq.
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        showMessage('Belə bir hesab varsa, bərpa linki göndərildi.');
      } else {
        showMessage('Göndərmək alınmadı: ${e.message}');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }



  Widget _googleLogo({double size = 20}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGLogoPainter(),
      ),
    );
  }

  /// Google/Apple üçün ortaq axın: yüklənmə, xəta mətni, yönləndirmə.
  Future<void> _social(Future<UserCredential> Function() run) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await run();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', true);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      final message = describeAuthError(error);
      // Boş mətn = istifadəçi özü ləğv edib, xəta göstərmirik.
      if (!mounted || message.isEmpty) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signInWithGoogle() => _social(signInWithGoogle);

  Future<void> _signInWithApple() => _social(signInWithApple);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 760;

    return Scaffold(
      backgroundColor: const Color(0xff05030d),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.05,
                colors: [
                  Color(0xff2b0a4a),
                  Color(0xff0b0717),
                  Color(0xff05030d),
                ],
              ),
            ),
          ),
          Positioned(
            top: 90,
            right: -110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55ff1fcf),
                      blurRadius: 150,
                      spreadRadius: 95,
                    ),
                  ],
                ),
                child: SizedBox(width: 1, height: 1),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x443776ff),
                      blurRadius: 140,
                      spreadRadius: 85,
                    ),
                  ],
                ),
                child: SizedBox(width: 1, height: 1),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _loginHeader(mobile),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 20 : 32,
                      mobile ? 28 : 18,
                      mobile ? 20 : 32,
                      36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470),
                        child: Column(
                          children: [
                            if (!mobile)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.chevron_left, color: Colors.white70),
                                  label: const Text('Geri', style: TextStyle(color: Colors.white70)),
                                ),
                              ),
                            const SizedBox(height: 4),
                            const Text(
                              'Daxil ol',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 31,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Hesabına daxil olaraq yeni insanlarla tanış ol!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xffc9c2dd), fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xff121023).withValues(alpha: .94),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xff2c2743)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _darkField(
                                    controller: emailController,
                                    hint: 'E-poçt və ya istifadəçi adı',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                                  ),
                                  const SizedBox(height: 12),
                                  _darkField(
                                    controller: passwordController,
                                    hint: 'Şifrə',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: hidePassword,
                                    autofillHints: const [AutofillHints.password],
                                    onSubmitted: (_) => login(),
                                    suffix: IconButton(
                                      onPressed: () => setState(() => hidePassword = !hidePassword),
                                      icon: Icon(
                                        hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: const Color(0xffcfc5eb),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: rememberMe,
                                          activeColor: const Color(0xff8b5cff),
                                          checkColor: Colors.white,
                                          side: const BorderSide(color: Color(0xffbdb4d4)),
                                          onChanged: (v) => setState(() => rememberMe = v ?? true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Məni yadda saxla', style: TextStyle(color: Colors.white, fontSize: 13)),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: loading ? null : _resetPassword,
                                        child: const Text(
                                          'Şifrəni unutmusan?',
                                          style: TextStyle(color: Color(0xffd8c9ff), fontSize: 12, decoration: TextDecoration.underline),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xff11b8ff), Color(0xff7657ff), Color(0xffff16cc)],
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: loading ? null : login,
                                        child: loading
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                            : const Text('Daxil ol', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.white.withValues(alpha: .16))),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 14),
                                        child: Text('və ya', style: TextStyle(color: Color(0xffb7aecb), fontSize: 12)),
                                      ),
                                      Expanded(child: Divider(color: Colors.white.withValues(alpha: .16))),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _socialButton(
                                    provider: 'google',
                                    text: 'Google ilə davam et',
                                    onPressed: _signInWithGoogle,
                                  ),
                                  if (appleSignInAvailable) ...[
                                    const SizedBox(height: 10),
                                    _socialButton(
                                      provider: 'apple',
                                      text: 'Apple ilə davam et',
                                      onPressed: _signInWithApple,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _socialButton(
                                    provider: 'phone',
                                    text: 'Nömrə ilə davam et',
                                    onPressed: _signInWithPhone,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Hesabın yoxdur?', style: TextStyle(color: Color(0xffc7bfd8))),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                                  },
                                  child: const Text(
                                    'Yeni hesab yarat',
                                    style: TextStyle(color: Color(0xffff32d7), decoration: TextDecoration.underline, decorationColor: Color(0xffff32d7)),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _loginHeader(bool mobile) {
    return Container(
      height: mobile ? 68 : 76,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 20 : 44),
      decoration: const BoxDecoration(
        color: Color(0xdd080613),
        border: Border(bottom: BorderSide(color: Color(0xff211b35))),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xff18b9ff), Color(0xff8b5cff), Color(0xffff22c7)],
            ).createShader(r),
            child: Text(
              'VIBE',
              style: TextStyle(color: Colors.white, fontSize: mobile ? 27 : 31, fontWeight: FontWeight.w900, letterSpacing: -1.5),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(width: 70),
            const Text('Ana səhifə', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(width: 42),
            const Text('Kəşf et', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 42),
            const Text('Canlı', style: TextStyle(color: Colors.white70)),
            const SizedBox(width: 42),
            const Text('Mesajlar', style: TextStyle(color: Colors.white70)),
          ],
          const Spacer(),
          if (mobile)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            )
          else ...[
            const Icon(Icons.language_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Text('AZ', style: TextStyle(color: Colors.white70)),
          ],
        ],
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xffff32d7),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xffaaa2bd), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xffcfc5eb), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xff17142a),
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xff302a49))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xff9b5cff), width: 1.3)),
      ),
    );
  }

  Widget _socialButton({
    required String provider,
    required String text,
    required Future<void> Function() onPressed,
  }) {
    final isGoogle = provider == 'google';
    final isPhone = provider == 'phone';

    // Rəsmi qaydalar: Google ağ fonda, Apple qara fonda.
    // Nömrə düyməsi tətbiqin öz rəngindədir.
    final background = isGoogle
        ? Colors.white
        : (isPhone ? const Color(0xff1a1230) : Colors.black);
    final foreground = isGoogle ? const Color(0xff1f1f1f) : Colors.white;

    return Opacity(
      opacity: loading ? .6 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : () => onPressed(),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGoogle
                    ? const Color(0xffdadce0)
                    : (isPhone
                        ? vPurple.withValues(alpha: .55)
                        : Colors.white.withValues(alpha: .22)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isGoogle)
                  _googleLogo(size: 20)
                else if (isPhone)
                  const Icon(Icons.phone_iphone_rounded,
                      size: 22, color: Color(0xffd9ccff))
                else
                  Icon(Icons.apple, size: 25, color: foreground),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .1,
                    ),
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

// ============================================================
// REGISTER
// ============================================================

/// Şifrə bərpası üçün e-poçt soruşan pəncərə.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController controller =
      TextEditingController(text: widget.initialEmail);
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = controller.text.trim();
    if (!email.contains('@') || !email.contains('.') || email.length < 6) {
      setState(() => error = 'Düzgün e-poçt ünvanı yaz.');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: vPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Şifrəni bərpa et', style: TextStyle(color: vInk)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesabının e-poçtunu yaz — bərpa linkini ora göndərəcəyik.',
            style: TextStyle(color: vMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: vInk),
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            decoration: InputDecoration(
              hintText: 'ad@nümunə.com',
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ləğv et', style: TextStyle(color: vMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Göndər', style: TextStyle(color: vPink)),
        ),
      ],
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final cityController = TextEditingController();
  final aboutController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  bool acceptedTerms = false;

  Future<void> register() async {
    final name = nameController.text.trim();
    final age = int.tryParse(ageController.text.trim());
    final city = cityController.text.trim();
    final about = aboutController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty ||
        age == null ||
        city.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showMessage('Vacib xanaları doldur.');
      return;
    }

    if (password.length < 6) {
      showMessage('Şifrə ən azı 6 simvol olmalıdır.');
      return;
    }

    if (age < 18) {
      showMessage('VIBE yalnız 18 yaşdan yuxarı istifadəçilər üçündür.');
      return;
    }

    if (!acceptedTerms) {
      showMessage('Davam etmək üçün şərtləri və icma qaydalarını qəbul et.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }

      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('rememberMe', true);

      final uid = result.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'age': age,
        'city': city,
        'about': about,
        'email': email,
        'online': true,
        'coins': 100,
        'level': 1,
        'acceptedTermsAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Təsdiq linki — göndərilməsə də qeydiyyat pozulmur.
      try {
        await result.user!.sendEmailVerification();
      } catch (_) {}

      Telemetry.log('sign_up', {'method': 'email'});

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      // Ən çox rast gəlinən hal: bu e-poçtla artıq hesab var.
      if (e.code == 'email-already-in-use') {
        _offerLogin(email);
      } else {
        showMessage(describeRegisterError(e));
      }
    } catch (e) {
      showMessage('Qeydiyyat alınmadı. Bağlantını yoxla.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Hesab artıq varsa, istifadəçini girişə yönəldirik.
  void _offerLogin(String email) {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: vPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bu e-poçtla hesab var',
            style: TextStyle(color: vInk, fontSize: 18)),
        content: Text(
          '$email artıq qeydiyyatdan keçib. Daxil ola, '
          'şifrəni unutmusansa bərpa edə bilərsən.',
          style: const TextStyle(color: vMuted, fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Başqa e-poçt', style: TextStyle(color: vMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialog);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text('Daxil ol', style: TextStyle(color: vPink)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    cityController.dispose();
    aboutController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Hesab yarat',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            // Başlıq şəffafdır və məzmun onun altından keçir; ilk sətir
            // başlığın altında qalmasın deyə yuxarıdan boşluq buraxılır.
            padding: const EdgeInsets.fromLTRB(18, kToolbarHeight + 6, 18, 28),
            children: [
              const Text(
                'Bir neçə sətir — sonra VIBE səninkidir.',
                style: TextStyle(color: vMuted, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 20),

              _section(
                title: 'Səni tanıyaq',
                icon: Icons.person_rounded,
                children: [
                  _field(
                    controller: nameController,
                    label: 'Ad',
                    icon: Icons.badge_rounded,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 11),

                  // Yaş və şəhər yan-yana: ikisi də qısadır, ayrı sətir
                  // tutmaları formanı lazımsız uzadırdı.
                  Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: _field(
                          controller: ageController,
                          label: 'Yaş',
                          icon: Icons.cake_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _field(
                          controller: cityController,
                          label: 'Şəhər',
                          icon: Icons.place_rounded,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _field(
                    controller: aboutController,
                    label: 'Haqqımda',
                    hint: 'Nəyi sevirsən, nədən danışmağı xoşlayırsan?',
                    icon: Icons.chat_bubble_rounded,
                    maxLines: 3,
                    maxLength: 150,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _section(
                title: 'Giriş məlumatları',
                icon: Icons.lock_rounded,
                children: [
                  _field(
                    controller: emailController,
                    label: 'E-poçt',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 11),
                  _field(
                    controller: passwordController,
                    label: 'Şifrə',
                    hint: 'Ən azı 6 simvol',
                    icon: Icons.key_rounded,
                    obscureText: hidePassword,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => hidePassword = !hidePassword),
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: vMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _termsCard(),
              const SizedBox(height: 16),

              GradientButton(
                label: loading ? 'Yaradılır…' : 'Qeydiyyatdan keç',
                icon: Icons.arrow_forward_rounded,
                gradient: vBrand,
                height: 54,
                onPressed: loading ? null : register,
              ),

              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => LegalPage.openPrivacy(context),
                  child: const Text(
                    'Məxfilik siyasəti',
                    style: TextStyle(color: Color(0xff9d94ae), fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Başlıqlı qutu — sahələri mənaya görə qruplaşdırır.
  ///
  /// Əvvəl altı sahə ardıcıl düzülmüşdü və forma sonu görünməyən bir siyahı
  /// kimi oxunurdu. İki qrup adamın gözünə "bu qədərmiş" deyir.
  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      decoration: BoxDecoration(
        color: vPanel.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: vPink),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }

  /// Formanın bütün sahələri eyni görünsün deyə tək yerdən qurulur.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    int maxLines = 1,
    int? maxLength,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: vPink,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xff6f6786), fontSize: 13),
        labelStyle: const TextStyle(color: vMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: vPink, fontSize: 13),
        prefixIcon: Padding(
          // Çox sətirli sahədə ikon mətnin ilk sətri ilə eyni xətdə dursun.
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 44 : 0),
          child: Icon(icon, size: 19, color: vMuted),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: vPanelHigh,
        counterStyle: const TextStyle(color: Color(0xff6f6786), fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: vLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: vLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: vPink, width: 1.4),
        ),
      ),
    );
  }

  /// Şərtlərin qəbulu.
  ///
  /// App Store 1.2 bəndi bunu tələb edir. Bütün qutuya basmaq işarəni
  /// dəyişir — kiçik kvadratı tutmağa çalışmaq telefonda əziyyətlidir.
  Widget _termsCard() {
    return GestureDetector(
      onTap: () => setState(() => acceptedTerms = !acceptedTerms),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: acceptedTerms
              ? vPink.withValues(alpha: .10)
              : vPanel.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: acceptedTerms ? vPink.withValues(alpha: .55) : vLine,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: acceptedTerms ? vPink : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: acceptedTerms ? vPink : const Color(0xff5c5474),
                  width: 1.6,
                ),
              ),
              child: acceptedTerms
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '18 yaşım tamamdır və ',
                    style: TextStyle(color: Color(0xffb7aecb), fontSize: 12.5),
                  ),
                  GestureDetector(
                    onTap: () => LegalPage.openTerms(context),
                    child: const Text(
                      'istifadə şərtlərini',
                      style: TextStyle(
                        color: Color(0xffff65dc),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xffff65dc),
                      ),
                    ),
                  ),
                  const Text(
                    ' və ',
                    style: TextStyle(color: Color(0xffb7aecb), fontSize: 12.5),
                  ),
                  GestureDetector(
                    onTap: () => LegalPage.openRules(context),
                    child: const Text(
                      'icma qaydalarını',
                      style: TextStyle(
                        color: Color(0xffff65dc),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xffff65dc),
                      ),
                    ),
                  ),
                  const Text(
                    ' qəbul edirəm. Uyğunsuz məzmuna sıfır dözümlülük var.',
                    style: TextStyle(color: Color(0xffb7aecb), fontSize: 12.5),
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

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  final UserProfile profile;

  const MainScreen({super.key, required this.profile});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int selectedIndex = 0;

  Timer? heartbeat;
  bool foreground = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    setOnline();

    // Serverin saatı ilə telefonun saatı arasındakı fərq bir dəfə
    // ölçülür. Onsuz "onlayn", "yazır…" və "görüldü" nişanları saatı
    // düz olmayan cihazlarda heç vaxt işləmirdi.
    unawaited(syncServerClock(widget.profile.uid));

    ensureWelcomeBonus(widget.profile.uid);
    startPushNotifications(widget.profile.uid);

    // Tətbiq açıq olanda push gəlmir — mesajı səslə bildiririk.
    chime.start(widget.profile.uid);
    Telemetry.setUser(widget.profile.uid);

    // Bildirişə toxunanda söhbəti aç.
    pendingPushTarget.addListener(_openPushTarget);

    // Gündəlik mükafat — tətbiq açılandan bir az sonra.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Əvvəl yeniliklər, sonra mükafat: ikisi eyni anda açılsa
      // biri o birinin üstünü örtür.
      await maybeShowWhatsNew(context);
      if (mounted) await _offerDailyReward();
    });

    heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      setOnline();
    });
  }

  /// Yeni mesaj səsi.
  final MessageChime chime = MessageChime();

  /// Gündəlik mükafat hazırdırsa pəncərəni açır.
  ///
  /// Gözləmə var ki, ekran oturuşsun və istifadəçi qarşılanan kimi
  /// pəncərə ilə üzləşməsin.
  Future<void> _offerDailyReward() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};

      final now = DateTime.now();
      if (!canClaimToday(lastClaimFrom(data), now)) return;
      if (!mounted) return;

      final streak = nextStreak(lastClaimFrom(data), streakFrom(data), now);

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => DailyRewardSheet(
          uid: widget.profile.uid,
          streak: streak,
        ),
      );
    } catch (_) {
      // Mükafat göstərilmədisə tətbiq normal işləyir.
    }
  }

  Future<void> setOnline() async {
    if (!foreground ||
        FirebaseAuth.instance.currentUser?.uid != widget.profile.uid) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .set({
            'online': true,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> setOffline() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.profile.uid)
          .set({
            'online': false,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;

    if (state == AppLifecycleState.resumed) {
      setOnline();
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      setOffline();
    }
  }

  @override
  void dispose() {
    chime.dispose();
    heartbeat?.cancel();
    pendingPushTarget.removeListener(_openPushTarget);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Push bildirişindən gələn söhbəti açır.
  void _openPushTarget() {
    final target = pendingPushTarget.value;
    if (target == null || !mounted) return;
    pendingPushTarget.value = null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealChatPage(
          currentProfile: widget.profile,
          targetUid: target.uid,
          targetName: target.name,
        ),
      ),
    );
  }

  void navigate(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      SocialHome(profile: widget.profile),
      MomentsPage(profile: widget.profile),
      SocialFeed(profile: widget.profile, rooms: true),
      SocialMessages(profile: widget.profile, navigate: navigate),
      SocialProfile(profile: widget.profile, navigate: navigate),
    ];

    return Scaffold(
      body: IncomingCalls(
        uid: widget.profile.uid,
        child: Column(
          children: [
            const UpdateBanner(),
            const EmailVerifyBanner(),
            Expanded(
              child: IndexedStack(index: selectedIndex, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('members', arrayContains: widget.profile.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final unread = (snapshot.data?.docs ?? const [])
              .where((doc) => isUnread(doc.data(), widget.profile.uid))
              .length;

          return VibeBottomNav(
            index: selectedIndex,
            onChanged: navigate,
            messageBadge: unread,
            onCreate: _openCreateSheet,
          );
        },
      ),
    );
  }

  /// Mərkəzdəki "+" düyməsi: nə paylaşmaq istədiyini soruşur.
  void _openCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        decoration: const BoxDecoration(
          color: Color(0xff120d1d),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xff33264a))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xff3c2f55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _createTile(
                sheet,
                Icons.auto_awesome_rounded,
                'Anını paylaş',
                'Şəkil və ya fikir paylaş',
                const [Color(0xff8b5cff), Color(0xffff2bd6)],
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateMomentPage(profile: widget.profile),
                  ),
                ),
              ),
              _createTile(
                sheet,
                Icons.play_circle_fill_rounded,
                'VIBE Video',
                'Şaquli video lentini aç və paylaş',
                const [Color(0xff22a7ff), Color(0xff8b5cff)],
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VibeVideoPage(profile: widget.profile),
                  ),
                ),
              ),
              _createTile(
                sheet,
                Icons.mic_rounded,
                'Səsli otaq',
                'Öz otağını yarat, dostlarını çağır',
                const [Color(0xff48e08a), Color(0xff22a7ff)],
                () => navigate(2),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createTile(
    BuildContext sheet,
    IconData icon,
    String title,
    String subtitle,
    List<Color> colors,
    VoidCallback action,
  ) => ListTile(
    onTap: () {
      Navigator.pop(sheet);
      action();
    },
    leading: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 15.5,
      ),
    ),
    subtitle: Text(subtitle, style: const TextStyle(color: vMuted, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xff7b7390)),
  );
}

// ============================================================
// VIBE VIDEO — neon vertical feed
// ============================================================

class VibeVideoFeed extends StatefulWidget {
  const VibeVideoFeed({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<VibeVideoFeed> createState() => _VibeVideoFeedState();
}

class _VibeVideoFeedState extends State<VibeVideoFeed> {
  final PageController controller = PageController();
  final Set<int> liked = <int>{};
  final Set<int> saved = <int>{};

  final List<Map<String, dynamic>> videos = const [
    {'name': 'VIBE', 'caption': 'Yeni insanlarla tanış, söhbət et və öz VIBE-ını paylaş ✨', 'emoji': '✨', 'likes': 128, 'comments': 24},
    {'name': 'Online', 'caption': 'Gecənin enerjisi buradadır 💜', 'emoji': '💜', 'likes': 214, 'comments': 39},
    {'name': 'VIBE Live', 'caption': 'Yuxarı sürüşdür və növbəti anı kəşf et 🔥', 'emoji': '🔥', 'likes': 302, 'comments': 51},
  ];

  @override
  void initState() {
    super.initState();
    _loadVideoState();
  }

  Future<void> _loadVideoState() async {
    final prefs = await SharedPreferences.getInstance();
    final likes = prefs.getStringList('vibe_video_likes_${widget.profile.uid}') ?? const <String>[];
    final saves = prefs.getStringList('vibe_video_saves_${widget.profile.uid}') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      liked
        ..clear()
        ..addAll(likes.map(int.tryParse).whereType<int>());
      saved
        ..clear()
        ..addAll(saves.map(int.tryParse).whereType<int>());
    });
  }

  Future<void> _toggleVideoLike(int index) async {
    setState(() => liked.contains(index) ? liked.remove(index) : liked.add(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vibe_video_likes_${widget.profile.uid}', liked.map((e) => '$e').toList());
  }

  Future<void> _toggleVideoSave(int index) async {
    setState(() => saved.contains(index) ? saved.remove(index) : saved.add(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vibe_video_saves_${widget.profile.uid}', saved.map((e) => '$e').toList());
    if (mounted) info(saved.contains(index) ? 'Video yadda saxlanıldı 💜' : 'Yadda saxlanılanlardan çıxarıldı.');
  }

  Future<void> _shareVideo(int index) async {
    final item = videos[index];
    final text = 'VIBE · @${item['name']} — ${item['caption']}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) info('Paylaşım mətni kopyalandı. İstədiyin yerə yapışdıra bilərsən.');
  }

  Future<void> _openVideoComments(int index) async {
    final controller = TextEditingController();
    final key = 'vibe_video_comments_${widget.profile.uid}_$index';
    final prefs = await SharedPreferences.getInstance();
    final comments = <String>[...(prefs.getStringList(key) ?? const <String>[])];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff120d1d),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .62,
            child: Column(
              children: [
                Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 14),
                const Text('Şərhlər', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(child: Text('İlk şərhi sən yaz 💜', style: TextStyle(color: Color(0xffa89fbd))))
                      : ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xff2d2540)),
                          itemBuilder: (_, i) => ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xff8b5cff), child: Icon(Icons.person, color: Colors.white)),
                            title: Text(widget.profile.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            subtitle: Text(comments[i], style: const TextStyle(color: Color(0xffd8d0e7))),
                          ),
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
                        comments.add(text);
                        controller.clear();
                        await prefs.setStringList(key, comments);
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void info(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xff171021),
        content: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff05030b),
      body: Stack(
        children: [
          PageView.builder(
            controller: controller,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final item = videos[index];
              final isLiked = liked.contains(index);
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xff080611), Color(0xff1a0d28), Color(0xff07050d)],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(colors: [Color(0x558b5cff), Color(0x11ff2bd6), Colors.transparent]),
                          boxShadow: const [BoxShadow(color: Color(0x338b5cff), blurRadius: 80, spreadRadius: 18)],
                        ),
                        alignment: Alignment.center,
                        child: Text('${item['emoji']}', style: const TextStyle(fontSize: 92)),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 88,
                      bottom: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xff8b5cff), Color(0xffff2bd6)])),
                              alignment: Alignment.center,
                              child: Text('${item['name']}'[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 10),
                            Text('@${item['name']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 7),
                            const Icon(Icons.verified_rounded, color: Color(0xffb06cff), size: 18),
                          ]),
                          const SizedBox(height: 12),
                          Text('${item['caption']}', style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
                          const SizedBox(height: 10),
                          const Row(children: [Icon(Icons.music_note_rounded, color: Colors.white70, size: 17), SizedBox(width: 5), Text('VIBE original sound', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 28,
                      child: Column(
                        children: [
                          _videoAction(
                            icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: '${(item['likes'] as int) + (isLiked ? 1 : 0)}',
                            active: isLiked,
                            onTap: () => _toggleVideoLike(index),
                          ),
                          _videoAction(icon: Icons.chat_bubble_outline_rounded, label: '${item['comments']}', onTap: () => _openVideoComments(index)),
                          _videoAction(icon: Icons.share_rounded, label: 'Paylaş', onTap: () => _shareVideo(index)),
                          _videoAction(icon: saved.contains(index) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: saved.contains(index) ? 'Saxlanıb' : 'Yadda saxla', active: saved.contains(index), onTap: () => _toggleVideoSave(index)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  const Text('İzlənilən', style: TextStyle(color: Color(0xff9f96b4), fontWeight: FontWeight.w700)),
                  const SizedBox(width: 22),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sənin üçün', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Container(width: 34, height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [Color(0xff8b5cff), Color(0xffff2bd6)]))),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => info('Video yükləmə üçün qalereya seçimi növbəti texniki mərhələdə server storage ilə qoşulacaq.'), icon: const Icon(Icons.add_box_outlined, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoAction({required IconData icon, required String label, required VoidCallback onTap, bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xff16101f).withValues(alpha: .92),
                shape: BoxShape.circle,
                border: Border.all(color: active ? const Color(0xffff2bd6) : const Color(0xff38264c)),
              ),
              child: Icon(icon, color: active ? const Color(0xffff2bd6) : Colors.white, size: 27),
            ),
            const SizedBox(height: 5),
            SizedBox(width: 64, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PERSON PAGE
// social_ui.dart bu səhifədən istifadə edir
// ============================================================

class PersonPage extends StatefulWidget {
  final UserProfile currentProfile;
  final String targetUid;

  const PersonPage({
    super.key,
    required this.currentProfile,
    required this.targetUid,
  });

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  static const tabs = ['Profil', 'Anlar', 'Hədiyyələr', 'Dostlar'];

  int tab = 0;
  int coverIndex = 0;

  String get targetUid => widget.targetUid;
  UserProfile get currentProfile => widget.currentProfile;

  // ----------------------------------------------------------
  // ƏMƏLİYYATLAR
  // ----------------------------------------------------------

  Future<void> _toggleFollow(bool following, String targetName) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentProfile.uid)
        .collection('following')
        .doc(targetUid);
    final reverse = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentProfile.uid);

    final batch = FirebaseFirestore.instance.batch();
    if (following) {
      batch.delete(ref);
      batch.delete(reverse);
    } else {
      batch.set(ref, {
        'uid': targetUid,
        'name': targetName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(reverse, {
        'uid': currentProfile.uid,
        'name': currentProfile.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();

      if (!following) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(targetUid)
              .collection('notifications')
              .add({
                'type': 'follow',
                'title': '${currentProfile.name} səni izləməyə başladı',
                'body': 'Profilinə yeni izləyici gəldi 💜',
                'fromUid': currentProfile.uid,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}

        // Cihaz bildirişi.
        unawaited(sendPushToUser(
          toUid: targetUid,
          title: 'Yeni izləyici',
          body: '${currentProfile.name} səni izləməyə başladı',
          type: 'follow',
          fromName: currentProfile.name,
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              following ? 'İzləmədən çıxarıldı.' : '$targetName izlənilir 💜',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İzləmə əməliyyatı alınmadı.')),
        );
      }
    }
  }

  Future<void> _blockUser(String targetName) async {
    try {
      await blockUser(
        myUid: currentProfile.uid,
        myName: currentProfile.name,
        targetUid: targetUid,
        targetName: targetName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetName bloklandı.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloklama alınmadı.')),
        );
      }
    }
  }

  Future<void> _unblockUser(String targetName) async {
    try {
      await unblockUser(myUid: currentProfile.uid, targetUid: targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetName blokdan çıxarıldı.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blok götürülmədi.')),
        );
      }
    }
  }

  Future<void> _reportUser(String targetName, String reason) async {
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentProfile.uid,
        'reporterName': currentProfile.name,
        'targetId': targetUid,
        'targetName': targetName,
        'reason': reason,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikayət göndərildi. Təşəkkür edirik.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikayət göndərilmədi.')),
        );
      }
    }
  }

  void _openSafetyMenu(String targetName) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Təhlükəsizlik',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Bu istifadəçi ilə bağlı əməliyyat seç',
                style: TextStyle(color: Color(0xff9e95ac)),
              ),
            ),
            for (final reason in const ['Saxta profil', 'Spam', 'Uyğunsuz davranış'])
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xffffb24a)),
                title: Text(
                  'Şikayət et · $reason',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reportUser(targetName, reason);
                },
              ),
            StreamBuilder<BlockState>(
              stream: watchBlockState(currentProfile.uid, targetUid),
              builder: (context, snapshot) {
                final blocked = snapshot.data?.iBlocked ?? false;
                return ListTile(
                  leading: Icon(
                    blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: const Color(0xffff5d76),
                  ),
                  title: Text(
                    blocked ? 'Blokdan çıxar' : 'İstifadəçini blokla',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    blocked
                        ? 'Yenidən mesajlaşa biləcəksiniz'
                        : 'Mesaj, zəng və profil bağlanır',
                    style: const TextStyle(color: Color(0xff9e95ac), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (blocked) {
                      _unblockUser(targetName);
                    } else {
                      _blockUser(targetName);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // GÖRÜNÜŞ
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: vBg,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: Center(
              child: Text(
                'Profil xətası:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.data() == null) {
          return const LoadingPage();
        }

        final data = snapshot.data!.data()!;
        final name = '${data['name'] ?? 'İstifadəçi'}';
        final age = '${data['age'] ?? ''}'.trim();
        final about = '${data['about'] ?? ''}'.trim();
        final photo = '${data['photoUrl'] ?? data['imageUrl'] ?? ''}';
        final online = isReallyOnline(data);
        final status = VibeStatus.from(data);
        final level = data['level'] is num ? (data['level'] as num).toInt() : 0;
        final vipUntil = data['vipUntil'];
        final vipActive = data['vip'] == true &&
            (vipUntil is! Timestamp || vipUntil.toDate().isAfter(DateTime.now()));
        // Qalereya artıq users/{uid}/gallery alt kolleksiyasındadır;
        // örtük karuseli üçün yalnız profil şəkli kifayətdir.
        const gallery = <String>[];
        final tags = ((data['tags'] as List?) ?? (data['interests'] as List?) ?? const [])
            .map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        return Scaffold(
          backgroundColor: vBg,
          body: Stack(
            children: [
              // ---- örtük şəkli + foto karusel ----
              Builder(
                builder: (context) {
                  final photos = <String>[
                    if (photo.trim().isNotEmpty) photo,
                    ...gallery.where((e) => e != photo),
                  ];
                  final index = photos.isEmpty
                      ? 0
                      : coverIndex.clamp(0, photos.length - 1);

                  return SizedBox(
                    height: 330,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VibePhoto(
                          url: photos.isEmpty ? '' : photos[index],
                          name: name,
                          emoji: '${data['avatarEmoji'] ?? ''}',
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x99000000),
                                Colors.transparent,
                                Color(0xff070510),
                              ],
                              stops: [0, .45, 1],
                            ),
                          ),
                        ),
                        if (photos.length > 1)
                          Positioned(
                            left: 14,
                            bottom: 92,
                            child: SizedBox(
                              height: 46,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                shrinkWrap: true,
                                itemCount: photos.length,
                                itemBuilder: (context, i) => Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: PressableScale(
                                    onTap: () => setState(() => coverIndex = i),
                                    child: Container(
                                      width: 46,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: i == index
                                              ? Colors.white
                                              : Colors.white24,
                                          width: i == index ? 2 : 1,
                                        ),
                                      ),
                                      child: VibePhoto(url: photos[i], name: name),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // ---- məzmun ----
              ListView(
                padding: const EdgeInsets.only(top: 250, bottom: 36),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _infoCard(
                      data: data,
                      name: name,
                      age: age,
                      online: online,
                      level: level,
                      vip: vipActive,
                    ),
                  ),
                  const SizedBox(height: 18),
                  UnderlineTabs(
                    labels: tabs,
                    index: tab,
                    onChanged: (i) => setState(() => tab = i),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _tabBody(
                      name: name,
                      about: about,
                      gallery: gallery,
                      tags: tags,
                      status: status,
                      data: data,
                    ),
                  ),
                ],
              ),

              // ---- üst düymələr ----
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 6,
                right: 6,
                child: Row(
                  children: [
                    _roundButton(
                      Icons.arrow_back_rounded,
                      'Geri',
                      () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _roundButton(
                      Icons.card_giftcard_rounded,
                      'Hədiyyə göndər',
                      () => _openGiftInfo(name),
                    ),
                    const SizedBox(width: 6),
                    _roundButton(
                      Icons.videocam_rounded,
                      'Video zəng',
                      () => startCall(
                        context,
                        currentProfile.uid,
                        currentProfile.name,
                        targetUid,
                        name,
                        true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _roundButton(
                      Icons.more_horiz_rounded,
                      'Daha çox',
                      () => _openSafetyMenu(name),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: PressableScale(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .42),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
      );

  /// Örtüyün üzərinə düşən əsas məlumat kartı.
  Widget _infoCard({
    required Map<String, dynamic> data,
    required String name,
    required String age,
    required bool online,
    required int level,
    required bool vip,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: const Color(0xff151020).withValues(alpha: .96),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xff2f2447)),
      boxShadow: const [
        BoxShadow(color: Color(0x88000000), blurRadius: 26, offset: Offset(0, 10)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  VerifiedName(
                    name: name,
                    verified: data['verified'] == true || vip,
                    fontSize: 19,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: online
                              ? const Color(0xff2de28a)
                              : const Color(0xff6b6475),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          activityText(data),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: vMuted, fontSize: 11.5),
                        ),
                      ),
                      if ('${data['city'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        PlaceLabel(text: '${data['city']}'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentProfile.uid)
                  .collection('following')
                  .doc(targetUid)
                  .snapshots(),
              builder: (context, followSnap) {
                final following = followSnap.data?.exists == true;
                return PressableScale(
                  onTap: () => _toggleFollow(following, name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: following ? null : vHot,
                      color: following ? const Color(0xff221a33) : null,
                      borderRadius: BorderRadius.circular(20),
                      border: following
                          ? Border.all(color: const Color(0xff4a3a68))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          following
                              ? Icons.check_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          following ? 'İzlənilir' : 'Takip et',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ---- kiçik statistika nişanları ----
        Row(
          children: [
            GenderAgeChip(gender: genderCode(data), age: age, fontSize: 10.5),
            const SizedBox(width: 7),
            if (level > 0) ...[
              LevelTag(level: level, fontSize: 10.5),
              const SizedBox(width: 7),
            ],
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(targetUid)
                  .collection('followers')
                  .snapshots(),
              builder: (context, snap) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: vPurple.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: vPurple.withValues(alpha: .55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, size: 11, color: vPink),
                    const SizedBox(width: 3),
                    Text(
                      compactCount(snap.data?.docs.length ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ---- əsas əməliyyatlar ----
        Row(
          children: [
            _squareAction(
              Icons.call_rounded,
              'Səsli zəng',
              () => startCall(
                context,
                currentProfile.uid,
                currentProfile.name,
                targetUid,
                name,
                false,
              ),
            ),
            const SizedBox(width: 8),
            _squareAction(
              Icons.chat_bubble_outline_rounded,
              'Söhbəti aç',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RealChatPage(
                    currentProfile: currentProfile,
                    targetUid: targetUid,
                    targetName: name,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _squareAction(
              Icons.ios_share_rounded,
              'Profili paylaş',
              () {
                Clipboard.setData(
                  ClipboardData(text: 'VIBE profili: $name (ID: $targetUid)'),
                );
                notifySocial(context, 'Profil məlumatı kopyalandı.');
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GradientButton(
                label: 'Salam de',
                icon: Icons.favorite_rounded,
                height: 46,
                fontSize: 14,
                onPressed: () => _sayHello(name),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  /// Bir toxunuşla salam göndərir və söhbəti açır.
  Future<void> _sayHello(String name) async {
    final chatId = chatIdFor(currentProfile.uid, targetUid);
    final chat = FirebaseFirestore.instance.collection('chats').doc(chatId);
    const text = 'Salam 👋';

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chat, {
        'members': [currentProfile.uid, targetUid],
        'memberNames': {
          currentProfile.uid: currentProfile.name,
          targetUid: name,
        },
        // Qarşı tərəfdə oxunmamış sayğacı — siyahıda rəqəm kimi görünür.
        'unread': {targetUid: FieldValue.increment(1)},
        'lastMessage': text,
        'lastSenderId': currentProfile.uid,
        // "Ən çox yazışılan" süzgəci bu sayğaca görə sıralayır.
        'messageCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      batch.set(chat.collection('messages').doc(), {
        'senderId': currentProfile.uid,
        'text': text,
        'type': 'text',
        'createdAt': Timestamp.now(),
      });
      await batch.commit();
    } catch (_) {
      if (!mounted) return;
      notifySocial(context, 'Salam göndərilmədi. Bloklanmış ola bilər.');
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealChatPage(
          currentProfile: currentProfile,
          targetUid: targetUid,
          targetName: name,
        ),
      ),
    );
  }

  Widget _squareAction(IconData icon, String tooltip, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: PressableScale(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xff211936),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xff3a2d58)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );

  // ----------------------------------------------------------
  // TAB MƏZMUNU
  // ----------------------------------------------------------

  Widget _tabBody({
    required String name,
    required String about,
    required List<String> gallery,
    required List<String> tags,
    required VibeStatus? status,
    required Map<String, dynamic> data,
  }) {
    switch (tab) {
      case 1:
        return _momentsTab(name);
      case 2:
        return _giftsTab();
      case 3:
        return _friendsTab();
      default:
        return _profileTab(
          about: about,
          gallery: gallery,
          tags: tags,
          status: status,
          name: name,
        );
    }
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _profileTab({
    required String about,
    required List<String> gallery,
    required List<String> tags,
    required VibeStatus? status,
    required String name,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (status != null) ...[
        VibePill(status: status),
        const SizedBox(height: 18),
      ],
      _sectionTitle('Özəl albüm'),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .collection('gallery')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) return _emptyBox('Hələ şəkil paylaşmayıb.');

          return SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final d = docs[i].data();
                return Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: PressableScale(
                    onTap: () => _openPhoto('${d['data'] ?? d['thumb'] ?? ''}', name),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 92,
                        child: VibePhoto(
                          url: '${d['thumb'] ?? ''}',
                          name: name,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      const SizedBox(height: 22),
      if (tags.isNotEmpty) ...[
        _sectionTitle('Profil etiketləri'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final tag in tags) VibeChip(label: tag)],
        ),
        const SizedBox(height: 22),
      ],
      _sectionTitle('Haqqında'),
      Text(
        about.isEmpty ? 'Haqqında məlumat yazmayıb.' : about,
        style: const TextStyle(color: Color(0xffc5bdd0), height: 1.5, fontSize: 13.5),
      ),
    ],
  );

  Widget _momentsTab(String name) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('moments')
            .where('ownerUid', isEqualTo: targetUid)
            .limit(60)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const VibeShimmer(height: 180, radius: 18);
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return _emptyBox('Hələ an paylaşmayıb.');

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VibePhoto(url: '${d['imageUrl'] ?? ''}', name: name),
              );
            },
          );
        },
      );

  Widget _giftsTab() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .snapshots(),
    builder: (context, snapshot) {
      final d = snapshot.data?.data() ?? const <String, dynamic>{};
      final received = d['giftReceived'] is num ? (d['giftReceived'] as num) : 0;
      final sent = d['giftSent'] is num ? (d['giftSent'] as num) : 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Hədiyyə statistikası'),
          Row(
            children: [
              Expanded(child: _giftBox('Alınan', compactCount(received), vPink)),
              const SizedBox(width: 10),
              Expanded(child: _giftBox('Göndərilən', compactCount(sent), vBlue)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Hədiyyələr səsli otaqlarda göndərilir.',
            style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.5),
          ),
        ],
      );
    },
  );

  Widget _giftBox(String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.card_giftcard_rounded, color: color, size: 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: vMuted, fontSize: 12)),
      ],
    ),
  );

  Widget _friendsTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .limit(60)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const VibeShimmer(height: 120, radius: 18);
      }
      final docs = snapshot.data!.docs;
      if (docs.isEmpty) return _emptyBox('Hələ izləyicisi yoxdur.');

      return Column(
        children: [
          for (final doc in docs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: doc.id == currentProfile.uid
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonPage(
                          currentProfile: currentProfile,
                          targetUid: doc.id,
                        ),
                      ),
                    ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xff2a183f),
                child: Text(
                  '${doc.data()['name'] ?? '?'}'.characters.firstOrNull
                          ?.toUpperCase() ??
                      '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(
                '${doc.data()['name'] ?? 'İstifadəçi'}',
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
              ),
            ),
        ],
      );
    },
  );

  Widget _emptyBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 26),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xff161022),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff2a2140)),
    ),
    child: Text(text, style: const TextStyle(color: vMuted, fontSize: 13)),
  );

  void _openPhoto(String url, String name) => showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1,
          child: VibePhoto(url: url, name: name, fit: BoxFit.contain),
        ),
      ),
    ),
  );

  void _openGiftInfo(String name) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff151020),
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name üçün hədiyyə',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hədiyyələr səsli otaqlarda göndərilir. Otağa birlikdə gir və '
              'səhnədəki istifadəçiyə hədiyyə at.',
              style: TextStyle(color: vMuted, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Otaqlara keç',
              icon: Icons.mic_rounded,
              onPressed: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// REAL CHAT
// Emoji + Stiker + fokus
// ============================================================

class RealChatPage extends StatefulWidget {
  final UserProfile currentProfile;
  final String targetUid;
  final String targetName;

  const RealChatPage({
    super.key,
    required this.currentProfile,
    required this.targetUid,
    required this.targetName,
  });

  @override
  State<RealChatPage> createState() => _RealChatPageState();
}

class _RealChatPageState extends State<RealChatPage> {
  final messageController = TextEditingController();

  final messageFocusNode = FocusNode();

  Timer? activityTimer;
  Timer? typingTimer;

  bool sending = false;
  bool typingSent = false;
  bool voiceOpen = false;
  late final VoiceMessageService voiceService = VoiceMessageService();

  /// Cavab verilən mesaj: {id, name, text}
  Map<String, String>? replyTo;

  /// Söhbətin mövzusu — sənəddə saxlanılır, hər iki tərəf eyni görür.
  ChatTheme theme = chatThemes.first;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? themeSub;

  // ----- MÖVZU SÜZGƏCİ -----
  //
  // Söhbət qadağan mövzuya keçəndə yazışma dayanır. Qərarı
  // `chat_filter.dart` verir, kilidi `chat_lock.dart` yazır.

  /// Qüvvədə olan kilid. `null`-dırsa söhbət açıqdır.
  ChatLock? chatLock;

  /// Söhbətin indiki qiyməti — xəbərdarlıq zolağı buna baxır.
  ChatVerdict filterVerdict = ChatVerdict.clean;

  /// Son mesajların mətni: yeni mesaj göndərilməzdən əvvəl ölçü
  /// bunların üstünə qoyulur.
  List<String> recentTexts = const [];

  /// Söhbətin neçə dəfə bağlandığı — müddət buna görə uzanır.
  int lockCount = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? filterSub;

  /// Hansı vaxta qədər "oxundu" yazmışıq — təkrar yazının qarşısını alır.
  DateTime? markedReadUpTo;

  /// Qarşı tərəf yazır?
  ///
  /// Nişanın təzəliyi **bizim öz saatımızla** ölçülür: nişanı ilk
  /// dəfə görəndə vaxtı yazırıq. Əvvəl sənəddəki server vaxtı ilə
  /// telefonun saatı müqayisə olunurdu — telefonun saatı bir neçə
  /// saniyə fərqlidirsə, "yazır…" heç vaxt görünmürdü. İki quşun
  /// işləməməsi də eyni səbəbdən idi.
  bool peerTyping = false;
  DateTime? peerTypingSince;

  /// Nişan bu qədər saxlanılır. Tətbiq sərt bağlananda sahə sənəddə
  /// `true` qalır — onsuz "yazır…" həmişəlik asılardı.
  static const _typingWindow = Duration(seconds: 12);

  bool get showTyping =>
      peerTyping &&
      peerTypingSince != null &&
      DateTime.now().difference(peerTypingSince!) < _typingWindow;

  /// İki kilid yazısının üst-üstə düşməməsi üçün.
  bool locking = false;

  /// Söhbəti canlandıran mini oyunlar.
  static const truths = <String>[
    'Doğruluq 🤫 Ən son kimə "gülməli video" göndərmisən?',
    'Doğruluq 🤫 Telefonunda ən çox açdığın tətbiq hansıdır?',
    'Doğruluq 🤫 Özündə ən çox bəyəndiyin xüsusiyyət nədir?',
    'Doğruluq 🤫 Ən son nəyə görə çox güldün?',
    'Doğruluq 🤫 Gizli istedadın var? Nədir?',
  ];

  static const dares = <String>[
    'Cəsarət 😈 Növbəti mesajını yalnız emoji ilə yaz!',
    'Cəsarət 😈 Səsli mesajda ən sevdiyin mahnının bir sətrini oxu 🎤',
    'Cəsarət 😈 Qalereyandakı sonuncu şəkli təsvir et (göndərmədən) 📸',
    'Cəsarət 😈 Mənə 10 saniyəlik ən yaxşı zarafatını danış 😂',
    'Cəsarət 😈 Adımı sadəcə emojilərlə yaz!',
  ];

  static const wouldYouRather = <String>[
    'Sən hansını seçərsən? 🤔 Dəniz kənarında səhər, yoxsa dağda gün batımı?',
    'Sən hansını seçərsən? 🤔 Bir il musiqisiz, yoxsa bir il serialsız?',
    'Sən hansını seçərsən? 🤔 Uçmaq bacarığı, yoxsa görünməzlik?',
    'Sən hansını seçərsən? 🤔 Həmişə gec qalmaq, yoxsa həmişə 1 saat tez gəlmək?',
    'Sən hansını seçərsən? 🤔 Pizza, yoxsa dönər? 🍕🌯',
  ];

  /// Söhbət boş olanda göstərilən söhbət açarları.
  static const iceBreakers = <String>[
    'Salam 👋 Günün necə keçir?',
    'Bir söz de, sənə mahnı tapım 🎧',
    'Ən son nəyə ürəkdən güldün? 😂',
    'Qəhvə yoxsa çay? ☕',
    'Bu həftə ən yaxşı anın hansı oldu? ✨',
    'Sənə bir sual: dəniz yoxsa dağ? 🌊⛰️',
  ];

  final List<String> emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥰',
    '😘',
    '😉',
    '😎',
    '🥳',
    '😭',
    '😢',
    '😡',
    '🤔',
    '🤭',
    '🫣',
    '😴',
    '❤️',
    '💜',
    '🤍',
    '🔥',
    '💯',
    '👍',
    '👎',
    '👏',
    '🙏',
    '✨',
    '🎉',
    '💪',
    '🤝',
    '👋',
    '🌹',
    '😇',
  ];

  final List<String> stickers = [
    '❤️',
    '😂',
    '🥰',
    '🔥',
    '💯',
    '🎉',
    '🐻',
    '😎',
    '💜',
    '✨',
    '🥳',
    '😘',
    '😍',
    '🤩',
    '👏',
    '💪',
  ];

  String get chatId {
    final ids = [widget.currentProfile.uid, widget.targetUid]..sort();

    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();

    messageController.addListener(_onTypingChanged);

    themeSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      final data = snap.data();
      final next = chatThemeOf(data?['theme']);
      final lock = readChatLock(data);

      final typingMap = data?['typing'];
      final typingNow =
          typingMap is Map && typingMap[widget.targetUid] == true;

      if (typingNow != peerTyping) {
        peerTyping = typingNow;
        peerTypingSince = typingNow ? DateTime.now() : null;
        if (mounted) setState(() {});
      }

      // Kilid sənəddədir: qarşı tərəf bağlanmaya səbəb olsa da,
      // hər iki ekran eyni anda bağlanır.
      if (next.id != theme.id ||
          lock?.until != chatLock?.until ||
          lockCount != lockCountOf(data)) {
        setState(() {
          theme = next;
          chatLock = lock;
          lockCount = lockCountOf(data);
        });
      }
    }, onError: (Object _) {});

    filterSub = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(filterWindow)
        .snapshots()
        .listen(_onRecentMessages, onError: (Object _) {});

    activityTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    themeSub?.cancel();
    filterSub?.cancel();
    activityTimer?.cancel();
    typingTimer?.cancel();
    messageController.removeListener(_onTypingChanged);
    if (typingSent) {
      _setTyping(false);
    }
    messageController.dispose();
    messageFocusNode.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final active = messageController.text.trim().isNotEmpty;
    typingTimer?.cancel();

    if (active && !typingSent) {
      typingSent = true;
      _setTyping(true);
    }

    if (!active && typingSent) {
      typingSent = false;
      _setTyping(false);
      return;
    }

    if (active) {
      typingTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        typingSent = false;
        _setTyping(false);
      });
    }
  }

  Future<void> _setTyping(bool value) async {
    final ref = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      await ref.update({
        'typing.${widget.currentProfile.uid}': value,
        'typingAt.${widget.currentProfile.uid}': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      try {
        await ref.set({
          'members': [widget.currentProfile.uid, widget.targetUid],
          'memberNames': {
            widget.currentProfile.uid: widget.currentProfile.name,
            widget.targetUid: widget.targetName,
          },
          'typing': {widget.currentProfile.uid: value},
          'typingAt': {widget.currentProfile.uid: FieldValue.serverTimestamp()},
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Son mesajlar dəyişəndə söhbətin mövzusu yenidən ölçülür.
  ///
  /// Ölçmə **hər iki tərəfin** mesajlarına baxır: mövzunu tək adam
  /// yox, söhbət özü müəyyən edir.
  void _onRecentMessages(QuerySnapshot<Map<String, dynamic>> snap) {
    final texts = <String>[];

    // Qarşı tərəfdən gələn ƏN TƏZƏ mesajın vaxtı.
    //
    // Sorğu `createdAt` üzrə azalan sıradadır, ona görə ilk tapılan
    // ən təzəsidir.
    Timestamp? newestIncoming;

    for (final doc in snap.docs) {
      final data = doc.data();

      if (newestIncoming == null &&
          data['senderId'] == widget.targetUid &&
          data['createdAt'] is Timestamp) {
        newestIncoming = data['createdAt'] as Timestamp;
      }

      // Stiker, şəkil və səs mətn kimi ölçülmür.
      if ('${data['type'] ?? 'text'}' != 'text') continue;
      texts.add('${data['text'] ?? ''}');
    }

    if (newestIncoming != null) _markRead(newestIncoming);

    final verdict = evaluateChat(texts);

    if (mounted) {
      setState(() {
        recentTexts = texts;
        filterVerdict = verdict;
      });
    } else {
      recentTexts = texts;
      filterVerdict = verdict;
    }

    if (verdict.blocks && chatLock == null) {
      unawaited(_lockChat(verdict.topic!));
    }
  }

  /// "Görüldü" işarəsini yazır.
  ///
  /// Burada bir incəlik var. Əvvəl bu sahəyə
  /// `FieldValue.serverTimestamp()` yazılırdı, mesajın `createdAt`
  /// sahəsi isə göndərənin **telefon saatı** ilə doldurulur. İki
  /// müxtəlif saatı müqayisə etmək olmaz: göndərənin saatı bir neçə
  /// dəqiqə irəlidirsə, `readAt` həmişə `createdAt`-dan kiçik çıxır və
  /// mesaj heç vaxt "görüldü" olmur. İki quşun görünməməsinin səbəbi
  /// bu idi.
  ///
  /// İndi oxunma nişanı kimi qarşı tərəfin öz mesajının `createdAt`
  /// dəyəri yazılır. Hər iki tərəf eyni saatdan gəlir, müqayisə
  /// doğrudur.
  Future<void> _markRead(Timestamp upTo) async {
    // Səhifə arxada qalıbsa oxunmuş sayılmır.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;

    // Eyni dəyəri təkrar yazmırıq — yoxsa dinləyici ilə yazı
    // bir-birini sonsuz oyadardı.
    if (markedReadUpTo != null && !upTo.toDate().isAfter(markedReadUpTo!)) {
      return;
    }
    markedReadUpTo = upTo.toDate();

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'members': [widget.currentProfile.uid, widget.targetUid],
        'readAt': {widget.currentProfile.uid: upTo},
        // Söhbət açıqdır — oxunmamış sayğacı sıfırlanır.
        'unread': {widget.currentProfile.uid: 0},
      }, SetOptions(merge: true));
    } catch (_) {
      // Yazıla bilmədisə növbəti mesajda yenidən cəhd olunur.
      markedReadUpTo = null;
    }
  }

  /// Söhbəti bağlayır.
  Future<void> _lockChat(FilterTopic topic) async {
    if (locking) return;
    locking = true;

    try {
      await applyChatLock(
        FirebaseFirestore.instance.collection('chats').doc(chatId),
        topic: topic,
        previousLocks: lockCount,
        members: [widget.currentProfile.uid, widget.targetUid],
      );
    } catch (_) {
      // Yazıla bilmədisə növbəti mesajda yenidən cəhd olunur.
    } finally {
      locking = false;
    }
  }

  Future<void> _setReaction(
    DocumentReference<Map<String, dynamic>> ref,
    String emoji,
  ) async {
    try {
      await ref.update({'reactions.${widget.currentProfile.uid}': emoji});
    } catch (_) {
      if (mounted) notifySocial(context, 'Reaksiya əlavə edilmədi.');
    }
  }

  /// Sağa sürüşdürəndə və ya menyudan cavab rejimini açır.
  void _startReply(String id, String name, String preview) {
    HapticFeedback.selectionClick();
    setState(() {
      replyTo = {'id': id, 'name': name, 'text': preview};
    });
    messageFocusNode.requestFocus();
  }

  /// Mesaja iki dəfə toxunanda sürətli ürək reaksiyası.
  void _quickReact(
    DocumentReference<Map<String, dynamic>> ref,
    Offset position,
  ) {
    showFloatingEmoji(context, position, '❤️');
    _setReaction(ref, '❤️');
  }

  /// Gün ayırıcısı üçün başlıq.
  String _dayLabel(DateTime day) {
    const months = [
      'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
      'iyul', 'avqust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    final difference = today.difference(that).inDays;

    if (difference == 0) return 'Bu gün';
    if (difference == 1) return 'Dünən';
    if (day.year != now.year) {
      return '${day.day} ${months[day.month - 1]} ${day.year}';
    }
    return '${day.day} ${months[day.month - 1]}';
  }

  /// Mesajın qısa mətn xülasəsi (cavab önizləməsi üçün).
  String _previewOf(Map<String, dynamic> data) {
    final type = '${data['type'] ?? 'text'}';
    if (type == 'audio') return '🎤 Səsli mesaj';
    if (type == 'sticker') return '${data['text'] ?? ''} Stiker';
    if (type == 'domino') return 'Domino oyunu';
    if (type == 'photo') return 'Şəkil';
    return '${data['text'] ?? ''}';
  }

  Future<void> _deleteMessage(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.delete();
      if (mounted) notifySocial(context, 'Mesaj silindi.');
    } catch (_) {
      if (mounted) notifySocial(context, 'Mesaj silinmədi.');
    }
  }

  void _openMessageActions(
    DocumentReference<Map<String, dynamic>> ref,
    bool mine,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reaksiya ver',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final e in const ['❤️', '😂', '🔥', '👍', '😮', '😢'])
                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        Navigator.pop(sheet);
                        _setReaction(ref, e);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 29)),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24, color: Color(0xff352447)),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Color(0xff9d7dff)),
                title: const Text('Cavab ver', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheet);
                  _startReply(
                    ref.id,
                    mine ? 'Sən' : widget.targetName,
                    _previewOf(data),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xff8fd4ff)),
                title: const Text('Mətni kopyala', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheet);
                  Clipboard.setData(ClipboardData(text: '${data['text'] ?? ''}'));
                  notifySocial(context, 'Mətn kopyalandı.');
                },
              ),
              if (mine)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xffff657b)),
                  title: const Text('Mesajı sil', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _deleteMessage(ref);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty || sending) {
      return;
    }

    final sent = await sendContent(text: text, type: 'text', lastMessage: text);

    if (mounted && sent && messageController.text.trim() == text) {
      messageController.clear();
      typingSent = false;
      _setTyping(false);
    }

    if (mounted) {
      messageFocusNode.requestFocus();
    }
  }

  Future<void> sendSticker(String sticker) async {
    if (sending) return;

    Navigator.pop(context);

    await sendContent(
      text: sticker,
      type: 'sticker',
      lastMessage: 'Stiker $sticker',
    );
  }

  Future<bool> sendContent({
    required String text,
    required String type,
    required String lastMessage,
  }) async {
    if (sending) return false;

    // Söhbət bağlıdırsa heç nə getmir — mətn də, stiker də, şəkil də.
    if (chatLock != null) {
      notifySocial(context, 'Bu söhbət dayandırılıb.');
      return false;
    }

    // İcma qaydaları: uyğunsuz məzmun göndərilmir.
    if (type == 'text' && !guardContent(context, text)) return false;

    // Mövzu süzgəci: bu mesaj həddi keçirsə, söhbət burada bağlanır
    // və mesajın özü də getmir.
    if (type == 'text') {
      final verdict = evaluateChat(recentTexts, pending: text);

      if (verdict.blocks) {
        await _lockChat(verdict.topic!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xff4a1020),
              duration: const Duration(seconds: 5),
              content: Text(
                'Söhbət dayandırıldı: ${verdict.topic!.label}. '
                '${verdict.topic!.explanation}',
              ),
            ),
          );
        }

        return false;
      }
    }

    setState(() {
      sending = true;
    });

    try {
      final chat = FirebaseFirestore.instance.collection('chats').doc(chatId);

      final message = chat.collection('messages').doc();

      final batch = FirebaseFirestore.instance.batch();

      batch.set(chat, {
        'members': [widget.currentProfile.uid, widget.targetUid],
        'memberNames': {
          widget.currentProfile.uid: widget.currentProfile.name,
          widget.targetUid: widget.targetName,
        },
        'unread': {widget.targetUid: FieldValue.increment(1)},
        'lastMessage': lastMessage,
        'lastSenderId': widget.currentProfile.uid,
        // "Ən çox yazışılan" süzgəci bu sayğaca görə sıralayır.
        'messageCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      final reply = replyTo;

      batch.set(message, {
        'senderId': widget.currentProfile.uid,
        'text': text,
        'type': type,
        'createdAt': Timestamp.now(),
        'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
        if (reply != null) 'replyId': reply['id'],
        if (reply != null) 'replyName': reply['name'],
        if (reply != null) 'replyText': reply['text'],
      });

      await batch.commit();

      if (mounted && reply != null) {
        setState(() => replyTo = null);
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.targetUid)
            .collection('notifications')
            .add({
          'type': 'message',
          'title': widget.currentProfile.name,
          'body': lastMessage,
          'fromUid': widget.currentProfile.uid,
          'chatId': chatId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // Cihaz bildirişi (Supabase Edge Function deploy edilibsə).
      unawaited(sendPushToUser(
        toUid: widget.targetUid,
        title: widget.currentProfile.name,
        body: lastMessage,
        fromName: widget.currentProfile.name,
      ));

      return true;
    } catch (_) {
      if (mounted) {
        notifySocial(context, 'Mesaj göndərilmədi. Yenidən sına.');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  void insertEmoji(String emoji) {
    final oldText = messageController.text;

    final selection = messageController.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = oldText.length;
      end = oldText.length;
    }

    final newText = oldText.replaceRange(start, end, emoji);

    messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );

    Navigator.pop(context);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        messageFocusNode.requestFocus();
      }
    });
  }

  void openEmojiPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xff120d1d),
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Emoji seç',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: emojis.length,
                    itemBuilder: (context, index) {
                      final emoji = emojis[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          insertEmoji(emoji);
                        },
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Təsadüfi oyun sualını mesaj kimi göndərir.
  Future<void> _sendFun(List<String> pool) async {
    Navigator.pop(context);
    final text = pool[math.Random().nextInt(pool.length)];
    await sendContent(text: text, type: 'text', lastMessage: text);
  }

  /// "+" düyməsi: stiker, oyun və digər əlavələr.
  /// Şəkli tam ekranda açır — böyük nüsxə ayrıca sənəddən gəlir.
  void _openPhoto(
    DocumentReference<Map<String, dynamic>> messageRef,
    String thumb,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (dialog) => Stack(
        children: [
          Center(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: messageRef.collection('media').doc('full').get(),
              builder: (_, snap) {
                final full = '${snap.data?.data()?['data'] ?? ''}';
                final source = full.isNotEmpty ? full : thumb;
                final provider = vibeImageProvider(source);
                if (provider == null) {
                  return const Icon(Icons.broken_image_rounded,
                      color: vMuted, size: 48);
                }
                return InteractiveViewer(
                  maxScale: 4,
                  child: Image(image: provider, fit: BoxFit.contain),
                );
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.pop(dialog),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Söhbətə şəkil göndərir.
  ///
  /// Şəkil sıxılıb Firestore-da data URI kimi saxlanılır (pullu Storage
  /// tələb etmir) — kiçik nüsxə mesajda, böyüyü ayrıca sənəddə.
  Future<void> _sendPhoto(ImageSource source) async {
    if (sending) return;

    // Kamera bir şəkil verir.
    if (source == ImageSource.camera) {
      final one = await pickStoredImage(
        source: source,
        fullWidth: 1080,
        thumbWidth: 320,
      );
      if (one == null || !mounted) return;
      await _pushPhoto(one);
      return;
    }

    // Qalereya: bir dəfəyə dördə qədər şəkil. Əvvəl hər şəkil üçün
    // qalereya yenidən açılırdı.
    final files = await pickGalleryPhotos(max: 4);
    if (files.isEmpty || !mounted) return;

    for (final file in files) {
      if (!mounted) return;

      final image = compressToStoredImage(
        file.bytes,
        fullWidth: 1080,
        thumbWidth: 320,
      );
      if (image == null) continue;

      await _pushPhoto(image);
    }
  }

  /// Bir şəkli söhbətə yazır.
  Future<void> _pushPhoto(StoredImage picked) async {
    if (chatLock != null) {
      notifySocial(context, 'Bu söhbət dayandırılıb.');
      return;
    }

    setState(() => sending = true);
    try {
      final chat = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final message = chat.collection('messages').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(chat, {
        'members': [widget.currentProfile.uid, widget.targetUid],
        'memberNames': {
          widget.currentProfile.uid: widget.currentProfile.name,
          widget.targetUid: widget.targetName,
        },
        'unread': {widget.targetUid: FieldValue.increment(1)},
        'lastMessage': '📷 Şəkil',
        'lastSenderId': widget.currentProfile.uid,
        // "Ən çox yazışılan" süzgəci bu sayğaca görə sıralayır.
        'messageCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      batch.set(message, {
        'senderId': widget.currentProfile.uid,
        'text': '',
        'type': 'photo',
        'photo': picked.thumb,
        'createdAt': Timestamp.now(),
        'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Tam ölçülü nüsxə ayrıca — siyahı sürətli qalsın.
      batch.set(message.collection('media').doc('full'), {'data': picked.full});

      await batch.commit();

      unawaited(sendPushToUser(
        toUid: widget.targetUid,
        title: widget.currentProfile.name,
        body: '📷 Şəkil göndərdi',
        fromName: widget.currentProfile.name,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şəkil göndərilmədi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  /// Söhbətdəki dostla domino oyununu başladır.
  ///
  /// Oyun yaradılır, söhbətə dəvət mesajı düşür və hər iki tərəf
  /// həmin mesajdan oyuna girə bilir.
  Future<void> _startDomino() async {
    if (sending) return;
    setState(() => sending = true);

    try {
      final matchId = await createDominoMatch(
        myUid: widget.currentProfile.uid,
        myName: widget.currentProfile.name,
        opponentUid: widget.targetUid,
        opponentName: widget.targetName,
      );

      final chat = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final batch = FirebaseFirestore.instance.batch();

      batch.set(chat, {
        'members': [widget.currentProfile.uid, widget.targetUid],
        'memberNames': {
          widget.currentProfile.uid: widget.currentProfile.name,
          widget.targetUid: widget.targetName,
        },
        'unread': {widget.targetUid: FieldValue.increment(1)},
        'lastMessage': 'Domino oyunu',
        'lastSenderId': widget.currentProfile.uid,
        // "Ən çox yazışılan" süzgəci bu sayğaca görə sıralayır.
        'messageCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      batch.set(chat.collection('messages').doc(), {
        'senderId': widget.currentProfile.uid,
        'text': 'Domino oynayaq?',
        'type': 'domino',
        'matchId': matchId,
        'createdAt': Timestamp.now(),
        'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await batch.commit();

      unawaited(sendPushToUser(
        toUid: widget.targetUid,
        title: widget.currentProfile.name,
        body: 'Səni domino oyununa dəvət edir',
        fromName: widget.currentProfile.name,
      ));

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DominoPage(
            matchId: matchId,
            profile: widget.currentProfile,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oyun başlamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void openMoreSheet() {
    messageFocusNode.unfocus();

    // Siyahı yeddi sətirdir; adi vərəq ekranın yarısını keçməyə qoymur və
    // son sətirlər kəsilirdi. Ona görə vərəq sürüşən rejimdədir və hündürlüyü
    // ekranın 85%-nə qədər uzana bilir.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xff120d1d),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Söhbəti canlandır 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xff48e08a)),
                  title: const Text('Şəkil göndər', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Qalereyadan seç', style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _sendPhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded, color: Color(0xff22a7ff)),
                  title: const Text('Şəkil çək', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Kamera ilə indi çək', style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _sendPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xffff5bd6)),
                  title: const Text('Stiker göndər', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Böyük emoji stikerlər', style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheet);
                    openStickerPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.casino_rounded, color: Color(0xff48e08a)),
                  title: const Text('Domino oyna',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Dostunla növbə ilə — real oyun',
                      style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _startDomino();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_alt_rounded, color: Color(0xff8fd4ff)),
                  title: const Text('Doğruluq', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Təsadüfi sual göndər', style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () => _sendFun(truths),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_rounded, color: Color(0xffff8a3d)),
                  title: const Text('Cəsarət', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Kiçik bir tapşırıq at', style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () => _sendFun(dares),
                ),
                ListTile(
                  leading: const Icon(Icons.casino_rounded, color: Color(0xff48e08a)),
                  title: const Text('Sən hansını seçərsən?', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('İki variantdan biri', style: TextStyle(color: vMuted, fontSize: 12)),
                  onTap: () => _sendFun(wouldYouRather),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void openStickerPicker() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xff120d1d),
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Stiker seç',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(18),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: stickers.length,
                    itemBuilder: (context, index) {
                      final sticker = stickers[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          sendSticker(sticker);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff21162f),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            sticker,
                            style: const TextStyle(fontSize: 45),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUid)
          .snapshots(),
      builder: (context, userSnapshot) {
        String status = 'Aktivlik bilinmir';

        bool online = false;

        if (userSnapshot.hasData &&
            userSnapshot.data!.exists &&
            userSnapshot.data!.data() != null) {
          final data = userSnapshot.data!.data()!;

          status = activityText(data);
          online = isReallyOnline(data);
        }

        final peerVibe = VibeStatus.from(userSnapshot.data?.data());

        return Scaffold(
          backgroundColor: theme.background.last,
          appBar: AppBar(
            backgroundColor: theme.background.last,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            titleSpacing: 4,
            title: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PersonPage(
                    currentProfile: widget.currentProfile,
                    targetUid: widget.targetUid,
                  ),
                ),
              ),
              child: Row(
              children: [
                // Başlıqdakı avatar.
                //
                // Əvvəl burada yalnız adın ilk hərfi vardı — şəkil
                // göstərilmirdi. Onlayn nişanı isə ümumiyyətlə yox
                // idi: yanında "İndi aktivdir" yazılsa da yaşıl nöqtə
                // görünmürdü.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: online
                              ? const Color(0xff2de28a)
                              : Colors.transparent,
                          width: 1.6,
                        ),
                      ),
                      child: ClipOval(
                        child: VibePhoto(
                          url:
                              '${userSnapshot.data?.data()?['photoUrl'] ?? ''}',
                          name: widget.targetName,
                        ),
                      ),
                    ),

                    if (online)
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xff2de28a),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.background.last,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xaa2de28a),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Əhval nişanı yuxarı keçdi ki, yaşıl nöqtə ilə
                    // üst-üstə düşməsin.
                    if (peerVibe != null)
                      Positioned(
                        right: -4,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: peerVibe.mood.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xff0d0917), width: 2),
                          ),
                          child: Text(
                            peerVibe.mood.emoji,
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.targetName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          // Nişan söhbət sənədinin dinləyicisindən gəlir —
                          // burada ayrıca axın açmağa ehtiyac yoxdur.
                          final isTyping = showTyping;
                          // Nişan yalnız təzə olanda göstərilir.
                          //
                          // Tətbiq düzgün bağlanmasa sahə silinmir; belə
                          // halda adam çıxsa da "səsli söhbətdə" görünürdü.
                          // Otaqdakı ürək döyüntüsü hər 25 saniyədə
                          // activeRoomAt-ı təzələyir, ona görə 90 saniyə
                          // kifayət qədər geniş hədddir.
                          final roomAt =
                              userSnapshot.data?.data()?['activeRoomAt'];
                          final roomFresh = roomAt is Timestamp &&
                              DateTime.now()
                                      .difference(roomAt.toDate())
                                      .inSeconds <
                                  90;

                          final roomId = roomFresh
                              ? '${userSnapshot.data?.data()?['activeRoomId'] ?? ''}'
                              : '';

                          // Qarşı tərəf səsli otaqdadırsa, oraya keçid göstəririk.
                          if (roomId.isNotEmpty && !isTyping) {
                            return InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PartyRoomPage(
                                    profile: widget.currentProfile,
                                    roomId: roomId,
                                  ),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.graphic_eq_rounded,
                                      size: 12, color: Color(0xff8b5cff)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Səsli söhbətdə',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff8b5cff),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Text(
                            isTyping ? 'yazır…' : status,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isTyping
                                  ? const Color(0xffff65dc)
                                  : online
                                      ? const Color(0xff45f0a8)
                                      : const Color(0xff9b91ae),
                              fontWeight: isTyping ? FontWeight.w800 : FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  startCall(
                    context,
                    widget.currentProfile.uid,
                    widget.currentProfile.name,
                    widget.targetUid,
                    widget.targetName,
                    false,
                  );
                },
                tooltip: 'Səsli zəng',
                icon: const Icon(Icons.call_outlined),
              ),
              IconButton(
                onPressed: () {
                  startCall(
                    context,
                    widget.currentProfile.uid,
                    widget.currentProfile.name,
                    widget.targetUid,
                    widget.targetName,
                    true,
                  );
                },
                tooltip: 'Video zəng',
                icon: const Icon(Icons.videocam_outlined),
              ),
              IconButton(
                onPressed: () => showChatThemeSheet(
                  context,
                  chatId: chatId,
                  current: theme,
                ),
                tooltip: 'Söhbət mövzusu',
                icon: const Icon(Icons.palette_outlined),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: theme.backgroundGradient),
            child: StreamBuilder<BlockState>(
            stream: watchBlockState(widget.currentProfile.uid, widget.targetUid),
            builder: (context, blockSnap) {
              final block = blockSnap.data ?? BlockState.none;
              return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Mesaj xətası:\n'
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xffff2bd6)));
                    }

                    final messages = snapshot.data!.docs;

                    if (messages.isEmpty) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                        child: Column(
                          children: [
                            Container(
                              width: 74,
                              height: 74,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: vHot,
                                boxShadow: [
                                  BoxShadow(color: Color(0x55ff2bd6), blurRadius: 24),
                                ],
                              ),
                              child: const Icon(
                                Icons.waving_hand_rounded,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${widget.targetName} ilə söhbətə başla',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Aşağıdakılardan birinə toxun — buz dərhal əriyir 💜',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.45),
                            ),
                            const SizedBox(height: 14),
                            VibePillStream(uid: widget.targetUid, compact: false),
                            const SizedBox(height: 22),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final prompt in iceBreakers)
                                  VibeChip(
                                    label: prompt,
                                    onTap: sending
                                        ? null
                                        : () => sendContent(
                                            text: prompt,
                                            type: 'text',
                                            lastMessage: prompt,
                                          ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data();

                        final mine =
                            data['senderId'] == widget.currentProfile.uid;

                        final type = '${data['type'] ?? 'text'}';

                        final text = '${data['text'] ?? ''}';
                        final messageRef = messages[index].reference;
                        final createdAt = data['createdAt'];
                        final reactions = (data['reactions'] as Map?) ?? const {};
                        final reactionValues = reactions.values.map((e) => '$e').where((e) => e.isNotEmpty).toList();

                        // --- gün ayırıcısı ---
                        DateTime? dayOf(int i) {
                          if (i < 0 || i >= messages.length) return null;
                          final value = messages[i].data()['createdAt'];
                          return value is Timestamp ? value.toDate() : null;
                        }

                        final thisDay = dayOf(index);
                        final olderDay = dayOf(index + 1);
                        final showDay = thisDay != null &&
                            (olderDay == null ||
                                thisDay.year != olderDay.year ||
                                thisDay.month != olderDay.month ||
                                thisDay.day != olderDay.day);

                        // --- cavab + jestlər ---
                        final replyName = '${data['replyName'] ?? ''}';
                        final replyText = '${data['replyText'] ?? ''}';

                        Offset doubleTapAt = Offset.zero;

                        Widget decorate(Widget bubble) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDay)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: .08)),
                                    ),
                                    child: Text(
                                      _dayLabel(thisDay),
                                      style: const TextStyle(
                                        color: Color(0xffb6adc7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onDoubleTapDown: (details) => doubleTapAt = details.globalPosition,
                              onDoubleTap: () => _quickReact(messageRef, doubleTapAt),
                              onHorizontalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity > 220) {
                                  _startReply(
                                    messageRef.id,
                                    mine ? 'Sən' : widget.targetName,
                                    _previewOf(data),
                                  );
                                }
                              },
                              child: Column(
                                crossAxisAlignment:
                                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (replyText.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 3),
                                      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                                      constraints: const BoxConstraints(maxWidth: 280),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: .05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border(
                                          left: BorderSide(
                                            color: mine ? const Color(0xffff65dc) : const Color(0xff8b5cff),
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            replyName.isEmpty ? 'Cavab' : replyName,
                                            style: const TextStyle(
                                              color: Color(0xffd0b6ff),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            replyText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xffa89fbd),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  bubble,
                                ],
                              ),
                            ),
                          ],
                        );

                        if (type == 'audio') {
                          final path = '${data['audioPath'] ?? ''}';
                          final duration = data['durationMs'];
                          return decorate(Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: mine ? theme.mineGradient : null,
                                color: mine ? null : const Color(0xff1b1426),
                                border: mine ? null : Border.all(color: const Color(0xff352447)),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: VoicePlayer(
                                key: ValueKey(messages[index].id),
                                mine: mine,
                                durationMs: duration is num
                                    ? duration.toInt()
                                    : 0,
                                load: () => voiceService.download(path),
                              ),
                            ),
                          ));
                        }

                        if (type == 'domino') {
                          final matchId = '${data['matchId'] ?? ''}';
                          return decorate(Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              constraints: const BoxConstraints(maxWidth: 250),
                              decoration: BoxDecoration(
                                color: vPanel,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: vLine),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.casino_rounded,
                                          color: Color(0xff48e08a), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Domino',
                                        style: TextStyle(
                                          color: vInk,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    mine
                                        ? 'Dəvət göndərdin'
                                        : 'Səni oyuna dəvət edir',
                                    style: const TextStyle(
                                      color: vMuted,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  GradientButton(
                                    label: 'Oyuna keç',
                                    height: 40,
                                    fontSize: 13.5,
                                    gradient: vBrand,
                                    onPressed: matchId.isEmpty
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DominoPage(
                                                  matchId: matchId,
                                                  profile:
                                                      widget.currentProfile,
                                                ),
                                              ),
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          ));
                        }

                        if (type == 'photo') {
                          final thumb = '${data['photo'] ?? ''}';
                          return decorate(Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () => _openPhoto(messageRef, thumb),
                              onLongPress: () =>
                                  _openMessageActions(messageRef, mine, data),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                  maxHeight: 360,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: vLine),
                                ),
                                clipBehavior: Clip.antiAlias,
                                // contain, cover deyil: uzun ekran şəkli
                                // cover ilə ortadan kəsilir və boş bloka
                                // oxşayır. contain nisbəti saxlayır.
                                child: thumb.isEmpty
                                    ? const SizedBox(
                                        width: 180,
                                        height: 140,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_rounded,
                                            color: vMuted,
                                          ),
                                        ),
                                      )
                                    : Image(
                                        image: vibeImageProvider(thumb)!,
                                        fit: BoxFit.contain,
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null) return child;
                                          return const SizedBox(
                                            width: 180,
                                            height: 140,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(
                                                color: vPink,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, _, _) =>
                                            const SizedBox(
                                          width: 180,
                                          height: 140,
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.broken_image_rounded,
                                                  color: vMuted,
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  'Şəkil açılmadı',
                                                  style: TextStyle(
                                                    color: vMuted,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ));
                        }

                        // --- zəng qeydi ---
                        //
                        // Zəng söhbətdə iz qoymalıdır: cavabsız zəngi
                        // sabah görmək lazımdır. Toxunanda yenidən
                        // zəng edir — cavabsız zəngdən sonra adamın
                        // ilk istədiyi budur.
                        if (type == 'call') {
                          final video = data['callVideo'] == true;
                          final outcome = outcomeFromName(data['callOutcome']);
                          final missed = outcome != CallOutcome.answered;

                          return decorate(Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: PressableScale(
                              onTap: () => startCall(
                                context,
                                widget.currentProfile.uid,
                                widget.currentProfile.name,
                                widget.targetUid,
                                widget.targetName,
                                video,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(13, 9, 15, 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xff1b1426),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: missed && !mine
                                        ? const Color(0xff5a2433)
                                        : const Color(0xff352447),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      video
                                          ? (missed
                                              ? Icons.videocam_off_rounded
                                              : Icons.videocam_rounded)
                                          : (missed
                                              ? Icons.phone_missed_rounded
                                              : Icons.phone_in_talk_rounded),
                                      size: 17,
                                      color: missed
                                          ? const Color(0xffff8a9b)
                                          : const Color(0xff2de28a),
                                    ),
                                    const SizedBox(width: 9),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          callLogText(
                                            video: video,
                                            outcome: outcome,
                                            seconds: int.tryParse(
                                                    '${data['callSeconds'] ?? 0}') ??
                                                0,
                                            mine: mine,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Yenidən zəng et',
                                          style: TextStyle(
                                            color: vMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ));
                        }

                        if (type == 'sticker') {
                          return decorate(Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () =>
                                  _openMessageActions(messageRef, mine, data),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(5),
                                child: Text(
                                  text,
                                  style: const TextStyle(fontSize: 58),
                                ),
                              ),
                            ),
                          ));
                        }

                        // Yalnız emojidən ibarət qısa mesajlar böyük görünür.
                        final emojiOnly = text.trim().isNotEmpty &&
                            text.trim().length <= 8 &&
                            !RegExp(r'[0-9A-Za-zƏəĞğİıÖöŞşÜüÇç]').hasMatch(text);

                        if (emojiOnly) {
                          return decorate(Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () =>
                                  _openMessageActions(messageRef, mine, data),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
                                child: Column(
                                  crossAxisAlignment: mine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(text, style: const TextStyle(fontSize: 46)),
                                    if (reactionValues.isNotEmpty)
                                      Text(
                                        reactionValues.join(' '),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ));
                        }

                        return decorate(Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _openMessageActions(messageRef, mine, data),
                            child: Container(
                            constraints: const BoxConstraints(maxWidth: 310),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              gradient: mine ? theme.mineGradient : null,
                              color: mine ? null : const Color(0xff1b1426),
                              border: mine ? null : Border.all(color: const Color(0xff352447)),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x09000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                if (reactionValues.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      for (final reaction in reactionValues)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: .22),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(reaction, style: const TextStyle(fontSize: 14)),
                                        ),
                                    ],
                                  ),
                                ],
                                if (mine) ...[
                                  const SizedBox(height: 5),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .snapshots(),
                                      builder: (_, chatSnap) {
                                        final chatData = chatSnap.data?.data() ?? const <String, dynamic>{};
                                        final readAtMap = (chatData['readAt'] as Map?) ?? const {};
                                        final targetReadAt = readAtMap[widget.targetUid];
                                        final seen = targetReadAt is Timestamp &&
                                            createdAt is Timestamp &&
                                            !targetReadAt.toDate().isBefore(createdAt.toDate());

                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              seen ? Icons.done_all_rounded : Icons.done_rounded,
                                              size: 15,
                                              color: seen
                                                  ? const Color(0xff7ee7ff)
                                                  : Colors.white54,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              seen ? 'Görüldü' : 'Göndərildi',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                color: seen
                                                    ? const Color(0xff7ee7ff)
                                                    : Colors.white54,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          ),
                        ));
                      },
                    );
                  },
                ),
              ),

              // ==========================
              // MESAJ YAZMA PANELİ
              // ==========================
              BlockBanner(
                state: block,
                name: widget.targetName,
                onUnblock: () => unblockUser(
                  myUid: widget.currentProfile.uid,
                  targetUid: widget.targetUid,
                ),
              ),

              // Hədd yaxınlaşır — bağlanmadan əvvəl xəbərdarlıq.
              if (chatLock == null &&
                  !block.blocked &&
                  filterVerdict.level == FilterLevel.warn &&
                  filterVerdict.topic != null)
                ChatWarnStrip(topic: filterVerdict.topic!),

              if (chatLock != null)
                ChatLockBanner(lock: chatLock!)
              else if (block.blocked)
                const SizedBox.shrink()
              else if (voiceOpen)
                VoiceComposer(
                  newId: () => FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages')
                      .doc()
                      .id,
                  send: (draft) => voiceService.send(
                    draft: draft,
                    chatId: chatId,
                    senderId: widget.currentProfile.uid,
                    senderName: widget.currentProfile.name,
                    recipientId: widget.targetUid,
                    recipientName: widget.targetName,
                  ),
                  onClose: () => setState(() {
                    voiceOpen = false;
                  }),
                )
              else
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 7, 7, 8),
                    decoration: const BoxDecoration(
                      color: const Color(0xff0d0917),
                      border: const Border(top: BorderSide(color: Color(0xff2a1a3b))),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x09000000),
                          blurRadius: 12,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(6, 2, 6, 8),
                          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(14),
                            border: const Border(
                              left: BorderSide(color: Color(0xffff65dc), width: 3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${replyTo!['name']} mesajına cavab',
                                      style: const TextStyle(
                                        color: Color(0xffd0b6ff),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${replyTo!['text']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xffa89fbd),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cavabı ləğv et',
                                onPressed: () => setState(() => replyTo = null),
                                icon: const Icon(Icons.close_rounded,
                                    color: Color(0xff9d94ae), size: 19),
                              ),
                            ],
                          ),
                        ),
                      Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Stiker və oyunlar',
                          onPressed: openMoreSheet,
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xffff5bd6)),
                        ),
                        IconButton(
                          tooltip: 'Emoji',
                          onPressed: openEmojiPicker,
                          icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xffc8b9dd)),
                        ),

                        // Basıb saxla, danış, burax.
                        //
                        // Əvvəl mikrofon ayrıca panel açırdı: bas,
                        // panel gəlsin, yaz, dayandır, göndər — dörd
                        // toxunuş. İndi bir hərəkətdir.
                        VoiceHoldButton(
                          enabled: !sending,
                          newId: () => FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .collection('messages')
                              .doc()
                              .id,
                          send: (draft) => voiceService.send(
                            draft: draft,
                            chatId: chatId,
                            senderId: widget.currentProfile.uid,
                            senderName: widget.currentProfile.name,
                            recipientId: widget.targetUid,
                            recipientName: widget.targetName,
                          ),
                        ),

                        Expanded(
                          child: TextField(
                            controller: messageController,
                            focusNode: messageFocusNode,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: const Color(0xffff2bd6),
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'Mesaj yaz...',
                              hintStyle: const TextStyle(color: Color(0xff8f86a3)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xff181121),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xffff2bd6),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xff3b2948),
                          ),
                          onPressed: sending ? null : sendMessage,
                          icon: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ),
            ],
              );
            },
          ),
          ),
        );
      },
    );
  }
}
