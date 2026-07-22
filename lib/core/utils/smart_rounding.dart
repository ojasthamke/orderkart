/// SmartRounding — Bill rounding logic
/// Examples: 58 → 60, 39 → 40, 97 → 100, 123 → 125
library;

class SmartRounding {
  SmartRounding._();

  /// Returns the smart-rounded value for a given amount.
  /// Returns the original amount if already a clean number.
  static double round(double amount) {
    if (amount <= 0) return amount;
    return (amount / 5.0).ceil() * 5.0;
  }

  /// Returns true if rounding would change the amount
  static bool needsRounding(double amount) => round(amount) != amount;

  /// Savings (or extra) from rounding
  static double difference(double original, double rounded) =>
      rounded - original;

  static String _format(double val, String currency) {
    return '$currency${val.toStringAsFixed(val == val.roundToDouble() ? 0 : 2)}';
  }

  /// Friendly label: '₹58 → ₹60 (save ₹2)'
  static String label(double original, double rounded, String currency) {
    final diff = (rounded - original).abs();
    final origStr = _format(original, currency);
    final roundStr = _format(rounded, currency);
    final diffStr = _format(diff, currency);

    if (rounded > original) {
      return '$origStr → $roundStr (+$diffStr)';
    } else if (rounded < original) {
      return '$origStr → $roundStr (-$diffStr)';
    }
    return '$origStr → $roundStr';
  }
}
