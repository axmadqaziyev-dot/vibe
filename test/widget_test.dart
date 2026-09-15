import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('Signed out users are immediately offline', () {
    final data = {'online': false, 'lastSeen': Timestamp.now()};
    expect(isReallyOnline(data), false);
    expect(activityText(data), isNot('İndi aktivdir'));
  });
  test('Presence expires after a lost connection', () {
    expect(isReallyOnline({'online': true, 'lastSeen': Timestamp.now()}), true);
    expect(
      isReallyOnline({
        'online': true,
        'lastSeen': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 60)),
        ),
      }),
      false,
    );
    expect(isReallyOnline({'online': true}), false);
  });
}
