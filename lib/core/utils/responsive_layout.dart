/// ResponsiveLayout — Adaptive layout helpers (Delegates to ResponsiveHelper)
library;

import 'package:flutter/material.dart';
import 'responsive_helper.dart';

class ResponsiveLayout {
  ResponsiveLayout._();

  static bool isSmallPhone(BuildContext context) =>
      ResponsiveHelper.isSmallPhone(context);
  static bool isNormalPhone(BuildContext context) =>
      ResponsiveHelper.isNormalPhone(context);
  static bool isMobile(BuildContext context) =>
      ResponsiveHelper.isMobile(context);
  static bool isTablet(BuildContext context) =>
      ResponsiveHelper.isTablet(context);
  static bool isDesktop(BuildContext context) =>
      ResponsiveHelper.isDesktop(context);
  static bool isLandscape(BuildContext context) =>
      ResponsiveHelper.isLandscape(context);

  static int gridCount(
    BuildContext context, {
    int smallPhone = 1,
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    return ResponsiveHelper.gridCount(
      context,
      smallPhone: smallPhone,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  static double horizontalPadding(BuildContext context) =>
      ResponsiveHelper.padding(context);
  static double screenWidth(BuildContext context) =>
      ResponsiveHelper.width(context);
  static double screenHeight(BuildContext context) =>
      ResponsiveHelper.height(context);
}
