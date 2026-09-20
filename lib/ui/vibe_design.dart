// VIBE design system.
// Bütün ekranlar üçün ortaq rəng, jest və animasiya elementləri.
// Heç bir əlavə paketdən asılı deyil.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// TOKENS
// ============================================================

const vPink = Color(0xffff2bd6);
const vPurple = Color(0xff8b5cff);
const vBlue = Color(0xff22a7ff);
const vMint = Color(0xff2de28a);
const vGold = Color(0xffffd458);
const vRose = Color(0xffff657b);

const vBg = Color(0xff070510);
const vPanel = Color(0xff141020);
const vPanelHigh = Color(0xff1b1528);
const vLine = Color(0xff2d2540);
const vInk = Color(0xfff7f3ff);
const vMuted = Color(0xffa89fbd);

const vBrand = LinearGradient(colors: [vBlue, vPurple, vPink]);
const vHot = LinearGradient(colors: [Color(0xff7b3cff), vPink]);
const vSunset = LinearGradient(colors: [Color(0xffffd458), Color(0xffff8a3d)]);

/// Kartlar üçün standart künc radiusu.
const vRadius = 24.0;

// ============================================================
// AURORA — canlı arxa fon
// ============================================================

/// Yavaş hərəkət edən neon ləkələr. Əsas səhifələrin fonu.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child, this.strength = 1});

  final Widget child;

  /// 0 = sönük, 1 = normal, 1.5 = daha parlaq.
  final double strength;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _blob(Alignment alignment, Color color, double size) => Align(
    alignment: alignment,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: .26 * widget.strength),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff160b29), Color(0xff0a0614), Color(0xff05040b)],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final t = controller.value * 2 * math.pi;
                return Stack(
                  children: [
                    _blob(
                      Alignment(-.45 + math.sin(t) * .45, -.95 + math.cos(t) * .12),
                      vPink,
                      330,
                    ),
                    _blob(
                      Alignment(.8 + math.cos(t * .8) * .22, -.3 + math.sin(t * .8) * .25),
                      vPurple,
                      300,
                    ),
                    _blob(
                      Alignment(-.7 + math.sin(t * .65) * .35, .8),
                      vBlue,
                      290,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

// ============================================================
// JEST — basanda kiçilən + titrəyən sarğı
// ============================================================

/// Toxunanda kiçilir və yüngül haptik verir.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool down = false;

  void _set(bool value) {
    if (mounted && down != value) setState(() => down = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapCancel: widget.onTap == null ? null : () => _set(false),
    onTapUp: widget.onTap == null
        ? null
        : (_) {
            _set(false);
            if (widget.haptic) HapticFeedback.selectionClick();
            widget.onTap!.call();
          },
    onLongPress: widget.onLongPress == null
        ? null
        : () {
            if (widget.haptic) HapticFeedback.mediumImpact();
            widget.onLongPress!.call();
          },
    child: AnimatedScale(
      scale: down ? widget.scale : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

// ============================================================
// SƏTHLƏR
// ============================================================

/// Şüşə effektli kart: yarımşəffaf fon + işıqlı kənar.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.radius = vRadius,
    this.glow,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final Color? glow;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: vPanel.withValues(alpha: .66),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? Colors.white.withValues(alpha: .09)),
      boxShadow: [
        BoxShadow(
          color: (glow ?? Colors.black).withValues(alpha: glow == null ? .35 : .22),
          blurRadius: glow == null ? 18 : 26,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

/// Qradiyent rəngli mətn.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = vBrand,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (rect) => gradient.createShader(rect),
    child: Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: style.copyWith(color: Colors.white),
    ),
  );
}

/// Qradiyent doldurulmuş düymə.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient = vHot,
    this.height = 48,
    this.expand = true,
    this.fontSize = 15,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final double height;
  final bool expand;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final content = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // `alignment` verilsə, Container boş yeri doldurur —
      // ona görə yalnız tam enli düymədə istifadə olunur.
      alignment: expand ? Alignment.center : null,
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled ? const Color(0xff2a2238) : null,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: gradient.colors.last.withValues(alpha: .38),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 3, color: disabled ? vMuted : Colors.white),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: disabled ? vMuted : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );

    return PressableScale(
      onTap: onPressed,
      child: expand ? SizedBox(width: double.infinity, child: content) : content,
    );
  }
}

/// Seçilə bilən kiçik çip.
class VibeChip extends StatelessWidget {
  const VibeChip({
    super.key,
    required this.label,
    this.emoji = '',
    this.selected = false,
    this.onTap,
    this.color = vPurple,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: .26)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : Colors.white.withValues(alpha: .10),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 14)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji.isNotEmpty) ...[
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : vMuted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bölmə başlığı + sağda kiçik məlumat/düymə.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.onTrailingTap,
    this.icon,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19, color: vPink),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -.3,
            ),
          ),
        ),
        if (trailing != null)
          PressableScale(
            onTap: onTrailingTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                trailing!,
                style: const TextStyle(
                  color: vPink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ============================================================
// SKELETON — yüklənmə animasiyası
// ============================================================

/// Məzmun gəlməmişdən əvvəl göstərilən parıldayan boşluq.
class VibeShimmer extends StatefulWidget {
  const VibeShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 12,
    this.shape = BoxShape.rectangle,
  });

  final double width, height, radius;
  final BoxShape shape;

  @override
  State<VibeShimmer> createState() => _VibeShimmerState();
}

class _VibeShimmerState extends State<VibeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final shift = controller.value * 2 - 1;
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          shape: widget.shape,
          borderRadius: widget.shape == BoxShape.circle
              ? null
              : BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(shift - 1, 0),
            end: Alignment(shift + 1, 0),
            colors: const [
              Color(0xff171126),
              Color(0xff2a2140),
              Color(0xff171126),
            ],
          ),
        ),
      );
    },
  );
}

/// Profil kartları üçün hazır skelet şəbəkəsi.
class VibeCardSkeleton extends StatelessWidget {
  const VibeCardSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 620 ? 3 : 2);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns >= 3 ? .74 : .66,
        ),
        // Foto kartın yerini tutan tək parıltı — hər ölçüdə daşmır.
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const VibeShimmer(radius: 0),
              Positioned(
                left: 9,
                right: 9,
                bottom: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 9,
                      width: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 7,
                      width: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================
// UÇAN EMOJİ — ikiqat toxunuş reaksiyası
// ============================================================

/// Ekranda verilmiş nöqtədən yuxarı uçan emoji göstərir.
void showFloatingEmoji(BuildContext context, Offset position, String emoji) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 900),
  );

  final entry = OverlayEntry(
    builder: (context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Positioned(
          left: position.dx - 22,
          top: position.dy - 22 - 90 * Curves.easeOut.transform(t),
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: .6 + 1.1 * Curves.elasticOut.transform(t),
                child: Text(emoji, style: const TextStyle(fontSize: 38)),
              ),
            ),
          ),
        );
      },
    ),
  );

  overlay.insert(entry);
  HapticFeedback.lightImpact();
  controller.forward().whenComplete(() {
    entry.remove();
    controller.dispose();
  });
}
