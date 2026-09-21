import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/home_discover.dart';
import 'package:flutter_application_1/ui/vibe_design.dart';

/// Kəşf kartlarının şəbəkəsini çəkir.
///
/// Dizayn dəyişikliyini yalnız koda baxmaqla qiymətləndirmək olmur —
/// bu sınaq şəkil çıxarır ki, nəticə gözlə görünsün.
void main() {
  testWidgets('Kəşf kartları çəkilir', (tester) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('PreviewFont')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }

    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Ekrandakı real siyahıya oxşar nümunə: adların çoxu "A" ilə
    // başlayır — rəngin yalnız ilk hərfdən asılı olmadığını göstərir.
    final people = <Map<String, dynamic>>[
      {'name': 'Asif', 'age': 25, 'city': 'Bakı', 'gender': 'kişi'},
      {'name': 'Asif Nasrullazadə', 'age': 26, 'city': 'Bakı', 'gender': 'kişi'},
      {'name': 'Aysel', 'age': 23, 'city': 'Gəncə', 'gender': 'qadın'},
      {'name': 'Axmed', 'age': 23, 'city': 'Qaziyev', 'gender': 'kişi'},
      {'name': 'İlkin Samedov', 'age': 22, 'city': 'Əfqanıstan'},
      {'name': 'Musa', 'age': 22, 'city': 'Sumqayıt', 'gender': 'kişi'},
      {'name': 'Nurlan', 'age': 28, 'city': 'Bakı', 'gender': 'kişi'},
      {'name': 'Salam1', 'age': 26, 'city': 'Bakı'},
      {'name': 'Vurgun Safarov', 'age': 22, 'city': 'Bakı', 'gender': 'kişi'},
    ];

    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: font.existsSync() ? 'PreviewFont' : null,
        ),
        home: Scaffold(
          backgroundColor: vBg,
          body: RepaintBoundary(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: people.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .74,
                ),
                itemBuilder: (context, i) => DiscoverCard(
                  data: people[i],
                  me: const {'city': 'Bakı'},
                  favorite: i == 2,
                  onFavorite: () {},
                  onTap: () {},
                  onChat: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Hər kartda ad və söhbət düyməsi var.
    expect(find.text('Asif'), findsOneWidget);
    expect(
      find.byIcon(Icons.chat_bubble_rounded),
      findsNWidgets(people.length),
    );

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts').createSync(recursive: true);
      File('artifacts/kesf_kartlari.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox());
  });
}
