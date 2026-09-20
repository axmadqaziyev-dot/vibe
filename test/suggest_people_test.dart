import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/suggest_people.dart';

Candidate p(
  String uid, {
  String? name,
  bool online = false,
  String photo = '',
  String country = '',
  bool hasAbout = false,
  bool suspended = false,
}) =>
    Candidate(
      uid: uid,
      name: name ?? uid,
      online: online,
      photo: photo,
      country: country,
      hasAbout: hasAbout,
      suspended: suspended,
    );

void main() {
  group('Bal', () {
    test('Onlayn adam ən ağır çəkidir', () {
      expect(
        candidateScore(p('a', online: true)),
        greaterThan(candidateScore(p('b', photo: 'x.jpg', hasAbout: true))),
      );
    });

    test('Şəkli olan profil şəkilsizdən yuxarıdır', () {
      expect(
        candidateScore(p('a', photo: 'x.jpg')),
        greaterThan(candidateScore(p('b'))),
      );
    });

    test('Eyni ölkə bal qazandırır', () {
      expect(
        candidateScore(p('a', country: 'AZ'), myCountry: 'AZ'),
        greaterThan(candidateScore(p('b', country: 'TR'), myCountry: 'AZ')),
      );
    });
  });

  group('Siyahının qurulması', () {
    test('Özün siyahıya düşmürsən', () {
      final out = pickSuggestions([p('me'), p('a')], myUid: 'me');
      expect(out.map((e) => e.uid), ['a']);
    });

    test('Tanış olduğun adamlar təkrar tövsiyə olunmur', () {
      final out = pickSuggestions(
        [p('a'), p('b'), p('c')],
        myUid: 'me',
        known: {'a', 'b'},
      );

      expect(out.map((e) => e.uid), ['c']);
    });

    test('Bloklananlar və dayandırılmış hesablar çıxarılır', () {
      final out = pickSuggestions(
        [p('a'), p('b', suspended: true), p('c')],
        myUid: 'me',
        blocked: {'a'},
      );

      expect(out.map((e) => e.uid), ['c']);
    });

    test('Adsız yarımçıq profil göstərilmir', () {
      final out = pickSuggestions([p('a', name: '   '), p('b')], myUid: 'me');
      expect(out.map((e) => e.uid), ['b']);
    });

    test('Say həddi gözlənilir', () {
      final out = pickSuggestions(
        [for (var i = 0; i < 20; i++) p('u$i')],
        myUid: 'me',
        limit: 6,
      );

      expect(out.length, 6);
    });

    test('Onlayn olanlar başa keçir', () {
      final out = pickSuggestions(
        [p('offline1'), p('online1', online: true), p('offline2')],
        myUid: 'me',
      );

      expect(out.first.uid, 'online1');
    });

    test('Bal bərabər olanda sıra sabit qalır', () {
      final first = pickSuggestions([p('Zaur'), p('Aysel')], myUid: 'me');
      final second = pickSuggestions([p('Aysel'), p('Zaur')], myUid: 'me');

      expect(first.map((e) => e.uid), second.map((e) => e.uid));
    });

    test('Namizəd yoxdursa siyahı boş qayıdır', () {
      expect(pickSuggestions(const [], myUid: 'me'), isEmpty);
    });
  });
}
