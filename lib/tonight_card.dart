import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'tonight.dart';
import 'ui/vibe_design.dart';

/// "Bu axşam nə istəyirsən?" kartı.
///
/// Niyyət seçiləndən sonra kəşf siyahısı ona uyğun adamları önə çıxarır.
/// Seçim səkkiz saatdan sonra özü sönür — "bu axşam" sabaha qalmamalıdır.
class TonightCard extends StatelessWidget {
  const TonightCard({
    super.key,
    required this.uid,
    this.database,
    this.onChanged,
  });

  final String uid;
  final FirebaseFirestore? database;

  /// Seçim dəyişəndə siyahı yenidən sıralansın deyə.
  final ValueChanged<Tonight?>? onChanged;

  FirebaseFirestore get db => database ?? FirebaseFirestore.instance;

  Future<void> _choose(BuildContext context, Tonight? current) async {
    final picked = await showModalBottomSheet<Tonight>(
      context: context,
      backgroundColor: const Color(0xff151020),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bu axşam nə istəyirsən?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Seçiminə uyğun adamlar siyahının başına keçəcək.',
                  style: TextStyle(color: vMuted, fontSize: 12.5),
                ),
              ),
            ),
            for (final item in Tonight.values)
              ListTile(
                leading: Text(item.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: item == current ? vPink : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  item.hint,
                  style: const TextStyle(color: vMuted, fontSize: 12),
                ),
                trailing: item == current
                    ? const Icon(Icons.check_circle_rounded, color: vPink)
                    : null,
                onTap: () => Navigator.pop(sheet, item),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null) return;

    // Eyni seçimə ikinci dəfə basmaq onu söndürür.
    final next = picked == current ? null : picked;

    try {
      await db.collection('users').doc(uid).set({
        'tonight': next == null
            ? FieldValue.delete()
            : {'intent': next.id, 'at': Timestamp.now()},
      }, SetOptions(merge: true));
    } catch (_) {}

    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final current = tonightOf(snap.data?.data()?['tonight']);

        return GestureDetector(
          onTap: () => _choose(context, current),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: current == null
                    ? [const Color(0xff241a44), const Color(0xff17122a)]
                    : [vPurple.withValues(alpha: .45), vPink.withValues(alpha: .3)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: current == null
                    ? vLine
                    : vPink.withValues(alpha: .55),
              ),
            ),
            child: Row(
              children: [
                Text(
                  current?.emoji ?? '🌙',
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current == null
                            ? 'Bu axşam nə istəyirsən?'
                            : current.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        current == null
                            ? 'Seç — sənə uyğun adamlar önə çıxsın'
                            : current.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: vMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  current == null
                      ? Icons.chevron_right_rounded
                      : Icons.edit_rounded,
                  color: vMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Başqasının kartındakı niyyət nişanı.
class TonightBadge extends StatelessWidget {
  const TonightBadge({super.key, required this.data, this.mine});

  /// Qarşı tərəfin profil sənədi.
  final Map<String, dynamic> data;

  /// Mənim niyyətim — uyğun gəlirsə nişan parlaq olur.
  final Tonight? mine;

  @override
  Widget build(BuildContext context) {
    final theirs = tonightOf(data['tonight']);
    if (theirs == null) return const SizedBox.shrink();

    final match = mine == null ? 0.0 : tonightMatch(mine!, theirs);
    final strong = match >= 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong
            ? vMint.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: strong ? vMint.withValues(alpha: .6) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(theirs.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            strong ? 'Sənə uyğun' : theirs.label,
            style: TextStyle(
              color: strong ? vMint : Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
