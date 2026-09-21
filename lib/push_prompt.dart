import 'package:flutter/material.dart';

import 'push_notifications.dart';
import 'ui/vibe_design.dart';

/// "Bildirişləri aç" kartı.
///
/// iPhone icazə pəncərəsini yalnız istifadəçi toxunanda açır — avtomatik
/// çağırış sakitcə rədd edilir. Ona görə soruşmaq düymədən keçir.
///
/// Kart yalnız hələ soruşulmayıbsa görünür; icazə verildikdə və ya
/// rədd edildikdə yox olur.
class PushPrompt extends StatefulWidget {
  const PushPrompt({super.key, required this.uid});

  final String uid;

  @override
  State<PushPrompt> createState() => _PushPromptState();
}

class _PushPromptState extends State<PushPrompt> {
  bool? status;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    webPushStatus().then((value) {
      if (mounted) setState(() => status = value);
    });
  }

  Future<void> _ask() async {
    setState(() => busy = true);

    final ok = await askWebPush(widget.uid);
    if (!mounted) return;

    setState(() {
      busy = false;
      status = ok ? true : false;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İcazə verilmədi. Telefonda tətbiq ana ekrana əlavə olunmalıdır.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // null = hələ soruşulmayıb. Qalan hallarda kart lazım deyil.
    if (status != null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            vPurple.withValues(alpha: .35),
            vPink.withValues(alpha: .22),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: vPink.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bildirişləri aç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Mesaj gələndə xəbərin olsun.',
                  style: TextStyle(color: vMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : _ask,
            child: Text(
              busy ? '…' : 'Aç',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
