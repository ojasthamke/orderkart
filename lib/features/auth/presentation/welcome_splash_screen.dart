import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';

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

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen> {
  @override
  void initState() {
    super.initState();
    AppHaptics.buttonClick(); // Play a premium confirmation click/buzz
    
    // Hold the screen for 3.2 seconds to let the beautiful animations shine
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(widget.args.nextRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
      body: Stack(
        children: [
          // ── BACKGROUND GRADIENT ──
          Container(
            decoration: BoxDecoration(gradient: bgGradient),
          ),

          // ── FLOATING ABSTRACT AMBIENT SHAPES ──
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

          // ── MAIN CONTENT LAYER ──
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
                      // ── LOGO IN A CONCENTRIC PULSING HALO ──
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Ripple 1
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
                          
                          // Outer Ripple 2
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

                          // Rotating outer gradient halo
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

                          // Central Logo Card
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          )
                              .animate()
                              .scale(duration: 800.ms, curve: Curves.easeOutBack)
                              .shimmer(delay: 800.ms, duration: 1.5.seconds),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // ── GLASSMORPHIC GREETING CARD ──
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
                                )
                                    .animate()
                                    .fadeIn(duration: 600.ms)
                                    .slideY(begin: 0.3, end: 0.0, curve: Curves.easeOutCubic),
                                
                                const SizedBox(height: 12),
                                
                                Text(
                                  widget.args.name,
                                  style: nameStyle,
                                  textAlign: TextAlign.center,
                                )
                                    .animate(delay: 200.ms)
                                    .fadeIn(duration: 800.ms)
                                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack)
                                    .shimmer(delay: 1.seconds, duration: 1.2.seconds),
                              ],
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 800.ms, delay: 100.ms)
                          .slideY(begin: 0.1, end: 0.0, curve: Curves.easeOut),

                      const SizedBox(height: 48),

                      // ── ANIMATED PULSING PROGRESS GLOW ──
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
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
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
    );
  }
}
