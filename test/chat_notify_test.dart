import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/chat_notify.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<void> follow(String me, String them) => db
      .collection('users')
      .doc(me)
      .collection('following')
      .doc(them)
      .set({'at': 1});

  test('izləyirsənsə bildiriş yazılmır', () async {
    // Asif İlkini izləyir — İlkinin mesajı gözləniləndir.
    await follow('asif', 'ilkin');

    await notifyNewMessage(
      toUid: 'asif',
      fromUid: 'ilkin',
      fromName: 'İlkin',
      body: 'salam',
      chatId: 'asif_ilkin',
      database: db,
    );

    final snap =
        await db.collection('users').doc('asif').collection('notifications').get();

    expect(snap.docs, isEmpty);
  });

  test('tanımadığın adam yazanda bildiriş gedir', () async {
    await notifyNewMessage(
      toUid: 'asif',
      fromUid: 'yad',
      fromName: 'Yad adam',
      body: 'salam',
      chatId: 'asif_yad',
      database: db,
    );

    final snap =
        await db.collection('users').doc('asif').collection('notifications').get();

    expect(snap.docs.length, 1);
    expect(snap.docs.first.data()['type'], 'message');
    expect(snap.docs.first.data()['title'], 'Yad adam');
  });

  test('özünə bildiriş getmir', () async {
    await notifyNewMessage(
      toUid: 'asif',
      fromUid: 'asif',
      fromName: 'Asif',
      body: 'qeyd',
      chatId: 'asif_asif',
      database: db,
    );

    final snap =
        await db.collection('users').doc('asif').collection('notifications').get();

    expect(snap.docs, isEmpty);
  });

  test('izləmə yoxlaması', () async {
    await follow('asif', 'ilkin');

    expect(
      await receiverFollows(toUid: 'asif', fromUid: 'ilkin', database: db),
      isTrue,
    );
    expect(
      await receiverFollows(toUid: 'asif', fromUid: 'yad', database: db),
      isFalse,
    );
  });
}
