import 'package:flutter/material.dart';
import '../../../core/utils/haptics.dart';
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

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoOpacity;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();
    AppHaptics.buttonClick();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // ── Background: vegetable line art ──
          Positioned.fill(
            child: Image.asset(
              'assets/splash_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // ── Centered logo ──
          Center(
            child: AnimatedBuilder(
              animation: _logoOpacity,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: 0.9 + (_logoOpacity.value * 0.1),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Image.asset(
                  'assets/orderkart_logo.jpg',
                  width: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'OrderKart',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom loading bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: AnimatedBuilder(
              animation: _progressValue,
              builder: (context, _) {
                return Center(
                  child: SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressValue.value,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFE8A317),
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
