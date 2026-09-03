import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../widgets/zoomable_chart.dart';
import '../services/parameter_registry.dart';

class BrakeSystemTab extends StatefulWidget {
  const BrakeSystemTab({super.key});

  @override
  State<BrakeSystemTab> createState() => _BrakeSystemTabState();
}

class _BrakeSystemTabState extends State<BrakeSystemTab> {

  Widget _buildChart(String title, Color color, List<FlSpot> spots, double minX, double maxX, {bool isNa = false, double? thresholdLine, double? minY, double? maxY}) {
    return Container(
      decoration: BoxDecoration(
        color: RacingTheme.background,
        border: Border.all(color: RacingTheme.border),
      ),
      child: isNa 
        ? Center(child: Text('$title — Data not available', style: RacingTheme.chartTitleStyle))
        : Stack(
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
                    extraLinesData: ExtraLinesData(
                      horizontalLines: thresholdLine != null ? [
                        HorizontalLine(
                          y: thresholdLine,
                          color: RacingTheme.danger,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: RacingTheme.chartTextStyle.copyWith(color: RacingTheme.danger, fontSize: 10),
                            labelResolver: (l) => 'THRESHOLD',
                          )
                        )
                      ] : [],
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
                          reservedSize: 44,
                          interval: (maxY != null && minY != null) ? ((maxY - minY) / 5).clamp(0.1, double.infinity) : null,
                          getTitlesWidget: (val, meta) {
                            if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                            String text;
                            if (val >= 1000) {
                              text = '${(val / 1000).toStringAsFixed(1)}k';
                            } else if (val <= -1000) {
                              text = '${(val / 1000).toStringAsFixed(1)}k';
                            } else {
                              text = val.toStringAsFixed(1);
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(text, 
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
                            '${s.y.toStringAsFixed(1)} @ ${(s.x / 1000).toStringAsFixed(1)}s',
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
            ],
          ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, List<Widget> charts) {
    if (charts.isEmpty) {
      return Center(child: Text('No brake data available in this log.', style: RacingTheme.chartTitleStyle));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: charts.length,
        itemBuilder: (context, index) => charts[index],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, List<Widget> charts) {
    if (charts.isEmpty) {
      return Center(child: Text('No brake data available.', style: RacingTheme.chartTitleStyle));
    }
    
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: isLandscape
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: charts.length,
                itemBuilder: (context, index) => charts[index],
              )
            : Column(
                children: charts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(height: 200, child: c),
                )).toList(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool hasData = provider.loadedLogData.isNotEmpty;
        double minX = 0;
        double maxX = hasData ? provider.totalDurationMs.toDouble() : 1000;

        List<Widget> charts = [];

        if (hasData) {
          
          List<String> brakeChannels = provider.availableChannels.where((c) {
            final def = ParameterRegistry().getParameter(c);
            return def.group == 'BRAKES' || (def.group == 'TEMPERATURES' && def.displayName.toLowerCase().contains('brake'));
          }).toList();

          for (String channel in brakeChannels) {
            final def = ParameterRegistry().getParameter(channel);
            // Use cached downsampled spots
            List<FlSpot> spots = provider.downsampledSpots[channel] ?? [];
            double? maxVal = provider.channelStats[channel]?['max'];
            double? minVal = provider.channelStats[channel]?['min'];

            if (spots.isNotEmpty) {
              double? threshold = (def.displayName.toLowerCase().contains('pressure') || def.unit == 'bar') ? SettingsService().brakeWarningThreshold : null;
              charts.add(_buildChart(
                '${def.displayName} (${def.unit})',
                def.color,
                spots,
                minX,
                maxX,
                thresholdLine: threshold,
                minY: minVal != null && minVal < 0 ? minVal : 0,
                maxY: maxVal != null ? (maxVal * 1.2) : null,
              ));
            }
          }
        }

        if (!kIsWeb && Platform.isAndroid) {
          return _buildMobileLayout(context, charts);
        }
        return _buildDesktopLayout(context, charts);
      },
    );
  }
}
