import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../services/parameter_registry.dart';
import '../widgets/zoomable_chart.dart';

class ChannelsTab extends StatefulWidget {
  const ChannelsTab({super.key});

  @override
  State<ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<ChannelsTab> {
  String? _editingChannel;
  final TextEditingController _editCtrl = TextEditingController();

  final List<Color> _palette = Colors.primaries;



  Widget _buildDesktopLayout(BuildContext context, DaqProvider provider, bool hasData, List<String> available, List<String> selected, List<LineChartBarData> barData, double minX, double maxX) {
    return Row(
      children: [
        // Right Panel (Chart) -> now on the Left
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: selected.isEmpty 
              ? Center(child: Text('Select channels to overlay', style: Theme.of(context).textTheme.bodySmall))
              : ZoomableChart(
                  originalMinX: minX,
                  originalMaxX: maxX,
                  channelName: selected.length <= 3 
                      ? selected.map((c) => ParameterRegistry().getParameter(c).displayName).join(', ')
                      : '${selected.length} Channels Overlaid',
                  builder: (context, currentMinX, currentMaxX) => RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minX: currentMinX,
                        maxX: currentMaxX,
                        lineBarsData: barData,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          axisNameWidget: Text('Time (s)', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: RacingTheme.textPrimary)),
                          axisNameSize: 20,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 80,
                            interval: maxX > 0 ? (maxX / 8).clamp(1.0, double.infinity) : 1000,
                            getTitlesWidget: (val, meta) {
                              if (val == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('${(val/1000).round()}s', 
                                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: RacingTheme.textPrimary)),
                              );
                            },
                          )
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 80,
                            getTitlesWidget: (val, meta) {
                              if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(val.toStringAsFixed(0), 
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: RacingTheme.textPrimary), textAlign: TextAlign.right),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (val) => FlLine(color: RacingTheme.border, strokeWidth: 1),
                        getDrawingVerticalLine: (val) => FlLine(color: RacingTheme.border, strokeWidth: 1),
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
                              '${ParameterRegistry().getParameter(selected[s.barIndex]).displayName}: ${s.y.toStringAsFixed(2)}',
                              Theme.of(context).textTheme.bodySmall!.copyWith(color: _palette[s.barIndex % _palette.length]),
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
                      extraLinesData: ExtraLinesData(
                        verticalLines: [
                          if (provider.crosshairTime != null)
                            VerticalLine(
                              x: provider.crosshairTime!,
                              color: Colors.white24,
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          if (provider.currentTimestampMs > 0)
                            VerticalLine(
                              x: provider.currentTimestampMs.toDouble(),
                              color: RacingTheme.danger,
                              strokeWidth: 1.5,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
          ),
        ),
        
        // Left Panel (280px) -> now on the Right
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: RacingTheme.panel,
            border: Border(left: BorderSide(color: RacingTheme.border, width: 1)),
          ),
          child: !hasData 
            ? Center(child: Text('No Data', style: Theme.of(context).textTheme.bodySmall)) 
            : Column(
                children: [
                  _buildActionChips(context, provider),
                  Expanded(
                    child: _buildChannelList(context, provider, available, selected),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildChannelList(BuildContext context, DaqProvider provider, List<String> available, List<String> selected) {
    return ListView.builder(
      itemCount: available.length,
      itemBuilder: (context, index) {
        String ch = available[index];
        bool isSelected = selected.contains(ch);
        double? currentVal = provider.currentSensorValues[ch];
        
        int colorIndex = isSelected ? selected.indexOf(ch) % _palette.length : -1;
        Color dotColor = isSelected ? _palette[colorIndex] : RacingTheme.textMuted;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: () {
              if (_editingChannel != ch) {
                provider.toggleOverlayChannel(ch);
              }
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: RacingTheme.border, width: 1)),
                color: isSelected ? RacingTheme.border.withOpacity(0.3) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _editingChannel == ch
                        ? TextField(
                            controller: _editCtrl,
                            autofocus: true,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: RacingTheme.textPrimary),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (newVal) {
                              if (newVal.isNotEmpty) {
                                ParameterRegistry().getParameter(ch).displayName = newVal;
                                setState(() => _editingChannel = null);
                              }
                            },
                          )
                        : Text(ParameterRegistry().getParameter(ch).displayName, 
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isSelected ? RacingTheme.textPrimary : RacingTheme.textSecondary,
                            )),
                  ),
                  if (_editingChannel != ch)
                    IconButton(
                      icon: Icon(Icons.edit, size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () {
                        setState(() {
                          _editingChannel = ch;
                          _editCtrl.text = ParameterRegistry().getParameter(ch).displayName;
                        });
                      },
                    ),
                  if (currentVal != null && _editingChannel != ch)
                    Text(currentVal.toStringAsFixed(2), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 13, color: RacingTheme.primaryAccent)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionChips(BuildContext context, DaqProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: RacingTheme.border, width: 1)),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _ActionChip('ALL', () {
            provider.clearOverlayChannels();
            // Up to 18 channels allowed
            for (var ch in provider.availableChannels.take(18)) {
              provider.toggleOverlayChannel(ch);
            }
          }),
          _ActionChip('NONE', () {
            provider.clearOverlayChannels();
          }),
          _ActionChip('RAW', () {
            provider.clearOverlayChannels();
            var raw = provider.availableChannels.where((c) => !ParameterRegistry().getParameter(c).isDerived).take(18);
            for (var ch in raw) {
              provider.toggleOverlayChannel(ch);
            }
          }),
          _ActionChip('DERIVED', () {
            provider.clearOverlayChannels();
            var derived = provider.availableChannels.where((c) => ParameterRegistry().getParameter(c).isDerived).take(18);
            for (var ch in derived) {
              provider.toggleOverlayChannel(ch);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DaqProvider provider, bool hasData, List<String> available, List<String> selected, List<LineChartBarData> barData, double minX, double maxX) {
    return Column(
      children: [
        // Top Panel: Chart
        SizedBox(
          height: 300,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: RacingTheme.background,
              border: Border(bottom: BorderSide(color: RacingTheme.border)),
            ),
            child: selected.isEmpty 
              ? Center(child: Text('Select channels to overlay', style: Theme.of(context).textTheme.bodySmall))
              : ZoomableChart(
                  originalMinX: minX,
                  originalMaxX: maxX,
                  channelName: selected.join(', '),
                  builder: (context, currentMinX, currentMaxX) => RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minX: currentMinX,
                        maxX: currentMaxX,
                        lineBarsData: barData,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          axisNameWidget: Text('Time (s)', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: RacingTheme.textPrimary)),
                          axisNameSize: 16,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: maxX > 0 ? (maxX / 4).clamp(1.0, double.infinity) : 1000,
                            getTitlesWidget: (val, meta) {
                              if (val == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${(val/1000).round()}s', 
                                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: RacingTheme.textPrimary)),
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
                            getTitlesWidget: (val, meta) {
                              if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Text(val.toStringAsFixed(0), 
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: RacingTheme.textPrimary), textAlign: TextAlign.right),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (val) => FlLine(color: RacingTheme.border, strokeWidth: 1),
                        getDrawingVerticalLine: (val) => FlLine(color: RacingTheme.border, strokeWidth: 1),
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
                              '${ParameterRegistry().getParameter(selected[s.barIndex]).displayName}: ${s.y.toStringAsFixed(2)}',
                              Theme.of(context).textTheme.bodySmall!.copyWith(color: _palette[s.barIndex % _palette.length]),
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
                      extraLinesData: ExtraLinesData(
                        verticalLines: [
                          if (provider.crosshairTime != null)
                            VerticalLine(
                              x: provider.crosshairTime!,
                              color: Colors.white24,
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          if (provider.currentTimestampMs > 0)
                            VerticalLine(
                              x: provider.currentTimestampMs.toDouble(),
                              color: RacingTheme.danger,
                              strokeWidth: 1.5,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
          ),
        ),
        _buildActionChips(context, provider),
        // Bottom Panel: Channel List
        Expanded(
          child: Container(
            color: RacingTheme.panel,
            child: !hasData 
              ? Center(child: Text('No Data', style: Theme.of(context).textTheme.bodySmall)) 
              : _buildChannelList(context, provider, available, selected),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool hasData = provider.loadedLogData.isNotEmpty;
        List<String> available = provider.availableChannels;
        List<String> selected = provider.selectedOverlayChannels;

        List<LineChartBarData> barData = [];
        double minX = 0;
        double maxX = hasData ? provider.totalDurationMs.toDouble() : 1000;

        if (hasData && selected.isNotEmpty) {
          for (int i = 0; i < selected.length; i++) {
            String ch = selected[i];
            List<FlSpot> spots = [];
            for (var item in provider.loadedLogData) {
              if (item[ch] != null) {
                spots.add(FlSpot(item['Time_ms'] as double, item[ch] as double));
              }
            }
            if (spots.isNotEmpty) {
              barData.add(
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: _palette[i % _palette.length],
                  barWidth: SettingsService().chartLineThickness,
                  dotData: const FlDotData(show: false),
                )
              );
            }
          }
        }

        if (!kIsWeb && Platform.isAndroid) {
          return _buildMobileLayout(context, provider, hasData, available, selected, barData, minX, maxX);
        }
        return _buildDesktopLayout(context, provider, hasData, available, selected, barData, minX, maxX);
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: RacingTheme.primaryAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: RacingTheme.primaryAccent)),
        child: Text(label, style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
