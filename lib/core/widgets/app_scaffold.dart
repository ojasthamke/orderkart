import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/presentation/settings_provider.dart';
import '../utils/haptics.dart';
import 'app_drawer.dart';

class FloatingGlassAppBar extends StatelessWidget
    implements PreferredSizeWidget {
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: (isDark ? const Color(0xFF1E293B) : Colors.white)
            .withValues(alpha: isDark ? 0.88 : 0.95),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
          primary: false,
          bottom: bottom,
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(56.0 + 16.0 + (bottom?.preferredSize.height ?? 0.0));
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
          color4: Color(0xFF6EE7B7),
        );
      case 'ocean':
        return const MeshColors(
          color1: Color(0xFF0284C7),
          color2: Color(0xFF38BDF8),
          color3: Color(0xFF60A5FA),
          color4: Color(0xFF93C5FD),
        );
      case 'berry':
        return const MeshColors(
          color1: Color(0xFF9333EA),
          color2: Color(0xFFC084FC),
          color3: Color(0xFFE879F9),
          color4: Color(0xFFF472B6),
        );
      case 'minimal':
        return const MeshColors(
          color1: Color(0xFF64748B),
          color2: Color(0xFF94A3B8),
          color3: Color(0xFFCBD5E1),
          color4: Color(0xFFE2E8F0),
        );
      case 'sunset':
      default:
        return const MeshColors(
          color1: Color(0xFFF59E0B),
          color2: Color(0xFFF97316),
          color3: Color(0xFFFB7185),
          color4: Color(0xFFFDA4AF),
        );
    }
  }
}

class AppScaffold extends ConsumerStatefulWidget {
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
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final meshTheme =
        ref.watch(settingsProvider).valueOrNull?.meshTheme ?? 'sunset';
    final colors = MeshColors.resolve(meshTheme);

    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final bool shouldShowBack = widget.showBack && canPop;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: widget.backgroundColor ??
                (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          ),
        ),
        // Ambient soft pastel glow circles (Vibrant Hardware-Accelerated Mesh)
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
                  colors.color1.withValues(alpha: isDark ? 0.28 : 0.16),
                  colors.color1.withValues(alpha: isDark ? 0.10 : 0.05),
                  colors.color1.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
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
                  colors.color2.withValues(alpha: isDark ? 0.24 : 0.14),
                  colors.color2.withValues(alpha: isDark ? 0.08 : 0.04),
                  colors.color2.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
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
                  colors.color3.withValues(alpha: isDark ? 0.20 : 0.12),
                  colors.color3.withValues(alpha: isDark ? 0.06 : 0.03),
                  colors.color3.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
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
                  colors.color4.withValues(alpha: isDark ? 0.16 : 0.10),
                  colors.color4.withValues(alpha: isDark ? 0.05 : 0.02),
                  colors.color4.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Scaffold with transparent background overlaying the mesh background
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: FloatingGlassAppBar(
            title: widget.title,
            leading: shouldShowBack
                ? IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    tooltip: 'Back',
                    onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                  )
                : IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Open Menu',
                    onPressed: () {
                      AppHaptics.buttonClick();
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
            actions: widget.actions,
            bottom: widget.bottom,
          ),
          body: widget.body != null ? SafeArea(child: widget.body!) : null,
          drawer: widget.drawer ?? const AppDrawer(),
          floatingActionButton: widget.floatingActionButton,
          bottomNavigationBar: widget.bottomNavigationBar,
          bottomSheet: widget.bottomSheet,
        ),
      ],
    );
  }
}
