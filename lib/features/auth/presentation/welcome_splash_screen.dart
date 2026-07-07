import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/haptics.dart';
import '../../dashboard/presentation/main_screen.dart';
import '../../dashboard/presentation/worker_dashboard_screen.dart';
import '../../../app.dart';

class WelcomeSplashScreenArgs {
  final String name;
  final String nextRoute;

  WelcomeSplashScreenArgs({required this.name, required this.nextRoute});
}

class WelcomeSplashScreen extends StatefulWidget {
  final WelcomeSplashScreenArgs args;

  const WelcomeSplashScreen({super.key, required this.args});

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _uiOpacity;
  late Animation<Offset> _dashboardSlide;

  @override
  void initState() {
    super.initState();
    AppHaptics.buttonClick(); // Play a premium confirmation click/buzz
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 0.0 to 1.7 seconds: Normal welcome screen displays
    // 1.7 to 2.5 seconds: Zoom in logo, slide up dashboard, fade out UI
    final startTransitionInterval = CurveTween(
      curve: const Interval(0.68, 1.0, curve: Curves.easeInOutCubic),
    );

    _logoScale = Tween<double>(begin: 1.0, end: 25.0).animate(
      _controller.drive(startTransitionInterval),
    );

    _logoOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      _controller.drive(startTransitionInterval),
    );

    _uiOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      _controller.drive(startTransitionInterval),
    );

    _dashboardSlide = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      _controller.drive(startTransitionInterval),
    );

    // Start the animation
    _controller.forward();

    // Mark welcome screen as shown at the end of the animation and perform instantaneous navigation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        AppStartupScreen.welcomeShown = true;
        Navigator.of(context).pushReplacementNamed(
          widget.args.nextRoute,
          arguments: {'instant': true},
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Resolve target screen to overlay
    Widget targetScreen = const SizedBox.shrink();
    if (widget.args.nextRoute == AppRoutes.workerDashboard) {
      targetScreen = const WorkerDashboardScreen();
    } else if (widget.args.nextRoute == AppRoutes.dashboard || widget.args.nextRoute == '/') {
      targetScreen = const MainScreen();
    }

    // Smooth animated background gradient colors
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF030712), Color(0xFF111827), Color(0xFF1F2937)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
          );

    final titleStyle = GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: FontWeight.w400,
      color: isDark ? Colors.white60 : Colors.black54,
      letterSpacing: 2.0,
    );

    final nameStyle = GoogleFonts.outfit(
      fontSize: 34,
      fontWeight: FontWeight.w900,
      color: AppColors.primary,
      letterSpacing: -0.5,
      shadows: [
        Shadow(
          blurRadius: 15.0,
          color: AppColors.primary.withOpacity(0.35),
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF030712) : const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          // ── BOTTOM LAYER: TARGET SCREEN (SLIDES UP) ──
          AnimatedBuilder(
            animation: _dashboardSlide,
            builder: (context, child) {
              return SlideTransition(
                position: _dashboardSlide,
                child: child,
              );
            },
            child: targetScreen,
          ),

          // ── TOP LAYER: WELCOME SPLASH ELEMENTS ──
          AnimatedBuilder(
            animation: _uiOpacity,
            builder: (context, child) {
              if (_uiOpacity.value <= 0.0) {
                return const SizedBox.shrink();
              }
              return Opacity(
                opacity: _uiOpacity.value,
                child: child,
              );
            },
            child: Stack(
              children: [
                // Background Gradient
                Container(
                  decoration: BoxDecoration(gradient: bgGradient),
                ),

                // Blob 1
                Positioned(
                  top: -100,
                  left: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(isDark ? 0.04 : 0.03),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: -20, end: 20, duration: 4.seconds, curve: Curves.easeInOut)
                      .moveX(begin: -10, end: 10, duration: 3.seconds, curve: Curves.easeInOut),
                ),
                
                // Blob 2
                Positioned(
                  bottom: -150,
                  right: -50,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight.withOpacity(isDark ? 0.03 : 0.02),
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .moveY(begin: 30, end: -30, duration: 5.seconds, curve: Curves.easeInOut)
                      .moveX(begin: 15, end: -15, duration: 4.seconds, curve: Curves.easeInOut),
                ),

                // Welcome Greeting Card and Progress dots
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Spacer to accommodate the independent logo center position
                            const SizedBox(height: 160),

                            const SizedBox(height: 48),

                            // Glassmorphic greeting card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'WELCOME BACK',
                                        style: titleStyle,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        widget.args.name,
                                        style: nameStyle,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),

                            // Progress Dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.25),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                                    .animate(onPlay: (controller) => controller.repeat())
                                    .scale(
                                      begin: const Offset(1.0, 1.0),
                                      end: const Offset(1.4, 1.4),
                                      delay: (index * 200).ms,
                                      duration: 600.ms,
                                      curve: Curves.easeInOut,
                                    )
                                    .then()
                                    .scale(
                                      begin: const Offset(1.4, 1.4),
                                      end: const Offset(1.0, 1.0),
                                      duration: 600.ms,
                                      curve: Curves.easeInOut,
                                    );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── INDEPENDENT LOGO LAYER FOR UNHAMPERED SCALE/ZOOM ──
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (_logoOpacity.value <= 0.0) {
                return const SizedBox.shrink();
              }
              return Center(
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Concentric Halo / Ripple Rings (Only active when logo is not scaling)
                AnimatedBuilder(
                  animation: _logoScale,
                  builder: (context, child) {
                    if (_logoScale.value > 1.1) {
                      return const SizedBox.shrink();
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.04),
                          ),
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.5, 1.5), duration: 2.2.seconds, curve: Curves.easeOut)
                            .fadeOut(duration: 2.2.seconds),
                        
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.02),
                          ),
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.5, 1.5), delay: 1.1.seconds, duration: 2.2.seconds, curve: Curves.easeOut)
                            .fadeOut(duration: 2.2.seconds),

                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .rotate(end: 1, duration: 8.seconds),
                      ],
                    );
                  },
                ),

                // White circular background for logo.png
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
