import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class VideoFollowButton extends StatelessWidget {
  const VideoFollowButton({
    super.key,
    required this.profile,
    required this.targetUid,
    required this.targetName,
  });

  final UserProfile profile;
  final String targetUid;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    if (targetUid.isEmpty || targetUid == profile.uid) {
      return const SizedBox.shrink();
    }

    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(profile.uid)
        .collection('following')
        .doc(targetUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: followingRef.snapshots(),
      builder: (_, snap) {
        final following = snap.data?.exists == true;
        return OutlinedButton(
          onPressed: () async {
            final reverse = FirebaseFirestore.instance
                .collection('users')
                .doc(targetUid)
                .collection('followers')
                .doc(profile.uid);

            final batch = FirebaseFirestore.instance.batch();
            if (following) {
              batch.delete(followingRef);
              batch.delete(reverse);
            } else {
              batch.set(followingRef, {
                'uid': targetUid,
                'name': targetName,
                'createdAt': Timestamp.now(),
              });
              batch.set(reverse, {
                'uid': profile.uid,
                'name': profile.name,
                'createdAt': Timestamp.now(),
              });
            }
            await batch.commit();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: following
                  ? Colors.white24
                  : const Color(0xffff2bd6),
            ),
          ),
          child: Text(following ? 'İzlənilir' : 'İzlə'),
        );
      },
    );
  }
}

class VideoRepostButton extends StatelessWidget {
  const VideoRepostButton({
    super.key,
    required this.profile,
    required this.videoId,
  });

  final UserProfile profile;
  final String videoId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('videos')
        .doc(videoId)
        .collection('reposts')
        .doc(profile.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final active = snap.data?.exists == true;
        return IconButton(
          tooltip: active ? 'Repost sil' : 'Repost et',
          onPressed: () async {
            if (active) {
              await ref.delete();
            } else {
              await ref.set({
                'uid': profile.uid,
                'name': profile.name,
                'createdAt': Timestamp.now(),
              });
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(profile.uid)
                  .collection('reposts')
                  .doc(videoId)
                  .set({
                'videoId': videoId,
                'createdAt': Timestamp.now(),
              });
            }
          },
          icon: Icon(
            Icons.repeat_rounded,
            color: active ? const Color(0xff35e18b) : Colors.white,
          ),
        );
      },
    );
  }
}
