// VIBE MODERASİYA PANELİ.
//
// App Store Guideline 1.2 uyğunsuz məzmuna 24 saat ərzində reaksiya tələb edir.
// Burada admin şikayəti görür, profilə baxır və hesabı dayandıra bilir.
//
// Dayandırılmış hesab tətbiqə girə bilmir (bax: AuthGate → SuspendedPage).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ui/vibe_design.dart';
import 'ui/vibe_chrome.dart';
import 'app/i18n.dart';

class VibeAdminPanel extends StatefulWidget {
  const VibeAdminPanel({super.key});

  @override
  State<VibeAdminPanel> createState() => _VibeAdminPanelState();
}

class _VibeAdminPanelState extends State<VibeAdminPanel> {
  static const tabs = ['Yeni', 'Baxılıb', 'Dayandırılmış'];

  int tab = 0;

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status, {
    String? note,
  }) async {
    await ref.update({
      'status': status,
      if (note != null) 'moderatorNote': note,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hesabı dayandırır — istifadəçi girişdə bloklanır.
  Future<void> _suspend(String uid, String name, String reason) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: const Color(0xff151020),
        title: Text(
          '$name dayandırılsın?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'İstifadəçi tətbiqə girə bilməyəcək. Qərarı sonradan geri ala bilərsən.',
          style: TextStyle(color: vMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('İmtina'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: vRose),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t('Dayandır')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'suspended': true,
        'suspendedReason': reason,
        'suspendedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name dayandırıldı.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('Əməliyyat alınmadı.'))),
        );
      }
    }
  }

  Future<void> _unsuspend(String uid, String name) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'suspended': false,
        'suspendedReason': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name yenidən aktivdir.')),
        );
      }
    } catch (_) {}
  }

  /// Şikayət edilən istifadəçinin son paylaşımlarını göstərir və silməyə imkan verir.
  void _openContent(String uid, String name) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff120d1d),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheet).size.height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name — paylaşımlar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('moments')
                      .where('ownerUid', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: vPink),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Paylaşım yoxdur.',
                          style: TextStyle(color: vMuted),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        return Card(
                          color: const Color(0xff1a1329),
                          child: ListTile(
                            leading: SizedBox(
                              width: 46,
                              height: 46,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: VibePhoto(
                                  url: '${d['thumbUrl'] ?? d['imageUrl'] ?? ''}',
                                  name: name,
                                ),
                              ),
                            ),
                            title: Text(
                              '${d['caption'] ?? '(mətn yoxdur)'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: t('Paylaşımı sil'),
                              onPressed: () async {
                                await docs[i].reference.delete();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(t('Paylaşım silindi.')),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: vRose,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: vBg,
      appBar: AppBar(
        backgroundColor: const Color(0xff0d0917),
        foregroundColor: Colors.white,
        title: const Text(
          'VIBE Moderasiya',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          UnderlineTabs(
            labels: tabs,
            index: tab,
            onChanged: (i) => setState(() => tab = i),
          ),
          Expanded(
            child: tab == 2 ? _suspendedList() : _reportList(),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // ŞİKAYƏTLƏR
  // ----------------------------------------------------------

  Widget _reportList() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Şikayətlər yüklənmədi.\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator(color: vPink));
      }

      final docs = snap.data!.docs.where((doc) {
        final status = '${doc.data()['status'] ?? 'new'}';
        return tab == 0 ? status == 'new' : status != 'new';
      }).toList();

      if (docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: vPurple,
                size: 54,
              ),
              const SizedBox(height: 12),
              Text(
                tab == 0 ? 'Yeni şikayət yoxdur' : 'Baxılmış şikayət yoxdur',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final doc = docs[i];
          final d = doc.data();
          final status = '${d['status'] ?? 'new'}';
          final targetId = '${d['targetId'] ?? ''}';
          final targetName = '${d['targetName'] ?? 'İstifadəçi'}';
          final reason = '${d['reason'] ?? 'Qeyd edilməyib'}';
          final at = d['createdAt'];

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff151020),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xff352447)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: vRose),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        targetName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Səbəb: $reason',
                  style: const TextStyle(color: Color(0xffd6cde1)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Göndərən: ${d['reporterName'] ?? d['reporterId'] ?? '—'}'
                  '${at is Timestamp ? '  ·  ${at.toDate().day}.${at.toDate().month} '
                        '${at.toDate().hour}:${at.toDate().minute.toString().padLeft(2, '0')}' : ''}',
                  style: const TextStyle(color: Color(0xff9e95ac), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: targetId.isEmpty
                          ? null
                          : () => _openContent(targetId, targetName),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(t('Məzmuna bax')),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: vRose),
                      onPressed: targetId.isEmpty
                          ? null
                          : () async {
                              await _suspend(targetId, targetName, reason);
                              await _setStatus(
                                doc.reference,
                                'reviewed',
                                note: 'suspended',
                              );
                            },
                      icon: const Icon(Icons.gavel_rounded, size: 18),
                      label: Text(t('Hesabı dayandır')),
                    ),
                    if (status == 'new') ...[
                      OutlinedButton.icon(
                        onPressed: () => _setStatus(doc.reference, 'dismissed'),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text(t('Əsassız')),
                      ),
                      FilledButton.icon(
                        onPressed: () => _setStatus(doc.reference, 'reviewed'),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(t('Baxıldı')),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  // ----------------------------------------------------------
  // DAYANDIRILMIŞ HESABLAR
  // ----------------------------------------------------------

  Widget _suspendedList() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .where('suspended', isEqualTo: true)
        .limit(100)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator(color: vPink));
      }
      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return const Center(
          child: Text(
            'Dayandırılmış hesab yoxdur.',
            style: TextStyle(color: vMuted),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        itemBuilder: (context, i) {
          final d = docs[i].data();
          final name = '${d['name'] ?? 'İstifadəçi'}';

          return Card(
            color: const Color(0xff151020),
            child: ListTile(
              leading: SizedBox(
                width: 44,
                height: 44,
                child: ClipOval(
                  child: VibePhoto(url: '${d['photoUrl'] ?? ''}', name: name),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${d['suspendedReason'] ?? 'Səbəb qeyd edilməyib'}',
                style: const TextStyle(color: vMuted, fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: () => _unsuspend(docs[i].id, name),
                child: Text(t('Bərpa et'), style: TextStyle(color: vMint)),
              ),
            ),
          );
        },
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'reviewed' => 'Baxılıb',
      'dismissed' => 'Əsassız',
      _ => 'Yeni',
    };
    final color = switch (status) {
      'reviewed' => const Color(0xff34d399),
      'dismissed' => const Color(0xff8d8499),
      _ => const Color(0xffffb24a),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}
