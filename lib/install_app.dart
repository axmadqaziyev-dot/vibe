import 'dart:async';

import 'package:flutter/material.dart';

import 'install_app_stub.dart'
    if (dart.library.js_interop) 'install_app_web.dart' as platform;

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// Veb versiyanı telefonun ana ekranına "əsl tətbiq" kimi quraşdırmaq.
///
/// Mağaza hesabı olmadan istifadəçi VIBE loqolu ikon alır və tətbiq
/// brauzer zolağı olmadan tam ekranda açılır.
bool get canInstallApp => platform.canInstallApp();

bool get isRunningStandalone => platform.isRunningStandalone();

bool get isIosBrowser => platform.isIosBrowser();

void promptInstallApp() => platform.promptInstallApp();

/// Serverə yeni versiya yayımlanıbmı?
bool get isUpdateReady => platform.isUpdateReady();

/// Yeni versiyanı yükləyir.
void reloadApp() => platform.reloadApp();

/// HTML açılış ekranını gizlədir (yalnız veb).
void hideStartupSplash() => platform.hideStartupSplash();

/// Quraşdırma lazımdırmı? (brauzerdədir və hələ quraşdırılmayıb)
bool get shouldOfferInstall =>
    !isRunningStandalone && (canInstallApp || isIosBrowser);

/// iOS Safari `beforeinstallprompt` hadisəsini dəstəkləmir —
/// orada addımları özümüz izah edirik.
Future<void> showIosInstallHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: vPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(t('VIBE-ı ana ekrana əlavə et'),
          style: TextStyle(color: vInk, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. Aşağıdakı «Paylaş» düyməsinə toxun',
              style: TextStyle(color: vMuted, height: 1.6)),
          Text('2. «Ana ekrana əlavə et» seç',
              style: TextStyle(color: vMuted, height: 1.6)),
          Text('3. «Əlavə et» düyməsini bas',
              style: TextStyle(color: vMuted, height: 1.6)),
          SizedBox(height: 10),
          Text(t('VIBE ikonu telefonunda görünəcək və tam ekranda açılacaq.'),
              style: TextStyle(color: vInk, fontSize: 13, height: 1.5)),
        ],
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

/// Quraşdırma düyməsi — quraşdırma mümkün deyilsə heç nə göstərmir.
///
/// Brauzerin `beforeinstallprompt` hadisəsi səhifə çəkiləndən sonra da
/// gələ bilər, ona görə qısa müddət ərzində vəziyyəti yoxlayırıq.
class InstallAppButton extends StatefulWidget {
  const InstallAppButton({super.key, this.compact = false});

  final bool compact;

  @override
  State<InstallAppButton> createState() => _InstallAppButtonState();
}

class _InstallAppButtonState extends State<InstallAppButton> {
  Timer? poll;
  bool available = shouldOfferInstall;

  @override
  void initState() {
    super.initState();
    if (available) return;

    var tries = 0;
    poll = Timer.periodic(const Duration(seconds: 1), (timer) {
      tries++;
      final now = shouldOfferInstall;
      if (now || tries >= 20) timer.cancel();
      if (now && mounted) setState(() => available = true);
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!available) return const SizedBox.shrink();
    final compact = widget.compact;

    void run() {
      if (isIosBrowser && !canInstallApp) {
        showIosInstallHelp(context);
      } else {
        promptInstallApp();
      }
    }

    if (compact) {
      return TextButton.icon(
        onPressed: run,
        icon: const Icon(Icons.install_mobile_rounded, color: vPink, size: 18),
        label: const Text(
          'Tətbiqi quraşdır',
          style: TextStyle(color: vPink, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vLine),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: vBrand,
            ),
            child: const Icon(Icons.install_mobile_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIBE-ı telefonuna qur',
                  style: TextStyle(
                    color: vInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ana ekranda ikon, tam ekran görünüş',
                  style: TextStyle(color: vMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: run,
            child: const Text(
              'Qur',
              style: TextStyle(color: vPink, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}


/// Yeni versiya yayımlananda görünən zolaq.
///
/// Veb versiyada istifadəçi tətbiqi bağlamadan da yeniliyi ala bilir:
/// zolaq çıxır, "Yenilə" düyməsi səhifəni yeni versiya ilə açır.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  Timer? poll;
  bool ready = false;
  bool hidden = false;

  @override
  void initState() {
    super.initState();
    poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final now = isUpdateReady;
      if (now != ready && mounted) setState(() => ready = now);
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready || hidden) return const SizedBox.shrink();

    return Material(
      color: const Color(0xff17103a),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: vPink, size: 19),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'VIBE-ın yeni versiyası hazırdır.',
                  style: TextStyle(color: vInk, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: reloadApp,
                child: const Text(
                  'Yenilə',
                  style: TextStyle(
                    color: vPink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sonra',
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
