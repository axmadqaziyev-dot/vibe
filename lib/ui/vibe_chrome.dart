// VIBE app chrome — dizayn maketindəki ortaq elementlər:
// üst panel, tablar, filtr pilləri, foto, alt naviqasiya.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/i18n.dart';
import 'vibe_design.dart';

// ============================================================
// LOGO VƏ ÜST PANEL
// ============================================================

class VibeLogo extends StatelessWidget {
  const VibeLogo({super.key, this.size = 27});

  final double size;

  @override
  Widget build(BuildContext context) => GradientText(
    'VIBE',
    gradient: const LinearGradient(colors: [vPink, vPurple, vBlue]),
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.2,
      fontStyle: FontStyle.italic,
    ),
  );
}

/// Ana səhifə / Anlar ekranlarının üst paneli.
class VibeTopBar extends StatelessWidget {
  const VibeTopBar({super.key, this.actions = const [], this.leading});

  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 12, 6),
    child: Row(
      children: [
        leading ?? const VibeLogo(),
        const Spacer(),
        ...actions,
      ],
    ),
  );
}

/// Üst paneldəki dəyirmi ikon düyməsi.
class TopIconButton extends StatelessWidget {
  const TopIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color = Colors.white,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final button = PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: color, size: 25),
            if (badge > 0)
              Positioned(
                right: -5,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xffff4d5e),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: vBg, width: 1.4),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Qızıl VIP tacı.
class VipCrown extends StatelessWidget {
  const VipCrown({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    child: const Padding(
      padding: EdgeInsets.all(8),
      child: Icon(Icons.workspace_premium_rounded, color: vGold, size: 26),
    ),
  );
}

// ============================================================
// TABLAR
// ============================================================

/// "Kəşf et · Yaxınlıq · Online · Popular" — altı xətli tablar.
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(18, 0, 18, 6),
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: padding,
      itemCount: labels.length,
      itemBuilder: (context, i) {
        final selected = i == index;
        return PressableScale(
          onTap: () => onChanged(i),
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    color: selected ? Colors.white : vMuted,
                    fontSize: selected ? 16 : 15,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: selected ? 26 : 0,
                  decoration: BoxDecoration(
                    color: vPink,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: selected
                        ? const [BoxShadow(color: Color(0xaaff2bd6), blurRadius: 9)]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// "Hamısı · Qızlar · Oğlanlar · Online" — dolu pillər.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: padding,
      itemCount: labels.length,
      itemBuilder: (context, i) {
        final selected = i == index;
        return Padding(
          padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
          child: PressableScale(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? vHot : null,
                color: selected ? null : const Color(0xff19132a),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: selected ? Colors.transparent : const Color(0xff2e2542),
                ),
                boxShadow: selected
                    ? [BoxShadow(color: vPink.withValues(alpha: .35), blurRadius: 14)]
                    : null,
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: selected ? Colors.white : vMuted,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ============================================================
// FOTO
// ============================================================

/// Həm şəbəkə linkini, həm də Firestore-da saxlanan `data:` URI-ni açır.
///
/// Firebase Storage Blaze planı tələb etdiyi üçün şəkillər Firestore-da
/// data URI kimi saxlanılır — bu funksiya hər iki formatı dəstəkləyir.
ImageProvider? vibeImageProvider(String value) {
  final url = value.trim();
  if (url.isEmpty) return null;

  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }

  return NetworkImage(url);
}

/// Şəbəkə və ya data URI şəkli; şəkil yoxdursa qradiyent + baş hərf göstərir.
class VibePhoto extends StatelessWidget {
  const VibePhoto({
    super.key,
    required this.url,
    required this.name,
    this.fit = BoxFit.cover,
    this.emoji = '',
  });

  final String url;
  final String name;
  final BoxFit fit;
  final String emoji;

  static const _palette = [
    [Color(0xff7b3cff), Color(0xffff2bd6)],
    [Color(0xff22a7ff), Color(0xff7b3cff)],
    [Color(0xffff5f6d), Color(0xffffc371)],
    [Color(0xff11998e), Color(0xff38ef7d)],
    [Color(0xfff857a6), Color(0xffff5858)],
    [Color(0xff4568dc), Color(0xffb06ab3)],
  ];

  Widget _fallback() {
    final seed = name.isEmpty ? 0 : name.codeUnitAt(0);
    final colors = _palette[seed % _palette.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              emoji.isNotEmpty
                  ? emoji
                  : (name.isEmpty
                        ? '?'
                        : String.fromCharCode(name.runes.first).toUpperCase()),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = vibeImageProvider(url);
    if (provider == null) return _fallback();

    return Image(
      image: provider,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => _fallback(),
      frameBuilder: (context, child, frame, wasSync) =>
          (frame != null || wasSync) ? child : const VibeShimmer(radius: 0),
    );
  }
}

// ============================================================
// KİÇİK NİŞANLAR
// ============================================================

/// 0 = bilinmir, 1 = qadın, 2 = kişi.
int genderCode(Map<String, dynamic> data) {
  final raw = '${data['gender'] ?? data['sex'] ?? ''}'.toLowerCase();
  if (raw.contains('qız') ||
      raw.contains('qiz') ||
      raw.contains('qadın') ||
      raw.contains('qadin') ||
      raw.contains('female') ||
      raw == 'f') {
    return 1;
  }
  if (raw.contains('oğlan') ||
      raw.contains('oglan') ||
      raw.contains('kişi') ||
      raw.contains('kisi') ||
      raw.contains('male') ||
      raw == 'm') {
    return 2;
  }
  return 0;
}

/// "♀ 22" formasında cinsiyyət + yaş nişanı.
class GenderAgeChip extends StatelessWidget {
  const GenderAgeChip({
    super.key,
    required this.gender,
    required this.age,
    this.fontSize = 10,
  });

  final int gender;
  final String age;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final female = gender == 1;
    final color = gender == 0
        ? const Color(0xff7a7391)
        : (female ? vPink : vBlue);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * .55, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gender == 0
                ? Icons.person_rounded
                : (female ? Icons.female_rounded : Icons.male_rounded),
            size: fontSize + 2,
            color: color,
          ),
          if (age.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              age,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Qızıl VIP etiketi.
class VipTag extends StatelessWidget {
  const VipTag({super.key, this.level = 1, this.fontSize = 10});

  final int level;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: fontSize * .6, vertical: 2),
    decoration: BoxDecoration(
      gradient: vSunset,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.workspace_premium_rounded, size: fontSize + 2, color: const Color(0xff4c2600)),
        const SizedBox(width: 2),
        Text(
          'VIP$level',
          style: TextStyle(
            color: const Color(0xff4c2600),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

/// Səviyyə nişanı.
class LevelTag extends StatelessWidget {
  const LevelTag({super.key, required this.level, this.fontSize = 10});

  final int level;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: fontSize * .6, vertical: 2),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xff48e08a), Color(0xff22a7ff)]),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bolt_rounded, size: fontSize + 2, color: Colors.white),
        Text(
          '$level',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

/// Ad + təsdiq nişanı.
class VerifiedName extends StatelessWidget {
  const VerifiedName({
    super.key,
    required this.name,
    this.verified = false,
    this.fontSize = 20,
    this.color = Colors.white,
  });

  final String name;
  final bool verified;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      if (verified) ...[
        const SizedBox(width: 5),
        Icon(Icons.verified_rounded, size: fontSize * .8, color: vBlue),
      ],
    ],
  );
}

/// Rəqəm + alt yazı (izləyici, bəyənmə…).
class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: vMuted, fontSize: 11.5),
        ),
      ],
    ),
  );
}

/// 1200 → "1.2K", 4800 → "4.8K"
String compactCount(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
  }
  return '$value';
}

// ============================================================
// MƏSAFƏ
// ============================================================

/// İki profil arasında real məsafə (km). Koordinat yoxdursa null.
double? distanceKm(Map<String, dynamic> a, Map<String, dynamic> b) {
  double? number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  final lat1 = number(a['lat'] ?? a['latitude']);
  final lon1 = number(a['lng'] ?? a['lon'] ?? a['longitude']);
  final lat2 = number(b['lat'] ?? b['latitude']);
  final lon2 = number(b['lng'] ?? b['lon'] ?? b['longitude']);

  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;

  const earth = 6371.0;
  double radians(double degree) => degree * math.pi / 180;

  final dLat = radians(lat2 - lat1);
  final dLon = radians(lon2 - lon1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  return earth * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Məsafə varsa "2.1km", yoxsa şəhər adı.
String placeLabel(Map<String, dynamic> me, Map<String, dynamic> other) {
  final km = distanceKm(me, other);
  if (km != null) {
    return km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(1)}km';
  }
  final city = '${other['city'] ?? ''}'.trim();
  if (city.isNotEmpty) return city;
  return '${other['country'] ?? ''}'.trim();
}

/// Kiçik yer nişanı: 📍 2.1km
class PlaceLabel extends StatelessWidget {
  const PlaceLabel({
    super.key,
    required this.text,
    this.fontSize = 10.5,
    this.color = vMuted,
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.place_rounded, size: fontSize + 2, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ALT NAVİQASİYA (5 tab + mərkəzi "+")
// ============================================================

class VibeNavItem {
  const VibeNavItem(this.icon, this.activeIcon, this.labelKey);

  final IconData icon;
  final IconData activeIcon;

  /// i18n açarı — etiket seçilmiş dildə göstərilir.
  final String labelKey;

  String get label => t(labelKey);
}

const vibeNavItems = <VibeNavItem>[
  VibeNavItem(Icons.home_outlined, Icons.home_rounded, 'nav.home'),
  VibeNavItem(Icons.explore_outlined, Icons.explore_rounded, 'nav.moments'),
  VibeNavItem(Icons.live_tv_outlined, Icons.live_tv_rounded, 'nav.rooms'),
  VibeNavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded,
      'nav.messages'),
  VibeNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'nav.me'),
];

/// Maketdəki alt panel: 2 tab · qaldırılmış "+" · 3 tab.
class VibeBottomNav extends StatelessWidget {
  const VibeBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onCreate,
    this.messageBadge = 0,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onCreate;
  final int messageBadge;

  Widget _item(int i) {
    final item = vibeNavItems[i];
    final selected = index == i;

    return Expanded(
      child: PressableScale(
        onTap: () => onChanged(i),
        scale: .9,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 24,
                    color: selected ? vPink : const Color(0xff8b8399),
                  ),
                  if (i == 3 && messageBadge > 0)
                    Positioned(
                      right: -7,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xffff4d5e),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xff0b0714), width: 1.4),
                        ),
                        child: Text(
                          messageBadge > 99 ? '99+' : '$messageBadge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: selected ? Colors.white : const Color(0xff8b8399),
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xff0b0714),
      border: Border(top: BorderSide(color: Color(0xff241a36))),
      boxShadow: [
        BoxShadow(color: Color(0x88000000), blurRadius: 24, offset: Offset(0, -6)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            _item(0),
            _item(1),
            SizedBox(
              width: 68,
              child: Center(
                child: PressableScale(
                  onTap: onCreate,
                  scale: .88,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [vPurple, vPink],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: vPink.withValues(alpha: .5),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            _item(2),
            _item(3),
            _item(4),
          ],
        ),
      ),
    ),
  );
}
