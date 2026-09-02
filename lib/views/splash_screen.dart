import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/racing_theme.dart';
import '../main.dart'; // To access MainDashboardShell

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startSequence();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 3100));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(opacity: animation, child: const MainDashboardShell());
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: Animate(
        effects: [
          FadeEffect(begin: 1.0, end: 0.0, delay: 2700.ms, duration: 400.ms),
        ],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase 1: Logo — transparent, no background box
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  final glowOpacity = 0.15 + (_glowController.value * 0.35);
                  return Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7DD3FC).withValues(alpha: glowOpacity),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/images/team_logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox(width: 200, height: 200),
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    end: const Offset(1.0, 1.0),
                    duration: 800.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 40),

              // Phase 2: TEAM ARION — letters slide up one by one
              Row(
                mainAxisSize: MainAxisSize.min,
                children: "TEAM ARION".split('').map((char) {
                  return Padding(
                    padding: EdgeInsets.only(right: char == ' ' ? 20 : 0),
                    child: Text(
                      char,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3 * 48, // 0.3em
                      ),
                    ),
                  );
                }).toList().animate(interval: 60.ms)
                  .fadeIn(delay: 600.ms, duration: 400.ms)
                  .slideY(begin: 0.5, end: 0, delay: 600.ms, duration: 400.ms, curve: Curves.easeOut),
              ),

              const SizedBox(height: 20),

              // Phase 3: DAQ DASHBOARD
              const Text(
                'DAQ DASHBOARD',
                style: TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontSize: 20,
                  fontFamily: 'JetBrains Mono',
                  letterSpacing: 0.2 * 20, // 0.2em
                ),
              ).animate()
                .fadeIn(delay: 1200.ms, duration: 400.ms),

              const SizedBox(height: 12),

              // Phase 4: AR25...
              Text(
                'AR25 · DATA ACQUISITION SYSTEM',
                style: TextStyle(
                  color: RacingTheme.textMuted,
                  fontSize: 14,
                  letterSpacing: 2.0,
                ),
              ).animate()
                .fadeIn(delay: 1600.ms, duration: 400.ms),

              const SizedBox(height: 40),

              // Phase 5: Progress bar
              SizedBox(
                width: 300,
                height: 3,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: RacingTheme.border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF7DD3FC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                        .animate()
                        .scaleX(
                          begin: 0,
                          end: 1,
                          alignment: Alignment.centerLeft,
                          delay: 1400.ms,
                          duration: 1200.ms,
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ).animate().fadeIn(delay: 1400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
