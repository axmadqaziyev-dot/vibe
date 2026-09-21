/// Otağın fonu.
///
/// SUGO-da hər otağın öz mənzərəsi var və otaqlar bir-birindən məhz
/// bununla seçilir. Bizdə isə bütün otaqlar eyni görünürdü — girən
/// adam hansı otaqda olduğunu yalnız başlıqdan bilirdi.
///
/// İki yol var:
///
/// 1. **Hazır fonlar** — otaq sahibi siyahıdan seçir. Şəkil deyil,
///    qradiyentdir: heç nə yüklənmir, tətbiqin ölçüsü artmır, ən zəif
///    internetdə də dərhal görünür.
/// 2. **Öz şəkli** — sahib qalereyadan şəkil seçir, Supabase-ə
///    yüklənir və bütün iştirakçılar eyni fonu görür.
///
/// Hansı seçilirsə seçilsin, üstünə tünd pərdə salınır. Onsuz ad,
/// söhbət və düymələr açıq şəkildə itirdi.
library;

import 'package:flutter/material.dart';

import 'ui/vibe_chrome.dart';

/// Hazır fon.
class RoomScene {
  const RoomScene({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colors,
  });

  final String id;
  final String name;
  final String emoji;
  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      );
}

const roomScenes = <RoomScene>[
  RoomScene(
    id: 'gece',
    name: 'Gecə',
    emoji: '🌌',
    colors: [Color(0xff1b1035), Color(0xff2b1b4f), Color(0xff0a0714)],
  ),
  RoomScene(
    id: 'deniz',
    name: 'Dəniz',
    emoji: '🌊',
    colors: [Color(0xff0f2f4a), Color(0xff123f57), Color(0xff06121c)],
  ),
  RoomScene(
    id: 'gunbatimi',
    name: 'Gün batımı',
    emoji: '🌇',
    colors: [Color(0xff4a1f3a), Color(0xff7a2f3a), Color(0xff180a12)],
  ),
  RoomScene(
    id: 'mesa',
    name: 'Meşə',
    emoji: '🌲',
    colors: [Color(0xff123027), Color(0xff1d4a37), Color(0xff071310)],
  ),
  RoomScene(
    id: 'neon',
    name: 'Neon',
    emoji: '💜',
    colors: [Color(0xff2a0f45), Color(0xff5b1f6b), Color(0xff11061c)],
  ),
  RoomScene(
    id: 'qizil',
    name: 'Qızıl',
    emoji: '👑',
    colors: [Color(0xff3d2c10), Color(0xff6b4d16), Color(0xff150f05)],
  ),
  RoomScene(
    id: 'buz',
    name: 'Buz',
    emoji: '❄️',
    colors: [Color(0xff16283d), Color(0xff28455e), Color(0xff080f16)],
  ),
  RoomScene(
    id: 'kosmos',
    name: 'Kosmos',
    emoji: '🚀',
    colors: [Color(0xff10122e), Color(0xff26214f), Color(0xff05050f)],
  ),
];

RoomScene? sceneById(Object? id) {
  final key = '${id ?? ''}';
  if (key.isEmpty) return null;

  for (final scene in roomScenes) {
    if (scene.id == key) return scene;
  }
  return null;
}

/// Otağın fonunu çəkir.
///
/// Fon seçilməyibsə heç nə çəkmir — çağıran tərəf öz adi fonunu
/// göstərir.
class RoomBackdrop extends StatelessWidget {
  const RoomBackdrop({
    super.key,
    required this.sceneId,
    required this.imageUrl,
  });

  final Object? sceneId;
  final String imageUrl;

  /// Otağın öz fonu varmı?
  static bool isSet(Map<String, dynamic> room) =>
      '${room['bgUrl'] ?? ''}'.isNotEmpty || sceneById(room['bgScene']) != null;

  @override
  Widget build(BuildContext context) {
    final scene = sceneById(sceneId);
    final image = imageUrl.isEmpty ? null : vibeImageProvider(imageUrl);

    if (scene == null && image == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          Image(
            image: image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: (scene ?? roomScenes.first).gradient,
              ),
            ),
          )
        else
          DecoratedBox(decoration: BoxDecoration(gradient: scene!.gradient)),

        // Tünd pərdə.
        //
        // Açıq şəkil qoyulanda ağ yazılar itirdi. Pərdə yuxarıda və
        // aşağıda daha tündür: başlıq və söhbət məhz orada oturur.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xcc07050f),
                Color(0x8807050f),
                Color(0xcc07050f),
                Color(0xee07050f),
              ],
              stops: [0, .3, .72, 1],
            ),
          ),
        ),
      ],
    );
  }
}
