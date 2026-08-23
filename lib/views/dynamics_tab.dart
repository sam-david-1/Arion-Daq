import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../widgets/zoomable_chart.dart';
import '../services/parameter_registry.dart';

class DynamicsTab extends StatelessWidget {
  const DynamicsTab({super.key});

  Widget _buildGgScatter(BuildContext context, DaqProvider provider, bool hasData) {
    return Container(
      decoration: BoxDecoration(
        color: RacingTheme.background,
        border: Border.all(color: RacingTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TRACTION CIRCLE (G-G DIAGRAM)', style: RacingTheme.chartTitleStyle),
                if (hasData)
                  InkWell(
                    onTap: () {
                      provider.askAi("Analyze the Traction Circle (G-G Diagram) for this session, evaluating cornering vs braking forces.");
                      provider.setAiSidebarMode(true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: RacingTheme.primaryAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: RacingTheme.primaryAccent)),
                      child: Text('✦ Ask AI', style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: () {
              // Smart detection: check for ANY lateral/longitudinal G source
              final channels = provider.availableChannels;
              bool hasLatG = channels.contains('LatAccel_G') || channels.contains('Ay') || channels.contains('Lateral G') || channels.contains('Gyro_X');
              bool hasLongG = channels.contains('LongAccel_G') || channels.contains('Ax') || channels.contains('Longitudinal G') || channels.contains('Gyro_Y');
              if (!hasData || !hasLatG || !hasLongG) {
                return Center(child: Text('IMU Data N/A', style: Theme.of(context).textTheme.bodySmall));
              }
              return LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(constraints.maxWidth, constraints.maxHeight) - 40;
                    return Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: size,
                            height: size,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _GgScatterPainter(
                                  trail: provider.ggTrail,
                                  allData: provider.loadedLogData,
                                  currentTimestampMs: provider.currentTimestampMs,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: Text('Accel (+G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Positioned(
                            bottom: 0,
                            child: Text('Brake (-G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Positioned(
                            right: 0,
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text('Right (+G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text('Left (-G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
            }(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstrument(BuildContext context, String title, Widget child, bool isNa) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: RacingTheme.panel,
          border: Border.all(color: RacingTheme.border),
        ),
        child: isNa 
          ? Center(child: Text('$title\nN/A', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(title, style: RacingTheme.chartTitleStyle),
                ),
                Expanded(child: child),
              ],
            ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, DaqProvider provider, bool hasData, double pitch, double roll, double yaw, List<Widget> imuCharts) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // Left 50%
          Expanded(
            flex: 50,
            child: _buildGgScatter(context, provider, hasData),
          ),
          // Right 50%
          Expanded(
            flex: 50,
            child: Column(
              children: [
                // Top 30%: Instruments
                Expanded(
                  flex: 30,
                  child: Row(
                    children: [
                      _buildInstrument(context, 'PITCH', _PitchInstrument(pitch: pitch), false),
                      _buildInstrument(context, 'ROLL', _RollInstrument(roll: roll), false),
                      _buildInstrument(context, 'YAW', _YawInstrument(yaw: yaw), false),
                    ],
                  ),
                ),
                // Bottom 70%: Charts
                Expanded(
                  flex: 70,
                  child: imuCharts.isEmpty 
                    ? Center(child: Text('IMU Time Series N/A', style: Theme.of(context).textTheme.bodySmall))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: imuCharts.length,
                        itemBuilder: (context, index) => imuCharts[index],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DaqProvider provider, bool hasData, double pitch, double roll, double yaw, List<Widget> imuCharts) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(
              height: 350,
              child: _buildGgScatter(context, provider, hasData),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: Row(
                children: [
                  _buildInstrument(context, 'PITCH', _PitchInstrument(pitch: pitch), false),
                  _buildInstrument(context, 'ROLL', _RollInstrument(roll: roll), false),
                  _buildInstrument(context, 'YAW', _YawInstrument(yaw: yaw), false),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...imuCharts.map((c) => SizedBox(height: 250, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: c))),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, String title, Color color, List<FlSpot> spots, double minX, double maxX, {double? minY, double? maxY}) {
    return Container(
      decoration: BoxDecoration(
        color: RacingTheme.background,
        border: Border.all(color: RacingTheme.border),
      ),
      child: Stack(
        children: [
          ZoomableChart(
            originalMinX: minX,
            originalMaxX: maxX,
            channelName: title,
            builder: (context, currentMinX, currentMaxX) => RepaintBoundary(
              child: LineChart(
                LineChartData(
                  clipData: const FlClipData.all(),
                  minX: currentMinX,
                  maxX: currentMaxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: color,
                      barWidth: SettingsService().chartLineThickness,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: maxX > 0 ? (maxX / 8).clamp(1.0, double.infinity) : 1000,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${(val/1000).toStringAsFixed(1)}s', 
                              style: TextStyle(color: RacingTheme.textPrimary, fontSize: 11)),
                          );
                        },
                      )
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: (maxY != null && minY != null) ? ((maxY - minY) / 4).clamp(0.1, double.infinity) : null,
                        getTitlesWidget: (val, meta) {
                          if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(val.toStringAsFixed(1), 
                              textAlign: TextAlign.right,
                              style: TextStyle(color: RacingTheme.textPrimary, fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
                    getDrawingVerticalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      if (Provider.of<DaqProvider>(context).crosshairTime != null)
                        VerticalLine(
                          x: Provider.of<DaqProvider>(context).crosshairTime!,
                          color: RacingTheme.textSecondary,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      VerticalLine(
                        x: Provider.of<DaqProvider>(context).currentTimestampMs.toDouble(),
                        color: RacingTheme.danger,
                        strokeWidth: 2,
                      ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    getTouchLineEnd: (b, i) => double.infinity,
                    getTouchedSpotIndicator: (bar, spots) {
                      return spots.map((s) => TouchedSpotIndicatorData(
                        const FlLine(color: Colors.transparent),
                        const FlDotData(show: false),
                      )).toList();
                    },
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (spot) => RacingTheme.panel,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((s) => LineTooltipItem(
                          '${s.y.toStringAsFixed(1)}\\n@ ${(s.x / 1000).toStringAsFixed(1)}s',
                          RacingTheme.chartTextStyle,
                        )).toList();
                      },
                    ),
                    touchCallback: (e, r) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (r?.lineBarSpots != null && r!.lineBarSpots!.isNotEmpty) {
                          Provider.of<DaqProvider>(context, listen: false).setCrosshairTime(r.lineBarSpots!.first.x);
                        } else {
                          Provider.of<DaqProvider>(context, listen: false).setCrosshairTime(null);
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12, left: 12,
            child: Text(title, style: TextStyle(color: RacingTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
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
        
        double pitch = 0;
        double roll = 0;
        double yaw = 0;
        
        if (hasData) {
          int currentIdx = (provider.currentTimestampMs / 10).floor();
          if (currentIdx >= 0 && currentIdx < provider.loadedLogData.length) {
            var row = provider.loadedLogData[currentIdx];
            
            double? p = (row['Pitch_deg'] as num?)?.toDouble() ?? (row['PitchRate_'] as num?)?.toDouble();
            double? r = (row['Roll_deg'] as num?)?.toDouble() ?? (row['RollRate_d'] as num?)?.toDouble();
            double? y = (row['Yaw_deg'] as num?)?.toDouble() ?? (row['YawRate_c'] as num?)?.toDouble();
            
            // Fallback to old hardcoded names if custom ones not found
            if (p == null) {
              double? gy = (row['Gyro_Y'] as num?)?.toDouble() ?? (row['Gy'] as num?)?.toDouble();
              if (gy != null) pitch = gy / 131.0;
            } else {
              pitch = p;
            }
            
            if (r == null) {
              double? gx = (row['Gyro_X'] as num?)?.toDouble() ?? (row['Gx'] as num?)?.toDouble();
              if (gx != null) roll = gx / 131.0;
            } else {
              roll = r;
            }
            
            if (y == null) {
              double? gz = (row['Gyro_Z'] as num?)?.toDouble() ?? (row['Gz'] as num?)?.toDouble();
              if (gz != null) yaw = gz / 131.0;
            } else {
              yaw = y;
            }
          }
        }

        double minX = 0;
        double maxX = hasData ? provider.totalDurationMs.toDouble() : 1000;
        
        List<Widget> imuCharts = [];
        
        if (hasData) {
          
          List<String> imuChannels = provider.availableChannels.where((c) {
            final def = ParameterRegistry().getParameter(c);
            return def.group == 'IMU';
          }).toList();
          
          // Deduplicate: if both a raw channel and its derived counterpart
          // share the same displayName, keep only the derived one.
          Set<String> seenDisplayNames = {};
          List<String> deduped = [];
          // Process derived channels first so they get priority
          imuChannels.sort((a, b) {
            final aDerived = ParameterRegistry().getParameter(a).isDerived ? 0 : 1;
            final bDerived = ParameterRegistry().getParameter(b).isDerived ? 0 : 1;
            return aDerived.compareTo(bDerived);
          });
          for (String ch in imuChannels) {
            final def = ParameterRegistry().getParameter(ch);
            if (!seenDisplayNames.contains(def.displayName)) {
              seenDisplayNames.add(def.displayName);
              deduped.add(ch);
            }
          }
          imuChannels = deduped;
          
          for (String channel in imuChannels) {
            final def = ParameterRegistry().getParameter(channel);
            List<FlSpot> spots = [];
            double? minVal, maxVal;
            
            for (var item in provider.loadedLogData) {
              double t = item['Time_ms'] as double;
              if (item[channel] != null) {
                double val = (item[channel] as num).toDouble();
                spots.add(FlSpot(t, val));
                if (maxVal == null || val > maxVal) maxVal = val;
                if (minVal == null || val < minVal) minVal = val;
              }
            }
            
            if (spots.isNotEmpty) {
              imuCharts.add(_buildChart(
                context,
                '${def.displayName} (${def.unit})', 
                def.color, 
                spots, 
                minX, 
                maxX,
                minY: minVal != null ? (minVal < 0 ? minVal * 1.2 : 0) : null,
                maxY: maxVal != null ? (maxVal > 0 ? maxVal * 1.2 : 0) : null,
              ));
            }
          }
        }

        if (!kIsWeb && Platform.isAndroid) {
          return _buildMobileLayout(context, provider, hasData, pitch, roll, yaw, imuCharts);
        }
        return _buildDesktopLayout(context, provider, hasData, pitch, roll, yaw, imuCharts);
      },
    );
  }
}

class _GgScatterPainter extends CustomPainter {
  final List<Offset> trail;
  final List<Map<String, dynamic>> allData;
  final int currentTimestampMs;
  
  _GgScatterPainter({required this.trail, required this.allData, required this.currentTimestampMs});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 6; // -3g to +3g

    final paintGrid = Paint()..color = RacingTheme.border..style = PaintingStyle.stroke..strokeWidth = 1;
    final paintLimit = Paint()..color = RacingTheme.danger..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    
    // Axes
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paintGrid);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paintGrid);

    // 2g limit circle (dashed logic simplified for custom paint, we just draw solid for now unless we implement path metrics, wait prompt says dashed)
    _drawDashedCircle(canvas, center, 2 * scale, paintLimit);

    // Scatter points
    final paintDots = Paint()
      ..color = RacingTheme.primaryAccent.withOpacity(0.4)
      ..style = PaintingStyle.fill;
      
    // Trail
    final paintTrail = Paint()
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < trail.length; i++) {
      double opacity = (i / trail.length).clamp(0.0, 1.0);
      paintTrail.color = RacingTheme.primaryAccent.withOpacity(opacity);
      Offset pos = Offset(center.dx + trail[i].dx * scale, center.dy - trail[i].dy * scale);
      canvas.drawCircle(pos, 3, paintTrail);
    }
    
    // Current point
    if (trail.isNotEmpty) {
      final paintCurrent = Paint()..color = Colors.white..style = PaintingStyle.fill;
      Offset pos = Offset(center.dx + trail.last.dx * scale, center.dy - trail.last.dy * scale);
      canvas.drawCircle(pos, 6, paintCurrent);
    }
  }
  
  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    final dashWidth = 5.0;
    final dashSpace = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();
    final sweepAngle = (2 * math.pi) / dashCount;
    
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * sweepAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PitchInstrument extends StatelessWidget {
  final double pitch;
  const _PitchInstrument({required this.pitch});
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _PitchPainter(pitch),
        size: Size.infinite,
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final double pitch;
  _PitchPainter(this.pitch);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pitch * math.pi / 180);
    
    final paintSky = Paint()..color = Colors.blue;
    final paintEarth = Paint()..color = Colors.brown;
    
    canvas.drawRect(Rect.fromLTWH(-size.width, -size.height, size.width * 2, size.height), paintSky);
    canvas.drawRect(Rect.fromLTWH(-size.width, 0, size.width * 2, size.height), paintEarth);
    
    final paintLine = Paint()..color = Colors.white..strokeWidth = 2;
    canvas.drawLine(Offset(-20, 0), Offset(20, 0), paintLine);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RollInstrument extends StatelessWidget {
  final double roll;
  const _RollInstrument({required this.roll});
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.rotate(
        angle: roll * math.pi / 180,
        child: Icon(Icons.directions_car, size: 60, color: RacingTheme.textPrimary),
      ),
    );
  }
}

class _YawInstrument extends StatelessWidget {
  final double yaw;
  const _YawInstrument({required this.yaw});
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: RacingTheme.border)),
            child: const Center(child: Text('N', style: TextStyle(color: Colors.red, fontSize: 10))),
          ),
          Transform.rotate(
            angle: yaw * math.pi / 180,
            child: Icon(Icons.navigation, size: 40, color: RacingTheme.primaryAccent),
          ),
        ],
      ),
    );
  }
}
