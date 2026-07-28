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
        return quantity / 1000.0; // convert to kg

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
        return baseQty * 1000.0;

      case 'ml':
      case 'milliliter':
      case 'millilitre':
        return baseQty * 1000.0;

      case 'dozen':
      case 'dozens':
      case 'dz':
        return baseQty / 12.0;

      default:
        return baseQty;
    }
  }
}
