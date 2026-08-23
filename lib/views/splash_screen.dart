import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/racing_theme.dart';
import '../main.dart'; // To access MainDashboardShell

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'LOADING MODULES...';

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 2000));
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ARION', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 64, fontWeight: FontWeight.bold))
                    .animate().fadeIn(duration: 400.ms).moveY(begin: 10, end: 0),
                const SizedBox(width: 12),
                Text('DAQ', style: TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold))
                    .animate().fadeIn(delay: 200.ms, duration: 400.ms).moveY(begin: 10, end: 0),
              ],
            ),
            const SizedBox(height: 12),
            Text('AR25 · DATA ACQUISITION SYSTEM', style: TextStyle(color: RacingTheme.textMuted, fontSize: 20, fontFamily: 'JetBrains Mono'))
                .animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 2,
              child: Stack(
                children: [
                  Container(color: RacingTheme.border),
                  Container(color: const Color(0xFF7DD3FC))
                      .animate()
                      .scaleX(begin: 0, end: 1, duration: 1500.ms, alignment: Alignment.centerLeft),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
