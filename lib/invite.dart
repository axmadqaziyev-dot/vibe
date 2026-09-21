import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/vibe_design.dart';
import 'app/i18n.dart';

/// Dostları VIBE-a dəvət etmək.
///
/// Tətbiq yeni olduğu üçün ən böyük problem boş ekranlardır — dəvət linki
/// istifadəçiyə bunu özü həll etmək imkanı verir. Əlavə paket tələb etmir:
/// link lövhəyə kopyalanır, istifadəçi istədiyi yerə yapışdırır.
const String vibeWebUrl = 'https://vibe-f9d13.web.app';

String inviteLink({String? referrerUid}) =>
    referrerUid == null || referrerUid.isEmpty
        ? vibeWebUrl
        : '$vibeWebUrl/?ref=$referrerUid';

String inviteMessage({required String name, String? referrerUid}) =>
    '$name səni VIBE-a dəvət edir 💜\n'
    'Səsli otaqlar, oyunlar və yeni dostlar — hamısı bir yerdə.\n'
    '${inviteLink(referrerUid: referrerUid)}';

Future<void> showInviteSheet(
  BuildContext context, {
  required String name,
  String? referrerUid,
}) {
  final text = inviteMessage(name: name, referrerUid: referrerUid);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => Container(
      decoration: const BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: vLine)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: vLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Dostlarını dəvət et',
              style: TextStyle(
                color: vInk,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Linki kopyala və istədiyin yerə — WhatsApp, Instagram, '
              'Telegram — yapışdır.',
              style: TextStyle(color: vMuted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: vBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: vLine),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: vInk,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: t('Mətni kopyala'),
              icon: Icons.copy_rounded,
              gradient: vBrand,
              height: 50,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: text));
                if (sheet.mounted) Navigator.pop(sheet);
                messenger.showSnackBar(
                  SnackBar(content: Text(t('Dəvət mətni kopyalandı 💜'))),
                );
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(text: inviteLink(referrerUid: referrerUid)),
                  );
                  if (sheet.mounted) Navigator.pop(sheet);
                  messenger.showSnackBar(
                    SnackBar(content: Text(t('Link kopyalandı'))),
                  );
                },
                child: const Text(
                  'Yalnız linki kopyala',
                  style: TextStyle(color: vMuted, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Boş ekranlarda göstərilən dəvət kartı.
class InviteCard extends StatelessWidget {
  const InviteCard({
    super.key,
    required this.name,
    this.referrerUid,
    this.title = 'Hələ sakitdir',
    this.subtitle = 'Dostlarını çağır — VIBE onlarla daha əyləncəlidir.',
  });

  final String name;
  final String? referrerUid;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vLine),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: vHot,
            ),
            child: const Icon(Icons.group_add_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: vInk,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: vMuted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: t('Dostlarını dəvət et'),
            icon: Icons.ios_share_rounded,
            expand: false,
            gradient: vBrand,
            onPressed: () => showInviteSheet(
              context,
              name: name,
              referrerUid: referrerUid,
            ),
          ),
        ],
      ),
    );
  }
}
