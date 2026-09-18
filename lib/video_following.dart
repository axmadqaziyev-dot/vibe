import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'user_profile.dart';

class FollowingVideoIds extends StatelessWidget {
  const FollowingVideoIds({
    super.key,
    required this.profile,
    required this.builder,
  });

  final UserProfile profile;
  final Widget Function(BuildContext context, Set<String> ids) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .collection('following')
          .snapshots(),
      builder: (_, snap) {
        final ids = snap.data?.docs.map((e) => e.id).toSet() ?? <String>{};
        return builder(context, ids);
      },
    );
  }
}
