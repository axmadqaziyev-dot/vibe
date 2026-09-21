/// Konum paylaşmaq.
///
/// İki növ var və ikisi tamam ayrı şeydir:
///
/// * **Mövcud konum** — bir anlıq şəkil. Göndərildi, bitdi.
/// * **Canlı konum** — seçilmiş müddət ərzində hərəkət etdikcə
///   yenilənir. Qarşı tərəf xəritədə sənin getdiyini görür.
///
/// Canlı konum mesajın özündə yenilənir, yeni mesaj yaradılmır —
/// yoxsa on beş dəqiqədə söhbət yüzlərlə mesajla dolardı.
///
/// Müddət bitəndə yenilənmə dayanır və mesaj "Bitdi" olur. Dayandırmaq
/// üçün göndərən "Dayandır" düyməsinə basır; tətbiq bağlansa da müddət
/// onsuz da keçir — yəni konum sonsuza qədər paylaşılmır.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Canlı konum üçün seçilə bilən müddətlər.
const liveDurations = <Duration>[
  Duration(minutes: 15),
  Duration(hours: 1),
  Duration(hours: 8),
];

String durationLabel(Duration value) {
  if (value.inHours >= 1) return '${value.inHours} saat';
  return '${value.inMinutes} dəqiqə';
}

/// Konum mesajının vəziyyəti.
class LiveLocation {
  const LiveLocation({
    required this.latitude,
    required this.longitude,
    required this.live,
    this.until,
    this.stopped = false,
  });

  final double latitude;
  final double longitude;
  final bool live;
  final DateTime? until;
  final bool stopped;

  /// Hələ yenilənirmi?
  bool activeAt(DateTime now) =>
      live && !stopped && until != null && until!.isAfter(now);

  static LiveLocation? from(Map<String, dynamic> data) {
    double? number(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('${value ?? ''}');

    final lat = number(data['lat']);
    final lng = number(data['lng']);
    if (lat == null || lng == null) return null;

    final until = data['liveUntil'];

    return LiveLocation(
      latitude: lat,
      longitude: lng,
      live: data['live'] == true,
      until: until is Timestamp ? until.toDate() : null,
      stopped: data['stopped'] == true,
    );
  }
}

/// Qalan vaxtı yazır.
String liveLeftText(Duration left) {
  if (left.isNegative) return 'Bitdi';
  if (left.inMinutes < 1) return 'Bir neçə saniyə qalıb';
  if (left.inMinutes < 60) return '${left.inMinutes} dəqiqə qalıb';
  return '${left.inHours} saat qalıb';
}

/// Cihazın konumunu alır.
///
/// İcazə verilməsə və ya xidmət bağlı olsa `null` qaytarır — çağıran
/// tərəf istifadəçiyə səbəbi deyir.
Future<Position?> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Vaxt həddi olmasa zəif siqnalda gözləmə sonsuz uzanır.
        timeLimit: Duration(seconds: 20),
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Canlı konumu izləyən və mesajı yeniləyən xidmət.
///
/// Hər söhbət üçün bir dənə işləyir; yeni paylaşım köhnəsini dayandırır.
class LiveLocationSender {
  LiveLocationSender._();

  static final LiveLocationSender instance = LiveLocationSender._();

  StreamSubscription<Position>? _watch;
  Timer? _deadline;
  DocumentReference<Map<String, dynamic>>? _message;

  bool get running => _message != null;

  /// Yeniləməni başladır.
  void start({
    required DocumentReference<Map<String, dynamic>> message,
    required Duration duration,
  }) {
    stop();
    _message = message;

    _watch = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // On metrdən az hərəkətdə yazmırıq: hər addımda Firestore-a
        // yazmaq həm bahadır, həm batareyanı yeyir.
        distanceFilter: 10,
      ),
    ).listen((position) {
      _message?.set({
        'lat': position.latitude,
        'lng': position.longitude,
        'movedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }, onError: (Object _) {});

    _deadline = Timer(duration, stop);
  }

  /// Yeniləməni dayandırır və mesajı bağlı işarələyir.
  void stop() {
    _watch?.cancel();
    _watch = null;

    _deadline?.cancel();
    _deadline = null;

    final message = _message;
    _message = null;

    if (message != null) {
      message.set({'stopped': true}, SetOptions(merge: true)).catchError(
        (Object _) {},
      );
    }
  }
}
