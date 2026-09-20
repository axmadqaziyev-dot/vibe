import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vibe_design.dart';
import 'welcome_scenes.dart';

/// Xoş gəldin ekranının canlı fonu.
///
/// Rəqib tətbiqlərdə burada fırlanan insan fotoları olur. Biz başqasının
/// şəklini icazəsiz göstərə bilmərik, ona görə fon tətbiqin öz
/// illüstrasiyasıdır: səhnə hər bir neçə saniyədən bir dəyişir, işıqlar
/// yavaş-yavaş hərəkət edir — ekran video kimi canlı görünür.
class VibeWelcomeBackdrop extends StatefulWidget {
  const VibeWelcomeBackdrop({super.key});

  @override
  State<VibeWelcomeBackdrop> createState() => _VibeWelcomeBackdropState();
}

/// Arxa fonda göstəriləcək şəkillər.
///
/// `assets/welcome/` qovluğuna şəkil atıb `pubspec.yaml`-da elan etsən,
/// ekran avtomatik onları növbə ilə göstərir (yavaş yaxınlaşma effekti ilə).
/// Siyahı boş olsa, tətbiqin öz illüstrasiyası göstərilir.
///
/// Qeyd: bura yalnız haqqı sənə məxsus olan və ya süni intellektlə
/// yaradılmış şəkillər qoyulmalıdır.
const List<String> welcomeImages = [
  // 'assets/welcome/1.jpg',
  // 'assets/welcome/2.jpg',
  // 'assets/welcome/3.jpg',
];

/// Hər səhnənin öz rəng ahəngi və şüarı var.
class WelcomeScene {
  const WelcomeScene({
    required this.top,
    required this.bottom,
    required this.accent,
  });

  final Color top;
  final Color bottom;
  final Color accent;
}

const List<WelcomeScene> welcomeScenes = [
  WelcomeScene(
    top: Color(0xff2b1560),
    bottom: Color(0xff0a0618),
    accent: Color(0xff8b5cff),
  ),
  WelcomeScene(
    top: Color(0xff4a1150),
    bottom: Color(0xff0c0518),
    accent: Color(0xffff2bd6),
  ),
  WelcomeScene(
    top: Color(0xff0f2a5c),
    bottom: Color(0xff070a1a),
    accent: Color(0xff22a7ff),
  ),
];

class _VibeWelcomeBackdropState extends State<VibeWelcomeBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  int index = 0;

  @override
  void initState() {
    super.initState();
    _drift.addListener(_maybeAdvance);
  }

  /// Səhnə hər 6 saniyədən bir dəyişir — ayrıca timer saxlamırıq.
  void _maybeAdvance() {
    final next = ((_drift.value * 4).floor()) % welcomeScenes.length;
    if (next != index && mounted) setState(() => index = next);
  }

  @override
  void dispose() {
    _drift.removeListener(_maybeAdvance);
    _drift.dispose();
    super.dispose();
  }

  /// Şəkil varsa onu, yoxsa çəkilmiş səhnələri göstərir.
  Widget _scenery() {
    if (welcomeImages.isEmpty) {
      // Üç səhnə növbə ilə dəyişir: oxuyan, söhbət edən, məclis.
      return AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final zoom = 1 + math.sin(_drift.value * 2 * math.pi) * .04;
          return Transform.scale(
            scale: zoom,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: Align(
                key: ValueKey(index),
                alignment: const Alignment(0, -.22),
                child: FractionallySizedBox(
                  heightFactor: .62,
                  widthFactor: .92,
                  child: WelcomeSceneArt(
                    scene: index,
                    time: _drift.value,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Şəkillər növbə ilə dəyişir, hər biri yavaş-yavaş yaxınlaşır.
    final image = welcomeImages[index % welcomeImages.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1200),
      child: AnimatedBuilder(
        key: ValueKey(image),
        animation: _drift,
        builder: (context, child) {
          final zoom = 1.06 + math.sin(_drift.value * 2 * math.pi) * .05;
          return Transform.scale(scale: zoom, child: child);
        },
        child: Image.asset(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = welcomeScenes[index];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Rəng ahəngi yumşaq keçidlə dəyişir.
        AnimatedContainer(
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scene.top, scene.bottom],
            ),
          ),
        ),

        // Yavaş hərəkət edən işıq ləkələri.
        AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            final t = _drift.value * 2 * math.pi;
            return Stack(
              children: [
                _blob(
                  color: scene.accent,
                  dx: math.sin(t) * 40 - 60,
                  dy: math.cos(t * .8) * 30 + 60,
                  size: 300,
                  opacity: .34,
                ),
                _blob(
                  color: vPink,
                  dx: math.cos(t * .7) * 50 + 140,
                  dy: math.sin(t * .9) * 40 + 320,
                  size: 260,
                  opacity: .24,
                ),
              ],
            );
          },
        ),

        // Səhnə: şəkil və ya illüstrasiya, yavaş yaxınlaşma ilə.
        _scenery(),

        // Aşağıda mətn və düymələr oxunaqlı olsun deyə tündləşdirmə.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xe60a0618)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _blob({
    required Color color,
    required double dx,
    required double dy,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      left: dx,
      top: dy,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Giriş ekranındakı böyük ağ düymə (Apple / Google üslubu).
class WelcomeAuthButton extends StatelessWidget {
  const WelcomeAuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  /// "Son giriş" kimi kiçik nişan.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 14),
              SizedBox(width: 34, height: 34, child: Center(child: icon)),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff1f1f1f),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );

    if (badge == null) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 14,
          top: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: vRose,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Alt sıradakı kiçik dəyirmi düymələr.
class WelcomeMiniButton extends StatelessWidget {
  const WelcomeMiniButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .12),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
