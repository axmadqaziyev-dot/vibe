import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// GÜNDƏLİK GİRİŞ MÜKAFATI.
///
/// Hər gün tətbiqə girənə sikkə verilir. Ardıcıl günlər artdıqca mükafat
/// böyüyür; bir gün buraxılsa, seriya birinci günə qayıdır.
///
/// Məntiq təmiz funksiyalardadır — Firebase-siz yoxlanıla bilir.

/// Yeddi günlük dövrənin mükafatları.
const List<int> dailyRewards = [20, 30, 40, 60, 80, 120, 200];

/// Seriyanın neçənci günüdür (1..7).
int dayInCycle(int streak) {
  if (streak <= 0) return 1;
  final position = (streak - 1) % dailyRewards.length;
  return position + 1;
}

/// Həmin seriya gününə düşən sikkə.
int rewardForStreak(int streak) => dailyRewards[dayInCycle(streak) - 1];

/// İki tarix eyni gündədirmi? (yerli vaxta görə)
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Bu gün mükafat alına bilərmi?
bool canClaimToday(DateTime? lastClaim, DateTime now) {
  if (lastClaim == null) return true;
  return !_sameDay(lastClaim, now);
}

/// Mükafat alındıqdan sonrakı seriya.
///
/// Dünən alıbsa seriya davam edir; daha əvvəl alıbsa yenidən 1-dən başlayır.
int nextStreak(DateTime? lastClaim, int currentStreak, DateTime now) {
  if (lastClaim == null) return 1;

  final yesterday = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));

  if (_sameDay(lastClaim, yesterday)) {
    return currentStreak <= 0 ? 1 : currentStreak + 1;
  }
  if (_sameDay(lastClaim, now)) {
    // Bu gün artıq alınıb — seriya dəyişmir.
    return currentStreak <= 0 ? 1 : currentStreak;
  }
  return 1;
}

/// Profil məlumatından son alma tarixini oxuyur.
DateTime? lastClaimFrom(Map<String, dynamic> data) {
  final raw = data['dailyClaimAt'];
  return raw is Timestamp ? raw.toDate() : null;
}

int streakFrom(Map<String, dynamic> data) =>
    int.tryParse('${data['dailyStreak'] ?? 0}') ?? 0;

/// Mükafatı verir və seriyanı yeniləyir.
///
/// Artıq alınıbsa `null` qaytarır — ikinci dəfə verilmir.
Future<int?> claimDailyReward({
  required String uid,
  FirebaseFirestore? database,
  DateTime? now,
}) async {
  final db = database ?? FirebaseFirestore.instance;
  final moment = now ?? DateTime.now();
  final ref = db.collection('users').doc(uid);

  final snapshot = await ref.get();
  final data = snapshot.data() ?? const <String, dynamic>{};

  if (!canClaimToday(lastClaimFrom(data), moment)) return null;

  final streak = nextStreak(lastClaimFrom(data), streakFrom(data), moment);
  final reward = rewardForStreak(streak);

  // Sikkə və "alındı" nişanı BİR yazıda gedir: əks halda aralarında
  // kəsilmə olsa, istifadəçi mükafatı iki dəfə ala bilərdi.
  await ref.set({
    'dailyClaimAt': Timestamp.fromDate(moment),
    'dailyStreak': streak,
    'coins': FieldValue.increment(reward),
  }, SetOptions(merge: true));

  // Tarixçə — uğursuz olsa da balans düzgün qalır.
  try {
    await ref.collection('wallet').add({
      'amount': reward,
      'reason': 'Gündəlik mükafat · $streak-ci gün',
      'at': FieldValue.serverTimestamp(),
    });
  } catch (_) {}

  return reward;
}

/// Gündəlik mükafat pəncərəsi.
class DailyRewardSheet extends StatefulWidget {
  const DailyRewardSheet({
    super.key,
    required this.uid,
    required this.streak,
    this.database,
  });

  final String uid;

  /// Alınacaq mükafatın seriya nömrəsi.
  final int streak;

  final FirebaseFirestore? database;

  @override
  State<DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends State<DailyRewardSheet> {
  bool busy = false;
  int? claimed;

  Future<void> _claim() async {
    if (busy) return;
    setState(() => busy = true);

    try {
      final reward = await claimDailyReward(
        uid: widget.uid,
        database: widget.database,
      );
      if (!mounted) return;

      if (reward == null) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        claimed = reward;
        busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mükafat alınmadı. Yenidən sına.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = dayInCycle(widget.streak);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff2a1a52), Color(0xff140d24)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xff6b4bb8))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: SafeArea(
        top: false,
        child: claimed == null ? _rewardList(today) : _congrats(),
      ),
    );
  }

  /// Yeddi günün şəbəkəsi.
  Widget _rewardList(int today) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: vLine,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text(
          'Gündəlik giriş mükafatı',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ardıcıl $today-ci gün · hər gün daha çox',
          style: const TextStyle(color: vMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),

        // Bugünkü gün — enli kart.
        _bigDay(today),
        const SizedBox(height: 10),

        // Qalan günlər — üç sütunda.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var day = 1; day <= dailyRewards.length; day++)
              if (day != today) _smallDay(day, today),
          ],
        ),

        const SizedBox(height: 18),
        GradientButton(
          label: busy ? 'Alınır…' : 'Mükafatı al',
          icon: Icons.card_giftcard_rounded,
          gradient: vBrand,
          height: 52,
          onPressed: busy ? null : _claim,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Sonra',
            style: TextStyle(color: vMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _bigDay(int day) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffffd458), Color(0xffff9f27)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$day. gün',
            style: const TextStyle(
              color: Color(0xff3a2a00),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _perk('🪙', '${dailyRewards[day - 1]} coin'),
              _perk('🎁', 'Hədiyyə fondu'),
              _perk('⚡', 'Seriya davam'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _perk(String emoji, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff3a2a00),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _smallDay(int day, int today) {
    final done = day < today;

    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 32 - 16) / 3,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: done ? .05 : .09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done ? vMint.withValues(alpha: .5) : Colors.white24,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$day. gün',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              done ? Icons.check_circle_rounded : Icons.monetization_on_rounded,
              size: 24,
              color: done ? vMint : vGold,
            ),
            const SizedBox(height: 4),
            Text(
              'x${dailyRewards[day - 1]}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mükafat alındıqdan sonrakı ekran.
  Widget _congrats() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: vLine,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text(
          'Təbriklər!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _prize('🪙', '$claimed coin', 'balansına düşdü')),
            const SizedBox(width: 10),
            Expanded(
              child: _prize(
                '⚡',
                '${widget.streak}. gün',
                'seriya davam edir',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _prize(
                '🎁',
                '${rewardForStreak(widget.streak + 1)} coin',
                'sabah səni gözləyir',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Sabah yenidən gəl — mükafat daha böyük olacaq.',
          textAlign: TextAlign.center,
          style: TextStyle(color: vMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: t('Bağla'),
          gradient: vBrand,
          height: 52,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _prize(String emoji, String title, String subtitle) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: vMuted, fontSize: 10.5),
            ),
          ],
        ),
      );
}
