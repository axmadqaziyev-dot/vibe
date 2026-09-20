import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/invite.dart';
import 'package:flutter_application_1/onboarding.dart';

void main() {
  group('Profil tamamlama yoxlaması', () {
    test('Boş profil onboarding tələb edir', () {
      expect(needsOnboarding({'name': 'Aysel'}), isTrue);
    });

    test('Cins var, maraq yoxdursa yenə tələb olunur', () {
      expect(needsOnboarding({'gender': 'qadın'}), isTrue);
      expect(needsOnboarding({'gender': 'qadın', 'interests': []}), isTrue);
    });

    test('Cins və maraqlar varsa tələb olunmur', () {
      expect(
        needsOnboarding({
          'gender': 'kişi',
          'interests': ['Musiqi'],
        }),
        isFalse,
      );
    });

    test('Bir dəfə tamamlanıbsa bir daha soruşulmur', () {
      // Köhnə istifadəçi maraqlarını silsə belə ekran təkrar açılmır.
      expect(
        needsOnboarding({
          'onboardedAt': Timestamp.now(),
          'gender': '',
          'interests': [],
        }),
        isFalse,
      );
    });

    test('Köhnə `sex` və `tags` sahələri də qəbul olunur', () {
      expect(
        needsOnboarding({
          'sex': 'female',
          'tags': ['Kitab'],
        }),
        isFalse,
      );
    });
  });

  group('Dəvət linki', () {
    test('Referans olmadan sadə link qaytarır', () {
      expect(inviteLink(), vibeWebUrl);
      expect(inviteLink(referrerUid: ''), vibeWebUrl);
    });

    test('Referans varsa linkə əlavə olunur', () {
      expect(inviteLink(referrerUid: 'abc123'), '$vibeWebUrl/?ref=abc123');
    });

    test('Dəvət mətnində ad və link var', () {
      final text = inviteMessage(name: 'Aysel', referrerUid: 'abc123');
      expect(text, contains('Aysel'));
      expect(text, contains('$vibeWebUrl/?ref=abc123'));
    });
  });
}
