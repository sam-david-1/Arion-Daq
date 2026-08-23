import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../services/parameter_registry.dart';
import '../widgets/channel_selector_list.dart';
import '../widgets/zoomable_chart.dart';
import 'dart:convert';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  List<String> _selectedChannels = [];
  bool _initialized = false;
  final ScrollController _chartsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  void _initChannels(DaqProvider provider) {
    if (_initialized) return;
    if (provider.availableChannels.isEmpty) return;
    
    var saved = SettingsService().getSelectedChannels('overview');
    if (saved.isEmpty) {
      _selectedChannels = List.from(provider.availableChannels);
    } else {
      _selectedChannels = saved.where((c) => provider.availableChannels.contains(c)).toList();
    }
    _initialized = true;
  }

  void _toggleChannel(String channel, bool? value) {
    setState(() {
      if (value == true) {
        if (!_selectedChannels.contains(channel)) _selectedChannels.add(channel);
      } else {
        _selectedChannels.remove(channel);
      }
      SettingsService().setSelectedChannels('overview', _selectedChannels);
    });
  }

  void _selectAll(List<String> available) => setState(() { _selectedChannels = List.from(available); SettingsService().setSelectedChannels('overview', _selectedChannels); });
  void _selectNone() => setState(() { _selectedChannels.clear(); SettingsService().setSelectedChannels('overview', _selectedChannels); });
  void _selectRaw(List<String> available) => setState(() { _selectedChannels = available.where((c) => !ParameterRegistry().getParameter(c).isDerived).toList(); SettingsService().setSelectedChannels('overview', _selectedChannels); });
  void _selectDerived(List<String> available) => setState(() { _selectedChannels = available.where((c) => ParameterRegistry().getParameter(c).isDerived).toList(); SettingsService().setSelectedChannels('overview', _selectedChannels); });

  Widget _buildMetricCard(BuildContext context, String label, String value, String unit, Color color, {List<FlSpot>? sparklineSpots}) {
    return Expanded(
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: RacingTheme.panel,
          border: Border(
            top: BorderSide(color: color, width: 2),
            left: BorderSide(color: RacingTheme.border),
            right: BorderSide(color: RacingTheme.border),
            bottom: BorderSide(color: RacingTheme.border),
          ),
        ),
        child: Stack(
          children: [
            if (sparklineSpots != null && sparklineSpots.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 30,
                child: IgnorePointer(
                  child: LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: sparklineSpots,
                          isCurved: true,
                          color: color.withOpacity(0.4),
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(value, style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ), overflow: TextOverflow.ellipsis),
                      ),
                      if (unit.isNotEmpty && value != 'N/A') ...[
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(unit, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Tooltip Icon
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: 'Detailed metrics for $label',
                child: Icon(Icons.info_outline, size: 12, color: RacingTheme.textMuted),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildChart(String title, Color color, List<FlSpot> spots, double minX, double maxX) {
    bool isNa = spots.isEmpty;
    double? minY;
    double? maxY;
    if (!isNa) {
      minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (minY == maxY) {
        minY -= 1.0;
        maxY += 1.0;
      }
      double range = maxY - minY;
      minY -= range * 0.1;
      maxY += range * 0.1;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: RacingTheme.background,
        border: Border.all(color: RacingTheme.border),
      ),
      child: isNa 
        ? Center(child: Text('${ParameterRegistry().getParameter(title).displayName} — Data not available', style: RacingTheme.chartTitleStyle))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 12, bottom: 4),
                child: Text('${ParameterRegistry().getParameter(title).displayName} Trend', style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ZoomableChart(
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
                            barWidth: 1.5,
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
                          drawHorizontalLine: true,
                          getDrawingHorizontalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
                          getDrawingVerticalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
                        ),
                        extraLinesData: ExtraLinesData(
                          verticalLines: [
                            if (Provider.of<DaqProvider>(context).crosshairTime != null)
                              VerticalLine(
                                x: Provider.of<DaqProvider>(context).crosshairTime!,
                                color: RacingTheme.textSecondary.withValues(alpha: 0.5),
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
                                '${s.y.toStringAsFixed(1)}\n@ ${(s.x / 1000).toStringAsFixed(1)}s',
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
              ),
            ],
          ),
    );
  }



  Widget _buildDesktopLayout(BuildContext context, DaqProvider provider, bool hasData, String tpsVal, String brakeVal, String durVal, String rateVal, String steerVal, String samplesVal, List<FlSpot> tpsSpots, List<FlSpot> brakeSpots, List<FlSpot> angleSpots, double minX, double maxX, String alertText, Color alertColor) {
    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        children: [
          // Top Metrics Row
          Row(
            children: [

              _buildMetricCard(context, 'Peak TPS', tpsVal, '°', RacingTheme.primaryAccent, sparklineSpots: tpsSpots),
              _buildMetricCard(context, 'Peak Brake', brakeVal, 'bar', RacingTheme.danger, sparklineSpots: brakeSpots),
              _buildMetricCard(context, 'Duration', durVal, 's', RacingTheme.success),
              _buildMetricCard(context, 'Sample Rate', rateVal, 'Hz', Colors.purpleAccent),
              _buildMetricCard(context, 'Max Steering', steerVal, '°', RacingTheme.warning, sparklineSpots: angleSpots),
              _buildMetricCard(context, 'Total Samples', samplesVal, '', RacingTheme.primaryAccent),
            ],
          ),
          const SizedBox(height: 16),
          
          // Charts Area with Selector
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main Chart Area
                Expanded(
                  child: _selectedChannels.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text('No channels selected', style: TextStyle(color: RacingTheme.textMuted))))
                    : ListView.builder(
                        padding: const EdgeInsets.only(right: 16.0),
                        controller: _chartsScrollController,
                        itemCount: _selectedChannels.length,
                        itemBuilder: (context, index) {
                              String channel = _selectedChannels[index];
                              // Extract spots for this channel
                              List<FlSpot> channelSpots = [];
                              if (hasData) {
                                for (var item in provider.loadedLogData) {
                                  double t = item['Time_ms'] as double;
                                  if (item[channel] != null) {
                                    channelSpots.add(FlSpot(t, (item[channel] as num).toDouble()));
                                  }
                                }
                              }
                              // Pick a color based on channel name hash or predefined
                              Color color = Colors.primaries[channel.hashCode % Colors.primaries.length];
                              if (channel == 'TPS_Deg') color = RacingTheme.primaryAccent;
                              if (channel == 'Brake_Bar') color = RacingTheme.danger;
                              if (channel == 'Angle') color = RacingTheme.warning;
                              return SizedBox(
                                height: 250,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildChart(channel, color, channelSpots, minX, maxX),
                                ),
                              );
                            },
                          ),
                ),
                const SizedBox(width: 16),
                // Channel Selector Right Panel
                Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: RacingTheme.panel,
                    border: Border.all(color: RacingTheme.border),
                  ),
                  child: ChannelSelectorList(
                    availableChannels: provider.availableChannels,
                    selectedChannels: _selectedChannels,
                    onToggle: _toggleChannel,
                    onSelectAll: () => _selectAll(provider.availableChannels),
                    onSelectNone: _selectNone,
                    onSelectRaw: () => _selectRaw(provider.availableChannels),
                    onSelectDerived: () => _selectDerived(provider.availableChannels),
                  ),
                ),
              ],
            ),
          ),
            
          const SizedBox(height: 8),
          
          // Bottom Alert Strip
          Container(
            height: 32,
            width: double.infinity,
            decoration: BoxDecoration(
              color: RacingTheme.panel,
              border: Border(top: BorderSide(color: RacingTheme.border, width: 1)),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              alertText, 
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: alertColor, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DaqProvider provider, bool hasData, double minX, double maxX) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget chartsContent = _selectedChannels.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(child: Text('Select channels above', style: TextStyle(color: RacingTheme.textMuted))),
          )
        : isLandscape
            ? GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _selectedChannels.length,
                itemBuilder: (context, index) {
                  return _buildMobileChart(context, provider, _selectedChannels[index], hasData, minX, maxX);
                },
              )
            : Column(
                children: _selectedChannels.map((channel) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: _buildMobileChart(context, provider, channel, hasData, minX, maxX),
                    ),
                  );
                }).toList(),
              );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: provider.availableChannels.map((channel) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(channel, style: TextStyle(fontSize: 11, color: _selectedChannels.contains(channel) ? RacingTheme.background : RacingTheme.textPrimary)),
                      selected: _selectedChannels.contains(channel),
                      selectedColor: RacingTheme.primaryAccent,
                      backgroundColor: RacingTheme.panel,
                      onSelected: (val) => _toggleChannel(channel, val),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            chartsContent,
          ],
        ),
      ),
    );
  }

  Widget _buildMobileChart(BuildContext context, DaqProvider provider, String channel, bool hasData, double minX, double maxX) {
    List<FlSpot> channelSpots = [];
    if (hasData) {
      for (var item in provider.loadedLogData) {
        double t = item['Time_ms'] as double;
        if (item[channel] != null) {
          channelSpots.add(FlSpot(t, (item[channel] as num).toDouble()));
        }
      }
    }
    Color color = Colors.primaries[channel.hashCode % Colors.primaries.length];
    if (channel == 'TPS_Deg') color = RacingTheme.primaryAccent;
    if (channel == 'Brake_Bar') color = RacingTheme.danger;
    if (channel == 'Angle') color = RacingTheme.warning;

    return _buildChart(channel, color, channelSpots, minX, maxX);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        _initChannels(provider);
        bool hasData = provider.loadedLogData.isNotEmpty;
        
        String tpsVal = provider.maxTps?.toStringAsFixed(1) ?? 'N/A';
        String brakeVal = provider.maxBrake?.toStringAsFixed(1) ?? 'N/A';
        String durVal = hasData ? (provider.totalDurationMs / 1000).toStringAsFixed(1) : 'N/A';
        String rateVal = hasData ? provider.sampleRate.toStringAsFixed(0) : 'N/A';
        String steerVal = provider.maxAngle?.toStringAsFixed(1) ?? 'N/A';
        String samplesVal = hasData ? provider.sampleCount.toString() : 'N/A';

        List<FlSpot> tpsSpots = [];
        List<FlSpot> brakeSpots = [];
        List<FlSpot> angleSpots = [];
        double minX = 0;
        double maxX = hasData ? provider.totalDurationMs.toDouble() : 1000;

        if (hasData) {
          for (var item in provider.loadedLogData) {
            double t = item['Time_ms'] as double;
            if (item['TPS_Deg'] != null) tpsSpots.add(FlSpot(t, item['TPS_Deg']));
            if (item['Brake_Bar'] != null) brakeSpots.add(FlSpot(t, item['Brake_Bar']));
            if (item['Angle'] != null) angleSpots.add(FlSpot(t, item['Angle']));
          }
        }

        // Latest alert
        String alertText = "ALL SYSTEMS NOMINAL";
        Color alertColor = RacingTheme.textMuted;
        if (hasData && provider.alerts.isNotEmpty) {
          var pastAlerts = provider.alerts.where((a) => a['time'] <= provider.currentTimestampMs).toList();
          if (pastAlerts.isNotEmpty) {
            var latest = pastAlerts.last;
            alertText = "⚠ ${latest['event']} ${(latest['value'] as double).toStringAsFixed(1)} @ ${(latest['time']/1000).toStringAsFixed(1)}s";
            alertColor = latest['severity'] == 'danger' ? RacingTheme.danger : RacingTheme.warning;
          }
        }

        if (!kIsWeb && Platform.isAndroid) {
          return _buildMobileLayout(context, provider, hasData, minX, maxX);
        }
        return _buildDesktopLayout(context, provider, hasData, tpsVal, brakeVal, durVal, rateVal, steerVal, samplesVal, tpsSpots, brakeSpots, angleSpots, minX, maxX, alertText, alertColor);
      },
    );
  }
}
