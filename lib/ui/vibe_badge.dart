/// Adın yanındakı nişanlar.
///
/// Səviyyə və VIP pilləsi yalnız profildə qalsa, mənası olmazdı.
/// Onların işi otaqda, söhbətdə, lentdə — hər yerdə görünməkdir:
/// status göründüyü üçün dəyərlidir.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../vibe_level.dart';

/// Hazır məlumatla nişan cütü.
class VibeBadgeRow extends StatelessWidget {
  const VibeBadgeRow({
    super.key,
    required this.badges,
    this.compact = false,
  });

  final VibeBadges badges;

  /// Dar yerdə yalnız VIP göstərilir.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (!compact || !badges.hasVip) {
      items.add(_Pill(
        text: 'Lv ${badges.level}',
        color: Color(levelColor(badges.level)),
      ));
    }

    if (badges.hasVip) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 4));
      items.add(_Pill(
        text: badges.vipText,
        color: Color(vipColor(badges.vip)),
        strong: true,
      ));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

/// İstifadəçi sənədini özü oxuyan nişan.
///
/// Sənəd yaddaşda saxlanılır: otaqda iyirmi ad varsa, hər biri üçün
/// ayrıca sorğu getsəydi siyahı yavaşlayardı.
class VibeBadgeFor extends StatefulWidget {
  const VibeBadgeFor({
    super.key,
    required this.uid,
    this.compact = false,
    this.database,
  });

  final String uid;
  final bool compact;
  final FirebaseFirestore? database;

  @override
  State<VibeBadgeFor> createState() => _VibeBadgeForState();
}

class _VibeBadgeForState extends State<VibeBadgeFor> {
  /// Bu açılışda oxunmuş sənədlər.
  static final _cache = <String, VibeBadges>{};

  VibeBadges? badges;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.uid.isEmpty) return;

    final cached = _cache[widget.uid];
    if (cached != null) {
      setState(() => badges = cached);
      return;
    }

    try {
      final snap = await (widget.database ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(widget.uid)
          .get();

      final value = VibeBadges.from(snap.data());
      _cache[widget.uid] = value;

      if (mounted) setState(() => badges = value);
    } catch (_) {
      // Nişan gəlməsə ad onsuz da görünür.
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = badges;
    if (value == null) return const SizedBox.shrink();

    return VibeBadgeRow(badges: value, compact: widget.compact);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    this.strong = false,
  });

  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: strong ? .9 : .22),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: .7), width: .8),
          boxShadow: strong
              ? [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 8)]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: strong ? Colors.white : color,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
      );
}
