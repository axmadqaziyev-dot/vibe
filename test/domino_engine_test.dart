import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/games/domino_engine.dart';

/// Oyunun qaydaları — ekran olmadan yoxlanılır.
void main() {
  const a = 'aysel';
  const b = 'murad';

  group('Paylama', () {
    test('Hər oyunçuya 7 daş düşür, qalanı bazarda qalır', () {
      final game = DominoState.newGame([a, b], seed: 1);

      expect(game.handOf(a).length, 7);
      expect(game.handOf(b).length, 7);
      expect(game.boneyard.length, 28 - 14);
      expect(game.board, isEmpty);
    });

    test('Bütün 28 daş bir dəfə paylanır', () {
      final game = DominoState.newGame([a, b], seed: 7);
      final all = <String>{
        ...game.handOf(a).map((t) => t.key),
        ...game.handOf(b).map((t) => t.key),
        ...game.boneyard.map((t) => t.key),
      };
      expect(all.length, 28);
    });

    test('İki nəfərdən az oyunçu ilə oyun başlamır', () {
      expect(() => DominoState.newGame([a]), throwsA(isA<DominoMoveError>()));
    });
  });

  group('Daş qoymaq', () {
    DominoState blank() => DominoState(
          players: const [a, b],
          hands: {
            a: [const PlacedTile(3, 5), const PlacedTile(1, 2)],
            b: [const PlacedTile(5, 6)],
          },
          board: const [],
          boneyard: const [],
          turn: a,
          passes: 0,
        );

    test('Boş masaya istənilən daş qoyulur', () {
      final game = blank().play(a, const PlacedTile(3, 5), DominoSide.right);
      expect(game.board.length, 1);
      expect(game.leftEnd, 3);
      expect(game.rightEnd, 5);
      expect(game.turn, b);
    });

    test('Daş uyğun ucda avtomatik çevrilir', () {
      // Masa: 3-5. Sağ uc 5-dir; 5-6 daşı olduğu kimi, 6-5 çevrilərək qoyulur.
      final game = blank()
          .play(a, const PlacedTile(3, 5), DominoSide.right)
          .play(b, const PlacedTile(6, 5), DominoSide.right);

      expect(game.board.last.left, 5);
      expect(game.board.last.right, 6);
      expect(game.rightEnd, 6);
    });

    test('Sol uca qoyulanda da düzgün çevrilir', () {
      final game = DominoState(
        players: const [a, b],
        hands: {
          a: [const PlacedTile(1, 3)],
          b: [const PlacedTile(0, 0)],
        },
        board: const [PlacedTile(3, 5)],
        boneyard: const [],
        turn: a,
        passes: 0,
      ).play(a, const PlacedTile(1, 3), DominoSide.left);

      expect(game.board.first.left, 1);
      expect(game.board.first.right, 3);
      expect(game.leftEnd, 1);
    });

    test('Uyğun gəlməyən daş qəbul edilmir', () {
      final game = blank().play(a, const PlacedTile(3, 5), DominoSide.right);
      expect(
        () => game.play(b, const PlacedTile(5, 6), DominoSide.left),
        throwsA(isA<DominoMoveError>()),
      );
    });

    test('Növbə başqasındadırsa hərəkət edilmir', () {
      expect(
        () => blank().play(b, const PlacedTile(5, 6), DominoSide.right),
        throwsA(isA<DominoMoveError>()),
      );
    });

    test('Əlində olmayan daş oynanmır', () {
      expect(
        () => blank().play(a, const PlacedTile(6, 6), DominoSide.right),
        throwsA(isA<DominoMoveError>()),
      );
    });
  });

  group('Bazar və ötürmə', () {
    DominoState stuck({List<PlacedTile> boneyard = const []}) => DominoState(
          players: const [a, b],
          hands: {
            a: [const PlacedTile(0, 1)],
            b: [const PlacedTile(4, 4)],
          },
          board: const [PlacedTile(6, 6)],
          boneyard: boneyard,
          turn: a,
          passes: 0,
        );

    test('Oynanacaq daş varkən bazardan çəkmək olmur', () {
      final game = DominoState(
        players: const [a, b],
        hands: {
          a: [const PlacedTile(6, 2)],
          b: [const PlacedTile(4, 4)],
        },
        board: const [PlacedTile(6, 6)],
        boneyard: const [PlacedTile(0, 0)],
        turn: a,
        passes: 0,
      );
      expect(() => game.draw(a), throwsA(isA<DominoMoveError>()));
    });

    test('Uyğun daş yoxdursa bazardan çəkilir və növbə qalır', () {
      final game = stuck(boneyard: const [PlacedTile(2, 2)]).draw(a);

      expect(game.handOf(a).length, 2);
      expect(game.boneyard, isEmpty);
      expect(game.turn, a);
    });

    test('Bazar doluykən ötürmək olmur', () {
      final game = stuck(boneyard: const [PlacedTile(2, 2)]);
      expect(() => game.pass(a), throwsA(isA<DominoMoveError>()));
    });

    test('Bazar boşdursa növbə ötürülür', () {
      final game = stuck().pass(a);
      expect(game.turn, b);
      expect(game.passes, 1);
      expect(game.isOver, isFalse);
    });

    test('Hər iki tərəf ötürəndə xalı az olan udur', () {
      // a-nın xalı 1, b-nin xalı 8 → a udur.
      final game = stuck().pass(a).pass(b);

      expect(game.outcome, DominoOutcome.blocked);
      expect(game.winner, a);
    });

    test('Xallar bərabər olanda qalib olmur', () {
      final game = DominoState(
        players: const [a, b],
        hands: {
          a: [const PlacedTile(1, 1)],
          b: [const PlacedTile(0, 2)],
        },
        board: const [PlacedTile(6, 6)],
        boneyard: const [],
        turn: a,
        passes: 0,
      ).pass(a).pass(b);

      expect(game.outcome, DominoOutcome.blocked);
      expect(game.winner, isNull);
    });
  });

  group('Qalib', () {
    test('Son daşı oynayan udur', () {
      final game = DominoState(
        players: const [a, b],
        hands: {
          a: [const PlacedTile(6, 3)],
          b: [const PlacedTile(1, 1)],
        },
        board: const [PlacedTile(6, 6)],
        boneyard: const [],
        turn: a,
        passes: 0,
      ).play(a, const PlacedTile(6, 3), DominoSide.left);

      expect(game.outcome, DominoOutcome.finished);
      expect(game.winner, a);
      expect(game.isOver, isTrue);
    });

    test('Oyun bitəndən sonra hərəkət edilmir', () {
      final game = DominoState(
        players: const [a, b],
        hands: {a: const [], b: const [PlacedTile(1, 1)]},
        board: const [PlacedTile(6, 6)],
        boneyard: const [],
        turn: a,
        passes: 0,
        winner: a,
        outcome: DominoOutcome.finished,
      );

      expect(
        () => game.play(a, const PlacedTile(1, 1), DominoSide.left),
        throwsA(isA<DominoMoveError>()),
      );
    });
  });

  group('Yadda saxlama', () {
    test('Vəziyyət yazılıb geri oxunanda dəyişmir', () {
      final game = DominoState.newGame([a, b], seed: 42)
          .play(
            DominoState.newGame([a, b], seed: 42).turn,
            DominoState.newGame([a, b], seed: 42)
                .handOf(DominoState.newGame([a, b], seed: 42).turn)
                .first,
            DominoSide.right,
          );

      final restored = DominoState.fromMap(game.toMap());

      expect(restored.turn, game.turn);
      expect(restored.board.first.encode(), game.board.first.encode());
      expect(restored.boneyard.length, game.boneyard.length);
      expect(restored.handOf(a).length, game.handOf(a).length);
      expect(restored.outcome, game.outcome);
    });
  });
}
