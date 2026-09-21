import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/stories.dart';

final now = DateTime(2026, 9, 21, 20);

Story make(
  String id, {
  required String owner,
  int hoursAgo = 1,
  String name = 'VIBE',
}) =>
    Story(
      id: id,
      ownerUid: owner,
      ownerName: name,
      createdAt: now.subtract(Duration(hours: hoursAgo)),
    );

void main() {
  group('Yaşama müddəti', () {
    test('Təzə stori yaşayır', () {
      expect(make('a', owner: 'u1', hoursAgo: 3).alive(now: now), isTrue);
    });

    test('24 saatdan köhnə stori ölür', () {
      expect(make('a', owner: 'u1', hoursAgo: 25).alive(now: now), isFalse);
    });

    test('Sərhəddə — tam 24 saat artıq ölüdür', () {
      expect(make('a', owner: 'u1', hoursAgo: 24).alive(now: now), isFalse);
      expect(make('a', owner: 'u1', hoursAgo: 23).alive(now: now), isTrue);
    });

    test('Qalan saat düzgün hesablanır', () {
      expect(make('a', owner: 'u1', hoursAgo: 4).hoursLeft(now: now), 20);
      expect(make('a', owner: 'u1', hoursAgo: 30).hoursLeft(now: now), 0);
    });
  });

  group('Sənəddən oxuma', () {
    test('Sahələr düzgün oxunur', () {
      final story = Story.from('s1', {
        'ownerUid': 'u1',
        'ownerName': 'Aygün',
        'imageUrl': 'a.jpg',
        'caption': 'Salam',
        'createdAt': now,
        'viewCount': 7,
      });

      expect(story.ownerName, 'Aygün');
      expect(story.viewCount, 7);
      expect(story.isVideo, isFalse);
    });

    test('Video stori tanınır', () {
      final story = Story.from('s1', {'videoUrl': 'v.mp4', 'createdAt': now});
      expect(story.isVideo, isTrue);
    });

    test('Tarixi olmayan sənəd köhnə sayılır', () {
      // Xarab sənəd ekranı sındırmamalı, sadəcə siyahıdan düşməlidir.
      final story = Story.from('s1', {'ownerUid': 'u1'});
      expect(story.alive(now: now), isFalse);
    });
  });

  group('Qruplaşdırma', () {
    test('Eyni adamın storiləri bir qrupdadır', () {
      final groups = groupStories(
        [
          make('a', owner: 'u1'),
          make('b', owner: 'u1', hoursAgo: 2),
          make('c', owner: 'u2'),
        ],
        me: 'me',
        now: now,
      );

      expect(groups.length, 2);
      expect(groups.firstWhere((g) => g.ownerUid == 'u1').stories.length, 2);
    });

    test('Qrupun içində köhnədən təzəyə sıralanır', () {
      final groups = groupStories(
        [
          make('teze', owner: 'u1', hoursAgo: 1),
          make('kohne', owner: 'u1', hoursAgo: 5),
        ],
        me: 'me',
        now: now,
      );

      expect(groups.first.stories.map((s) => s.id), ['kohne', 'teze']);
    });

    test('Ölü storilər siyahıya düşmür', () {
      final groups = groupStories(
        [make('a', owner: 'u1', hoursAgo: 40)],
        me: 'me',
        now: now,
      );

      expect(groups, isEmpty);
    });

    test('Öz storim həmişə birincidir', () {
      final groups = groupStories(
        [
          make('a', owner: 'u1', hoursAgo: 1),
          make('b', owner: 'me', hoursAgo: 10),
        ],
        me: 'me',
        now: now,
      );

      expect(groups.first.ownerUid, 'me');
    });

    test('Baxılmamışlar baxılanlardan öndədir', () {
      final groups = groupStories(
        [
          make('baxilan', owner: 'u1', hoursAgo: 1),
          make('yeni', owner: 'u2', hoursAgo: 5),
        ],
        me: 'me',
        seen: {'baxilan'},
        now: now,
      );

      expect(groups.first.ownerUid, 'u2');
      expect(groups.last.allSeen, isTrue);
    });

    test('Bir storisi baxılmamışsa qrup baxılmamış sayılır', () {
      final groups = groupStories(
        [
          make('a', owner: 'u1', hoursAgo: 1),
          make('b', owner: 'u1', hoursAgo: 2),
        ],
        me: 'me',
        seen: {'a'},
        now: now,
      );

      expect(groups.first.allSeen, isFalse);
    });

    test('Sahibi olmayan sənəd atlanır', () {
      final groups = groupStories(
        [make('a', owner: '', hoursAgo: 1)],
        me: 'me',
        now: now,
      );

      expect(groups, isEmpty);
    });
  });
}
