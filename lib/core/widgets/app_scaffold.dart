import 'dart:ui';
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Premium Apple-style frosted background stack
    final backgroundStack = Stack(
      children: [
        // Ambient soft pastel glow circles
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          right: -150,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple.withOpacity(isDark ? 0.12 : 0.06),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: 50,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withOpacity(isDark ? 0.10 : 0.05),
            ),
          ),
        ),
        // Glass filter overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // Content
        if (body != null) SafeArea(child: body!),
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      body: backgroundStack,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
    );
  }
}

