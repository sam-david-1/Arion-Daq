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

  /// Resolve which channel name to use for lateral / longitudinal G.
  /// Prioritizes exact matches for known proper G channels first.
  static String? _findChannel(List<String> channels, List<String> keywords) {
    // 1. Try exact matches first
    for (var kw in keywords) {
      for (var c in channels) {
        if (c.toLowerCase() == kw) return c;
      }
    }
    // 2. Try partial matches
    for (var kw in keywords) {
      for (var c in channels) {
        if (c.toLowerCase().contains(kw)) return c;
      }
    }
    return null;
  }

  /// Read a G value from a data row.
  static double _readG(Map<String, dynamic> row, String channel) {
    return (row[channel] as num?)?.toDouble() ?? 0;
  }

  /// Compute the auto-radius for the friction circle from actual data.
  static double _computeMaxG(List<Map<String, dynamic>> data, String latCh, String longCh) {
    double maxG = 0;
    for (var row in data) {
      double lat = _readG(row, latCh);
      double lng = _readG(row, longCh);
      double g = math.sqrt(lat * lat + lng * lng);
      if (g > maxG) maxG = g;
    }
    return maxG;
  }

  /// Binary search for the data index closest to a target timestamp.
  static int _binarySearch(List<Map<String, dynamic>> data, int targetMs) {
    int lo = 0, hi = data.length - 1;
    while (lo < hi) {
      int mid = (lo + hi) >> 1;
      if ((data[mid]['Time_ms'] as num).toDouble() < targetMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Widget _buildGgScatter(BuildContext context, DaqProvider provider, bool hasData) {
    final channels = provider.availableChannels;
    
    // Explicitly target the correct DAQ channels first
    final latChannel = _findChannel(channels, ['lataccel_g', 'lat_g', 'accel_y', 'lat', 'gyro_x']);
    final longChannel = _findChannel(channels, ['longaccel_g', 'long_g', 'accel_x', 'long', 'gyro_y']);
    final speedChannel = _findChannel(channels, ['speed', 'spd', 'vel']);

    // Current G values
    double curLatG = 0;
    double curLongG = 0;
    // Use pre-cached friction radius from provider (computed once on data load)
    double frictionRadius = provider.cachedFrictionRadius;

    if (hasData && latChannel != null && longChannel != null) {
      int idx = provider.loadedLogData.length > 1
          ? _binarySearch(provider.loadedLogData, provider.currentTimestampMs)
          : 0;
      var row = provider.loadedLogData[idx];
      curLatG = _readG(row, latChannel);
      curLongG = _readG(row, longChannel);
    }

    double totalG = math.sqrt(curLatG * curLatG + curLongG * curLongG);

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
            child: (!hasData || latChannel == null || longChannel == null)
              ? Center(child: Text('IMU Data N/A', style: Theme.of(context).textTheme.bodySmall))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: Column(
                    children: [
                      // TOP: Long G readout
                      _GReadout(label: 'LONG G', value: curLongG, color: const Color(0xFF7DD3FC), fontSize: 20),
                      Expanded(
                        child: Row(
                          children: [
                            // LEFT: Lat L readout
                            _GReadout(label: 'LAT L', value: -curLatG.abs(), color: const Color(0xFFF59E0B), fontSize: 16, vertical: true),
                            // CENTER: Diagram
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final size = math.min(constraints.maxWidth, constraints.maxHeight);
                                  return Center(
                                    child: SizedBox(
                                      width: size,
                                      height: size,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          RepaintBoundary(
                                            child: CustomPaint(
                                              size: Size(size, size),
                                              painter: _GgScatterPainter(
                                                allData: provider.loadedLogData,
                                                currentTimestampMs: provider.currentTimestampMs,
                                                latChannel: latChannel,
                                                longChannel: longChannel,
                                                speedChannel: speedChannel,
                                                frictionRadius: frictionRadius,
                                              ),
                                            ),
                                          ),
                                          // Axis labels
                                          Positioned(top: 2, left: 0, right: 0, child: Center(child: Text('Accel (+G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold)))),
                                          Positioned(bottom: 2, left: 0, right: 0, child: Center(child: Text('Brake (-G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold)))),
                                          Positioned(right: 2, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: 1, child: Text('Right (+G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))))),
                                          Positioned(left: 2, top: 0, bottom: 0, child: Center(child: RotatedBox(quarterTurns: 3, child: Text('Left (-G)', style: RacingTheme.chartTextStyle.copyWith(fontSize: 11, fontWeight: FontWeight.bold))))),
                                          // Position readout box
                                          Positioned(
                                            top: -24,
                                            left: -24,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF111418),
                                                border: Border.all(color: const Color(0xFF1E2530)),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('LAT:  ${curLatG >= 0 ? "+" : ""}${curLatG.toStringAsFixed(2)} g', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: Colors.white)),
                                                  Text('LONG: ${curLongG >= 0 ? "+" : ""}${curLongG.toStringAsFixed(2)} g', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: Colors.white)),
                                                  Text('TOTAL: ${totalG.toStringAsFixed(2)} g', style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 14, color: Color(0xFF7DD3FC))),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // RIGHT: Lat R readout
                            _GReadout(label: 'LAT R', value: curLatG.abs(), color: const Color(0xFFF59E0B), fontSize: 16, vertical: true),
                          ],
                        ),
                      ),
                      // BOTTOM: Brake G readout
                      _GReadout(label: 'BRAKE G', value: -curLongG.abs(), color: const Color(0xFFEF4444), fontSize: 20),
                      // Friction limit label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Friction limit: ${frictionRadius.toStringAsFixed(1)}g',
                          style: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
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
                // Bottom 70%: Charts — single column, full-width
                Expanded(
                  flex: 70,
                  child: imuCharts.isEmpty 
                    ? Center(child: Text('IMU Time Series N/A', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.builder(
                        padding: const EdgeInsets.all(4),
                        itemCount: imuCharts.length,
                        itemBuilder: (context, index) => SizedBox(
                          height: 220,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: imuCharts[index],
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
                            child: Text('${(val/1000).round()}s', 
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
          // Title is now rendered by ZoomableChart header row
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
            // Use cached downsampled spots
            List<FlSpot> spots = provider.downsampledSpots[channel] ?? [];
            double? minVal = provider.channelStats[channel]?['min'];
            double? maxVal = provider.channelStats[channel]?['max'];
            
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

/// Small readout widget for G values around the diagram.
class _GReadout extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double fontSize;
  final bool vertical;

  const _GReadout({
    required this.label,
    required this.value,
    required this.color,
    this.fontSize = 20,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final sign = value >= 0 ? '+' : '';
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: RacingTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          '$sign${value.toStringAsFixed(2)} g',
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, fontFamily: 'JetBrains Mono'),
        ),
      ],
    );

    if (vertical) {
      return SizedBox(
        width: 60,
        child: Center(child: RotatedBox(quarterTurns: vertical ? 0 : 0, child: content)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(child: content),
    );
  }
}

class _GgScatterPainter extends CustomPainter {
  final List<Map<String, dynamic>> allData;
  final int currentTimestampMs;
  final String latChannel;
  final String longChannel;
  final String? speedChannel;
  final double frictionRadius;
  
  _GgScatterPainter({
    required this.allData, 
    required this.currentTimestampMs,
    required this.latChannel,
    required this.longChannel,
    this.speedChannel,
    required this.frictionRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allData.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Display range = frictionRadius (already auto-calculated), add 10% margin
    double displayG = frictionRadius * 1.1;
    final scale = (size.width / 2) / displayG;

    final paintGrid = Paint()..color = RacingTheme.border..style = PaintingStyle.stroke..strokeWidth = 1;
    final paintLimit = Paint()..color = RacingTheme.danger..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    
    // Axes
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paintGrid);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paintGrid);

    // Friction circle — auto-calculated radius
    _drawDashedCircle(canvas, center, frictionRadius * scale, paintLimit);

    // Find current index using binary search
    int currentIndex = _binarySearch(allData, currentTimestampMs);

    // Plot ALL data points with state-based coloring
    final paintDots = Paint()..style = PaintingStyle.fill;
    
    for (var row in allData) {
      double lat = (row[latChannel] as num?)?.toDouble() ?? 0;
      double lng = (row[longChannel] as num?)?.toDouble() ?? 0;
      
      // State-based coloring
      paintDots.color = _stateColor(lat, lng);
      
      Offset pos = Offset(center.dx + lat * scale, center.dy - lng * scale);
      canvas.drawCircle(pos, 2, paintDots);
    }
    
    // Trail of last 50 points
    final paintTrail = Paint()..style = PaintingStyle.fill;
    int trailStart = math.max(0, currentIndex - 50);
    List<Offset> trail = [];
    
    for (int i = trailStart; i <= currentIndex; i++) {
      double lat = (allData[i][latChannel] as num?)?.toDouble() ?? 0;
      double lng = (allData[i][longChannel] as num?)?.toDouble() ?? 0;
      trail.add(Offset(center.dx + lat * scale, center.dy - lng * scale));
    }
    
    for (int i = 0; i < trail.length; i++) {
      double opacity = (i / math.max(trail.length, 1)).clamp(0.0, 1.0);
      paintTrail.color = const Color(0xFF7DD3FC).withOpacity(opacity);
      canvas.drawCircle(trail[i], 5, paintTrail);
    }

    // Crosshair lines at current G position
    if (trail.isNotEmpty) {
      final crosshairPaint = Paint()
        ..color = const Color(0xFF7DD3FC).withOpacity(0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      // Horizontal dashed line at current Y (long G)
      _drawDashedLine(canvas, Offset(0, trail.last.dy), Offset(size.width, trail.last.dy), crosshairPaint);
      // Vertical dashed line at current X (lat G)
      _drawDashedLine(canvas, Offset(trail.last.dx, 0), Offset(trail.last.dx, size.height), crosshairPaint);
    }
    
    // Current point with glow
    if (trail.isNotEmpty) {
      final paintGlow = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final paintCurrent = Paint()..color = Colors.white..style = PaintingStyle.fill;
      
      canvas.drawCircle(trail.last, 14, paintGlow);
      canvas.drawCircle(trail.last, 8, paintCurrent);
    }
  }

  /// Returns a color based on the vehicle's dynamic state.
  Color _stateColor(double latG, double longG) {
    const threshold = 0.15;
    bool braking = longG < -threshold;
    bool accelerating = longG > threshold;
    bool cornering = latG.abs() > threshold;

    if (braking && cornering) return Colors.orange.withOpacity(0.6);   // combined
    if (accelerating && cornering) return Colors.orange.withOpacity(0.6);
    if (braking) return const Color(0xFFEF4444).withOpacity(0.6);       // braking
    if (accelerating) return const Color(0xFF22C55E).withOpacity(0.6);  // accelerating
    if (cornering) return const Color(0xFFF59E0B).withOpacity(0.6);     // cornering
    return const Color(0xFF3B82F6).withOpacity(0.6);                    // coasting
  }
  
  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    final dashWidth = 5.0;
    final dashSpace = 5.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();
    if (dashCount <= 0) return;
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

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final unitX = dx / dist;
    final unitY = dy / dist;
    double drawn = 0;
    bool draw = true;
    while (drawn < dist) {
      final segLen = math.min(draw ? dashWidth : dashSpace, dist - drawn);
      if (draw) {
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(start.dx + unitX * (drawn + segLen), start.dy + unitY * (drawn + segLen)),
          paint,
        );
      }
      drawn += segLen;
      draw = !draw;
    }
  }

  /// Binary search for current index
  int _binarySearch(List<Map<String, dynamic>> data, int targetMs) {
    int lo = 0, hi = data.length - 1;
    while (lo < hi) {
      int mid = (lo + hi) >> 1;
      if ((data[mid]['Time_ms'] as num).toDouble() < targetMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  bool shouldRepaint(covariant _GgScatterPainter oldDelegate) {
    return oldDelegate.currentTimestampMs != currentTimestampMs ||
           oldDelegate.frictionRadius != frictionRadius ||
           !identical(oldDelegate.allData, allData);
  }
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
