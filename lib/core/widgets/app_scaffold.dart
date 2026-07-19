import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/presentation/settings_provider.dart';

class FloatingGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const FloatingGlassAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(isDark ? 0.72 : 0.85),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              title: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: leading,
              actions: actions,
              automaticallyImplyLeading: false,
              primary: false, // Prevents automatic status bar padding inside the card
              bottom: bottom,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(56.0 + 16.0 + (bottom?.preferredSize.height ?? 0.0));
}

class MeshColors {
  final Color color1;
  final Color color2;
  final Color color3;
  final Color color4;

  const MeshColors({
    required this.color1,
    required this.color2,
    required this.color3,
    required this.color4,
  });

  static MeshColors resolve(String theme) {
    switch (theme) {
      case 'forest':
        return const MeshColors(
          color1: Color(0xFF0D9488),
          color2: Color(0xFF10B981),
          color3: Color(0xFF34D399),
          color4: Color(0xFFF59E0B),
        );
      case 'abyss':
        return const MeshColors(
          color1: Color(0xFF312E81),
          color2: Color(0xFF1E1B4B),
          color3: Color(0xFF4C1D95),
          color4: Colors.black,
        );
      case 'sunset':
      default:
        return const MeshColors(
          color1: Color(0xFF3B82F6),
          color2: Color(0xFF8B5CF6),
          color3: Color(0xFFEC4899),
          color4: Color(0xFFF59E0B),
        );
    }
  }
}

class AppScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final meshTheme = ref.watch(settingsProvider).valueOrNull?.meshTheme ?? 'sunset';
    final colors = MeshColors.resolve(meshTheme);

    return Stack(
      children: [
        // Base solid background layer to prevent black window bleed
        Positioned.fill(
          child: Container(
            color: backgroundColor ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
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
                  colors.color1.withOpacity(isDark ? 0.35 : 0.22),
                  colors.color1.withOpacity(0),
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
                  colors.color2.withOpacity(isDark ? 0.30 : 0.18),
                  colors.color2.withOpacity(0),
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
                  colors.color3.withOpacity(isDark ? 0.25 : 0.15),
                  colors.color3.withOpacity(0),
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
                  colors.color4.withOpacity(isDark ? 0.20 : 0.12),
                  colors.color4.withOpacity(0),
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
        
        // Scaffold with transparent background overlaying the mesh background
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: FloatingGlassAppBar(
            title: title,
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
            actions: actions,
            bottom: bottom,
          ),
          body: body != null ? SafeArea(child: body!) : null,
          drawer: drawer,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          bottomSheet: bottomSheet,
        ),
      ],
    );
  }
}
