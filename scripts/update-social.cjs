const fs=require('fs');
const p='lib/main.dart'; let s=fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'').replace(/\r\n/g,'\n');
s=s.replace("import 'calls.dart';", "import 'calls.dart';\nimport 'social_ui.dart';\nimport 'preferences.dart';\nimport 'package:flutter/services.dart';");
s=s.replace('  runApp(const VibeApp());', "  appearance.value = (prefs.getInt('appearance') ?? 0).clamp(0, accentColors.length - 1);\n  runApp(const VibeApp());");
s=s.replace('    return MaterialApp(', '    return ValueListenableBuilder<int>(valueListenable: appearance, builder: (context, accent, _) => MaterialApp(');
s=s.replace('seedColor: const Color(0xff7c3aed)', 'seedColor: accentColors[accent]');
s=s.replace('        scaffoldBackgroundColor:', "        textTheme: const TextTheme(bodyMedium: TextStyle(color: ink), titleMedium: TextStyle(color: ink)),\n        chipTheme: ChipThemeData(side: BorderSide.none, backgroundColor: Colors.white.withValues(alpha: .7), selectedColor: accentColors[accent].withValues(alpha: .15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),\n        scaffoldBackgroundColor:");
s=s.replace('      home: const AuthGate(),\n    );', "      builder: (context, child) => ColoredBox(color: const Color(0xfff1eff7), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: child!))),\n      home: const AuthGate(),\n    ));");
s=s.replace('setState(() => rememberMe = prefs.getBool(\'rememberMe\') ?? true);', "setState(() { rememberMe = LoginMemory(prefs).remember; emailController.text = LoginMemory(prefs).email; });");
s=s.replace("      await prefs.setBool('rememberMe', rememberMe);", "      await LoginMemory(prefs).save(rememberMe, email);");
s=s.replace("      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(", "      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(");
s=s.replace('      if (!mounted) return;\n\n      Navigator.popUntil(context, (route) => route.isFirst);', '      TextInput.finishAutofillContext();\n      if (!mounted) return;\n\n      Navigator.popUntil(context, (route) => route.isFirst);');
s=s.replace("controller: emailController,", "controller: emailController,\n                  autofillHints: const [AutofillHints.username, AutofillHints.email],");
s=s.replace('controller: passwordController,', 'controller: passwordController,\n                  autofillHints: const [AutofillHints.password],');
const start=s.indexOf('    final pages = [',s.indexOf('class _MainScreenState'));
const end=s.indexOf('// ================= DISCOVER',start);
s=s.slice(0,start)+`    void navigate(int index) => setState(() => selectedIndex = index);
    final pages = [
      SocialHome(profile: widget.profile),
      SocialFeed(profile: widget.profile),
      SocialFeed(profile: widget.profile, rooms: true),
      SocialMessages(profile: widget.profile, navigate: navigate),
      SocialProfile(profile: widget.profile, navigate: navigate),
    ];
    return Scaffold(
      body: IncomingCalls(uid: widget.profile.uid, child: IndexedStack(index: selectedIndex, children: pages)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0,-4))]),
        child: NavigationBar(
          height: 76, backgroundColor: Colors.transparent, elevation: 0,
          indicatorColor: [const Color(0xffe8dfff), const Color(0xffefdcff), const Color(0xffddf4e4), const Color(0xffffe5d4), const Color(0xffffefbd)][selectedIndex],
          selectedIndex: selectedIndex, onDestinationSelected: navigate,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.favorite_border_rounded), label: 'Ana səhifə'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Anlar'),
            NavigationDestination(icon: Icon(Icons.meeting_room_outlined), label: 'Otaqlar'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Mesajlar'),
            NavigationDestination(icon: Icon(Icons.face_outlined), label: 'Mən'),
          ],
        ),
      ),
    );
  }
}

`+s.slice(end);
// Read receipts update only when messages arrive and this route is visible.
s=s.replace('  Timer? activityTimer;', '  Timer? activityTimer;\n  StreamSubscription? receiptSubscription;\n  bool sending = false;');
s=s.replace('    activityTimer = Timer.periodic', "    receiptSubscription = FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots().listen((doc) {\n      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false) && doc.exists && isUnread(doc.data()!, widget.currentProfile.uid)) {\n        doc.reference.update({'readAt.\u0024{widget.currentProfile.uid}': FieldValue.serverTimestamp()}).catchError((Object _) {});\n      }\n    }, onError: (Object _) {});\n    activityTimer = Timer.periodic");
s=s.replace('    activityTimer?.cancel();', '    activityTimer?.cancel();\n    receiptSubscription?.cancel();');
const sendStart=s.indexOf('  Future<void> sendMessage() async {',s.indexOf('class _RealChatPageState'));
const sendEnd=s.indexOf('  @override\n  Widget build',sendStart);
s=s.slice(0,sendStart)+`  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final chat = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(chat, {
        'members': [widget.currentProfile.uid, widget.targetUid],
        'memberNames': {widget.currentProfile.uid: widget.currentProfile.name, widget.targetUid: widget.targetName},
        'lastMessage': text, 'lastSenderId': widget.currentProfile.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(chat.collection('messages').doc(), {'senderId': widget.currentProfile.uid, 'text': text, 'createdAt': FieldValue.serverTimestamp()});
      await batch.commit();
      if (messageController.text.trim() == text) messageController.clear();
    } catch (_) {
      if (mounted) notifySocial(context, 'Mesaj göndərilmədi. Yenidən sına.');
    } finally { if (mounted) setState(() => sending = false); }
  }

`+s.slice(sendEnd);
s=s.replace('onPressed: sendMessage,','onPressed: sending ? null : sendMessage,');
fs.writeFileSync(p,s);
