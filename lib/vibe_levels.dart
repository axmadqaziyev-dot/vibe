import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'user_profile.dart';
import 'vip.dart';

/// VIP pilləsi və medallar səhifəsi.
class VibeLevelsPage extends StatelessWidget {
  const VibeLevelsPage({super.key, required this.profile, this.database});

  final UserProfile profile;
  final FirebaseFirestore? database;

  @override
  Widget build(BuildContext context) {
    final db = database ?? FirebaseFirestore.instance;
    final ref = db.collection('users').doc(profile.uid);

    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: vBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'VIP və medallar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final score = vipScore(data);
          final tier = tierForScore(score);
          final next = nextTier(score);
          final progress = tierProgress(score);
          final earned = earnedMedals(data).map((m) => m.id).toSet();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _tierCard(tier, next, score, progress),
              const SizedBox(height: 22),

              const Text(
                'PİLLƏLƏR',
                style: TextStyle(
                  color: vMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in vipTiers.where((t) => t.level > 0))
                _tierRow(item, score),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'MEDALLAR',
                    style: TextStyle(
                      color: vMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${earned.length} / ${allMedals.length}',
                    style: const TextStyle(color: vMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  for (final medal in allMedals)
                    MedalChip(medal: medal, earned: earned.contains(medal.id)),
                ],
              ),

              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Xal hədiyyə göndərəndə və alanda artır. '
                  'Pillə qalxdıqca nişanın, giriş effektin və kəşf lentindəki '
                  'yerin yaxşılaşır.',
                  style: TextStyle(color: vMuted, fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tierCard(VipTier tier, VipTier? next, int score, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tier.colors.first.withValues(alpha: .35),
            tier.colors.last.withValues(alpha: .18),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tier.color.withValues(alpha: .55)),
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: tier.colors),
              boxShadow: [
                BoxShadow(
                  color: tier.color.withValues(alpha: .5),
                  blurRadius: 24,
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            tier.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score xal',
            style: const TextStyle(color: vMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: .35),
              valueColor: AlwaysStoppedAnimation(tier.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Ən yüksək pillədəsən'
                : '${next.name} pilləsinə ${next.minScore - score} xal qalıb',
            style: const TextStyle(color: vInk, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final perk in tier.perks)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    perk,
                    style: const TextStyle(color: vInk, fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tierRow(VipTier tier, int score) {
    final reached = score >= tier.minScore;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reached ? tier.color.withValues(alpha: .6) : vLine,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: tier.colors),
            ),
            child: Icon(
              reached ? Icons.check_rounded : Icons.lock_outline_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  style: TextStyle(
                    color: reached ? Colors.white : vMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tier.perks.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: vMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            '${tier.minScore}',
            style: TextStyle(
              color: reached ? tier.color : vMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
