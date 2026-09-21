import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/whats_new.dart';

void main() {
  group('Yeniliklər siyahısı', () {
    test('Hər maddənin hamısı doldurulub', () {
      for (final item in whatsNewItems) {
        expect(item.emoji.trim(), isNotEmpty, reason: item.title);
        expect(item.title.trim(), isNotEmpty);
        expect(item.text.trim(), isNotEmpty, reason: item.title);
        // "Harada" ən vacib sahədir — funksiyanı tapmağın yeganə yolu.
        expect(item.where.trim(), isNotEmpty, reason: item.title);
      }
    });

    test('Başlıqlar təkrarlanmır', () {
      final titles = whatsNewItems.map((e) => e.title).toList();
      expect(titles.toSet().length, titles.length);
    });

    test('Versiya müsbətdir', () {
      expect(whatsNewVersion, greaterThan(0));
    });
  });

  testWidgets('Vərəq bütün maddələri göstərir', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showWhatsNew(context),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.text('VIBE-də yeniliklər'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);

    // Birinci maddə dərhal görünür.
    expect(find.text(whatsNewItems.first.title), findsOneWidget);

    // Siyahı uzundur — qalanı sürüşdürəndə gəlir. Əvvəl burada
    // ortadakı maddə birbaşa axtarılırdı və siyahıya yeni maddə
    // əlavə edəndə sınaq səbəbsiz yerə qırılırdı.
    await tester.scrollUntilVisible(
      find.text(whatsNewItems.last.title),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(whatsNewItems.last.title), findsOneWidget);
  });
}
