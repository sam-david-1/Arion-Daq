import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';

import 'state/daq_provider.dart';
import 'theme/racing_theme.dart';
import 'services/parameter_registry.dart';
import 'widgets/smart_detection_dialog.dart';
import 'theme/mobile_theme.dart';
import 'services/file_service.dart';
import 'dart:ui';

import 'views/mobile/mobile_home_screen.dart';
import 'views/mobile/mobile_telemetry_screen.dart';
import 'views/mobile/mobile_history_screen.dart';
import 'views/mobile/mobile_settings_screen.dart';

class MobileDashboardShell extends StatefulWidget {
  const MobileDashboardShell({super.key});

  @override
  State<MobileDashboardShell> createState() => _MobileDashboardShellState();
}

class _MobileDashboardShellState extends State<MobileDashboardShell> {
  int _bottomNavIndex = 0;
  final FileService _fileService = FileService();

  final List<Widget> _mainTabs = [
    const MobileHomeScreen(),
    const MobileTelemetryScreen(),
    const MobileHistoryScreen(),
    const MobileSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Ensure the system status bar and navigation bar match the dark theme and are visible
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: RacingTheme.panel,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
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
          if (unknown.isNotEmpty && mounted && !provider.hasShownSmartDetection) {
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

  void _onBottomNavTapped(int index) {
    setState(() {
      _bottomNavIndex = index;
    });
  }

  PreferredSizeWidget _buildAppBar(DaqProvider provider) {
    bool hasData = provider.loadedLogData.isNotEmpty;
    String statusText = hasData ? (provider.isPlaying ? 'REPLAY' : 'PAUSED') : 'NO SESSION';
    Color statusColor = hasData ? RacingTheme.success : RacingTheme.danger;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ),
      title: Text('ARION DAQ', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: MobileTheme.primaryNeon, fontSize: 16)),
      actions: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: MobileTheme.glassDecoration(radius: 8, isActive: false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: statusColor, 
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(statusText, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: MobileTheme.textBright, fontSize: 10)),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.folder_open, size: 24, color: MobileTheme.primaryNeon),
          onPressed: () => _pickAndLoadFile(provider),
        ),
      ],
    );
  }

  Widget _buildCompactReplayBar(DaqProvider provider) {
    if (provider.loadedLogData.isEmpty) return const SizedBox.shrink();

    String timeStr = '${(provider.currentTimestampMs / 1000).toStringAsFixed(1)}s';
    
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: RacingTheme.panel,
        border: Border(top: BorderSide(color: RacingTheme.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.stop, size: 28, color: Colors.white),
            onPressed: () => provider.stopPlayback(),
          ),
          IconButton(
            icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, size: 28, color: RacingTheme.primaryAccent),
            onPressed: () => provider.togglePlayback(),
          ),
          Text(timeStr, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12, color: Colors.white)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: RacingTheme.primaryAccent,
                inactiveTrackColor: RacingTheme.border,
                thumbColor: RacingTheme.primaryAccent,
              ),
              child: Slider(
                value: provider.currentTimestampMs.toDouble(),
                min: 0,
                max: provider.totalDurationMs.toDouble(),
                onChanged: (val) {
                  provider.seekTo(val.toInt());
                },
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
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(provider),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _mainTabs[_bottomNavIndex]
                        .animate(key: ValueKey(_bottomNavIndex))
                        .fadeIn(duration: 200.ms)
                        .slideX(begin: 0.05, end: 0),
                  ),
                  _buildCompactReplayBar(provider),
                ],
              ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 64,
                      decoration: MobileTheme.glassDecoration(radius: 32, isActive: false),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(Icons.dashboard_rounded, 'Home', 0),
                          _buildNavItem(Icons.speed_rounded, 'Live', 1),
                          _buildNavItem(Icons.history_rounded, 'History', 2),
                          _buildNavItem(Icons.settings_rounded, 'Settings', 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => _onBottomNavTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? MobileTheme.primaryNeon : MobileTheme.textMuted,
              size: isSelected ? 26 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? MobileTheme.textBright : MobileTheme.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
