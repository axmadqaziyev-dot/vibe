import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/vip.dart';

void main() {
  group('VIP xalı', () {
    test('Göndərilən və alınan hədiyyələrin cəmidir', () {
      expect(vipScore({'giftSent': 200, 'giftReceived': 300}), 500);
    });

    test('Boş profil sıfır xal verir', () {
      expect(vipScore({}), 0);
    });

    test('Mətn şəklində gələn rəqəmlər də oxunur', () {
      expect(vipScore({'giftSent': '120', 'giftReceived': '80'}), 200);
    });
  });

  group('Pillələr', () {
    test('Yeni istifadəçi ən aşağı pillədədir', () {
      expect(tierForScore(0).name, 'Yeni');
      expect(tierForScore(299).name, 'Yeni');
    });

    test('Hədd keçiləndə pillə qalxır', () {
      expect(tierForScore(300).name, 'Bürünc');
      expect(tierForScore(1500).name, 'Gümüş');
      expect(tierForScore(5000).name, 'Qızıl');
      expect(tierForScore(100000).name, 'Kral');
    });

    test('Ən yuxarı pillədən yuxarı qalxmır', () {
      expect(tierForScore(999999).name, 'Kral');
      expect(nextTier(999999), isNull);
      expect(tierProgress(999999), 1);
    });

    test('Pillələr xal sırası ilə düzülüb', () {
      for (var i = 1; i < vipTiers.length; i++) {
        expect(
          vipTiers[i].minScore,
          greaterThan(vipTiers[i - 1].minScore),
          reason: '${vipTiers[i].name} əvvəlkindən yuxarı olmalıdır',
        );
      }
    });

    test('İrəliləyiş iki pillə arasında düzgün hesablanır', () {
      // Bürünc 300, Gümüş 1500 → 900 xal tam ortadır.
      expect(tierProgress(900), closeTo(0.5, 0.01));
      expect(tierProgress(300), 0);
    });
  });

  group('Medallar', () {
    test('Yeni istifadəçi yalnız "Xoş gəldin" alır', () {
      final earned = earnedMedals({});
      expect(earned.length, 1);
      expect(earned.first.id, 'welcome');
    });

    test('Şəkil qoyanda medal əlavə olunur', () {
      final earned = earnedMedals({'photoUrl': 'data:image/jpeg;base64,xx'});
      expect(earned.map((m) => m.id), contains('photo'));
    });

    test('Şərtlər ödənəndə hamısı qazanılır', () {
      final earned = earnedMedals({
        'photoUrl': 'x',
        'giftSent': 50,
        'giftReceived': 2000,
        'roomsCreated': 1,
        'followersCount': 12,
        'momentCount': 3,
        'gameWins': 1,
      });
      expect(earned.length, allMedals.length);
    });

    test('Hədd altında medal verilmir', () {
      final earned = earnedMedals({'followersCount': 9, 'giftReceived': 999});
      final ids = earned.map((m) => m.id);
      expect(ids, isNot(contains('social')));
      expect(ids, isNot(contains('loved')));
    });
  });
}
