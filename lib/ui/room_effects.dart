import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../gifts.dart';
import 'vibe_design.dart';

/// OTAQ EFFEKTLƏRİ — giriş animasiyası və hədiyyə partlayışı.
///
/// Rəqib tətbiqlərdə otağın "canlı" hissini məhz bunlar yaradır:
/// kimsə daxil olanda ekranı kəsib keçən lent, hədiyyə gedəndə isə
/// böyük animasiya. Effektlər növbə ilə oynayır — üst-üstə düşmür.
class RoomEffectOverlay extends StatefulWidget {
  const RoomEffectOverlay({
    super.key,
    required this.roomId,
    this.database,
  });

  final String roomId;
  final FirebaseFirestore? database;

  @override
  State<RoomEffectOverlay> createState() => _RoomEffectOverlayState();
}

/// Oynadılacaq bir effekt.
class _Effect {
  _Effect.entry({required this.name, required this.vip})
      : gift = '',
        from = '',
        to = '',
        quantity = 0,
        total = 0,
        isGift = false;

  _Effect.gift({
    required this.gift,
    required this.from,
    required this.to,
    required this.quantity,
    required this.total,
  })  : name = '',
        vip = false,
        isGift = true;

  final String name;
  final bool vip;

  final String gift;
  final String from;
  final String to;
  final int quantity;

  /// Hədiyyənin ümumi dəyəri — böyük hədiyyələr tam ekran oynayır.
  final int total;

  final bool isGift;

  /// Hədiyyənin ağırlığı — animasiya buna görə seçilir.
  ///
  /// Əvvəl yalnız "1000-dən çoxdur / azdır" fərqi var idi. Nəticədə
  /// 1000 sikkəlik hədiyyə ilə 5000 sikkəlik eyni görünürdü — bahalı
  /// hədiyyə almağın mənası qalmırdı.
  GiftTier get tier => tierForPrice(total);

  bool get isEpic => tier.fullScreen;
}

class _RoomEffectOverlayState extends State<RoomEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..addStatusListener(_onFinished);

  final List<_Effect> _queue = [];
  _Effect? _current;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _giftSub;

  /// Ekran açılanda köhnə hadisələr oynanmasın.
  final DateTime _since = DateTime.now();

  FirebaseFirestore get _db => widget.database ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _room =>
      _db.collection('partyRooms').doc(widget.roomId);

  @override
  void initState() {
    super.initState();

    _eventSub = _room
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final data = change.doc.data();
        if (data == null || !_isFresh(data['createdAt'])) continue;

        final type = '${data['type'] ?? ''}';
        if (type != 'enter' && type != 'vip_enter') continue;

        _enqueue(_Effect.entry(
          name: '${data['name'] ?? 'Qonaq'}',
          vip: type == 'vip_enter',
        ));
      }
    });

    _giftSub = _room
        .collection('gifts')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final data = change.doc.data();
        if (data == null || !_isFresh(data['createdAt'])) continue;

        _enqueue(_Effect.gift(
          gift: '${data['emoji'] ?? data['gift'] ?? '🎁'}',
          from: '${data['fromName'] ?? data['from'] ?? ''}',
          to: '${data['toName'] ?? data['to'] ?? ''}',
          quantity: (data['quantity'] as num?)?.toInt() ?? 1,
          total: (data['total'] as num?)?.toInt() ?? 0,
        ));
      }
    });
  }

  /// Hadisə ekran açılandan sonra baş veribmi?
  bool _isFresh(Object? createdAt) {
    if (createdAt is! Timestamp) return false;
    final at = createdAt.toDate();
    return at.isAfter(_since.subtract(const Duration(seconds: 2)));
  }

  void _enqueue(_Effect effect) {
    if (!mounted) return;
    _queue.add(effect);
    if (_current == null) _playNext();
  }

  void _playNext() {
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    final next = _queue.removeAt(0);
    setState(() => _current = next);

    _controller.duration = Duration(
      milliseconds: next.isGift ? next.tier.durationMs : 2600,
    );
    _controller.forward(from: 0);
  }

  void _onFinished(AnimationStatus status) {
    if (status == AnimationStatus.completed) _playNext();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _giftSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effect = _current;
    if (effect == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => effect.isGift
            ? (effect.isEpic
                ? _EpicGift(effect: effect, t: _controller.value)
                : _GiftBurst(effect: effect, t: _controller.value))
            : _EntryBanner(effect: effect, t: _controller.value),
      ),
    );
  }
}

/// Otağa daxil olma lenti — sağdan sola süzülür.
class _EntryBanner extends StatelessWidget {
  const _EntryBanner({required this.effect, required this.t});

  final _Effect effect;
  final double t;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // Sağdan girir, ortada dayanır, sonra sola çıxır.
    final double offset;
    if (t < .25) {
      offset = width * (1 - t / .25);
    } else if (t < .72) {
      offset = 0;
    } else {
      offset = -width * ((t - .72) / .28);
    }

    final colors = effect.vip
        ? const [Color(0xffffb347), Color(0xffff2bd6)]
        : const [Color(0xff22a7ff), Color(0xff8b5cff)];

    return Align(
      alignment: const Alignment(0, -.62),
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: .5),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sürətlə gələn iz.
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  effect.vip
                      ? Icons.workspace_premium_rounded
                      : Icons.bolt_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  effect.vip
                      ? '${effect.name} VIP olaraq daxil oldu'
                      : '${effect.name} otağa qoşuldu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hədiyyə animasiyası — böyüyən emoji, şüalar və ad lenti.
class _GiftBurst extends StatelessWidget {
  const _GiftBurst({required this.effect, required this.t});

  final _Effect effect;
  final double t;

  @override
  Widget build(BuildContext context) {
    // Böyüyür, bir az dayanır, sonra sönür.
    final scale = t < .22
        ? Curves.easeOutBack.transform(t / .22) * 1.0
        : (t < .75 ? 1.0 : 1 + (t - .75) * .8);
    final opacity = t < .75 ? 1.0 : (1 - (t - .75) / .25).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fırlanan şüalar.
          Transform.rotate(
            angle: t * math.pi,
            child: CustomPaint(
              size: const Size(300, 300),
              painter: _RayPainter(progress: t),
            ),
          ),

          Transform.scale(
            scale: scale.clamp(0.0, 2.0),
            child: Text(
              effect.gift.isEmpty ? '🎁' : effect.gift,
              style: const TextStyle(fontSize: 96),
            ),
          ),

          // Ad lenti.
          Align(
            alignment: const Alignment(0, .34),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: vGold.withValues(alpha: .6)),
              ),
              child: Text(
                [
                  if (effect.from.isNotEmpty) effect.from,
                  '→',
                  if (effect.to.isNotEmpty) effect.to,
                  if (effect.quantity > 1) '×${effect.quantity}',
                ].join(' '),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RayPainter extends CustomPainter {
  _RayPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final length = size.width * (.28 + progress * .22);

      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * (length * .45),
        center + Offset(math.cos(angle), math.sin(angle)) * length,
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = (i.isEven ? vGold : vPink).withValues(alpha: fade * .7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter old) => old.progress != progress;
}


/// Bahalı hədiyyə — ekranı bütöv tutan animasiya.
///
/// Şimşək yuxarıdan aşağı vurur, ekran işıqlanır, hədiyyə böyüyür.
/// Solda göndərənin lenti görünür.
class _EpicGift extends StatelessWidget {
  const _EpicGift({required this.effect, required this.t});

  final _Effect effect;
  final double t;

  @override
  Widget build(BuildContext context) {
    final tier = effect.tier;
    final color = Color(tier.color);

    // Sönmə mərhələsi.
    final fade = t < .85 ? 1.0 : (1 - (t - .85) / .15).clamp(0.0, 1.0);

    // Şimşək ilk yarıda enir.
    final strike = (t / .45).clamp(0.0, 1.0);

    // Hədiyyə şimşək düşəndən sonra çıxır.
    final reveal = t < .4 ? 0.0 : ((t - .4) / .25).clamp(0.0, 1.0);

    return Opacity(
      opacity: fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ekranı tündləşdirən pərdə. Əfsanəvi hədiyyədə daha tünd —
          // animasiya tam görünsün.
          ColoredBox(
            color: Colors.black.withValues(
              alpha: (tier == GiftTier.legendary ? .78 : .62) * fade,
            ),
          ),

          // Şimşək və işıq.
          CustomPaint(
            painter: _LightningPainter(progress: strike, flash: reveal),
          ),

          // Pillənin rəngində hissəciklər.
          CustomPaint(
            painter: _SparkPainter(
              progress: reveal,
              count: tier.particles,
              color: color,
            ),
          ),

          // Əfsanəvi hədiyyədə pillə adı yazılır.
          if (tier == GiftTier.legendary)
            Align(
              alignment: const Alignment(0, -.42),
              child: Opacity(
                opacity: reveal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    tier.label.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),

          // Hədiyyə.
          Center(
            child: Transform.scale(
              scale: (.4 + reveal * .85).clamp(0.0, 1.4),
              child: Opacity(
                opacity: reveal,
                child: Text(
                  effect.gift.isEmpty ? '🎁' : effect.gift,
                  style: const TextStyle(fontSize: 130),
                ),
              ),
            ),
          ),

          // Göndərənin lenti — soldan sürüşür.
          Align(
            alignment: const Alignment(-1, .12),
            child: Transform.translate(
              offset: Offset(-260 * (1 - reveal), 0),
              child: Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.fromLTRB(10, 7, 16, 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff2a1a52), Color(0xff6b2f9e)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: vGold.withValues(alpha: .8)),
                  boxShadow: [
                    BoxShadow(
                      color: vGold.withValues(alpha: .35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .18),
                      ),
                      child: Center(
                        child: Text(
                          effect.from.isEmpty
                              ? '?'
                              : effect.from.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        effect.from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '×${effect.quantity}',
                      style: const TextStyle(
                        color: vGold,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Alan və dəyər.
          Align(
            alignment: const Alignment(0, .34),
            child: Opacity(
              opacity: reveal,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: vGold.withValues(alpha: .6)),
                ),
                child: Text(
                  '${effect.to} · ${effect.total} coin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Şimşək və partlayış işığı.
class _LightningPainter extends CustomPainter {
  _LightningPainter({required this.progress, required this.flash});

  /// Şimşəyin enmə nisbəti (0..1).
  final double progress;

  /// Düşdükdən sonrakı işıq (0..1).
  final double flash;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final centerX = size.width * .5;
    final endY = size.height * .52;

    // Zigzag yol.
    final path = Path()..moveTo(centerX + 40, 0);
    final random = math.Random(7);
    var y = 0.0;
    var x = centerX + 40;

    while (y < endY * progress) {
      y += size.height * .06;
      x += (random.nextDouble() - .5) * 60;
      path.lineTo(x, math.min(y, endY * progress));
    }

    // Kənar parıltı.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffff8a3d).withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Əsas xətt.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .95),
    );

    // Düşdüyü nöqtədə işıq.
    if (flash > 0) {
      final center = Offset(centerX, endY);
      canvas.drawCircle(
        center,
        size.width * (.2 + flash * .5),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xffffb347).withValues(alpha: .55 * (1 - flash)),
              const Color(0x00000000),
            ],
          ).createShader(
            Rect.fromCircle(
              center: center,
              radius: size.width * (.2 + flash * .5),
            ),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightningPainter old) =>
      old.progress != progress || old.flash != flash;
}


/// Hədiyyə açılanda dağılan hissəciklər.
///
/// Hər hissəcik mərkəzdən kənara uçur. Sayı hədiyyənin pilləsindən
/// gəlir: adi hədiyyədə sıfırdır, əfsanəvidə ekran dolur.
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.progress,
    required this.count,
    required this.color,
  });

  final double progress;
  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0 || progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final reach = size.shortestSide * .62;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      // Sabit "təsadüfi" bucaq: hər çəkilişdə eyni olsun, yoxsa
      // hissəciklər titrəyərdi.
      final angle = i * 2.399963;
      final spread = .35 + ((i * 37) % 65) / 100;

      final distance = reach * spread * progress;
      final point = center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);

      paint.color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0) * .9);
      canvas.drawCircle(point, 3.2 * (1 - progress * .5), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.count != count;
}
