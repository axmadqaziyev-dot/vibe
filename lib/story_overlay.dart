/// Storinin üstündəki yazı və stikerlər.
///
/// İndiyə qədər stori sadəcə şəkil idi: seçirsən, paylaşırsan.
/// Instagram-da isə storinin dəyəri məhz üstünə qoyduqlarındadır —
/// "Ad günün mübarək", ürək stikeri, bir söz. Onlarsız stori quru
/// şəkildir və adam onu paylaşmır.
///
/// Yer nisbi saxlanılır (0..1). Telefonların ekranı müxtəlif ölçüdədir
/// — piksellə saxlasaq, yazı kiçik ekranda kənara düşərdi.
library;

/// Üst qatın növü.
enum OverlayKind { text, emoji }

class StoryOverlay {
  const StoryOverlay({
    required this.kind,
    required this.value,
    this.dx = .5,
    this.dy = .5,
    this.scale = 1,
    this.colorValue = 0xffffffff,
  });

  final OverlayKind kind;
  final String value;

  /// Ekranın eninə və hündürlüyünə görə nisbi yer (0..1).
  final double dx;
  final double dy;

  final double scale;

  /// Yalnız yazı üçün.
  final int colorValue;

  StoryOverlay copyWith({
    String? value,
    double? dx,
    double? dy,
    double? scale,
    int? colorValue,
  }) =>
      StoryOverlay(
        kind: kind,
        value: value ?? this.value,
        // Kənara çıxmasın: barmaq sürüşüb ekrandan çıxanda yazı itirdi.
        dx: (dx ?? this.dx).clamp(0.04, 0.96),
        dy: (dy ?? this.dy).clamp(0.06, 0.94),
        scale: (scale ?? this.scale).clamp(0.4, 4.0),
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'value': value,
        'dx': dx,
        'dy': dy,
        'scale': scale,
        'color': colorValue,
      };

  static StoryOverlay? from(Object? raw) {
    if (raw is! Map) return null;

    final value = '${raw['value'] ?? ''}';
    if (value.isEmpty) return null;

    double number(Object? input, double fallback) {
      if (input is num) return input.toDouble();
      return double.tryParse('${input ?? ''}') ?? fallback;
    }

    return StoryOverlay(
      kind: '${raw['kind'] ?? ''}' == 'emoji'
          ? OverlayKind.emoji
          : OverlayKind.text,
      value: value,
      dx: number(raw['dx'], .5),
      dy: number(raw['dy'], .5),
      scale: number(raw['scale'], 1),
      colorValue: (number(raw['color'], 0xffffffff)).toInt(),
    );
  }

  static List<StoryOverlay> listFrom(Object? raw) {
    if (raw is! List) return const [];

    final out = <StoryOverlay>[];
    for (final item in raw) {
      final overlay = StoryOverlay.from(item);
      if (overlay != null) out.add(overlay);
    }
    return out;
  }
}

/// Şəkilsiz stori üçün fon.
class StoryBackground {
  const StoryBackground({
    required this.id,
    required this.name,
    required this.colors,
  });

  final String id;
  final String name;

  /// Yuxarıdan aşağı rənglər.
  final List<int> colors;
}

const storyBackgrounds = <StoryBackground>[
  StoryBackground(
    id: 'vibe',
    name: 'VIBE',
    colors: [0xff7b3cff, 0xffff2bd6],
  ),
  StoryBackground(
    id: 'gece',
    name: 'Gecə',
    colors: [0xff1b1035, 0xff0a0714],
  ),
  StoryBackground(
    id: 'gunes',
    name: 'Günəş',
    colors: [0xffffb03a, 0xffff5f6d],
  ),
  StoryBackground(
    id: 'deniz',
    name: 'Dəniz',
    colors: [0xff1f6fa8, 0xff0b2436],
  ),
  StoryBackground(
    id: 'mesa',
    name: 'Meşə',
    colors: [0xff1d6b4f, 0xff08211a],
  ),
  StoryBackground(
    id: 'ad-gunu',
    name: 'Ad günü',
    colors: [0xffff7ac6, 0xff9b4dff],
  ),
];

StoryBackground backgroundById(Object? id) {
  final key = '${id ?? ''}';
  for (final item in storyBackgrounds) {
    if (item.id == key) return item;
  }
  return storyBackgrounds.first;
}

/// Hazır şablon — bir toxunuşla stori.
///
/// Boş ekrana yazı yazmaq çətindir: adam nə yazacağını bilmir və
/// paylaşmaqdan vaz keçir. Şablon həmin maneəni götürür.
class StoryTemplate {
  const StoryTemplate({
    required this.id,
    required this.label,
    required this.emoji,
    required this.text,
    required this.backgroundId,
  });

  final String id;
  final String label;
  final String emoji;
  final String text;
  final String backgroundId;

  /// Şablondan hazır üst qatlar.
  List<StoryOverlay> overlays() => [
        StoryOverlay(
          kind: OverlayKind.text,
          value: text,
          dy: .42,
          scale: 1.2,
        ),
        StoryOverlay(
          kind: OverlayKind.emoji,
          value: emoji,
          dy: .62,
          scale: 2,
        ),
      ];
}

const storyTemplates = <StoryTemplate>[
  StoryTemplate(
    id: 'ad-gunu',
    label: 'Ad günü',
    emoji: '🎂',
    text: 'Ad günün mübarək!',
    backgroundId: 'ad-gunu',
  ),
  StoryTemplate(
    id: 'tebrik',
    label: 'Təbrik',
    emoji: '🎉',
    text: 'Təbrik edirəm!',
    backgroundId: 'vibe',
  ),
  StoryTemplate(
    id: 'sual',
    label: 'Sual ver',
    emoji: '💬',
    text: 'Mənə sual ver',
    backgroundId: 'deniz',
  ),
  StoryTemplate(
    id: 'yeni',
    label: 'Yeni paylaşım',
    emoji: '✨',
    text: 'Yeni anım var — bax!',
    backgroundId: 'gunes',
  ),
  StoryTemplate(
    id: 'otaq',
    label: 'Otağa dəvət',
    emoji: '🎙️',
    text: 'Səsli otaqdayam, gəl!',
    backgroundId: 'gece',
  ),
  StoryTemplate(
    id: 'tesekkur',
    label: 'Təşəkkür',
    emoji: '💜',
    text: 'Hamıya təşəkkür!',
    backgroundId: 'mesa',
  ),
];

/// Yazı üçün seçilə bilən rənglər.
const storyTextColors = <int>[
  0xffffffff,
  0xff000000,
  0xffff2bd6,
  0xffffd458,
  0xff2de28a,
  0xff22a7ff,
  0xffff657b,
];
