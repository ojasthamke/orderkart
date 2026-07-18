/// App Colors — Material 3 colour palette
/// White-dominant, sunlight-friendly, professional
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Brand ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF388E3C);       // Green 700
  static const Color primaryLight = Color(0xFF81C784);  // Green 300
  static const Color primarySurface = Color(0xFFE8F5E9); // Green 50

  // ── Accent ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);       // Green 800
  static const Color successLight = Color(0xFF43A047);  // Green 600
  static const Color successSurface = Color(0xFFE8F5E9); // Green 50

  static const Color warning = Color(0xFFE65100);       // Orange 900
  static const Color warningLight = Color(0xFFF57C00);  // Orange 700
  static const Color warningSurface = Color(0xFFFFF3E0); // Orange 50

  static const Color error = Color(0xFFC62828);         // Red 800
  static const Color errorLight = Color(0xFFE53935);    // Red 600
  static const Color errorSurface = Color(0xFFFFEBEE);  // Red 50

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FA);    // Off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);

  static const Color gray50  = Color(0xFFF8F9FA);
  static const Color gray100 = Color(0xFFF1F3F5);
  static const Color gray200 = Color(0xFFE9ECEF);
  static const Color gray300 = Color(0xFFDEE2E6);
  static const Color gray400 = Color(0xFFCED4DA);
  static const Color gray500 = Color(0xFFADB5BD);
  static const Color gray600 = Color(0xFF6C757D);
  static const Color gray700 = Color(0xFF495057);
  static const Color gray800 = Color(0xFF343A40);
  static const Color gray900 = Color(0xFF212529);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textHint      = Color(0xFFADB5BD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Status Colors (Delivery / Payment) ─────────────────────────────────────
  static const Color pending   = Color(0xFFF57C00);  // Orange
  static const Color delivered = Color(0xFF2E7D32);  // Green
  static const Color cancelled = Color(0xFFC62828);  // Red

  static const Color cash   = Color(0xFF1B5E20);  // Dark Green
  static const Color online = Color(0xFF0D47A1);  // Dark Blue
  static const Color upi    = Color(0xFF6A1B9A);  // Purple
  static const Color card   = Color(0xFF37474F);  // Blue Grey

  // ── Category Colors ────────────────────────────────────────────────────────
  static const Color vegetables = Color(0xFF388E3C); // Green
  static const Color fruits     = Color(0xFFE65100); // Orange
  static const Color groceries  = Color(0xFF1565C0); // Blue
  static const Color medicines  = Color(0xFFAD1457); // Pink/Red

  static LinearGradient get glassGradientLight => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.85),
          Colors.white.withOpacity(0.50),
        ],
      );

  static LinearGradient get glassGradientDark => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1E293B).withOpacity(0.65),
          const Color(0xFF0F172A).withOpacity(0.35),
        ],
      );

  static LinearGradient get specularGlowLight => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.70),
          Colors.white.withOpacity(0.15),
        ],
      );

  static LinearGradient get specularGlowDark => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.05),
        ],
      );

  // ── Card Shadow ────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static Color textPrimaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white70 : textSecondary;

  static Color textHintColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white38 : textHint;

  static Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1A) : gray200;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A0A0A) : white;
}
