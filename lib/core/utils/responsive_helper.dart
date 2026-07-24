// lib/core/utils/responsive_helper.dart

import 'package:flutter/material.dart';

class ResponsiveHelper {
  ResponsiveHelper._();

  // --- BREAKPOINTS ---
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isNormalPhone(BuildContext context) =>
      MediaQuery.of(context).size.width >= 360 &&
      MediaQuery.of(context).size.width < 600;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // --- SCREEN DIMENSIONS ---
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // --- ADAPTIVE PADDING ---
  static double padding(BuildContext context) {
    final w = width(context);
    if (w < 360) return 12;
    if (w < 600) return 16;
    if (w < 1024) return 24;
    return 32;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final p = padding(context);
    return EdgeInsets.symmetric(horizontal: p, vertical: p / 1.5);
  }

  // --- ADAPTIVE GRID COUNTS ---
  static int gridCount(
    BuildContext context, {
    int smallPhone = 1,
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    if (isLandscape(context) && isMobile(context)) return 3;
    if (isSmallPhone(context)) return smallPhone;
    return mobile;
  }

  // --- ADAPTIVE CARD / DIALOG WIDTHS ---
  static double dialogWidth(BuildContext context) {
    final w = width(context);
    if (w >= 1024) return 600;
    if (w >= 600) return 520;
    return w * 0.92;
  }

  static BoxConstraints dialogConstraints(BuildContext context) {
    final h = height(context);
    return BoxConstraints(
      maxWidth: dialogWidth(context),
      maxHeight: h * 0.85,
    );
  }

  // --- FONT & ICON SCALING HELPERS ---
  static double fontSize(BuildContext context, double baseSize) {
    final w = width(context);
    double scale = 1.0;
    if (w < 360) scale = 0.9;
    if (w >= 600 && w < 1024) scale = 1.1;
    if (w >= 1024) scale = 1.25;
    return baseSize * scale;
  }

  static double iconSize(BuildContext context, {double base = 22}) {
    final w = width(context);
    if (w < 360) return base * 0.9;
    if (w >= 600) return base * 1.15;
    return base;
  }
}
