/// AppScaffold — Consistent scaffold with back-button safety

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget? body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;
  final bool showBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final VoidCallback? onBack;

  const AppScaffold({
    super.key,
    required this.title,
    this.body,
    this.floatingActionButton,
    this.actions,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.showBack = true,
    this.bottom,
    this.backgroundColor,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: onBack ?? () => Navigator.of(context).pop(),
              )
            : drawer != null
                ? Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  )
                : null,
        automaticallyImplyLeading: false,
        actions: actions,
        bottom: bottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      drawer: drawer,
    );
  }
}
