import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../state/daq_provider.dart';
import '../../theme/mobile_theme.dart';
import 'dart:ui';

class MobileTelemetryScreen extends StatelessWidget {
  const MobileTelemetryScreen({super.key});

  Widget _buildGlowingProgressBar(String label, double value, double max, Color color, String unit) {
    double pct = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: MobileTheme.textBright, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${value.toStringAsFixed(1)} $unit', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Fira Code', shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 8)])),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 20,
            decoration: MobileTheme.glassDecoration(radius: 10),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: pct * 400, // Approximate screen width
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteeringWheel(double angle) {
    return Column(
      children: [
        Text('STEERING', style: TextStyle(color: MobileTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 32),
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing ring
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 2),
                boxShadow: [
                  BoxShadow(color: MobileTheme.primaryNeon.withOpacity(0.05), blurRadius: 40, spreadRadius: 10)
                ]
              ),
            ),
            // The Wheel
            AnimatedRotation(
              turns: angle / 360,
              duration: const Duration(milliseconds: 100),
              child: CustomPaint(
                size: const Size(200, 200),
                painter: SteeringWheelPainter(),
              ),
            ),
            // Center angle text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: MobileTheme.glassDecoration(radius: 20),
              child: Text('${angle.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Fira Code')),
            )
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        if (provider.loadedLogData.isEmpty) {
          return const Center(
            child: Text('Load a session to view live telemetry', style: TextStyle(color: MobileTheme.textMuted)),
          );
        }

        double tps = provider.currentSensorValues['TPS_Deg'] ?? 0.0;
        double brake = provider.currentSensorValues['Brake_Bar'] ?? 0.0;
        double angle = provider.currentSensorValues['Angle'] ?? 0.0;

        return Stack(
          children: [
            Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MobileTheme.dangerGlow.withOpacity(0.05),
                  boxShadow: [BoxShadow(color: MobileTheme.dangerGlow.withOpacity(0.05), blurRadius: 80, spreadRadius: 40)],
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: MobileTheme.glassDecoration(radius: 24),
                    child: Column(
                      children: [
                        _buildGlowingProgressBar('Throttle', tps, 100, MobileTheme.primaryNeon, '%'),
                        const SizedBox(height: 16),
                        _buildGlowingProgressBar('Brake', brake, 80, MobileTheme.dangerGlow, 'bar'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: MobileTheme.glassDecoration(radius: 24),
                    child: _buildSteeringWheel(angle),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class SteeringWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final accentPaint = Paint()
      ..color = MobileTheme.primaryNeon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final spokePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    // Draw main rim
    canvas.drawCircle(center, radius - 6, rimPaint);

    // Draw top center accent
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      -pi / 2 - 0.2,
      0.4,
      false,
      accentPaint,
    );

    // Draw left spoke
    canvas.drawLine(
      Offset(center.dx - radius + 12, center.dy),
      Offset(center.dx - 40, center.dy),
      spokePaint,
    );

    // Draw right spoke
    canvas.drawLine(
      Offset(center.dx + radius - 12, center.dy),
      Offset(center.dx + 40, center.dy),
      spokePaint,
    );
    
    // Draw bottom spoke
    canvas.drawLine(
      Offset(center.dx, center.dy + radius - 12),
      Offset(center.dx, center.dy + 40),
      spokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
