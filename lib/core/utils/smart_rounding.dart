/// SmartRounding — Bill rounding logic
/// Examples: 58 → 60, 39 → 40, 97 → 100, 123 → 125

class SmartRounding {
  SmartRounding._();

  /// Returns the smart-rounded value for a given amount.
  /// Returns the original amount if already a clean number.
  static double round(double amount) {
    if (amount <= 0) return amount;

    final intPart = amount.truncate();
    final units   = intPart % 10;

    // Already a round number
    if (units == 0 || units == 5) return amount.roundToDouble();

    // Round up to next 5 or 10
    double rounded;
    if (units < 5) {
      rounded = (intPart - units + 5).toDouble();
    } else {
      rounded = (intPart - units + 10).toDouble();
    }

    // If close to a round hundred, snap to it
    final nextHundred = ((intPart ~/ 100) + 1) * 100.0;
    if ((nextHundred - amount) <= 5) return nextHundred;

    return rounded;
  }

  /// Returns true if rounding would change the amount
  static bool needsRounding(double amount) => round(amount) != amount.roundToDouble();

  /// Savings (or extra) from rounding
  static double difference(double original, double rounded) =>
      rounded - original;

  /// Friendly label: '₹58 → ₹60 (save ₹2)'
  static String label(double original, double rounded, String currency) {
    final diff = (rounded - original).abs();
    if (rounded > original) {
      return '$currency${original.toStringAsFixed(0)} → $currency${rounded.toStringAsFixed(0)} (+$currency${diff.toStringAsFixed(0)})';
    }
    return '$currency${original.toStringAsFixed(0)} → $currency${rounded.toStringAsFixed(0)}';
  }
}
