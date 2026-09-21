import 'package:flutter/material.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/voice/voice_hold.dart';

void main() {
  group('sürüşdürmə', () {
    test('yerində qalanda yazı davam edir', () {
      expect(gestureFor(Offset.zero), HoldGesture.recording);
      expect(gestureFor(const Offset(-20, -10)), HoldGesture.recording);
    });

    test('sola sürüşdürəndə ləğv olunur', () {
      expect(
        gestureFor(const Offset(-cancelDistance, 0)),
        HoldGesture.willCancel,
      );
    });

    test('sağa sürüşdürmək ləğv etmir', () {
      // Barmaq sağa getsə heç nə olmamalıdır.
      expect(gestureFor(const Offset(120, 0)), HoldGesture.recording);
    });

    test('yuxarı sürüşdürəndə kilidlənir', () {
      expect(
        gestureFor(const Offset(0, -lockDistance)),
        HoldGesture.willLock,
      );
    });

    test('kilid ləğvdən üstündür', () {
      // Kilidləmək istəyən adam barmağını azca sola da apara bilər —
      // belə halda yazı silinməməlidir.
      expect(
        gestureFor(const Offset(-cancelDistance - 30, -lockDistance - 10)),
        HoldGesture.willLock,
      );
    });

    test('aşağı sürüşdürmək kilidləmir', () {
      expect(gestureFor(const Offset(0, 120)), HoldGesture.recording);
    });
  });

  group('sayğac', () {
    test('saniyə iki rəqəmlə yazılır', () {
      expect(holdTimer(0), '0:00');
      expect(holdTimer(7400), '0:07');
      expect(holdTimer(65000), '1:05');
    });
  });
}
