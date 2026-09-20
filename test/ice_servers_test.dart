import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/voice/ice_servers.dart';

void main() {
  group('WebRTC server siyahısı', () {
    test('TURN qoşulub', () {
      expect(hasTurnServer, isTrue,
          reason: 'TURN olmadan mobil internetdə zənglər qoşulmur');
    });

    test('STUN də var — açıq şəbəkələrdə TURN-a ehtiyac qalmasın', () {
      final servers = vibeIceConfig['iceServers'] as List;
      final urls = servers
          .expand((s) => s['urls'] is List ? s['urls'] as List : [s['urls']])
          .map((u) => '$u')
          .toList();

      expect(urls.any((u) => u.startsWith('stun:')), isTrue);
    });

    test('Həm UDP, həm TCP, həm TLS ünvanı var', () {
      final servers = vibeIceConfig['iceServers'] as List;
      final turn = servers
          .expand((s) => s['urls'] is List ? s['urls'] as List : [s['urls']])
          .map((u) => '$u')
          .where((u) => u.startsWith('turn:') || u.startsWith('turns:'))
          .toList();

      // Şəbəkələr fərqli qapıları bağlayır — hamısı olmalıdır.
      expect(turn.any((u) => u.contains(':80') && !u.contains('tcp')), isTrue,
          reason: 'UDP 80 yoxdur');
      expect(turn.any((u) => u.contains('transport=tcp')), isTrue,
          reason: 'TCP yoxdur');
      expect(turn.any((u) => u.startsWith('turns:')), isTrue,
          reason: 'TLS yoxdur');
    });

    test('Hər TURN girişində istifadəçi adı və şifrə var', () {
      final servers = vibeIceConfig['iceServers'] as List;

      for (final server in servers) {
        final urls = server['urls'] is List
            ? (server['urls'] as List).map((u) => '$u')
            : ['${server['urls']}'];

        final needsAuth =
            urls.any((u) => u.startsWith('turn:') || u.startsWith('turns:'));

        if (needsAuth) {
          expect('${server['username']}'.isNotEmpty, isTrue);
          expect('${server['credential']}'.isNotEmpty, isTrue);
        }
      }
    });
  });
}
