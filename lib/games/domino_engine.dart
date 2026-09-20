import 'dart:math';

/// DOMİNO OYUNUNUN QAYDALARI.
///
/// Bu fayl tamamilə təmiz Dart-dır: Firebase, Flutter və şəbəkə yoxdur.
/// Ona görə qaydalar ayrıca yoxlanıla bilir və oyun ekranı sadələşir.
///
/// Qaydalar (klassik "draw" variantı, 2 nəfər):
///  • 28 daş (0-0-dan 6-6-ya qədər), hər oyunçuya 7 daş, qalanı bazarda;
///  • növbədə olan oyunçu masanın uclarından birinə uyğun daş qoyur;
///  • uyğun daşı yoxdursa bazardan çəkir, oynaya bilirsə oynayır;
///  • bazar boşdursa və oynaya bilmirsə növbəni ötürür;
///  • daşları qurtaran udur; hər iki tərəf ötürərsə, xalı az olan udur.

/// Masaya qoyulmuş daş — hansı üzün solda olduğu vacibdir.
class PlacedTile {
  const PlacedTile(this.left, this.right);

  final int left;
  final int right;

  bool get isDouble => left == right;

  PlacedTile get flipped => PlacedTile(right, left);

  String encode() => '$left-$right';

  static PlacedTile decode(String value) {
    final parts = value.split('-');
    return PlacedTile(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Əldəki daşlar üçün sabit yazılış (kiçik üz əvvəl).
  String get key => left <= right ? '$left-$right' : '$right-$left';

  @override
  bool operator ==(Object other) =>
      other is PlacedTile && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => encode();
}

/// Masanın hansı ucuna qoyulur.
enum DominoSide { left, right }

/// Oyunun bitmə səbəbi.
enum DominoOutcome { playing, finished, blocked }

/// Qaydalara zidd hərəkət.
class DominoMoveError implements Exception {
  DominoMoveError(this.message);

  final String message;

  @override
  String toString() => message;
}

class DominoState {
  DominoState({
    required this.players,
    required this.hands,
    required this.board,
    required this.boneyard,
    required this.turn,
    required this.passes,
    this.winner,
    this.outcome = DominoOutcome.playing,
  });

  /// İki oyunçunun kimliyi (növbə sırası ilə).
  final List<String> players;

  /// Hər oyunçunun əlindəki daşlar.
  final Map<String, List<PlacedTile>> hands;

  /// Masadakı daşlar — soldan sağa.
  final List<PlacedTile> board;

  /// Bazardakı daşlar.
  final List<PlacedTile> boneyard;

  /// Növbə kimdədir.
  final String turn;

  /// Ardıcıl ötürmə sayı — hamı ötürəndə oyun bağlanır.
  final int passes;

  /// Qalibin kimliyi; bərabərlikdə `null`.
  final String? winner;

  final DominoOutcome outcome;

  bool get isOver => outcome != DominoOutcome.playing;

  /// Masanın sol ucundakı rəqəm.
  int? get leftEnd => board.isEmpty ? null : board.first.left;

  /// Masanın sağ ucundakı rəqəm.
  int? get rightEnd => board.isEmpty ? null : board.last.right;

  List<PlacedTile> handOf(String uid) => hands[uid] ?? const [];

  /// Oyunçunun xal cəmi (az olan udur).
  int pipsOf(String uid) =>
      handOf(uid).fold(0, (sum, tile) => sum + tile.left + tile.right);

  /// Bu daş masaya qoyula bilərmi?
  bool canPlace(PlacedTile tile, DominoSide side) {
    if (board.isEmpty) return true;
    final end = side == DominoSide.left ? leftEnd! : rightEnd!;
    return tile.left == end || tile.right == end;
  }

  /// Oyunçunun oynaya biləcəyi daş varmı?
  bool hasPlayable(String uid) => handOf(uid).any(
        (tile) =>
            canPlace(tile, DominoSide.left) || canPlace(tile, DominoSide.right),
      );

  /// Yeni oyun paylayır.
  ///
  /// [seed] verilərsə paylama təkrarlana bilir — testlər üçün.
  static DominoState newGame(List<String> players, {int? seed}) {
    if (players.length < 2) {
      throw DominoMoveError('Oyun üçün ən az iki nəfər lazımdır.');
    }

    final deck = <PlacedTile>[];
    for (var a = 0; a <= 6; a++) {
      for (var b = a; b <= 6; b++) {
        deck.add(PlacedTile(a, b));
      }
    }
    deck.shuffle(Random(seed));

    final hands = <String, List<PlacedTile>>{};
    var index = 0;
    for (final uid in players) {
      hands[uid] = deck.sublist(index, index + 7);
      index += 7;
    }

    // Ən böyük cütü olan başlayır; cüt yoxdursa birinci oyunçu.
    var starter = players.first;
    var best = -1;
    for (final uid in players) {
      for (final tile in hands[uid]!) {
        if (tile.isDouble && tile.left > best) {
          best = tile.left;
          starter = uid;
        }
      }
    }

    return DominoState(
      players: List.unmodifiable(players),
      hands: hands,
      board: const [],
      boneyard: deck.sublist(index),
      turn: starter,
      passes: 0,
    );
  }

  /// Növbəti oyunçu.
  String _next(String uid) {
    final i = players.indexOf(uid);
    return players[(i + 1) % players.length];
  }

  void _requireTurn(String uid) {
    if (isOver) throw DominoMoveError('Oyun bitib.');
    if (uid != turn) throw DominoMoveError('Növbə səndə deyil.');
  }

  /// Daşı masaya qoyur.
  DominoState play(String uid, PlacedTile tile, DominoSide side) {
    _requireTurn(uid);

    final hand = List<PlacedTile>.from(handOf(uid));
    final index = hand.indexWhere((t) => t.key == tile.key);
    if (index < 0) throw DominoMoveError('Bu daş sənin əlində yoxdur.');

    if (!canPlace(tile, side)) {
      throw DominoMoveError('Bu daş həmin uca uyğun gəlmir.');
    }

    hand.removeAt(index);

    final newBoard = List<PlacedTile>.from(board);
    if (newBoard.isEmpty) {
      newBoard.add(tile);
    } else if (side == DominoSide.left) {
      // Uyğun gələn üz sağda qalmalıdır ki, masanın ucuna birləşsin.
      final end = leftEnd!;
      newBoard.insert(0, tile.right == end ? tile : tile.flipped);
    } else {
      final end = rightEnd!;
      newBoard.add(tile.left == end ? tile : tile.flipped);
    }

    final newHands = Map<String, List<PlacedTile>>.from(hands);
    newHands[uid] = hand;

    // Daşları qurtardısa udur.
    if (hand.isEmpty) {
      return DominoState(
        players: players,
        hands: newHands,
        board: newBoard,
        boneyard: boneyard,
        turn: uid,
        passes: 0,
        winner: uid,
        outcome: DominoOutcome.finished,
      );
    }

    return DominoState(
      players: players,
      hands: newHands,
      board: newBoard,
      boneyard: boneyard,
      turn: _next(uid),
      passes: 0,
    );
  }

  /// Bazardan bir daş çəkir. Növbə dəyişmir.
  DominoState draw(String uid) {
    _requireTurn(uid);

    if (boneyard.isEmpty) {
      throw DominoMoveError('Bazar boşdur.');
    }
    if (hasPlayable(uid)) {
      throw DominoMoveError('Oynaya biləcəyin daş var — əvvəlcə onu oyna.');
    }

    final newBoneyard = List<PlacedTile>.from(boneyard);
    final drawn = newBoneyard.removeLast();

    final newHands = Map<String, List<PlacedTile>>.from(hands);
    newHands[uid] = [...handOf(uid), drawn];

    return DominoState(
      players: players,
      hands: newHands,
      board: board,
      boneyard: newBoneyard,
      turn: uid,
      passes: passes,
    );
  }

  /// Növbəni ötürür. Yalnız bazar boş və oynanacaq daş yoxdursa olar.
  DominoState pass(String uid) {
    _requireTurn(uid);

    if (hasPlayable(uid)) {
      throw DominoMoveError('Oynaya biləcəyin daş var.');
    }
    if (boneyard.isNotEmpty) {
      throw DominoMoveError('Əvvəlcə bazardan çək.');
    }

    final total = passes + 1;

    // Hamı ardıcıl ötürübsə oyun bağlanır.
    if (total >= players.length) {
      String? best;
      var bestPips = 1 << 30;
      var tie = false;

      for (final player in players) {
        final pips = pipsOf(player);
        if (pips < bestPips) {
          bestPips = pips;
          best = player;
          tie = false;
        } else if (pips == bestPips) {
          tie = true;
        }
      }

      return DominoState(
        players: players,
        hands: hands,
        board: board,
        boneyard: boneyard,
        turn: turn,
        passes: total,
        winner: tie ? null : best,
        outcome: DominoOutcome.blocked,
      );
    }

    return DominoState(
      players: players,
      hands: hands,
      board: board,
      boneyard: boneyard,
      turn: _next(uid),
      passes: total,
    );
  }

  // ----------------------------------------------------------
  // FIRESTORE ÜÇÜN ÇEVİRMƏ
  // ----------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'players': players,
        'hands': hands.map(
          (uid, tiles) => MapEntry(uid, tiles.map((t) => t.encode()).toList()),
        ),
        'board': board.map((t) => t.encode()).toList(),
        'boneyard': boneyard.map((t) => t.encode()).toList(),
        'turn': turn,
        'passes': passes,
        'winner': winner,
        'outcome': outcome.name,
      };

  static DominoState fromMap(Map<String, dynamic> data) {
    List<PlacedTile> tiles(Object? value) =>
        ((value as List?) ?? const []).map((e) => PlacedTile.decode('$e')).toList();

    final rawHands = (data['hands'] as Map?) ?? const {};

    return DominoState(
      players: ((data['players'] as List?) ?? const []).map((e) => '$e').toList(),
      hands: {
        for (final entry in rawHands.entries)
          '${entry.key}': tiles(entry.value),
      },
      board: tiles(data['board']),
      boneyard: tiles(data['boneyard']),
      turn: '${data['turn'] ?? ''}',
      passes: (data['passes'] as num?)?.toInt() ?? 0,
      winner: data['winner'] == null ? null : '${data['winner']}',
      outcome: DominoOutcome.values.firstWhere(
        (value) => value.name == '${data['outcome'] ?? 'playing'}',
        orElse: () => DominoOutcome.playing,
      ),
    );
  }
}
