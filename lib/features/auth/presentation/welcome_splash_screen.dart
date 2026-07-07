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
    
    // Hold the screen for 2.5 seconds before navigating
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(widget.args.nextRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Choose stylish gradient colors
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F19), Color(0xFF1E293B)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          );

    final titleStyle = GoogleFonts.outfit(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white60 : Colors.black54,
      letterSpacing: 1.5,
    );

    final nameStyle = GoogleFonts.outfit(
      fontSize: 38,
      fontWeight: FontWeight.w900,
      color: AppColors.primary,
      letterSpacing: -0.5,
      shadows: [
        Shadow(
          blurRadius: 15.0,
          color: AppColors.primary.withOpacity(0.3),
          offset: const Offset(0, 4),
        ),
      ],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              // Premium Pulsing Welcome Icon Circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.08),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.24),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.emoji_emotions_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ),
              )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.easeOutBack)
                  .then()
                  .shake(hz: 2, duration: 1500.ms, curve: Curves.easeInOut),
              
              const SizedBox(height: 32),
              
              // Animated welcome text
              Text(
                'Welcome',
                style: titleStyle,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.2, end: 0.0, curve: Curves.easeOut),
              
              const SizedBox(height: 8),
              
              // Animated user/worker name
              Text(
                widget.args.name,
                style: nameStyle,
                textAlign: TextAlign.center,
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 800.ms)
                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack),
                  
              const SizedBox(height: 48),
              
              // Premium loading dot micro-animation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  )
                      .animate(delay: (index * 150).ms)
                      .scale(duration: 400.ms, curve: Curves.easeInOut)
                      .then()
                      .scale(duration: 400.ms, curve: Curves.easeInOut);
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}
