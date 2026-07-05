/// AppHaptics — Custom haptic vibration feedback helpers
/// Gives every button action a unique, premium tactile feel

import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  /// Very soft vibration for item addition to cart
  static void itemAdded() {
    HapticFeedback.lightImpact();
  }

  /// Subtle click for chips, tabs, quantity spinners
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Medium tactile click for standard buttons
  static void buttonClick() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy firm vibration for major actions (Save Order, Record Payment, Checkout)
  static void primarySave() {
    HapticFeedback.heavyImpact();
  }

  /// Warning / Delete action vibration
  static void warning() {
    HapticFeedback.vibrate();
  }

  /// Success vibration
  static void success() {
    HapticFeedback.lightImpact();
  }

  /// Error vibration
  static void error() {
    HapticFeedback.vibrate();
  }
}
