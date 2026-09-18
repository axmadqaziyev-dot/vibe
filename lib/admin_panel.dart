import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VibeAdminPanel extends StatelessWidget {
  const VibeAdminPanel({super.key});

  Future<void> _setStatus(DocumentReference ref, String status) async {
    await ref.update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff070510),
      appBar: AppBar(
        backgroundColor: const Color(0xff0d0917),
        foregroundColor: Colors.white,
        title: const Text('VIBE Admin', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Admin xətası: ${snap.error}', style: const TextStyle(color: Colors.white)));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, color: Color(0xff8b5cff), size: 54),
                  SizedBox(height: 12),
                  Text('Şikayət yoxdur', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final status = '${d['status'] ?? 'new'}';
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
                        const Icon(Icons.flag_rounded, color: Color(0xffff5d76)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${d['targetName'] ?? 'İstifadəçi'}',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                        _StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Səbəb: ${d['reason'] ?? 'Qeyd edilməyib'}', style: const TextStyle(color: Color(0xffd6cde1))),
                    const SizedBox(height: 5),
                    Text('Göndərən: ${d['reporterName'] ?? d['reporterId'] ?? '—'}', style: const TextStyle(color: Color(0xff9e95ac), fontSize: 12)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: status == 'dismissed' ? null : () => _setStatus(doc.reference, 'dismissed'),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Bağla'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: status == 'reviewed' ? null : () => _setStatus(doc.reference, 'reviewed'),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Baxıldı'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'reviewed' => 'Baxılıb',
      'dismissed' => 'Bağlanıb',
      _ => 'Yeni',
    };
    final color = switch (status) {
      'reviewed' => const Color(0xff34d399),
      'dismissed' => const Color(0xff8d8499),
      _ => const Color(0xffffb24a),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}
