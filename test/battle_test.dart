import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/battle.dart';

void main() {
  group('Rejim', () {
    test('Hər rejimin adı, izahı və işarəsi var', () {
      for (final mode in BattleMode.values) {
        expect(mode.label.trim(), isNotEmpty);
        expect(mode.hint.trim(), isNotEmpty);
        expect(mode.emoji.trim(), isNotEmpty);
      }
    });

    test('Açardan rejim tapılır', () {
      expect(battleModeFrom('atisma'), BattleMode.atisma);
      expect(battleModeFrom('freestyle'), BattleMode.freestyle);
    });

    test('Tanınmayan açar meyxana sayılır', () {
      expect(battleModeFrom('kohne'), BattleMode.meyxana);
      expect(battleModeFrom(null), BattleMode.meyxana);
    });

    test('Hər rejimin söz siyahısı var və boş deyil', () {
      for (final mode in BattleMode.values) {
        expect(battleWords[mode], isNotNull, reason: mode.label);
        expect(battleWords[mode]!.length, greaterThan(5), reason: mode.label);
      }
    });
  });

  group('Söz seçimi', () {
    test('Eyni toxum hər cihazda eyni sözü verir', () {
      // Hamı eyni sözü görməlidir, yoxsa döyüş mənasını itirir.
      expect(
        battleWordFor(BattleMode.meyxana, 12345),
        battleWordFor(BattleMode.meyxana, 12345),
      );
    });

    test('Mənfi toxum da işləyir', () {
      expect(battleWordFor(BattleMode.meyxana, -7).trim(), isNotEmpty);
    });

    test('Söz öz rejiminin siyahısından gəlir', () {
      for (final mode in BattleMode.values) {
        final word = battleWordFor(mode, 3);
        expect(battleWords[mode], contains(word));
      }
    });
  });

  group('Növbə', () {
    test('Növbə mikrofondakılar arasında dövr edir', () {
      final speakers = [0, 1, 2];

      expect(battleSpeakerAt(speakers, 0), 0);
      expect(battleSpeakerAt(speakers, 1), 1);
      expect(battleSpeakerAt(speakers, 2), 2);
      expect(battleSpeakerAt(speakers, 3), 0);
    });

    test('Mikrofonda heç kim yoxdursa növbə də yoxdur', () {
      expect(battleSpeakerAt(const [], 5), -1);
    });

    test('Kürsü nömrələri ardıcıl olmaya bilər', () {
      // 1-ci və 4-cü kürsüdə iki nəfər var, aradakılar boşdur.
      final speakers = [1, 4];

      expect(battleSpeakerAt(speakers, 0), 1);
      expect(battleSpeakerAt(speakers, 1), 4);
      expect(battleSpeakerAt(speakers, 2), 1);
    });
  });

  group('Dövrə', () {
    test('Hamı bir dəfə deyəndən sonra dövrə artır', () {
      final speakers = [0, 1, 2];

      expect(battleRoundAt(speakers, 0), 1);
      expect(battleRoundAt(speakers, 2), 1);
      expect(battleRoundAt(speakers, 3), 2);
      expect(battleRoundAt(speakers, 6), 3);
    });

    test('Üç dövrə bitəndə döyüş bitir', () {
      final speakers = [0, 1];

      expect(battleFinished(speakers, 5), isFalse);
      expect(battleFinished(speakers, 6), isTrue);
    });

    test('Mikrofon boş olanda döyüş dərhal bitmiş sayılır', () {
      expect(battleFinished(const [], 0), isTrue);
    });
  });

  group('Uzunluq', () {
    test('Ümumi vaxt iştirakçı sayına görə artır', () {
      expect(battleTotalSeconds(2), 2 * 3 * battleTurnSeconds);
      expect(
        battleTotalSeconds(4),
        greaterThan(battleTotalSeconds(2)),
      );
    });

    test('Heç kim yoxdursa vaxt sıfırdır', () {
      expect(battleTotalSeconds(0), 0);
    });
  });
}
