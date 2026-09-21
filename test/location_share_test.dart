import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/location_share.dart';

void main() {
  final now = DateTime(2026, 9, 22, 12);

  group('konum sənəddən oxunur', () {
    test('koordinatlar oxunur', () {
      final spot = LiveLocation.from({'lat': 40.4, 'lng': 49.9})!;

      expect(spot.latitude, 40.4);
      expect(spot.longitude, 49.9);
      expect(spot.live, isFalse);
    });

    test('mətn kimi yazılmış koordinat da oxunur', () {
      final spot = LiveLocation.from({'lat': '40.4', 'lng': '49.9'});
      expect(spot?.latitude, 40.4);
    });

    test('koordinatsız sənəd null verir', () {
      expect(LiveLocation.from(const {}), isNull);
      expect(LiveLocation.from({'lat': 40.4}), isNull);
    });
  });

  group('canlı konumun vəziyyəti', () {
    LiveLocation live({DateTime? until, bool stopped = false}) => LiveLocation(
          latitude: 40,
          longitude: 49,
          live: true,
          until: until,
          stopped: stopped,
        );

    test('müddət bitməyibsə işləyir', () {
      expect(
        live(until: now.add(const Duration(minutes: 5))).activeAt(now),
        isTrue,
      );
    });

    test('müddət bitibsə dayanır', () {
      expect(
        live(until: now.subtract(const Duration(minutes: 1))).activeAt(now),
        isFalse,
      );
    });

    test('əl ilə dayandırılıbsa işləmir', () {
      // Müddət qalsa da göndərən dayandırıbsa paylaşım bitib.
      expect(
        live(until: now.add(const Duration(hours: 2)), stopped: true)
            .activeAt(now),
        isFalse,
      );
    });

    test('adi konum canlı sayılmır', () {
      const spot = LiveLocation(
        latitude: 40,
        longitude: 49,
        live: false,
      );
      expect(spot.activeAt(now), isFalse);
    });

    test('vaxtsız canlı konum işləmir', () {
      // Müddət yazılmayıbsa sonsuz paylaşım olardı — icazə vermirik.
      expect(live().activeAt(now), isFalse);
    });
  });

  group('qalan vaxt yazısı', () {
    test('dəqiqə və saat', () {
      expect(liveLeftText(const Duration(minutes: 14)), '14 dəqiqə qalıb');
      expect(liveLeftText(const Duration(hours: 3)), '3 saat qalıb');
    });

    test('bitmiş müddət', () {
      expect(liveLeftText(const Duration(minutes: -1)), 'Bitdi');
    });

    test('bir dəqiqədən az', () {
      expect(liveLeftText(const Duration(seconds: 20)),
          'Bir neçə saniyə qalıb');
    });
  });

  group('müddət adları', () {
    test('dəqiqə və saat ayrılır', () {
      expect(durationLabel(const Duration(minutes: 15)), '15 dəqiqə');
      expect(durationLabel(const Duration(hours: 8)), '8 saat');
    });
  });

  test('Timestamp-dan vaxt oxunur', () {
    final spot = LiveLocation.from({
      'lat': 40.0,
      'lng': 49.0,
      'live': true,
      'liveUntil': Timestamp.fromDate(now.add(const Duration(minutes: 30))),
    })!;

    expect(spot.activeAt(now), isTrue);
  });
}
