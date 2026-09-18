import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> sendVideoNotification({
  required String targetUid,
  required String fromUid,
  required String fromName,
  required String type,
  required String body,
  required String videoId,
}) async {
  if (targetUid.isEmpty || targetUid == fromUid) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
      .collection('notifications')
      .add({
    'type': type,
    'title': fromName,
    'body': body,
    'fromUid': fromUid,
    'videoId': videoId,
    'read': false,
    'createdAt': Timestamp.now(),
  });
}
