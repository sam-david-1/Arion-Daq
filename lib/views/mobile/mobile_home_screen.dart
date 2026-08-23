import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/daq_provider.dart';
import '../../theme/mobile_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';

class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key});

  Widget _buildKpiCard(String title, String value, String unit, Color accent) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.15),
            MobileTheme.backgroundEnd.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: MobileTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(color: MobileTheme.textBright, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Fira Code')),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSparklineCard(BuildContext context, String title, List<FlSpot> spots, Color color) {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: MobileTheme.glassDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(color: MobileTheme.textBright, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: spots.isEmpty 
              ? const Center(child: Text('No Data Available', style: TextStyle(color: MobileTheme.textMuted)))
              : LineChart(
                  LineChartData(
                    clipData: const FlClipData.all(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withOpacity(0.3),
                              color.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool hasData = provider.loadedLogData.isNotEmpty;

        String tpsVal = provider.maxTps?.toStringAsFixed(1) ?? '--';
        String brakeVal = provider.maxBrake?.toStringAsFixed(1) ?? '--';
        String durVal = hasData ? (provider.totalDurationMs / 1000).toStringAsFixed(1) : '--';

        List<FlSpot> tpsSpots = [];
        List<FlSpot> brakeSpots = [];
        
        if (hasData) {
          int step = (provider.loadedLogData.length / 100).ceil().clamp(1, 1000);
          for (int i = 0; i < provider.loadedLogData.length; i += step) {
            var item = provider.loadedLogData[i];
            double t = item['Time_ms'] as double;
            if (item['TPS_Deg'] != null) tpsSpots.add(FlSpot(t, item['TPS_Deg']));
            if (item['Brake_Bar'] != null) brakeSpots.add(FlSpot(t, item['Brake_Bar']));
          }
        }

        return Stack(
          children: [
            // Ambient background glow
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MobileTheme.primaryNeon.withOpacity(0.05),
                  boxShadow: [BoxShadow(color: MobileTheme.primaryNeon.withOpacity(0.05), blurRadius: 100, spreadRadius: 50)],
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120), // Bottom padding for floating nav
              physics: const BouncingScrollPhysics(),
              children: [
                Text('SESSION METRICS', style: TextStyle(color: MobileTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    children: [
                      _buildKpiCard('THROTTLE', tpsVal, '%', MobileTheme.primaryNeon),
                      _buildKpiCard('BRAKES', brakeVal, 'bar', MobileTheme.dangerGlow),
                      _buildKpiCard('TIME', durVal, 's', MobileTheme.successGlow),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('TELEMETRY INSIGHTS', style: TextStyle(color: MobileTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                _buildSparklineCard(context, 'Throttle Trace', tpsSpots, MobileTheme.primaryNeon),
                _buildSparklineCard(context, 'Brake Pressure Trace', brakeSpots, MobileTheme.dangerGlow),
              ],
            ),
          ],
        );
      },
    );
  }
}
