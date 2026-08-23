import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../state/daq_provider.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import '../services/file_service.dart';
import '../services/serial_service.dart';
import '../theme/racing_theme.dart';
import '../services/parameter_registry.dart';
import 'smart_detection_dialog.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../services/pdf_service.dart';

class TopBar extends StatefulWidget {
  final TabController tabController;
  const TopBar({super.key, required this.tabController});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final SerialService _serialService = SerialService();
  final FileService _fileService = FileService();
  
  StreamSubscription? _telemetrySub;
  StreamSubscription? _rawLogsSub;
  Timer? _portScanTimer;
  
  bool _isSearchExpanded = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _searchOverlay;

  @override
  void initState() {
    super.initState();
    _loadPorts();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _rawLogsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPorts() async {
    final ports = await _serialService.getAvailablePorts();
    if (mounted) {
      Provider.of<DaqProvider>(context, listen: false).setAvailablePorts(ports);
    }
  }

  Future<void> _pickAndLoadFile(DaqProvider provider) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final path = result.files.single.path!;
        final filename = result.files.single.name;
        final data = await _fileService.parseCsvLog(path);
        if (data.isNotEmpty) {
          int duration = data.last['Time_ms']?.toInt() ?? 0;
          provider.loadLogData(data, duration, filename: filename, filepath: path);
          
          var unknown = ParameterRegistry().unknownRawNames;
          if (unknown.isNotEmpty && !provider.hasShownSmartDetection) {
            provider.markSmartDetectionShown();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => SmartDetectionDialog(unknownChannels: unknown),
            );
          }
        }
      } catch (e) {
        debugPrint('File load error: $e');
      }
    }
  }

  Future<void> _handleExport(String type, DaqProvider provider) async {
    if (provider.loadedLogData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data loaded to export.')));
      return;
    }

    String? outputDir = await FilePicker.platform.getDirectoryPath();
    if (outputDir == null) return;

    try {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      if (type == 'CSV') {
        List<List<dynamic>> rows = [];
        if (provider.loadedLogData.isNotEmpty) {
          rows.add(provider.loadedLogData.first.keys.toList());
          for (var item in provider.loadedLogData) {
            rows.add(item.values.toList());
          }
        }
        String csv = const ListToCsvConverter().convert(rows);
        File('$outputDir\\export_$timestamp.csv').writeAsStringSync(csv);
        
      } else if (type == 'Excel') {
        var excel = Excel.createExcel();
        var sheet = excel['Sheet1'];
        if (provider.loadedLogData.isNotEmpty) {
          sheet.appendRow(provider.loadedLogData.first.keys.map((k) => TextCellValue(k)).toList());
          for (var item in provider.loadedLogData) {
            sheet.appendRow(item.values.map((v) {
              if (v is num) return DoubleCellValue(v.toDouble());
              return TextCellValue(v.toString());
            }).toList());
          }
        }
        var bytes = excel.save();
        if (bytes != null) {
          File('$outputDir\\export_$timestamp.xlsx').writeAsBytesSync(bytes);
        }
        
      } else if (type == 'PDF') {
        String filename = provider.loadedLogData.isNotEmpty ? SettingsService().getSessionHistory().first['filename'] : 'Log';
        await PdfService.exportPdf(provider, '$outputDir\\export_$timestamp.pdf', filename);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported $type successfully to $outputDir'), backgroundColor: RacingTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: RacingTheme.danger));
      }
    }
  }

  void _showSearchOverlay(BuildContext context, String result) {
    _searchOverlay?.remove();
    _searchOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          offset: const Offset(-260, 40),
          showWhenUnlinked: false,
          child: Material(
            elevation: 8,
            color: RacingTheme.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: RacingTheme.primaryAccent, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('AI Search Result', style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      InkWell(
                        onTap: () {
                          _searchOverlay?.remove();
                          _searchOverlay = null;
                        },
                        child: Icon(Icons.close, size: 14, color: RacingTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(result, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_searchOverlay!);
  }

  void _handleSearch(String query, DaqProvider provider) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    
    String contextStr = provider.buildAiContext();
    String? response = await AiService.ask(
      '',
      contextStr,
      [],
      'Answer this query about the telemetry data concisely: $query',
    );
    
    setState(() => _isSearching = false);
    if (response != null) {
      _showSearchOverlay(context, response);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool hasData = provider.loadedLogData.isNotEmpty;
        String statusText = hasData ? (provider.isPlaying ? 'REPLAY' : 'PAUSED') : 'NO SESSION';
        Color statusColor = hasData ? RacingTheme.success : RacingTheme.danger;

        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: RacingTheme.panel,
            border: Border(bottom: BorderSide(color: RacingTheme.border, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Left: Branding
              Text('ARION ', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: RacingTheme.primaryAccent, fontSize: 16)),
              Text('DAQ', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: RacingTheme.textPrimary, fontSize: 16)),
              
              const SizedBox(width: 24),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: RacingTheme.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: RacingTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(statusText, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: RacingTheme.textPrimary)),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Center: Tabs — fill all available space
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: RacingTheme.primaryAccent.withValues(alpha: 0.08),
                    highlightColor: RacingTheme.primaryAccent.withValues(alpha: 0.05),
                    hoverColor: RacingTheme.primaryAccent.withValues(alpha: 0.04),
                  ),
                  child: TabBar(
                    controller: widget.tabController,
                    isScrollable: false,
                    indicatorColor: RacingTheme.primaryAccent,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: RacingTheme.primaryAccent,
                    unselectedLabelColor: RacingTheme.textMuted,
                    labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                    ),
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) return RacingTheme.primaryAccent.withValues(alpha: 0.06);
                      if (states.contains(WidgetState.pressed)) return RacingTheme.primaryAccent.withValues(alpha: 0.12);
                      return Colors.transparent;
                    }),
                    tabs: const [
                      Tab(text: 'ANALYSIS'),
                      Tab(text: 'OVERVIEW'),
                      Tab(text: 'BRAKES'),
                      Tab(text: 'DYNAMICS'),
                      Tab(text: 'CHANNELS'),
                      Tab(text: 'HISTORY'),
                      Tab(text: 'CONVERT'),
                      Tab(text: 'MAP'),
                      Tab(text: 'SERIAL'),
                      Tab(text: 'SETTINGS'),
                    ],
                  ),
                ),
              ),
              
              // Right: Controls
              if (_isSearchExpanded)
                CompositedTransformTarget(
                  link: _searchLayerLink,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 200,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask AI about data...',
                        hintStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: RacingTheme.panel,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.primaryAccent)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.primaryAccent)),
                        suffixIcon: _isSearching
                            ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: RacingTheme.primaryAccent))
                            : IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() => _isSearchExpanded = false);
                                  _searchController.clear();
                                  _searchOverlay?.remove();
                                  _searchOverlay = null;
                                },
                              ),
                      ),
                      onSubmitted: (val) => _handleSearch(val, provider),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.search, size: 20, color: RacingTheme.primaryAccent),
                  tooltip: 'Search Telemetry (AI)',
                  onPressed: () => setState(() => _isSearchExpanded = true),
                ),
                
              PopupMenuButton<String>(
                icon: Icon(Icons.download, size: 20),
                tooltip: 'Export Data',
                color: RacingTheme.panel,
                onSelected: (val) => _handleExport(val, provider),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'CSV', child: Text('Export CSV')),
                  PopupMenuItem(value: 'Excel', child: Text('Export Excel')),
                  PopupMenuItem(value: 'PDF', child: Text('Export PDF')),
                ],
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.folder_open, size: 16),
                label: Text('LOAD LOG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RacingTheme.primaryAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => _pickAndLoadFile(provider),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _serialService.isConnected ? RacingTheme.success : RacingTheme.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(_serialService.isConnected ? 'DISCONNECT' : 'CONNECT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RacingTheme.border,
                  foregroundColor: RacingTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  final provider = Provider.of<DaqProvider>(context, listen: false);
                  if (provider.selectedPort != null) {
                    if (_serialService.isConnected) {
                      _serialService.disconnect();
                        _telemetrySub?.cancel();
                        _rawLogsSub?.cancel();
                        setState(() {});
                      } else {
                        _serialService.connect(provider.selectedPort!).then((_) {
                          _telemetrySub = _serialService.telemetryStream.listen((data) {
                          provider.updateLiveSensorValues(data);
                        });
                        _rawLogsSub = _serialService.rawLogsStream.listen((line) {
                          if (!provider.pauseAutoScroll) {
                            provider.addRawSerialLog(line);
                          }
                        });
                        setState(() {});
                      });
                    }
                  }
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}
