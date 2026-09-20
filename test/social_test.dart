import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/social_ui.dart';
import 'package:flutter_application_1/home_discover.dart';
import 'package:flutter_application_1/messages_page.dart';
import 'package:flutter_application_1/user_profile.dart';
import 'package:flutter_application_1/preferences.dart';
import 'package:flutter_application_1/ui/vibe_chrome.dart';
import 'package:flutter_application_1/profile_header.dart';
import 'package:flutter_application_1/coin_wallet.dart';
import 'package:flutter_application_1/media_store.dart';
import 'package:image/image.dart' as img;

const profile = UserProfile(
  uid: 'me',
  name: 'Əhməd',
  age: 25,
  city: 'Bakı',
  email: 'test@example.com',
  about: 'Musiqi və yeni dostlar ✨',
);


/// Widget ekranın görünən hissəsindədirmi? (Dar ekranlarda üfüqi
/// siyahıdakı pillər kadrdan kənarda qala bilər.)
bool _onScreen(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final rect = tester.getRect(finder.first);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return rect.left >= 0 &&
      rect.top >= 0 &&
      rect.right <= size.width &&
      rect.bottom <= size.height;
}

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


  testWidgets('Profili düzəlt düyməsi toxunuşu qəbul edir', (tester) async {
    // Regressiya: düymə Stack-in hüdudundan kənarda idi (bottom: -34),
    // görünürdü, amma heç bir toxunuş ona çatmırdı.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({'name': 'Əhməd'});

    var edited = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ProfileCoverHeader(
                profile: profile,
                database: db,
                onEdit: () => edited++,
                onSettings: () {},
                onShare: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Profili düzəlt'));
    await tester.pump();

    expect(edited, 1, reason: 'Düymə toxunuşu handler-ə çatmalıdır');
  });

  test('Balans çatmayanda InsufficientCoins atılır, balans dəyişmir', () async {
    // Regressiya: istisna tranzaksiyanın içindən atılırdı və Firestore onu
    // sarıdığı üçün "Oyun tamamlanmadı" kimi yanlış mesaj çıxırdı.
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({'coins': 5});

    await expectLater(
      changeCoins(uid: 'me', delta: -10, reason: 'test', database: db),
      throwsA(isA<InsufficientCoins>()),
    );

    final after = await db.collection('users').doc('me').get();
    expect(after.data()!['coins'], 5);
  });

  test('Uduş və xərc balansa düzgün yazılır', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({'coins': 100});

    expect(await changeCoins(uid: 'me', delta: -10, reason: 'mərc', database: db), 90);
    expect(await changeCoins(uid: 'me', delta: 30, reason: 'uduş', database: db), 120);
  });

  test('Şəkil sıxılıb Firestore sənədinə sığır', () {
    // 1200x900 rəngli şəkil — real foto ölçüsünə yaxın.
    final source = img.Image(width: 1200, height: 900);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }

    final stored = compressToStoredImage(img.encodeJpg(source));

    expect(stored, isNotNull);
    expect(stored!.thumb.startsWith('data:image/jpeg;base64,'), isTrue);
    expect(stored.full.startsWith('data:image/jpeg;base64,'), isTrue);

    // Kiçik nüsxə siyahılar üçün yüngül olmalıdır.
    expect(stored.thumb.length, lessThan(40 * 1024));
    // Böyük nüsxə Firestore-un 1 MB sənəd limitinin altında qalmalıdır.
    expect(stored.full.length, lessThan(700 * 1024));
    expect(stored.full.length, greaterThan(stored.thumb.length));
  });

  testWidgets('Axtarış Azərbaycan hərfləri ilə də tapır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({'name': 'Mən'});
    await db.collection('users').doc('a').set({
      'name': 'Ləman',
      'city': 'Şəki',
      'lastSeen': Timestamp.now(),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SocialHome(profile: profile, database: db)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Axtarışı aç
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));

    // "seki" yazılsa da "Şəki"dəki Ləman tapılmalıdır
    await tester.enterText(find.byType(TextField).first, 'seki');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ləman'), findsOneWidget);
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
        // Fonda dayanmadan işləyən animasiyalar var (aurora, shimmer),
        // ona görə pumpAndSettle yox, sabit addım istifadə olunur.
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }

      await show(SocialHome(profile: profile, database: db));
      expect(find.text('Aysel'), findsOneWidget);
      // "Online" pili üfüqi siyahıdadır; çox dar ekranda görünməyə bilər.
      final onlinePill = find.descendant(
        of: find.byType(PillTabs),
        matching: find.text('Online'),
      );
      if (_onScreen(tester, onlinePill)) {
        await tester.tap(onlinePill);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Dəniz'), findsNothing);
      }
      await show(
        SocialMessages(profile: profile, database: db, navigate: (_) {}),
      );
      // "Oxunmamış" pili də üfüqi siyahıdadır.
      final unreadPill = find.descendant(
        of: find.byType(PillTabs),
        matching: find.text('Oxunmamış'),
      );
      if (_onScreen(tester, unreadPill)) {
        await tester.tap(unreadPill);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Aysel'), findsOneWidget);
        expect(find.text('Dəniz'), findsNothing);
      }
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
      await tester.pump(const Duration(milliseconds: 600));
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
