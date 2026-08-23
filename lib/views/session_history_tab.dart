import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../services/parameter_registry.dart';
import '../widgets/smart_detection_dialog.dart';
import '../widgets/zoomable_chart.dart';
import '../services/file_service.dart';

import 'package:fl_chart/fl_chart.dart';

class SessionHistoryTab extends StatefulWidget {
  const SessionHistoryTab({super.key});

  @override
  State<SessionHistoryTab> createState() => _SessionHistoryTabState();
}

class _SessionHistoryTabState extends State<SessionHistoryTab> {
  List<Map<String, dynamic>> _history = [];
  
  String? _selectedSessionFn;
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _tagsCtrl = TextEditingController();

  String? _compareFn1;
  String? _compareFn2;
  List<Map<String, dynamic>> _compareData1 = [];
  List<Map<String, dynamic>> _compareData2 = [];
  bool _isLoadingCompare = false;
  
  String _selectedCompareChannel = 'TPS_Deg';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history = SettingsService().getSessionHistory();
    });
  }

  void _selectSession(String fn) {
    var s = _history.firstWhere((e) => e['filename'] == fn, orElse: () => <String, dynamic>{});
    setState(() {
      _selectedSessionFn = fn;
      _notesCtrl.text = s['notes'] ?? '';
      _tagsCtrl.text = (s['tags'] as List<dynamic>? ?? []).join(', ');
    });
  }

  Future<void> _saveNotesAndTags() async {
    if (_selectedSessionFn == null) return;
    var s = _history.firstWhere((e) => e['filename'] == _selectedSessionFn, orElse: () => <String, dynamic>{});
    if (s.isEmpty) return;
    
    s['notes'] = _notesCtrl.text;
    s['tags'] = _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    await SettingsService().saveSessionHistory(_history);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes and Tags saved.')));
  }

  Future<void> _toggleCompare(String fn) async {
    if (_compareFn1 == fn) {
      _compareFn1 = null;
      _compareData1 = [];
    } else if (_compareFn2 == fn) {
      _compareFn2 = null;
      _compareData2 = [];
    } else if (_compareFn1 == null) {
      _compareFn1 = fn;
    } else if (_compareFn2 == null) {
      _compareFn2 = fn;
    } else {
      _compareFn2 = fn; // Replace second
    }

    setState(() => _isLoadingCompare = true);
    
    if (_compareFn1 != null && _compareData1.isEmpty) {
      try {
        var s = _history.firstWhere((e) => e['filename'] == _compareFn1, orElse: () => <String, dynamic>{});
        String path = s['filepath'] ?? _compareFn1!;
        _compareData1 = await FileService().parseCsvLog(path);
      } catch (e) {
        _compareFn1 = null;
      }
    }
    if (_compareFn2 != null && _compareData2.isEmpty) {
      try {
        var s = _history.firstWhere((e) => e['filename'] == _compareFn2, orElse: () => <String, dynamic>{});
        String path = s['filepath'] ?? _compareFn2!;
        _compareData2 = await FileService().parseCsvLog(path);
      } catch (e) {
        _compareFn2 = null;
      }
    }
    
    setState(() => _isLoadingCompare = false);
  }

  Future<void> _reloadSession(String filename, DaqProvider provider) async {
    try {
      var s = _history.firstWhere((e) => e['filename'] == filename, orElse: () => <String, dynamic>{});
      String path = s['filepath'] ?? filename;
      final data = await FileService().parseCsvLog(path);
      if (data.isNotEmpty) {
        int duration = data.last['Time_ms']?.toInt() ?? 0;
        provider.loadLogData(data, duration, filename: filename, filepath: path);
        
        var unknown = ParameterRegistry().unknownRawNames;
        if (unknown.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => SmartDetectionDialog(unknownChannels: unknown),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reloaded $filename')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
  }

  Future<void> _deleteSession(String filename) async {
    await SettingsService().deleteSessionHistory(filename);
    _loadHistory();
  }

  Future<void> _clearAll() async {
    await SettingsService().clearSessionHistory();
    _loadHistory();
  }

  Widget _buildDesktopLayout(BuildContext context, DaqProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Left Panel: History List
          Expanded(
            flex: 30,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SESSION HISTORY', style: Theme.of(context).textTheme.labelSmall),
                    ElevatedButton.icon(
                      onPressed: _clearAll,
                      icon: Icon(Icons.delete_sweep, size: 16),
                      label: Text('CLEAR ALL'),
                      style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                    child: _history.isEmpty
                      ? Center(child: Text('No history.', style: Theme.of(context).textTheme.bodySmall))
                      : _buildHistoryList(provider),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Middle Panel: Compare Chart
          Expanded(
            flex: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('COMPARE SESSIONS', style: Theme.of(context).textTheme.labelSmall),
                    if (_compareFn1 != null || _compareFn2 != null)
                      Builder(
                        builder: (context) {
                          List<String> available = provider.availableChannels;
                          if (!available.contains(_selectedCompareChannel) && available.isNotEmpty) {
                            _selectedCompareChannel = available.first;
                          }
                          return DropdownButton<String>(
                            value: available.contains(_selectedCompareChannel) ? _selectedCompareChannel : null,
                            dropdownColor: RacingTheme.panel,
                            style: Theme.of(context).textTheme.bodySmall,
                            items: available.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCompareChannel = val);
                            },
                          );
                        }
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: RacingTheme.background, border: Border.all(color: RacingTheme.border)),
                    child: _isLoadingCompare
                      ? const Center(child: CircularProgressIndicator())
                      : (_compareFn1 == null && _compareFn2 == null)
                        ? Center(child: Text('Select sessions to compare', style: Theme.of(context).textTheme.bodySmall))
                        : _buildCompareChart(),
                  ),
                ),
                if (_compareFn1 != null || _compareFn2 != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_compareFn1 != null) ...[
                          Container(width: 12, height: 12, color: RacingTheme.primaryAccent),
                          const SizedBox(width: 8),
                          Text(_compareFn1!, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 24),
                        ],
                        if (_compareFn2 != null) ...[
                          Container(width: 12, height: 12, color: RacingTheme.danger),
                          const SizedBox(width: 8),
                          Text(_compareFn2!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Panel: Tags and Notes
          Expanded(
            flex: 30,
            child: _buildSessionDetailsPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetailsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SESSION DETAILS', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: _selectedSessionFn == null
              ? Center(child: Text('Select a session from history', style: Theme.of(context).textTheme.bodySmall))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedSessionFn!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: RacingTheme.textPrimary)),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('TAGS (comma separated)', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tagsCtrl,
                      style: Theme.of(context).textTheme.bodySmall,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: RacingTheme.background,
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Wet, Q1, Setup A',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('ENGINEER NOTES', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _notesCtrl,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: RacingTheme.background,
                          border: OutlineInputBorder(),
                          hintText: 'Enter session notes here...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _saveNotesAndTags,
                        child: Text('SAVE DETAILS'),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList(DaqProvider provider, {bool isMobile = false}) {
    return ListView.separated(
      itemCount: _history.length,
      separatorBuilder: (c, i) => const Divider(),
      itemBuilder: (context, index) {
        var session = _history[index];
        String fn = session['filename'] ?? 'Unknown';
        String date = session['date']?.split('.').first.replaceAll('T', ' ') ?? '';
        List<dynamic> tags = session['tags'] ?? [];

        bool isCompare = _compareFn1 == fn || _compareFn2 == fn;
        bool isSelected = _selectedSessionFn == fn;

        return InkWell(
          onTap: () => _selectSession(fn),
          child: Container(
            color: isSelected ? RacingTheme.primaryAccent.withOpacity(0.1) : Colors.transparent,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isMobile)
                      Checkbox(
                        value: isCompare,
                        onChanged: (_) => _toggleCompare(fn),
                        activeColor: RacingTheme.primaryAccent,
                      ),
                    Expanded(child: Text(fn, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: RacingTheme.textPrimary))),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 18),
                      color: RacingTheme.primaryAccent,
                      onPressed: () => _reloadSession(fn, provider),
                    ),
                  ],
                ),
                Text('Loaded: $date', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: RacingTheme.textMuted)),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: RacingTheme.primaryAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(t, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: RacingTheme.primaryAccent)),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, DaqProvider provider) {
    return Column(
      children: [
        // Top: Details Panel (fixed height)
        SizedBox(
          height: 350,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildSessionDetailsPanel(),
          ),
        ),
        // Bottom: History List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SESSION HISTORY', style: Theme.of(context).textTheme.labelSmall),
                    ElevatedButton.icon(
                      onPressed: _clearAll,
                      icon: Icon(Icons.delete_sweep, size: 16),
                      label: Text('CLEAR ALL'),
                      style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                    child: _history.isEmpty
                      ? Center(child: Text('No history.', style: Theme.of(context).textTheme.bodySmall))
                      : _buildHistoryList(provider, isMobile: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        if (!kIsWeb && Platform.isAndroid) {
          return _buildMobileLayout(context, provider);
        }
        return _buildDesktopLayout(context, provider);
      },
    );
  }

  Widget _buildCompareChart() {
    List<LineChartBarData> lines = [];
    double maxX = 0;
    
    if (_compareData1.isNotEmpty) {
      List<FlSpot> spots = [];
      for (var row in _compareData1) {
        if (row[_selectedCompareChannel] != null) {
          spots.add(FlSpot(row['Time_ms'] as double, (row[_selectedCompareChannel] as num).toDouble()));
        }
      }
      if (spots.isNotEmpty) {
        if (spots.last.x > maxX) maxX = spots.last.x;
        lines.add(LineChartBarData(
          spots: spots,
          isCurved: false,
          color: RacingTheme.primaryAccent,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
        ));
      }
    }

    if (_compareData2.isNotEmpty) {
      List<FlSpot> spots = [];
      for (var row in _compareData2) {
        if (row[_selectedCompareChannel] != null) {
          spots.add(FlSpot(row['Time_ms'] as double, (row[_selectedCompareChannel] as num).toDouble()));
        }
      }
      if (spots.isNotEmpty) {
        if (spots.last.x > maxX) maxX = spots.last.x;
        lines.add(LineChartBarData(
          spots: spots,
          isCurved: false,
          color: RacingTheme.danger,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
        ));
      }
    }
    double? minY;
    double? maxY;
    for (var line in lines) {
      for (var spot in line.spots) {
        if (minY == null || spot.y < minY) minY = spot.y;
        if (maxY == null || spot.y > maxY) maxY = spot.y;
      }
    }
    if (minY != null && maxY != null) {
      if (minY == maxY) {
        minY -= 1.0;
        maxY += 1.0;
      }
      double range = maxY - minY;
      minY -= range * 0.05;
      maxY += range * 0.05;
    }

    if (lines.isEmpty) return Center(child: Text('No $_selectedCompareChannel data to compare', style: Theme.of(context).textTheme.bodySmall));

    return ZoomableChart(
      originalMinX: 0,
      originalMaxX: maxX,
      channelName: _selectedCompareChannel,
      builder: (context, currentMinX, currentMaxX) => RepaintBoundary(
        child: LineChart(
          LineChartData(
            clipData: const FlClipData.all(),
            minX: currentMinX,
            maxX: currentMaxX,
            minY: minY,
            maxY: maxY,
            lineBarsData: lines,
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
            getDrawingHorizontalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
            getDrawingVerticalLine: (val) => FlLine(color: RacingTheme.gridLine, strokeWidth: 1),
          ),
          ),
        ),
      ),
    );
  }
}
