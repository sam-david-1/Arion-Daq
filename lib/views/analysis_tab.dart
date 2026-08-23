import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../services/parameter_registry.dart';
import '../widgets/channel_selector_list.dart';
import '../services/ai_service.dart';
import 'dart:math';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  List<String> _selectedChannels = [];
  bool _initialized = false;
  bool _isGeneratingSetup = false;
  String _setupRecommendations = '';

  void _initChannels(DaqProvider provider) {
    if (_initialized) return;
    if (provider.availableChannels.isEmpty) return;
    
    var saved = SettingsService().getSelectedChannels('analysis');
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
      SettingsService().setSelectedChannels('analysis', _selectedChannels);
    });
  }

  void _selectAll(List<String> available) => setState(() { _selectedChannels = List.from(available); SettingsService().setSelectedChannels('analysis', _selectedChannels); });
  void _selectNone() => setState(() { _selectedChannels.clear(); SettingsService().setSelectedChannels('analysis', _selectedChannels); });
  void _selectRaw(List<String> available) => setState(() { _selectedChannels = available.where((c) => !ParameterRegistry().getParameter(c).isDerived).toList(); SettingsService().setSelectedChannels('analysis', _selectedChannels); });
  void _selectDerived(List<String> available) => setState(() { _selectedChannels = available.where((c) => ParameterRegistry().getParameter(c).isDerived).toList(); SettingsService().setSelectedChannels('analysis', _selectedChannels); });
  
  Widget _buildStatCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: RacingTheme.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14, color: RacingTheme.primaryAccent)),
        ],
      ),
    );
  }

  Widget _buildHistogram(BuildContext context, String title, Map<String, double> data, Color color) {
    if (data.isEmpty) return Center(child: Text('$title\nN/A', textAlign: TextAlign.center, style: RacingTheme.chartTitleStyle));
    
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    int i = 0;
    
    var sortedKeys = data.keys.toList()..sort((a, b) {
      double numA = double.tryParse(a.split('-')[0]) ?? 0;
      double numB = double.tryParse(b.split('-')[0]) ?? 0;
      return numA.compareTo(numB);
    });

    for (var key in sortedKeys) {
      double val = data[key]!;
      if (val > maxY) maxY = val;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: val, color: color, width: 20, borderRadius: BorderRadius.zero)],
      ));
      i++;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(title, style: RacingTheme.chartTitleStyle),
        ),
        Expanded(
          child: RepaintBoundary(
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.1,
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxY > 0 ? (maxY / 5).clamp(1.0, double.infinity) : 1000,
                      getTitlesWidget: (val, meta) {
                        if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                        String text;
                        if (val >= 1000) {
                          text = '${(val / 1000).toStringAsFixed(1)}k';
                        } else if (val <= -1000) {
                          text = '${(val / 1000).toStringAsFixed(1)}k';
                        } else {
                          text = val.toStringAsFixed(0);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(text, style: TextStyle(color: RacingTheme.textPrimary, fontSize: 11), textAlign: TextAlign.right),
                        );
                      },
                    )
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() >= 0 && val.toInt() < sortedKeys.length) {
                          return SideTitleWidget(
                            meta: meta,
                            child: SizedBox(
                              width: 40,
                              child: Text(
                                sortedKeys[val.toInt()],
                                style: TextStyle(color: RacingTheme.textMuted, fontSize: 8),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    )
                  )
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingVerticalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
                  getDrawingHorizontalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Map<String, dynamic> _calculateChannelData(DaqProvider provider, String channel) {
    if (provider.loadedLogData.isEmpty) return {};
    
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sum = 0;
    int count = 0;
    
    double prevV = 0.0;
    double totalDerivative = 0.0;
    
    for (int j = 0; j < provider.loadedLogData.length; j++) {
      var item = provider.loadedLogData[j];
      if (item[channel] != null) {
        double v = item[channel] as double;
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
        sum += v;
        
        if (count > 0) {
          totalDerivative += (v - prevV).abs();
        }
        prevV = v;
        count++;
      }
    }
    
    if (count == 0) return {};
    
    double avg = sum / count;
    
    // Create Histogram
    Map<String, double> hist = {};
    if (maxVal > minVal && provider.sampleRate > 0) {
      double range = maxVal - minVal;
      double binSize = range / 10.0;
      if (binSize == 0) binSize = 1.0;
      
      double timePerSample = 1.0 / provider.sampleRate;
      
      for (var item in provider.loadedLogData) {
        if (item[channel] != null) {
          double v = item[channel] as double;
          int binIndex = ((v - minVal) / binSize).floor();
          if (binIndex == 10) binIndex = 9; // clamp max
          
          double binStart = minVal + (binIndex * binSize);
          String key = '${binStart.toStringAsFixed(1)}-${(binStart + binSize).toStringAsFixed(1)}';
          hist[key] = (hist[key] ?? 0.0) + timePerSample;
        }
      }
    }
    
    double varianceSum = 0;
    double timeInZone = 0;
    double threshold = maxVal * 0.8;
    for (var item in provider.loadedLogData) {
      if (item[channel] != null) {
        double v = item[channel] as double;
        varianceSum += pow(v - avg, 2);
        if (v >= threshold) {
           timeInZone += (1.0 / (provider.sampleRate > 0 ? provider.sampleRate : 1));
        }
      }
    }
    double stdDev = sqrt(varianceSum / count);
    double aggression = totalDerivative / count;
    
    return {
      'min': minVal,
      'max': maxVal,
      'avg': avg,
      'range': maxVal - minVal,
      'histogram': hist,
      'stdDev': stdDev,
      'timeInZone': timeInZone,
      'aggression': aggression,
    };
  }

  Widget _buildDesktopLayout(BuildContext context, DaqProvider provider, bool hasData) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: RacingTheme.primaryAccent, size: 16),
                    const SizedBox(width: 8),
                    Text('SESSION ANALYSIS', style: RacingTheme.chartTitleStyle.copyWith(fontSize: 14)),
                  ],
                ),
                if (hasData)
                  ElevatedButton.icon(
                    onPressed: () {
                      provider.askAi("Provide a comprehensive AI analysis summary for the entire session across all channels.");
                      provider.setAiSidebarMode(true);
                    },
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Analyze Whole Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RacingTheme.primaryAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Right Panel: Dynamic Stats & Histograms
            Expanded(
              child: _selectedChannels.isEmpty || !hasData
                ? Center(child: Text('No channels selected or data available', style: TextStyle(color: RacingTheme.textMuted)))
                : ListView.builder(
                    itemCount: _selectedChannels.length,
                    itemBuilder: (context, index) {
                      String channel = _selectedChannels[index];
                      var data = _calculateChannelData(provider, channel);
                      
                      Color color = Colors.primaries[channel.hashCode % Colors.primaries.length];
                      if (channel == 'TPS_Deg') color = RacingTheme.primaryAccent;
                      if (channel == 'Brake_Bar') color = RacingTheme.danger;
                      if (channel == 'Angle') color = RacingTheme.warning;
                      
                      if (data.isEmpty) {
                        return Container(
                          height: 150,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                          alignment: Alignment.center,
                          child: Text('$channel: Data not available', style: RacingTheme.chartTitleStyle),
                        );
                      }

                      return Container(
                        height: 350,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            // Stats Box
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(channel.toUpperCase(), style: RacingTheme.chartTitleStyle.copyWith(color: color, overflow: TextOverflow.ellipsis))),
                                        InkWell(
                                          onTap: () {
                                            provider.askAi("Analyze the distribution and statistics of the ${channel} channel for this session.");
                                            provider.setAiSidebarMode(true);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: color),
                                            ),
                                            child: Text('✦ Ask AI', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    _buildStatCard(context, 'Max', (data['max'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Min', (data['min'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Avg', (data['avg'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Volatility (SD)', (data['stdDev'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Aggression', (data['aggression'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Time > 80%', '${(data['timeInZone'] as double).toStringAsFixed(0)}s'),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Histogram Box
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                                child: _buildHistogram(context, '${ParameterRegistry().getParameter(channel).displayName} DISTRIBUTION', data['histogram'] as Map<String, double>, color),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(width: 16),
            // Left Panel: Channel Selector
            Container(
              width: 200,
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
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, DaqProvider provider, bool hasData) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel selection via chips
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
              if (_selectedChannels.isEmpty || !hasData)
                Center(child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Select channels or load data', style: TextStyle(color: RacingTheme.textMuted)),
                ))
              else
                Column(
                  children: _selectedChannels.map((channel) {
                    var data = _calculateChannelData(provider, channel);
                    
                    Color color = Colors.primaries[channel.hashCode % Colors.primaries.length];
                    if (channel == 'TPS_Deg') color = RacingTheme.primaryAccent;
                    if (channel == 'Brake_Bar') color = RacingTheme.danger;
                    if (channel == 'Angle') color = RacingTheme.warning;

                    if (data.isEmpty) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ParameterRegistry().getParameter(channel).displayName, style: TextStyle(color: RacingTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                            child: Column(
                              children: [
                                Text(ParameterRegistry().getParameter(channel).displayName.toUpperCase(), style: RacingTheme.chartTitleStyle.copyWith(color: color)),
                                const Divider(),
                                GridView.count(
                                  crossAxisCount: isLandscape ? 3 : 2,
                                  childAspectRatio: 3,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildStatCard(context, 'Max', (data['max'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Min', (data['min'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Avg', (data['avg'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Vol (SD)', (data['stdDev'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'Aggr.', (data['aggression'] as double).toStringAsFixed(0)),
                                    _buildStatCard(context, 'T > 80%', '${(data['timeInZone'] as double).toStringAsFixed(0)}s'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 250,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                            child: _buildHistogram(context, '$channel DISTRIBUTION', data['histogram'] as Map<String, double>, color),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              if (hasData) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, color: RacingTheme.primaryAccent, size: 16),
                              const SizedBox(width: 8),
                              Text('SETUP RECOMMENDATIONS', style: RacingTheme.chartTitleStyle.copyWith(color: RacingTheme.primaryAccent)),
                            ],
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  provider.askAi("Provide a comprehensive AI analysis summary for the entire session across all channels.");
                                  provider.setSidebarWidth(400);
                                },
                                icon: const Icon(Icons.analytics, size: 14),
                                label: const Text('Analyze Whole Session'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: _isGeneratingSetup ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.auto_awesome, size: 14),
                                label: const Text('Generate ✦', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.primaryAccent, foregroundColor: Colors.black, minimumSize: const Size(120, 32)),
                                onPressed: _isGeneratingSetup ? null : () async {
                                  setState(() => _isGeneratingSetup = true);
                                  String contextStr = provider.buildAiContext();
                                  String? res = await AiService.ask(
                                    '', 
                                    contextStr, 
                                    [], 
                                    'Based on this data, what setup changes would you recommend? Consider ride height, brake bias, and suspension data if available.'
                                  );
                                  setState(() {
                                    _isGeneratingSetup = false;
                                    _setupRecommendations = res ?? 'Failed to generate recommendations.';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_setupRecommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        MarkdownBody(
                          data: _setupRecommendations, 
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 12, color: RacingTheme.textPrimary, height: 1.5)
                          )
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        _initChannels(provider);
        bool hasData = provider.loadedLogData.isNotEmpty;

        if (!kIsWeb && Platform.isAndroid) {
          return _buildMobileLayout(context, provider, hasData);
        }
        return _buildDesktopLayout(context, provider, hasData);
      },
    );
  }
}
