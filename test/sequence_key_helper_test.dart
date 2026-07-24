import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/sequence_key_helper.dart';

void main() {
  test('SequenceKeyHelper generates midpoint keys correctly', () {
    // 1. Empties
    expect(SequenceKeyHelper.generateBetween(null, null), equals('m'));
    expect(SequenceKeyHelper.generateBetween('', ''), equals('m'));

    // 2. Insert at start (before next)
    final beforeM = SequenceKeyHelper.generateBetween(null, 'm');
    expect(beforeM.compareTo('m') < 0, isTrue);

    // 3. Insert at end (after prev)
    final afterM = SequenceKeyHelper.generateBetween('m', null);
    expect(afterM.compareTo('m') > 0, isTrue);

    // 4. Insert between 'a' and 'c' -> should be 'b'
    expect(SequenceKeyHelper.generateBetween('a', 'c'), equals('b'));

    // 5. Insert between consecutive characters ('a' and 'b') -> should append midpoint character
    final betweenAB = SequenceKeyHelper.generateBetween('a', 'b');
    expect(betweenAB.startsWith('a'), isTrue);
    expect(betweenAB.compareTo('a') > 0, isTrue);
    expect(betweenAB.compareTo('b') < 0, isTrue);

    // 6. Ordering verification
    final list = <String>[];
    String current = 'm';
    for (int i = 0; i < 5; i++) {
      current = SequenceKeyHelper.generateBetween(null, current);
      list.insert(0, current);
    }
    list.add('m');
    current = 'm';
    for (int i = 0; i < 5; i++) {
      current = SequenceKeyHelper.generateBetween(current, null);
      list.add(current);
    }

    // Verify list is sorted lexicographically
    for (int i = 0; i < list.length - 1; i++) {
      expect(list[i].compareTo(list[i + 1]) < 0, isTrue,
          reason: 'Failed comparing ${list[i]} and ${list[i + 1]}');
    }
  });
}
