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
        // Base solid background layer to prevent black window bleed
        Positioned.fill(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          ),
        ),
        // Ambient soft pastel glow circles (Vibrant Mesh)
        Positioned(
          top: -50,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(isDark ? 0.35 : 0.22), // Electric Blue
                  const Color(0xFF3B82F6).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.28,
          right: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(isDark ? 0.30 : 0.18), // Rich Violet
                  const Color(0xFF8B5CF6).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 50,
          left: -50,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFEC4899).withOpacity(isDark ? 0.25 : 0.15), // Rose/Pink
                  const Color(0xFFEC4899).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: 50,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFF59E0B).withOpacity(isDark ? 0.20 : 0.12), // Amber/Orange
                  const Color(0xFFF59E0B).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        // Glass filter overlay (tuned blur sigma)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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

