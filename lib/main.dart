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
            colorScheme: ColorScheme.fromSeed(seedColor: accentColors[accent]),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: ink),
              titleMedium: TextStyle(color: ink),
            ),
            chipTheme: ChipThemeData(
              side: BorderSide.none,
              backgroundColor: Colors.white.withValues(alpha: .7),
              selectedColor: accentColors[accent].withValues(alpha: .15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            scaffoldBackgroundColor: const Color(0xfff7f5fb),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xfff7f5fb),
              surfaceTintColor: Colors.transparent,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: Color(0xffeadfff),
            ),
          ),
          builder: (context, child) => child!,
          home: const AuthGate(),
        );
      },
    );
  }
}

// ============================================================
// USER PROFILE
// ============================================================

class UserProfile {
  final String uid;
  final String name;
  final int age;
  final String city;
  final String email;
  final String about;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.city,
    required this.email,
    required this.about,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      uid: '${data['uid'] ?? ''}',
      name: '${data['name'] ?? ''}',
      age: int.tryParse('${data['age'] ?? 0}') ?? 0,
      city: '${data['city'] ?? ''}',
      email: '${data['email'] ?? ''}',
      about: '${data['about'] ?? ''}',
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
  String language = 'AZ';

  static const languages = <String, String>{
    'AZ': '🇦🇿  Azərbaycan',
    'TR': '🇹🇷  Türkçe',
    'EN': '🇬🇧  English',
    'RU': '🇷🇺  Русский',
  };

  Map<String, String> get t {
    const data = {
      'AZ': {
        'home':'Ana səhifə','discover':'Kəşf et','live':'Canlı','messages':'Mesajlar',
        'login':'Daxil ol','people':'Real People','connections':'Real Connections',
        'desc':'Yeni insanlarla tanış ol,\nsöhbət et, dostluq qur və\nhəyatına yeni rəng qat!',
        'start':'Başla  →','create':'Yeni hesab yarat',
        'f1':'Real insanlar','f1s':'Dünya üzrə','f2':'Real söhbətlər','f2s':'Səmimi ünsiyyət',
        'f3':'Real əlaqələr','f3s':'Yeni imkanlar','f4':'Sərhədsiz tanışlıq','f4s':'Hər yerdən, hər zaman',
      },
      'TR': {
        'home':'Ana sayfa','discover':'Keşfet','live':'Canlı','messages':'Mesajlar',
        'login':'Giriş yap','people':'Gerçek İnsanlar','connections':'Gerçek Bağlantılar',
        'desc':'Yeni insanlarla tanış,\nsohbet et, arkadaşlık kur ve\nhayatına yeni renk kat!',
        'start':'Başla  →','create':'Yeni hesap oluştur',
        'f1':'Gerçek insanlar','f1s':'Dünya çapında','f2':'Gerçek sohbetler','f2s':'Samimi iletişim',
        'f3':'Gerçek bağlar','f3s':'Yeni fırsatlar','f4':'Sınırsız tanışma','f4s':'Her yerden, her zaman',
      },
      'EN': {
        'home':'Home','discover':'Discover','live':'Live','messages':'Messages',
        'login':'Log in','people':'Real People','connections':'Real Connections',
        'desc':'Meet new people,\nchat, make friends and\nadd new color to your life!',
        'start':'Start  →','create':'Create new account',
        'f1':'Real people','f1s':'Worldwide','f2':'Real chats','f2s':'Genuine conversations',
        'f3':'Real connections','f3s':'New possibilities','f4':'Borderless discovery','f4s':'Anywhere, anytime',
      },
      'RU': {
        'home':'Главная','discover':'Знакомства','live':'Эфир','messages':'Сообщения',
        'login':'Войти','people':'Настоящие люди','connections':'Настоящие связи',
        'desc':'Знакомься с новыми людьми,\nобщайся, находи друзей и\nдобавляй ярких красок в жизнь!',
        'start':'Начать  →','create':'Создать аккаунт',
        'f1':'Настоящие люди','f1s':'По всему миру','f2':'Живое общение','f2s':'Искренние разговоры',
        'f3':'Настоящие связи','f3s':'Новые возможности','f4':'Без границ','f4s':'Везде и всегда',
      },
    };
    return data[language]!;
  }

  Route<void> _instantRoute(Widget page) => PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => ColoredBox(color: const Color(0xff05030d), child: page),
    transitionsBuilder: (_, __, ___, child) => child,
  );

  void _login() => Navigator.of(context).push(_instantRoute(const LoginPage()));
  void _register() => Navigator.of(context).push(_instantRoute(const RegisterPage()));

  Widget _languageMenu() => PopupMenuButton<String>(
    initialValue: language,
    color: const Color(0xff100923),
    onSelected: (v) => setState(() => language = v),
    itemBuilder: (_) => languages.entries.map((e) => PopupMenuItem(
      value: e.key,
      child: Text(e.value, style: const TextStyle(color: Colors.white)),
    )).toList(),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.language, color: Colors.white, size: 21),
      const SizedBox(width: 7),
      Text(language, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff05030d),
    body: LayoutBuilder(builder: (_, c) => c.maxWidth >= 800 ? _desktop() : _mobile()),
  );

  Widget _desktop() {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Color(0xff05030d)),

      // Şəkildən yalnız sağdakı qız + neon hissəsini göstəririk.
      // Beləliklə şəklin içindəki köhnə VIBE/yazılar/düymələr görünmür.
      Positioned(
        top: 78,
        right: 0,
        bottom: 112,
        width: MediaQuery.sizeOf(context).width * .62,
        child: ClipRect(
          child: Image.asset(
            'lib/data/assets/image.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
      Positioned(
        top: 78,
        left: 0,
        right: 0,
        bottom: 112,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, .34, .58, 1.0],
                colors: [
                  const Color(0xff05030d),
                  const Color(0xff05030d),
                  const Color(0xff05030d).withValues(alpha: .45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(top:0,left:0,right:0,height:78,child: Container(color: const Color(0xff070512))),
      Positioned(left:0,right:0,bottom:0,height:112,child: Container(color: const Color(0xff070512))),

      // Üst menyu
      Positioned(top:0,left:0,right:0,height:78,child: Padding(
        padding: const EdgeInsets.symmetric(horizontal:70),
        child: Row(children:[
          const Text('VIBE',style:TextStyle(fontSize:34,fontWeight:FontWeight.w900,color:Color(0xffb43cff),shadows:[Shadow(color:Color(0xff1e8cff),blurRadius:12)])),
          const SizedBox(width:80),
          Text(t['home']!,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
          const SizedBox(width:45), Text(t['discover']!,style:const TextStyle(color:Colors.white70)),
          const SizedBox(width:45), Text(t['live']!,style:const TextStyle(color:Colors.white70)),
          const SizedBox(width:45), Text(t['messages']!,style:const TextStyle(color:Colors.white70)),
          const Spacer(), _languageMenu(), const SizedBox(width:35),
          OutlinedButton(onPressed:_login,style:OutlinedButton.styleFrom(
            foregroundColor:Colors.white,side:const BorderSide(color:Color(0xffb43cff)),
            padding:const EdgeInsets.symmetric(horizontal:30,vertical:18),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),
            child:Text(t['login']!)),
        ]),
      )),

      // Sol real Flutter mətnləri
      Positioned(left:80,top:150,width:470,child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('VIBE',style:TextStyle(fontSize:76,fontWeight:FontWeight.w900,color:Color(0xffb64cff),shadows:[Shadow(color:Color(0xff168cff),blurRadius:14)])),
        Text('${t['people']}\n${t['connections']}',style:const TextStyle(fontSize:34,fontStyle:FontStyle.italic,height:1.12,color:Color(0xffff62df))),
        const SizedBox(height:22),
        Text(t['desc']!,style:const TextStyle(fontSize:19,height:1.45,color:Colors.white70)),
        const SizedBox(height:28),
        SizedBox(width:420,height:66,child:DecoratedBox(
          decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff2399ff),Color(0xff8c3cff),Color(0xffff18c8)]),borderRadius:BorderRadius.circular(34)),
          child:Material(color:Colors.transparent,child:InkWell(onTap:_login,borderRadius:BorderRadius.circular(34),child:Center(child:Text(t['start']!,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800))))))),
        Center(child:TextButton(onPressed:_register,child:Text(t['create']!,style:const TextStyle(color:Colors.white70,decoration:TextDecoration.underline)))),
      ])),

      // Aşağı xüsusiyyətlər
      Positioned(left:70,right:70,bottom:18,height:75,child: Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        _feature(Icons.people_outline,t['f1']!,t['f1s']!),
        _feature(Icons.chat_bubble_outline,t['f2']!,t['f2s']!),
        _feature(Icons.favorite_border,t['f3']!,t['f3s']!),
        _feature(Icons.language,t['f4']!,t['f4s']!),
      ])),
    ]);
  }

  Widget _feature(IconData icon,String title,String sub)=>Row(children:[
    Icon(icon,color:const Color(0xffff27d9),size:40),const SizedBox(width:14),
    Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700)),
      const SizedBox(height:5),Text(sub,style:const TextStyle(color:Color(0xffb7a9db))),
    ])
  ]);

  Widget _mobile() {
    return Stack(fit:StackFit.expand,children:[
      Image.asset('lib/data/assets/image.png',fit:BoxFit.cover,alignment:const Alignment(.62,0)),
      Container(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[
        const Color(0xff05030d).withValues(alpha:.08),const Color(0xff05030d).withValues(alpha:.40),const Color(0xff05030d)
      ]))),
      SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(22,12,22,24),child:Column(children:[
        Row(children:[const Text('VIBE',style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),const Spacer(),_languageMenu()]),
        const Spacer(),
        const Text('VIBE',style:TextStyle(color:Colors.white,fontSize:58,fontWeight:FontWeight.w900,shadows:[Shadow(color:Color(0xffff28dc),blurRadius:20)])),
        Text('${t['people']}\n${t['connections']}',textAlign:TextAlign.center,style:const TextStyle(color:Color(0xffff77e9),fontSize:26,fontStyle:FontStyle.italic,height:1.15)),
        const SizedBox(height:12),
        Text(t['desc']!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,height:1.35)),
        const SizedBox(height:22),
        SizedBox(width:double.infinity,height:58,child:DecoratedBox(
          decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xff2998ff),Color(0xff8f39ff),Color(0xffff18c8)]),borderRadius:BorderRadius.circular(30)),
          child:Material(color:Colors.transparent,child:InkWell(onTap:_login,borderRadius:BorderRadius.circular(30),child:Center(child:Text(t['start']!,style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w800))))))),
        TextButton(onPressed:_register,child:Text(t['create']!,style:const TextStyle(color:Colors.white70,decoration:TextDecoration.underline))),
      ]))),
    ]);
  }
}

// ============================================================
// LOGIN
// ============================================================

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

    setState(() => loading = true);

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

      await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
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
      if (mounted) setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xff10162a);
    const pink = Color(0xffff2bd6);

    return Scaffold(
      backgroundColor: const Color(0xff050814),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.7),
            radius: 1.1,
            colors: [Color(0xff351052), Color(0xff0b1022), Color(0xff050814)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xff9c7bff), Color(0xffff35d8)],
                      ).createShader(bounds),
                      child: const Text(
                        'VIBE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Xoş gəlmisən',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Real insanlar, real söhbətlər, real VIBE 💜',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const SizedBox(height: 34),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: panel.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xff302750)),
                        boxShadow: [
                          BoxShadow(
                            color: pink.withValues(alpha: .08),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailController,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xffbd8cff)),
                              filled: true,
                              fillColor: const Color(0xff090e20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            autofillHints: const [AutofillHints.password],
                            obscureText: hidePassword,
                            onSubmitted: (_) => login(),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Şifrə',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xffbd8cff)),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => hidePassword = !hidePassword),
                                icon: Icon(
                                  hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xff090e20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: Colors.white54,
                            ),
                            child: CheckboxListTile(
                              value: rememberMe,
                              contentPadding: EdgeInsets.zero,
                              activeColor: pink,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Yadda saxla',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text(
                                'Çıxış etməyənə qədər hesab açıq qalsın',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              onChanged: (value) => setState(() => rememberMe = value ?? true),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                colors: [Color(0xff635bff), Color(0xffa63cff), Color(0xffff2bd6)],
                              ),
                            ),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: loading ? null : login,
                              child: loading
                                  ? const SizedBox(
                                      width: 23,
                                      height: 23,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Daxil ol',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white24)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text('və ya', style: TextStyle(color: Colors.white38)),
                        ),
                        const Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xff4b3a68)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text(
                        'Yeni hesab yarat',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
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

    final pages = [
      SocialHome(profile: widget.profile),
      VibeVideoFeed(profile: widget.profile),
      SocialFeed(profile: widget.profile),
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          height: 76,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: [
            const Color(0xffe8dfff),
            const Color(0xffffdce7),
            const Color(0xffefdcff),
            const Color(0xffddf4e4),
            const Color(0xffffe5d4),
            const Color(0xffffefbd),
          ][selectedIndex],
          selectedIndex: selectedIndex,
          onDestinationSelected: navigate,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              label: 'Ana səhifə',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline_rounded),
              selectedIcon: Icon(Icons.play_circle_fill_rounded),
              label: 'Video',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              label: 'Anlar',
            ),
            NavigationDestination(
              icon: Icon(Icons.meeting_room_outlined),
              label: 'Otaqlar',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              label: 'Mesajlar',
            ),
            NavigationDestination(
              icon: Icon(Icons.face_outlined),
              label: 'Mən',
            ),
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
            appBar: AppBar(),
            body: Center(child: Text('Profil xətası:\n${snapshot.error}')),
          );
        }

        if (!snapshot.hasData ||
            !snapshot.data!.exists ||
            snapshot.data!.data() == null) {
          return const LoadingPage();
        }

        final data = snapshot.data!.data()!;

        final name = '${data['name'] ?? 'İstifadəçi'}';

        final age = '${data['age'] ?? ''}';

        final city = '${data['city'] ?? ''}';

        final about = '${data['about'] ?? ''}';

        final online = isReallyOnline(data);

        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 65,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (online)
                      Positioned(
                        right: 4,
                        bottom: 5,
                        child: Container(
                          width: 23,
                          height: 23,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '$name, $age',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Center(child: Text(city)),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  activityText(data),
                  style: TextStyle(
                    color: online ? Colors.green : Colors.grey,
                    fontWeight: online ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Card(
                color: Colors.white,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Haqqımda',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        about.trim().isEmpty
                            ? 'Haqqında məlumat yazmayıb.'
                            : about,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 55,
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Mesaj yaz'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RealChatPage(
                          currentProfile: currentProfile,
                          targetUid: targetUid,
                          targetName: name,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
  StreamSubscription? receiptSubscription;

  bool sending = false;
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
    receiptSubscription?.cancel();
    messageController.dispose();
    messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty || sending) {
      return;
    }

    final sent = await sendContent(text: text, type: 'text', lastMessage: text);

    if (mounted && sent && messageController.text.trim() == text) {
      messageController.clear();
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
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(message, {
        'senderId': widget.currentProfile.uid,
        'text': text,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                            color: const Color(0xfff3efff),
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
          appBar: AppBar(
            titleSpacing: 4,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    widget.targetName.isNotEmpty
                        ? widget.targetName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                        ),
                      ),
                      Text(
                        status,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: online ? Colors.green : Colors.grey,
                        ),
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
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
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
                              color: Colors.grey,
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
                                color: mine
                                    ? const Color(0xff7c3aed)
                                    : Colors.white,
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
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 310),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xff7c3aed)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x09000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              text,
                              style: TextStyle(
                                color: mine ? Colors.white : Colors.black87,
                                fontSize: 16,
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
                      color: Colors.white,
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
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                        IconButton(
                          tooltip: 'Stiker',
                          onPressed: openStickerPicker,
                          icon: const Icon(Icons.auto_awesome_outlined),
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
                          icon: const Icon(Icons.mic_none_rounded),
                        ),

                        Expanded(
                          child: TextField(
                            controller: messageController,
                            focusNode: messageFocusNode,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'Mesaj yaz...',
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
                              fillColor: const Color(0xfff5f3f8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton.filled(
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
