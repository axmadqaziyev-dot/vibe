/// Xəritə lövhəsi.
///
/// Konum mesajında xəritə görünməlidir, yoxsa iki rəqəmdən ibarət
/// kart heç nə demir. Google Static Maps açar və ödəniş tələb edir,
/// ona görə OpenStreetMap-in açıq lövhələri istifadə olunur — açar
/// yoxdur, pul yoxdur.
///
/// Hesablama Web Mercator düsturudur: dünya `2^zoom` ədəd kvadrata
/// bölünür, nöqtənin hansına düşdüyü tapılır.
library;

import 'dart:math' as math;

/// Yaxınlaşma dərəcəsi — küçə səviyyəsi.
const int mapZoom = 15;

int tileX(double longitude, int zoom) {
  final n = 1 << zoom;
  // Uzunluq dairəsi -180..180 aralığındadır; 0..1-ə gətiririk.
  final x = ((longitude + 180) / 360 * n).floor();
  return x.clamp(0, n - 1);
}

int tileY(double latitude, int zoom) {
  final n = 1 << zoom;

  // Mercator qütblərdə sonsuzluğa gedir — xəritə ±85.05 dərəcə ilə
  // məhdudlanır, yoxsa hesablama daşır.
  final safe = latitude.clamp(-85.05112878, 85.05112878);
  final radians = safe * math.pi / 180;

  final y = ((1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
          2 *
          n)
      .floor();

  return y.clamp(0, n - 1);
}

/// Nöqtəni əhatə edən lövhənin ünvanı.
String mapTileUrl(double latitude, double longitude, {int zoom = mapZoom}) {
  final x = tileX(longitude, zoom);
  final y = tileY(latitude, zoom);
  return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
}

/// Xəritə tətbiqində açmaq üçün ünvan.
///
/// `geo:` sxemi Android-də yerli xəritəni açır, iOS-da isə tanınmır —
/// ona görə hər yerdə işləyən ümumi ünvan verilir.
String mapOpenUrl(double latitude, double longitude) =>
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

/// Koordinatı oxunaqlı yazır: "40.3777, 49.8920".
String coordinateText(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
