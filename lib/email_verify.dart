import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// E-poçtu təsdiqlənməmiş istifadəçiyə göstərilən zolaq.
///
/// Girişi bloklamır — yalnız xatırladır və linki yenidən göndərməyə imkan verir.
/// Yalnız e-poçt/şifrə ilə açılmış hesablarda görünür; Google və Apple
/// hesablarının e-poçtu onsuz da təsdiqlidir.
class EmailVerifyBanner extends StatefulWidget {
  const EmailVerifyBanner({super.key, this.auth});

  final FirebaseAuth? auth;

  @override
  State<EmailVerifyBanner> createState() => _EmailVerifyBannerState();
}

class _EmailVerifyBannerState extends State<EmailVerifyBanner> {
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;

  bool hidden = false;
  bool sending = false;
  DateTime? sentAt;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    // Başqa cihazda təsdiqləyə bilər — arada bir yoxlayırıq.
    poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.reload();
      if (mounted) setState(() {});
    } catch (_) {
      // Şəbəkə yoxdursa növbəti dəfə yenidən cəhd edilir.
    }
  }

  bool get _needsVerification {
    final user = _auth.currentUser;
    if (user == null || hidden) return false;
    final email = user.email;
    if (email == null || email.isEmpty || user.emailVerified) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _resend() async {
    final user = _auth.currentUser;
    if (user == null || sending) return;

    // Firebase qısa müddətdə təkrar göndərməyə icazə vermir.
    final last = sentAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 60) {
      _say('Bir dəqiqə gözlə, link artıq göndərilib.');
      return;
    }

    setState(() => sending = true);
    try {
      await user.sendEmailVerification();
      sentAt = DateTime.now();
      _say('Təsdiq linki ${user.email} ünvanına göndərildi.');
    } on FirebaseAuthException catch (e) {
      _say(e.code == 'too-many-requests'
          ? 'Çox cəhd oldu. Bir az sonra yenidən yoxla.'
          : 'Göndərmək alınmadı: ${e.message}');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsVerification) return const SizedBox.shrink();

    // SafeArea yalnız zolaq görünəndə tətbiq olunur — gizli halda
    // səhifələrin yuxarı boşluğunu dəyişməməlidir.
    return Material(
      color: const Color(0xff2a1d10),
      child: SafeArea(
        bottom: false,
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: const BoxDecoration(
          color: Color(0xff2a1d10),
          border: Border(bottom: BorderSide(color: Color(0xff5a3c14))),
        ),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_rounded,
                color: vGold, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'E-poçtunu təsdiqlə — hesabını qorumağa kömək edir.',
                style: TextStyle(color: vInk, fontSize: 13, height: 1.3),
              ),
            ),
            TextButton(
              onPressed: sending ? null : _resend,
              child: Text(
                sending ? 'Göndərilir…' : 'Göndər',
                style: const TextStyle(
                  color: vGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              tooltip: t('Bağla'),
              onPressed: () => setState(() => hidden = true),
              icon: const Icon(Icons.close_rounded, color: vMuted, size: 18),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
