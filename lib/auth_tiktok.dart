import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// TIKTOK İLƏ GİRİŞ.
///
/// Firebase-in hazır provayderləri arasında TikTok yoxdur. İşləməsi üçün:
///
///  1. https://developers.tiktok.com — tətbiq yarat, **Login Kit** əlavə et;
///  2. Client key və client secret al (TikTok tətbiqi təsdiqləməlidir);
///  3. Supabase Edge Function yaz: TikTok kodunu access token-ə, sonra
///     Firebase **custom token**-ə çevirsin (Admin SDK ilə);
///  4. Alınan ünvanı [tiktokExchangeUrl]-a, client key-i
///     [tiktokClientKey]-ə yaz.
///
/// Açarlar boş olduqda düymə görünür, amma toxunanda istifadəçiyə
/// hazır olmadığı aydın deyilir — səssiz xəta olmur.
const String tiktokClientKey = '';
const String tiktokExchangeUrl = '';

/// TikTok girişi qurulubmu?
bool get tiktokReady =>
    tiktokClientKey.isNotEmpty && tiktokExchangeUrl.isNotEmpty;

/// Hazır olmayanda göstərilən izah.
void showTiktokNotReady(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: vPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'TikTok girişi hazırlanır',
        style: TextStyle(color: vInk, fontSize: 18),
      ),
      content: const Text(
        'TikTok ilə giriş üçün TikTok Developers-də tətbiqin təsdiqi lazımdır. '
        'Təsdiq alınan kimi bu düymə işləyəcək.\n\n'
        'Hələlik Apple, Google, nömrə və ya e-poçt ilə davam edə bilərsən.',
        style: TextStyle(color: vMuted, fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(t('Anladım'), style: TextStyle(color: vPink)),
        ),
      ],
    ),
  );
}

/// TikTok loqosunun sadələşdirilmiş forması (giriş düyməsi üçün).
class TiktokMark extends StatelessWidget {
  const TiktokMark({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TiktokNotePainter()),
    );
  }
}

class _TiktokNotePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Not işarəsi üç dəfə çəkilir: firuzəyi və çəhrayı kölgələr, üstdə ağ.
    void note(Offset shift, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .13
        ..strokeCap = StrokeCap.round;

      final w = size.width;
      final h = size.height;

      // Gövdə və qarmaq.
      final path = Path()
        ..moveTo(w * .46 + shift.dx, h * .70 + shift.dy)
        ..lineTo(w * .46 + shift.dx, h * .18 + shift.dy)
        ..quadraticBezierTo(
          w * .60 + shift.dx,
          h * .34 + shift.dy,
          w * .80 + shift.dx,
          h * .34 + shift.dy,
        );
      canvas.drawPath(path, paint);

      // Baş hissə — dolu dairə.
      canvas.drawCircle(
        Offset(w * .34 + shift.dx, h * .70 + shift.dy),
        w * .16,
        Paint()..color = color,
      );
    }

    note(Offset(-size.width * .05, size.height * .04), const Color(0xff25f4ee));
    note(Offset(size.width * .05, -size.height * .02), const Color(0xfffe2c55));
    note(Offset.zero, Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
