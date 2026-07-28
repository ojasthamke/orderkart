import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/unit_converter.dart';

void main() {
  group('UnitConverter Tests', () {
    test('toBase converts weight correctly', () {
      expect(UnitConverter.toBase(500, 'gram'), 0.5);
      expect(UnitConverter.toBase(2, 'kg'), 2.0);
    });

    test('toBase converts volume correctly', () {
      expect(UnitConverter.toBase(250, 'ml'), 0.25);
      expect(UnitConverter.toBase(1.5, 'liter'), 1.5);
    });

    test('toBase converts dozen to pieces correctly', () {
      expect(UnitConverter.toBase(2, 'dozen'), 24.0);
      expect(UnitConverter.toBase(0.5, 'dozen'), 6.0);
      expect(UnitConverter.toBase(10, 'piece'), 10.0);
    });

    test('convert converts between units', () {
      expect(UnitConverter.convert(quantity: 1, fromUnit: 'dozen', toUnit: 'piece'), 12.0);
      expect(UnitConverter.convert(quantity: 12, fromUnit: 'piece', toUnit: 'dozen'), 1.0);
      expect(UnitConverter.convert(quantity: 1, fromUnit: 'kg', toUnit: 'gram'), 1000.0);
    });
  });
}
