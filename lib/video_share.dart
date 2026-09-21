import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_profile.dart';
import 'app/i18n.dart';

class VideoShareButton extends StatelessWidget {
  const VideoShareButton({
    super.key,
    required this.profile,
    required this.videoId,
    required this.ownerName,
    required this.caption,
  });

  final UserProfile profile;
  final String videoId;
  final String ownerName;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final video =
        FirebaseFirestore.instance.collection('videos').doc(videoId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: video.snapshots(),
      builder: (_, snap) {
        final count = int.tryParse('${snap.data?.data()?['shares'] ?? 0}') ?? 0;

        return InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () async {
            final text = 'VIBE · @$ownerName\n$caption\nVideo ID: $videoId';
            await Clipboard.setData(ClipboardData(text: text));
            await video.set(
              {'shares': FieldValue.increment(1)},
              SetOptions(merge: true),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('Paylaşım mətni kopyalandı.')),
                ),
              );
            }
          },
          child: Column(
            children: [
              const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
