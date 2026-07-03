import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/smart_rounding.dart';

void main() {
  group('SmartRounding Tests', () {
    test('Round numbers return original values', () {
      expect(SmartRounding.round(50), 50.0);
      expect(SmartRounding.round(45), 45.0);
      expect(SmartRounding.round(0), 0.0);
    });

    test('Values round to nearest 5 or 10', () {
      // 58 -> rounds up to 60
      expect(SmartRounding.round(58), 60.0);
      // 39 -> rounds up to 40
      expect(SmartRounding.round(39), 40.0);
      // 123 -> rounds up to 125
      expect(SmartRounding.round(123), 125.0);
    });

    test('Values near round hundred snap to it', () {
      // 97 -> 100
      expect(SmartRounding.round(97), 100.0);
      // 96 -> 100 (since 100 - 96 <= 5)
      expect(SmartRounding.round(96), 100.0);
    });
  });
}
