import 'package:english_ai/core/utils/sm2.dart';
import 'package:english_ai/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SM-2 parity with backend', () {
    test('successful reviews follow 1 -> 6 -> interval * EF', () {
      final first = calculateSm2(
        repetitionCount: 0,
        easeFactor: 2.5,
        intervalDays: 0,
        quality: 4,
      );
      expect(first.repetitionCount, 1);
      expect(first.intervalDays, 1);
      expect(first.easeFactor, 2.5);
      expect(first.status, 'reviewing');

      final second = calculateSm2(
        repetitionCount: first.repetitionCount,
        easeFactor: first.easeFactor,
        intervalDays: first.intervalDays,
        quality: 4,
      );
      expect(second.repetitionCount, 2);
      expect(second.intervalDays, 6);

      final third = calculateSm2(
        repetitionCount: second.repetitionCount,
        easeFactor: second.easeFactor,
        intervalDays: second.intervalDays,
        quality: 4,
      );
      expect(third.repetitionCount, 3);
      expect(third.intervalDays, 15);
    });

    test('failed recall resets the repetition count', () {
      final result = calculateSm2(
        repetitionCount: 4,
        easeFactor: 2.2,
        intervalDays: 30,
        quality: 2,
      );
      expect(result.repetitionCount, 0);
      expect(result.intervalDays, 1);
      expect(result.status, 'learning');
    });

    test('ease factor never drops below 1.3', () {
      final result = calculateSm2(
        repetitionCount: 0,
        easeFactor: 1.3,
        intervalDays: 1,
        quality: 0,
      );
      expect(result.easeFactor, greaterThanOrEqualTo(1.3));
    });

    test('interval >= 21 days is marked mastered', () {
      final result = calculateSm2(
        repetitionCount: 2,
        easeFactor: 2.5,
        intervalDays: 10,
        quality: 5,
      );
      expect(result.intervalDays, greaterThanOrEqualTo(21));
      expect(result.status, 'mastered');
    });
  });

  group('UUID helper', () {
    test('generates RFC 4122 v4 ids', () {
      final id = generateUuidV4();
      expect(isUuid(id), isTrue);
      expect(id[14], '4');
    });

    test('rejects legacy local ids', () {
      expect(isUuid('s1'), isFalse);
      expect(isUuid('1699999999999'), isFalse);
      expect(isUuid('not-a-uuid'), isFalse);
    });
  });
}
