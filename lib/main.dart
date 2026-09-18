import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'calls.dart';
import 'social_ui.dart';
import 'preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'voice/voice_composer.dart';
import 'voice/voice_message_service.dart';
import 'voice/voice_player.dart';
import 'user_profile.dart';
import 'vibe_video.dart';
import 'moments.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://phxqglacacbyspxucslh.supabase.co',
    publishableKey: 'sb_publishable_HhTEqYafIZGrApWxW3NwvA_LJrIU2Cd',
  );

  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();

    await FirebaseAuth.instance.setPersistence(
      (prefs.getBool('rememberMe') ?? true)
          ? Persistence.LOCAL
          : Persistence.SESSION,
    );
  }

  final prefs = await SharedPreferences.getInstance();

  if (!kIsWeb && prefs.getBool('rememberMe') == false) {
    await FirebaseAuth.instance.signOut();
  }

  appearance.value = (prefs.getInt('appearance') ?? 0).clamp(
    0,
    accentColors.length - 1,
  );

  runApp(const VibeApp());
}

// ============================================================
// VIBE APP
// ============================================================

class VibeApp extends StatelessWidget {
  const VibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
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

  final difference = DateTime.now().difference(lastSeen.toDate());

  return difference.inSeconds >= -5 && difference.inSeconds <= 45;
}

String activityText(Map<String, dynamic> data) {
  final lastSeen = data['lastSeen'];

  if (lastSeen is! Timestamp) {
    return 'Son görülmə bilinmir';
  }

  final time = lastSeen.toDate();
  final difference = DateTime.now().difference(time);

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
              return const MissingProfilePage();
            }

            return MainScreen(
              profile: UserProfile.fromMap(snapshot.data!.data()!),
            );
          },
        );
      },
    );
  }
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

class MissingProfilePage extends StatelessWidget {
  const MissingProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
          child: const Text('Yenidən giriş et'),
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
        const ColoredBox(color: Color(0xff05030d)),
        Container(color: const Color(0xff05030d).withValues(alpha: .74)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _logo(30),
                  const Spacer(),
                  const Icon(Icons.language, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: lang,
                      dropdownColor: const Color(0xff151022),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      items: const ['AZ','TR','EN','RU'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => lang = v ?? lang),
                    ),
                  ),
                ]),
                const Spacer(),
                _logo(64),
                const SizedBox(height: 12),
                Text('${x('people')}\n${x('connections')}', style: const TextStyle(color: Color(0xffff43d7), fontSize: 28, height: 1.12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                Text(x('desc'), style: const TextStyle(color: Colors.white70, fontSize: 17, height: 1.4)),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity, height: 58,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(32)), gradient: LinearGradient(colors: [Color(0xff13b9ff), Color(0xff7657ff), Color(0xffff10c8)])),
                    child: TextButton(onPressed: () => openPage(const LoginPage()), child: Text(x('start'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: TextButton(onPressed: () => openPage(const LoginPage()), child: Text(x('login'), style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white)))),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
    final rect = Offset.zero & size;
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
      if (e.code == 'invalid-credential') {
        showMessage('Email və ya şifrə yanlışdır.');
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

  Widget _appleLogo({double size = 22}) {
    return Icon(
      Icons.apple,
      color: const Color(0xfff2f2f2),
      size: size,
    );
  }

  Future<void> _saveSocialUser(User user) async {
    final fallbackName = user.email?.split('@').first ?? 'VIBE istifadəçisi';
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': (user.displayName ?? '').trim().isEmpty ? fallbackName : user.displayName!.trim(),
      'email': user.email ?? '',
      'age': 0,
      'city': '',
      'about': '',
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => loading = true);
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});

      final credential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      final user = credential.user;
      if (user != null) await _saveSocialUser(user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', true);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google ilə giriş alınmadı')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google ilə giriş alınmadı')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    try {
      setState(() => loading = true);
      final provider = AppleAuthProvider();
      provider.addScope('email');
      provider.addScope('name');

      final credential = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      final user = credential.user;
      if (user != null) await _saveSocialUser(user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', true);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Apple ilə giriş alınmadı')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple ilə giriş alınmadı')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

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
                                        onPressed: () => showMessage('Şifrə bərpasını növbəti addımda qoşacağıq.'),
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _socialButton(
                                          provider: 'google',
                                          text: 'Google ilə davam et',
                                          onPressed: _signInWithGoogle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _socialButton(
                                          provider: 'apple',
                                          text: 'Apple ilə davam et',
                                          onPressed: _signInWithApple,
                                        ),
                                      ),
                                    ],
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

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : () => onPressed(),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xff302a49)),
          backgroundColor: const Color(0xff17142a),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle) _googleLogo(size: 20) else _appleLogo(size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ============================================================
// REGISTER
// ============================================================

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
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      showMessage('Qeydiyyat xətası: $e');
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
      appBar: AppBar(title: const Text('Qeydiyyat')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Ad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Yaş',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cityController,
            decoration: const InputDecoration(
              labelText: 'Şəhər',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: aboutController,
            maxLines: 3,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Haqqımda',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: hidePassword,
            decoration: InputDecoration(
              labelText: 'Şifrə',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    hidePassword = !hidePassword;
                  });
                },
                icon: Icon(
                  hidePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Qeydiyyatdan keç',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        ],
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

    heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      setOnline();
    });
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
    heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void navigate(int index) {
      setState(() {
        selectedIndex = index;
      });
    }

    final pages = <Widget>[
      SocialHome(profile: widget.profile),
      VibeVideoPage(profile: widget.profile),
      MomentsPage(profile: widget.profile),
      SocialFeed(profile: widget.profile, rooms: true),
      SocialMessages(profile: widget.profile, navigate: navigate),
      SocialProfile(profile: widget.profile, navigate: navigate),
    ];

    return Scaffold(
      body: IncomingCalls(
        uid: widget.profile.uid,
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xff090611),
          border: Border(top: BorderSide(color: Color(0xff2a1b3e))),
          boxShadow: [
            BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, -6)),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 76,
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0xff8b5cff).withValues(alpha: .24),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? Colors.white : const Color(0xff9d94ae),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? const Color(0xffff2bd6) : const Color(0xff9d94ae),
                size: 25,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: navigate,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Ana səhifə'),
              NavigationDestination(icon: Icon(Icons.play_circle_outline_rounded), selectedIcon: Icon(Icons.play_circle_fill_rounded), label: 'Video'),
              NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Anlar'),
              NavigationDestination(icon: Icon(Icons.meeting_room_outlined), selectedIcon: Icon(Icons.meeting_room_rounded), label: 'Otaqlar'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Mesajlar'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Mən'),
            ],
          ),
        ),
      ),
    );
  }
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

class PersonPage extends StatelessWidget {
  final UserProfile currentProfile;
  final String targetUid;

  const PersonPage({
    super.key,
    required this.currentProfile,
    required this.targetUid,
  });

  Future<void> _toggleFollow(BuildContext context, bool following, String targetName) async {
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
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(following ? 'İzləmədən çıxarıldı.' : '$targetName izlənilir 💜')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İzləmə əməliyyatı alınmadı.')),
        );
      }
    }
  }

  Future<void> _blockUser(BuildContext context, String targetName) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentProfile.uid)
          .collection('blocked')
          .doc(targetUid)
          .set({
            'uid': targetUid,
            'name': targetName,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetName bloklandı.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bloklama alınmadı.')),
        );
      }
    }
  }

  Future<void> _reportUser(BuildContext context, String targetName, String reason) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikayət göndərildi. Təşəkkür edirik.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikayət göndərilmədi.')),
        );
      }
    }
  }

  void _openSafetyMenu(BuildContext context, String targetName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Təhlükəsizlik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              subtitle: Text('Bu istifadəçi ilə bağlı əməliyyat seç', style: TextStyle(color: Color(0xff9e95ac))),
            ),
            for (final reason in const ['Saxta profil', 'Spam', 'Uyğunsuz davranış'])
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xffffb24a)),
                title: Text('Şikayət et · $reason', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _reportUser(context, targetName, reason);
                },
              ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Color(0xffff5d76)),
              title: const Text('İstifadəçini blokla', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: const Color(0xff151020),
                    title: const Text('Bloklansın?', style: TextStyle(color: Colors.white)),
                    content: Text('$targetName artıq səninlə əlaqə yarada bilməyəcək.', style: const TextStyle(color: Color(0xffc5bdd0))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Ləğv et')),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Blokla')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await _blockUser(context, targetName);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(targetUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xff080611),
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: Center(child: Text('Profil xətası:\n${snapshot.error}', style: const TextStyle(color: Colors.white))),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return const LoadingPage();
        }

        final data = snapshot.data!.data()!;
        final name = '${data['name'] ?? 'İstifadəçi'}';
        final age = '${data['age'] ?? ''}';
        final city = '${data['city'] ?? ''}';
        final about = '${data['about'] ?? ''}';
        final image = '${data['photoUrl'] ?? data['imageUrl'] ?? ''}';
        final online = isReallyOnline(data);
        final vipUntil = data['vipUntil'];
        final vipActive = data['vip'] == true &&
            (vipUntil is! Timestamp || vipUntil.toDate().isAfter(DateTime.now()));

        return Scaffold(
          backgroundColor: const Color(0xff080611),
          appBar: AppBar(
            backgroundColor: const Color(0xff080611),
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                onPressed: () => _openSafetyMenu(context, name),
                tooltip: 'Daha çox',
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xff120a1d), Color(0xff080611)]),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 154,
                        height: 154,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: vipActive
                                ? const [Color(0xffffd166), Color(0xffff2bd6), Color(0xff8b5cff)]
                                : const [Color(0xff8b5cff), Color(0xffff2bd6)],
                          ),
                          boxShadow: vipActive
                              ? const [
                                  BoxShadow(color: Color(0x66ff2bd6), blurRadius: 26, spreadRadius: 3),
                                  BoxShadow(color: Color(0x558b5cff), blurRadius: 42, spreadRadius: 1),
                                ]
                              : null,
                        ),
                      ),
                      CircleAvatar(
                        radius: 72,
                        backgroundColor: const Color(0xff1b1425),
                        backgroundImage: image.trim().isNotEmpty ? NetworkImage(image) : null,
                        child: image.trim().isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w900)) : null,
                      ),
                      if (online)
                        Positioned(
                          right: 9,
                          bottom: 13,
                          child: Container(
                            width: 23,
                            height: 23,
                            decoration: BoxDecoration(color: const Color(0xff34d399), shape: BoxShape.circle, border: Border.all(color: const Color(0xff080611), width: 4)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(age.trim().isEmpty ? name : '$name, $age', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
                    const SizedBox(width: 7),
                    Icon(Icons.verified_rounded, color: vipActive ? const Color(0xffffd166) : const Color(0xffb06cff), size: 22),
                    if (vipActive) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xffffb84d), Color(0xffff2bd6)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                if (city.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(child: Text(city, style: const TextStyle(color: Color(0xffaaa1ba), fontSize: 14))),
                ],
                const SizedBox(height: 7),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: (online ? const Color(0xff34d399) : const Color(0xff6b6475)).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                    child: Text(activityText(data), style: TextStyle(color: online ? const Color(0xff5ee3ad) : const Color(0xffaaa1ba), fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _profileAction(context, Icons.chat_bubble_rounded, 'Mesaj', const [Color(0xff7b5cff), Color(0xffff2bd6)], () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RealChatPage(currentProfile: currentProfile, targetUid: targetUid, targetName: name)));
                    })),
                    const SizedBox(width: 10),
                    Expanded(child: _profileAction(context, Icons.call_rounded, 'Səsli zəng', const [Color(0xff1d8cff), Color(0xff8b5cff)], () => startCall(context, currentProfile.uid, currentProfile.name, targetUid, name, false))),
                    const SizedBox(width: 10),
                    Expanded(child: _profileAction(context, Icons.videocam_rounded, 'Video', const [Color(0xffff2bd6), Color(0xffff6a8b)], () => startCall(context, currentProfile.uid, currentProfile.name, targetUid, name, true))),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentProfile.uid)
                      .collection('following')
                      .doc(targetUid)
                      .snapshots(),
                  builder: (context, followSnap) {
                    final following = followSnap.data?.exists == true;
                    return SizedBox(
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: following
                              ? null
                              : const LinearGradient(colors: [Color(0xff7b5cff), Color(0xffff2bd6)]),
                          color: following ? const Color(0xff181121) : null,
                          borderRadius: BorderRadius.circular(16),
                          border: following ? Border.all(color: const Color(0xff4a355c)) : null,
                        ),
                        child: TextButton.icon(
                          onPressed: () => _toggleFollow(context, following, name),
                          icon: Icon(following ? Icons.check_rounded : Icons.person_add_alt_1_rounded, color: Colors.white),
                          label: Text(
                            following ? 'İzləyirsən' : 'İzlə',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xff151020), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xff332444))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Haqqımda', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(about.trim().isEmpty ? 'Haqqında məlumat yazmayıb.' : about, style: const TextStyle(color: Color(0xffc5bdd0), height: 1.45)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: const Color(0xff151020), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xff332444))),
                  child: Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: targetUid).snapshots(),
                          builder: (_, s) => _ProfileStat(value: '${s.data?.docs.length ?? 0}', label: 'Paylaşım'),
                        ),
                      ),
                      const SizedBox(height: 38, child: VerticalDivider(color: Color(0xff352945))),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(targetUid).collection('followers').snapshots(),
                          builder: (_, s) => _ProfileStat(value: '${s.data?.docs.length ?? 0}', label: 'İzləyici'),
                        ),
                      ),
                      const SizedBox(height: 38, child: VerticalDivider(color: Color(0xff352945))),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(targetUid).collection('following').snapshots(),
                          builder: (_, s) => _ProfileStat(value: '${s.data?.docs.length ?? 0}', label: 'İzlənilən'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileAction(BuildContext context, IconData icon, String text, List<Color> colors, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white), const SizedBox(height: 5), Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))]),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Color(0xff9e95ac), fontSize: 11))]);
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
  StreamSubscription? receiptSubscription;

  bool sending = false;
  bool typingSent = false;
  bool voiceOpen = false;
  late final VoiceMessageService voiceService = VoiceMessageService();

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

    receiptSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen((doc) {
          if (mounted &&
              (ModalRoute.of(context)?.isCurrent ?? false) &&
              doc.exists &&
              isUnread(doc.data()!, widget.currentProfile.uid)) {
            doc.reference
                .update({
                  'readAt.${widget.currentProfile.uid}':
                      FieldValue.serverTimestamp(),
                })
                .catchError((Object _) {});
          }
        }, onError: (Object _) {});

    activityTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    activityTimer?.cancel();
    typingTimer?.cancel();
    receiptSubscription?.cancel();
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
              if (mine) ...[
                const Divider(height: 24, color: Color(0xff352447)),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xffff657b)),
                  title: const Text('Mesajı sil', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _deleteMessage(ref);
                  },
                ),
              ],
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
        'lastMessage': lastMessage,
        'lastSenderId': widget.currentProfile.uid,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      batch.set(message, {
        'senderId': widget.currentProfile.uid,
        'text': text,
        'type': type,
        'createdAt': Timestamp.now(),
        'clientCreatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await batch.commit();

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

        return Scaffold(
          backgroundColor: const Color(0xff080611),
          appBar: AppBar(
            backgroundColor: const Color(0xff0d0917),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            titleSpacing: 4,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xff2a183f),
                  child: Text(
                    widget.targetName.isNotEmpty
                        ? widget.targetName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
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
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .snapshots(),
                        builder: (context, chatSnap) {
                          final chat = chatSnap.data?.data() ?? {};
                          final typing = chat['typing'];
                          final typingAt = chat['typingAt'];
                          final isTyping = typing is Map &&
                              typing[widget.targetUid] == true &&
                              typingAt is Map &&
                              typingAt[widget.targetUid] is Timestamp &&
                              DateTime.now()
                                      .difference((typingAt[widget.targetUid] as Timestamp).toDate())
                                      .inSeconds
                                  .abs() < 8;
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
            ],
          ),
          body: Column(
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
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 50,
                              color: const Color(0xff8f86a3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${widget.targetName} ilə söhbətə başla',
                              style: const TextStyle(color: Colors.grey),
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

                        if (type == 'audio') {
                          final path = '${data['audioPath'] ?? ''}';
                          final duration = data['durationMs'];
                          return Align(
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
                                gradient: mine
                                    ? const LinearGradient(colors: [Color(0xff7b3cff), Color(0xffff2bd6)])
                                    : null,
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
                          );
                        }

                        if (type == 'sticker') {
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(5),
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 58),
                              ),
                            ),
                          );
                        }

                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _openMessageActions(messageRef, mine),
                            child: Container(
                            constraints: const BoxConstraints(maxWidth: 310),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              gradient: mine
                                  ? const LinearGradient(colors: [Color(0xff7b3cff), Color(0xffff2bd6)])
                                  : null,
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
                                              size: 14,
                                              color: seen
                                                  ? const Color(0xff7ee7ff)
                                                  : Colors.white54,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              seen ? 'Görüldü' : 'Göndərildi',
                                              style: TextStyle(
                                                fontSize: 9,
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
                        );
                      },
                    );
                  },
                ),
              ),

              // ==========================
              // MESAJ YAZMA PANELİ
              // ==========================
              if (voiceOpen)
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Emoji',
                          onPressed: openEmojiPicker,
                          icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xffc8b9dd)),
                        ),
                        IconButton(
                          tooltip: 'Stiker',
                          onPressed: openStickerPicker,
                          icon: const Icon(Icons.auto_awesome_outlined, color: Color(0xffff5bd6)),
                        ),

                        IconButton(
                          tooltip: 'Səsli mesaj',
                          onPressed: sending
                              ? null
                              : () {
                                  messageFocusNode.unfocus();
                                  setState(() {
                                    voiceOpen = true;
                                  });
                                },
                          icon: const Icon(Icons.mic_none_rounded, color: Color(0xff9d7dff)),
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
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
