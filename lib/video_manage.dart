import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

Future<void> showVideoManageSheet(
  BuildContext context, {
  required UserProfile profile,
  required String videoId,
  required Map<String, dynamic> data,
}) async {
  final ownerUid = '${data['ownerUid'] ?? ''}';
  final mine = ownerUid == profile.uid;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xff151020),
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Wrap(
        children: [
          if (!mine)
            ListTile(
              leading: const Icon(
                Icons.visibility_off_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Maraqlı deyil',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(profile.uid)
                    .collection('hiddenVideos')
                    .doc(videoId)
                    .set({
                  'videoId': videoId,
                  'createdAt': Timestamp.now(),
                });
                if (context.mounted) Navigator.pop(sheet);
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(
                Icons.public_rounded,
                color: Color(0xff35e18b),
              ),
              title: const Text(
                'Public et',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('videos')
                    .doc(videoId)
                    .set(
                  {'visibility': 'public'},
                  SetOptions(merge: true),
                );
                if (context.mounted) Navigator.pop(sheet);
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Gizli et',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('videos')
                    .doc(videoId)
                    .set(
                  {'visibility': 'private'},
                  SetOptions(merge: true),
                );
                if (context.mounted) Navigator.pop(sheet);
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xffff657b),
              ),
              title: const Text(
                'Videonu sil',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final videoRef = FirebaseFirestore.instance
                    .collection('videos')
                    .doc(videoId);

                final url = '${data['videoUrl'] ?? ''}';

                await videoRef.delete();

                if (url.isNotEmpty) {
                  try {
                    await FirebaseStorage.instance.refFromURL(url).delete();
                  } catch (_) {}
                }

                if (context.mounted) Navigator.pop(sheet);
              },
            ),
        ],
      ),
    ),
  );
}
