import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/settings_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'state/daq_provider.dart';
import 'theme/racing_theme.dart';
import 'theme/mobile_theme.dart';
import 'widgets/top_bar.dart';
import 'widgets/bottom_replay_bar.dart';
import 'widgets/sidebar.dart';
import 'widgets/custom_title_bar.dart';
import 'widgets/status_bar.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';

import 'views/overview_tab.dart';
import 'views/brake_system_tab.dart';
import 'views/dynamics_tab.dart';
import 'views/channels_tab.dart';
import 'views/analysis_tab.dart';
import 'views/alerts_tab.dart';
import 'views/session_history_tab.dart';
import 'views/track_map_tab.dart';
import 'views/serial_tab.dart';
import 'views/settings_tab.dart';
import 'views/convert_tab.dart';
import 'views/splash_screen.dart';

import 'mobile_dashboard_shell.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1920, 1080),
      minimumSize: Size(1280, 720),
      center: true,
      backgroundColor: Color(0xFF0A0C10),
      title: 'ARION DAQ - AR25',
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DaqProvider()),
      ],
      child: const ArionDaqApp(),
    ),
  );
}


class SeekForwardIntent extends Intent { const SeekForwardIntent(); }

class SpeedUpIntent extends Intent { const SpeedUpIntent(); }
class SpeedDownIntent extends Intent { const SpeedDownIntent(); }
class TabSettingsIntent extends Intent { const TabSettingsIntent(); }
class TabMapIntent extends Intent { const TabMapIntent(); }
class TabBrakesIntent extends Intent { const TabBrakesIntent(); }
class ShowHelpIntent extends Intent { const ShowHelpIntent(); }

bool _hasSeenSplash = false;

class ArionDaqApp extends StatefulWidget {
  const ArionDaqApp({super.key});

  @override
  State<ArionDaqApp> createState() => _ArionDaqAppState();
}

class _ArionDaqAppState extends State<ArionDaqApp> {
  @override
  void initState() {
    super.initState();
    if (!_hasSeenSplash) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        _hasSeenSplash = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool isDesktop = kIsWeb || (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'ARION DAQ',
          theme: isDesktop ? RacingTheme.getTheme() : MobileTheme.getTheme(),
          home: _hasSeenSplash 
              ? (isDesktop ? const MainDashboardShell() : const MobileDashboardShell())
              : const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainDashboardShell extends StatefulWidget {
  const MainDashboardShell({super.key});

  @override
  State<MainDashboardShell> createState() => _MainDashboardShellState();
}

class _MainDashboardShellState extends State<MainDashboardShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showHelpOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: RacingTheme.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RacingTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KEYBOARD SHORTCUTS', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 16)),
                const SizedBox(height: 24),
                _buildShortcutRow('Space', 'Play/Pause'),
                _buildShortcutRow('R', 'Restart Replay'),
                _buildShortcutRow('Left/Right', 'Seek Replay ±1s'),
                _buildShortcutRow('Up/Down', 'Playback Speed'),
                _buildShortcutRow('S', 'Settings Tab'),
                _buildShortcutRow('M', 'Map Tab'),
                _buildShortcutRow('B', 'Brakes Tab'),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('CLOSE', style: TextStyle(color: RacingTheme.primaryAccent)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShortcutRow(String key, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: RacingTheme.border.withOpacity(0.5), borderRadius: BorderRadius.circular(4)),
            child: Text(key, style: TextStyle(fontFamily: 'JetBrains Mono', color: Colors.white, fontSize: 13)),
          ),
          Text(action, style: TextStyle(color: RacingTheme.textSecondary, fontSize: 14)),
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
          body: Column(
                  children: [
                    TopBar(tabController: _tabController),
                    Expanded(
                      child: Row(
                        children: [
                          const Sidebar(),
                          MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                double maxW = MediaQuery.of(context).size.width * 0.4;
                                if (maxW < 300) maxW = 300;
                                if (maxW > 600) maxW = 600;
                                double newW = provider.sidebarWidth + details.delta.dx;
                                if (newW > maxW) newW = maxW;
                                provider.setSidebarWidth(newW);
                              },
                              child: Container(
                                width: 4,
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onHorizontalDragEnd: (details) {
                                if (details.primaryVelocity != null) {
                                  if (details.primaryVelocity! > 300) {
                                    if (_tabController.index > 0) _tabController.animateTo(_tabController.index - 1);
                                  } else if (details.primaryVelocity! < -300) {
                                    if (_tabController.index < _tabController.length - 1) _tabController.animateTo(_tabController.index + 1);
                                  }
                                }
                              },
                              child: TabBarView(
                                controller: _tabController,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  const AnalysisTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const OverviewTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const BrakeSystemTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const DynamicsTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const ChannelsTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const SessionHistoryTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const ConvertTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const TrackMapTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const SerialTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                  const SettingsTab().animate().fadeIn(duration: 150.ms).slideX(begin: 0.02, end: 0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const BottomReplayBar(),
                    const StatusBar(),
                  ],
                ),
        );
      },
    );
  }
}
