import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/social_ui.dart';
import 'package:flutter_application_1/preferences.dart';

const profile = UserProfile(
  uid: 'me',
  name: 'Əhməd',
  age: 25,
  city: 'Bakı',
  email: 'test@example.com',
  about: 'Musiqi və yeni dostlar ✨',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Remember selection and email survive a fresh preferences read',
    () async {
      SharedPreferences.setMockInitialValues({});
      final memory = LoginMemory(await SharedPreferences.getInstance());
      await memory.save(true, 'person@example.com');
      final restored = LoginMemory(await SharedPreferences.getInstance());
      expect(restored.remember, true);
      expect(restored.email, 'person@example.com');
      await restored.save(false, 'person@example.com');
      expect(restored.remember, false);
      expect(restored.email, '');
      expect(restored.preferences.getString('rememberedEmail'), isNull);
    },
  );
  test('Unread excludes own messages and respects read receipts', () {
    final at = Timestamp.fromMillisecondsSinceEpoch(1000);
    final data = <String, dynamic>{'lastSenderId': 'peer', 'updatedAt': at};
    expect(isUnread(data, 'me'), true);
    data['readAt'] = {'me': at};
    expect(isUnread(data, 'me'), false);
    data['lastSenderId'] = 'me';
    data.remove('readAt');
    expect(isUnread(data, 'me'), false);
  });

  for (final width in [320.0, 390.0, 760.0]) {
    testWidgets('Social screens and filters at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      final now = Timestamp.now();
      await db.collection('users').doc('me').set({
        'name': profile.name,
        'avatarEmoji': '🌙',
      });
      await db.collection('users').doc('aya').set({
        'name': 'Aysel',
        'age': 24,
        'city': 'Bakı',
        'about': 'Musiqi, səyahət və bir fincan qəhvə',
        'online': true,
        'lastSeen': now,
        'avatarEmoji': '🌸',
      });
      await db.collection('users').doc('deniz').set({
        'name': 'Dəniz',
        'age': 26,
        'city': 'Gəncə',
        'about': 'Yeni dostlara salam!',
        'online': false,
        'lastSeen': now,
        'avatarEmoji': '🦋',
      });
      await db.collection('chats').doc('me_aya').set({
        'members': ['me', 'aya'],
        'lastMessage': 'Salam! Necəsən? ✨',
        'lastSenderId': 'aya',
        'updatedAt': now,
      });
      await db.collection('chats').doc('me_deniz').set({
        'members': ['me', 'deniz'],
        'lastMessage': 'Sabah danışarıq',
        'lastSenderId': 'me',
        'updatedAt': now,
      });
      Future<void> show(Widget page) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: accentColors.first),
            ),
            home: Scaffold(body: page),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(SocialHome(profile: profile, database: db));
      expect(find.text('Aysel'), findsOneWidget);
      await tester.tap(find.text('Aktiv'));
      await tester.pumpAndSettle();
      expect(find.text('Dəniz'), findsNothing);
      await show(
        SocialMessages(profile: profile, database: db, navigate: (_) {}),
      );
      await tester.tap(find.text('Oxunmamış'));
      await tester.pumpAndSettle();
      expect(find.text('Aysel'), findsOneWidget);
      expect(find.text('Dəniz'), findsNothing);
      await show(
        SocialProfile(profile: profile, database: db, navigate: (_) {}),
      );
      expect(find.text('Profil dekoru'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Capture mobile design preview', (tester) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (!font.existsSync()) return;
    final loader = FontLoader('PreviewFont')
      ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
    await loader.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({
      'name': 'Əhməd',
      'avatarEmoji': '🌙',
    });
    for (final (id, name, emoji) in [
      ('aya', 'Aysel', '🌸'),
      ('deniz', 'Dəniz', '🦋'),
      ('leyla', 'Leyla', '🌿'),
    ]) {
      await db.collection('users').doc(id).set({
        'name': name,
        'avatarEmoji': emoji,
        'age': 24,
        'city': 'Bakı',
        'about': 'Yeni dostlara salam!',
        'online': true,
        'lastSeen': Timestamp.now(),
      });
    }
    for (final (name, page, index) in [
      ('home', SocialHome(profile: profile, database: db), 0),
      (
        'profile',
        SocialProfile(profile: profile, database: db, navigate: (_) {}),
        4,
      ),
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'PreviewFont',
            colorScheme: ColorScheme.fromSeed(seedColor: accentColors.first),
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: page,
              bottomNavigationBar: NavigationBar(
                selectedIndex: index,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.favorite_border),
                    label: 'Ana səhifə',
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
                    icon: Icon(Icons.chat_bubble_outline),
                    label: 'Mesajlar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.face_outlined),
                    label: 'Mən',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('artifacts').createSync(recursive: true);
        File(
          'artifacts/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
