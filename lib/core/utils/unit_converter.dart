/// UnitConverter — Normalizes and converts quantities between compatible units
library;

class UnitConverter {
  UnitConverter._();

  /// Normalize a (quantity, unit) tuple to its base unit value.
  /// Standard base units: 'kg' for weight, 'liter' for volume, 'piece' for count.
  static double toBase(double quantity, String unit) {
    final u = unit.trim().toLowerCase();
    switch (u) {
      case 'gram':
      case 'grams':
      case 'g':
      case 'gm':
      case 'gms':
        return quantity / 1000.0; // convert to kg

      case 'quintal':
      case 'qnt':
        return quantity * 100.0; // convert to kg

      case 'ton':
      case 'tonne':
        return quantity * 1000.0; // convert to kg

      case 'ml':
      case 'milliliter':
      case 'millilitre':
        return quantity / 1000.0; // convert to liter

      case 'dozen':
      case 'dozens':
      case 'dz':
        return quantity * 12.0; // convert to piece

      case 'kg':
      case 'kilo':
      case 'kilogram':
      case 'kilograms':
      case 'liter':
      case 'litre':
      case 'liters':
      case 'litres':
      case 'l':
      case 'ltr':
      case 'piece':
      case 'pieces':
      case 'pc':
      case 'pcs':
      case 'packet':
      case 'packets':
      case 'pkt':
      default:
        return quantity;
    }
  }

  /// Convert a quantity from [fromUnit] to [toUnit].
  /// If units are incompatible or same, returns converted quantity or original.
  static double convert({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    final fromNorm = fromUnit.trim().toLowerCase();
    final toNorm = toUnit.trim().toLowerCase();

    if (fromNorm == toNorm) return quantity;

    // Convert from -> base, then base -> to
    final baseQty = toBase(quantity, fromUnit);

    switch (toNorm) {
      case 'gram':
      case 'grams':
      case 'g':
      case 'gm':
      case 'gms':
        return baseQty * 1000.0;

      case 'ml':
      case 'milliliter':
      case 'millilitre':
        return baseQty * 1000.0;

      case 'dozen':
      case 'dozens':
      case 'dz':
        return baseQty / 12.0;

      case 'quintal':
      case 'qnt':
        return baseQty / 100.0;

      case 'ton':
      case 'tonne':
        return baseQty / 1000.0;

      default:
        return baseQty;
    }
  }

  /// Check whether a unit is a weight-based unit (kg, gram, quintal, ton)
  static bool isWeightUnit(String unit) {
    final u = unit.trim().toLowerCase();
    return u == 'kg' ||
        u == 'kilo' ||
        u == 'kilogram' ||
        u == 'kilograms' ||
        u == 'gram' ||
        u == 'grams' ||
        u == 'g' ||
        u == 'gm' ||
        u == 'gms' ||
        u == 'quintal' ||
        u == 'qnt' ||
        u == 'ton' ||
        u == 'tonne';
  }

  /// Check whether a unit is a piece/count-based unit
  static bool isCountUnit(String unit) {
    final u = unit.trim().toLowerCase();
    return u == 'piece' ||
        u == 'pieces' ||
        u == 'pc' ||
        u == 'pcs' ||
        u == 'dozen' ||
        u == 'dozens' ||
        u == 'dz' ||
        u == 'packet' ||
        u == 'packets' ||
        u == 'pkt' ||
        u == 'box' ||
        u == 'bundle' ||
        u == 'strip' ||
        u == 'bottle';
  }

  /// Converts a given quantity and unit to weight in kilograms (kg) if weight-based
  /// If [weightPerPiece] is provided and unit is count-based, optionally converts to kg.
  static double toWeightInKg(double quantity, String unit, {double weightPerPiece = 0.0}) {
    if (isWeightUnit(unit)) {
      return toBase(quantity, unit);
    }
    if (isCountUnit(unit) && weightPerPiece > 0) {
      final u = unit.trim().toLowerCase();
      final pcs = (u.startsWith('dozen') || u == 'dz') ? quantity * 12.0 : quantity;
      return pcs * weightPerPiece;
    }
    return 0.0;
  }

  /// Formats weight in kg with smart units display (e.g. 12.5 kg or 750 g)
  static String formatWeight(double weightInKg) {
    if (weightInKg <= 0) return '0 kg';
    if (weightInKg < 1.0) {
      final grams = (weightInKg * 1000).round();
      return '$grams g';
    }
    return '${weightInKg.toStringAsFixed(weightInKg == weightInKg.roundToDouble() ? 0 : 2)} kg';
  }
}
