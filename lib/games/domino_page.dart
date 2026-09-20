import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../ui/vibe_design.dart';
import '../user_profile.dart';
import 'domino_engine.dart';
import 'domino_tile.dart';

/// İki nəfərlik domino oyunu.
///
/// Oyunun vəziyyəti Firestore-da bir sənəddə saxlanılır; hər iki tərəf
/// eyni sənədi izlədiyi üçün hərəkətlər dərhal qarşı tərəfdə görünür.
class DominoPage extends StatefulWidget {
  const DominoPage({
    super.key,
    required this.matchId,
    required this.profile,
    this.database,
  });

  final String matchId;
  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  State<DominoPage> createState() => _DominoPageState();
}

/// Yeni oyun yaradır və sənədin nömrəsini qaytarır.
Future<String> createDominoMatch({
  required String myUid,
  required String myName,
  required String opponentUid,
  required String opponentName,
  FirebaseFirestore? database,
}) async {
  final db = database ?? FirebaseFirestore.instance;
  final ref = db.collection('dominoMatches').doc();

  final game = DominoState.newGame([myUid, opponentUid]);

  await ref.set({
    'id': ref.id,
    'players': [myUid, opponentUid],
    'names': {myUid: myName, opponentUid: opponentName},
    'state': game.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  return ref.id;
}

class _DominoPageState extends State<DominoPage> {
  FirebaseFirestore get db => widget.database ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get match =>
      db.collection('dominoMatches').doc(widget.matchId);

  bool busy = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  /// Hərəkəti yazır; qaydaya ziddirsə istifadəçiyə izah edir.
  Future<void> _apply(DominoState Function() move) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final next = move();
      await match.set({
        'state': next.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on DominoMoveError catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Hərəkət yazılmadı. Bağlantını yoxla.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _playTile(DominoState game, PlacedTile tile) async {
    final left = game.canPlace(tile, DominoSide.left);
    final right = game.canPlace(tile, DominoSide.right);

    if (!left && !right) {
      _say('Bu daş masaya uyğun gəlmir.');
      return;
    }

    // Masa boşdursa və ya yalnız bir uc uyğundursa, seçim soruşmuruq.
    if (game.board.isEmpty || (left != right)) {
      final side = left ? DominoSide.left : DominoSide.right;
      await _apply(() => game.play(widget.profile.uid, tile, side));
      return;
    }

    final side = await showModalBottomSheet<DominoSide>(
      context: context,
      backgroundColor: vPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'Hansı ucа qoyaq?',
                style: TextStyle(
                  color: vInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back_rounded, color: vBlue),
              title: Text('Sol uc (${game.leftEnd})',
                  style: const TextStyle(color: vInk)),
              onTap: () => Navigator.pop(sheet, DominoSide.left),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded, color: vPink),
              title: Text('Sağ uc (${game.rightEnd})',
                  style: const TextStyle(color: vInk)),
              onTap: () => Navigator.pop(sheet, DominoSide.right),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (side == null) return;
    await _apply(() => game.play(widget.profile.uid, tile, side));
  }

  Future<void> _restart(Map<String, dynamic> data) async {
    final players =
        ((data['players'] as List?) ?? const []).map((e) => '$e').toList();
    if (players.length < 2) return;

    await match.set({
      'state': DominoState.newGame(players).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: vBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Domino',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: match.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Oyun yüklənmədi.',
                  style: TextStyle(color: vMuted)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: vPink),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(
              child: Text('Oyun tapılmadı.', style: TextStyle(color: vMuted)),
            );
          }

          final game = DominoState.fromMap(
            Map<String, dynamic>.from(data['state'] ?? const {}),
          );
          final names = Map<String, dynamic>.from(data['names'] ?? const {});

          final me = widget.profile.uid;
          final opponent = game.players.firstWhere(
            (uid) => uid != me,
            orElse: () => '',
          );

          return Column(
            children: [
              _opponentBar(game, opponent, '${names[opponent] ?? 'Rəqib'}'),
              Expanded(child: _boardView(game)),
              _statusBar(game, me, names),
              _myHand(game, me),
              _actions(game, me, data),
            ],
          );
        },
      ),
    );
  }

  Widget _opponentBar(DominoState game, String opponent, String name) {
    final theirTurn = game.turn == opponent && !game.isOver;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: theirTurn ? vHot : null,
              color: theirTurn ? null : vPanel,
              border: Border.all(color: theirTurn ? vPink : vLine),
            ),
            child: Center(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: vInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  theirTurn ? 'növbə onda…' : '${game.handOf(opponent).length} daş',
                  style: TextStyle(
                    color: theirTurn ? vPink : vMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Rəqibin daşları üzü aşağı.
          Row(
            children: [
              for (var i = 0; i < game.handOf(opponent).length.clamp(0, 7); i++)
                Container(
                  width: 12,
                  height: 24,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: vPanelHigh,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: vLine),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boardView(DominoState game) {
    if (game.board.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            'Masa boşdur — istənilən daşı qoy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: vMuted, fontSize: 13.5),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Row(
          children: [
            for (final tile in game.board)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DominoTileView(tile: tile, horizontal: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBar(
    DominoState game,
    String me,
    Map<String, dynamic> names,
  ) {
    String text;
    Color color;

    if (game.outcome == DominoOutcome.finished ||
        game.outcome == DominoOutcome.blocked) {
      if (game.winner == null) {
        text = 'Bərabərə!';
        color = vGold;
      } else if (game.winner == me) {
        text = 'Sən uddun 🎉';
        color = vMint;
      } else {
        text = '${names[game.winner] ?? 'Rəqib'} uddu';
        color = vRose;
      }
    } else if (game.turn == me) {
      text = 'Növbə səndədir';
      color = vMint;
    } else {
      text = 'Rəqibin növbəsi';
      color = vMuted;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Bazar: ${game.boneyard.length}',
            style: const TextStyle(color: vMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _myHand(DominoState game, String me) {
    final hand = game.handOf(me);
    final myTurn = game.turn == me && !game.isOver;

    return SizedBox(
      height: 96,
      child: hand.isEmpty
          ? const Center(
              child: Text('Daşın qalmadı.',
                  style: TextStyle(color: vMuted, fontSize: 13)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: hand.length,
              itemBuilder: (context, i) {
                final tile = hand[i];
                final playable = game.canPlace(tile, DominoSide.left) ||
                    game.canPlace(tile, DominoSide.right);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PressableScale(
                    onTap: myTurn && !busy ? () => _playTile(game, tile) : null,
                    child: Opacity(
                      opacity: myTurn && !playable ? .45 : 1,
                      child: DominoTileView(
                        tile: tile,
                        horizontal: false,
                        highlighted: myTurn && playable,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _actions(DominoState game, String me, Map<String, dynamic> data) {
    if (game.isOver) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: GradientButton(
          label: 'Yenidən oyna',
          icon: Icons.refresh_rounded,
          gradient: vBrand,
          onPressed: busy ? null : () => _restart(data),
        ),
      );
    }

    final myTurn = game.turn == me;
    final canDraw = myTurn && !game.hasPlayable(me) && game.boneyard.isNotEmpty;
    final canPass = myTurn && !game.hasPlayable(me) && game.boneyard.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canDraw && !busy
                  ? () => _apply(() => game.draw(me))
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: vInk,
                side: const BorderSide(color: vLine),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Bazardan çək'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canPass && !busy
                  ? () => _apply(() => game.pass(me))
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: vInk,
                side: const BorderSide(color: vLine),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Ötür'),
            ),
          ),
        ],
      ),
    );
  }
}
