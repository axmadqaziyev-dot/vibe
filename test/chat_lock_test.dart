import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/chat_filter.dart';
import 'package:flutter_application_1/chat_lock.dart';

void main() {
  late FakeFirebaseFirestore db;
  late DocumentReference<Map<String, dynamic>> chat;

  setUp(() {
    db = FakeFirebaseFirestore();
    chat = db.collection('chats').doc('a_b');
  });

  test('kilid yazılır və geri oxunur', () async {
    await applyChatLock(
      chat,
      topic: FilterTopic.adult,
      previousLocks: 0,
      members: const ['a', 'b'],
    );

    final lock = readChatLock((await chat.get()).data());

    expect(lock, isNotNull);
    expect(lock!.topic, FilterTopic.adult);
    expect(lock.left.inHours, greaterThan(22));
  });

  test('söhbət sənədi yoxdursa da yaradılır', () async {
    await applyChatLock(
      chat,
      topic: FilterTopic.religion,
      previousLocks: 0,
      members: const ['a', 'b'],
    );

    final data = (await chat.get()).data()!;

    // Üzvlər olmadan qayda sənədi oxumağa qoymaz.
    expect(data['members'], ['a', 'b']);
    expect(data['lockCount'], 1);
  });

  test('təkrar bağlanmada müddət uzanır', () async {
    await applyChatLock(
      chat,
      topic: FilterTopic.adult,
      previousLocks: 0,
      members: const ['a', 'b'],
    );
    await applyChatLock(
      chat,
      topic: FilterTopic.adult,
      previousLocks: 1,
      members: const ['a', 'b'],
    );

    final data = (await chat.get()).data()!;
    final lock = readChatLock(data)!;

    expect(data['lockCount'], 2);
    expect(lock.left.inHours, greaterThan(48));
  });

  test('müddəti bitmiş kilid qüvvədə deyil', () {
    final past = DateTime.now().subtract(const Duration(minutes: 1));

    final lock = readChatLock({
      'lockedUntil': Timestamp.fromDate(past),
      'lockedTopic': 'adult',
    });

    expect(lock, isNull);
  });

  test('kilidsiz söhbət açıqdır', () {
    expect(readChatLock(const {'lastMessage': 'salam'}), isNull);
    expect(readChatLock(null), isNull);
  });

  test('naməlum mövzu adı tətbiqi qırmır', () {
    final lock = readChatLock({
      'lockedUntil':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2))),
      'lockedTopic': 'kohne_deyer',
    });

    expect(lock, isNotNull);
  });
}
