import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

Future<void> showVideoReportSheet(
  BuildContext context, {
  required UserProfile profile,
  required String videoId,
  required String ownerUid,
}) async {
  final reasons = [
    'Spam',
    'Uyğunsuz məzmun',
    'Təhqir və ya zorakılıq',
    'Saxta profil',
    'Digər',
  ];

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff151020),
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Videonu şikayət et',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final reason in reasons)
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: Color(0xffff657b),
              ),
              title: Text(
                reason,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await FirebaseFirestore.instance.collection('reports').add({
                  'type': 'video',
                  'videoId': videoId,
                  'ownerUid': ownerUid,
                  'reporterUid': profile.uid,
                  'reason': reason,
                  'status': 'new',
                  'createdAt': Timestamp.now(),
                });
                if (context.mounted) {
                  Navigator.pop(sheet);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Şikayət göndərildi.'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    ),
  );
}
