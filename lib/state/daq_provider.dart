import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/file_service.dart';
import '../services/settings_service.dart';
import '../services/ai_service.dart';
import '../services/math_channel_service.dart';
import '../services/parameter_registry.dart';
import '../theme/racing_theme.dart';
import '../main.dart';
import 'dart:convert' as dart_convert;

class ChatMessage {
  final String role;
  final String content;
  final String model;
  final DateTime timestamp;
  ChatMessage({required this.role, required this.content, required this.model, required this.timestamp});
}

class DaqProvider extends ChangeNotifier {
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentTimestampMs = 0;
  int _totalDurationMs = 0;

  double? _crosshairTime;
  
  bool _isLightMode = false;
  bool get isLightMode => _isLightMode;

  // Serial Logs
  final List<String> _rawSerialLogs = [];
  bool _pauseAutoScroll = false;
  
  Map<String, double?> _currentSensorValues = {};
  String _currentVehicleState = 'STATIONARY';
  String get currentVehicleState => _currentVehicleState;
  
  List<Map<String, dynamic>> _loadedLogData = [];
  Timer? _playbackTimer;

  // Serial Port State
  List<String> _availablePorts = [];
  String? _selectedPort;

  List<String> get availablePorts => _availablePorts;
  String? get selectedPort => _selectedPort;

  void setAvailablePorts(List<String> ports) {
    _availablePorts = ports;
    if (_availablePorts.isNotEmpty && _selectedPort == null) {
      _selectedPort = _availablePorts.first;
    }
    notifyListeners();
  }

  void setSelectedPort(String? port) {
    _selectedPort = port;
    notifyListeners();
  }

  // Available Channels
  List<String> _availableChannels = [];
  List<String> _selectedOverlayChannels = [];

  // Analysis Stats
  double? _maxTps;
  double? _minTps;
  double? _avgTps;
  double _wotTime = 0.0;
  
  double? _maxBrake;
  double? _minBrake;
  double? _avgBrake;
  int _brakeSpikeCount = 0;
  
  double? _maxAngle;
  double? _minAngle;
  double? _avgAngle;
  double? _rangeAngle;
  
  int _sampleCount = 0;
  double _sampleRate = 0.0;

  // Histograms (Maps of Bin -> Time in seconds)
  Map<String, double> _tpsHistogram = {};
  Map<String, double> _brakeHistogram = {};
  Map<String, double> _steeringHistogram = {};

  // Alerts
  bool _alertsEnabled = true;
  List<Map<String, dynamic>> _alerts = [];
  
  // G-G Trail Buffer (last 100 points)
  final List<Offset> _ggTrail = [];

  // AI Chat and Context
  List<ChatMessage> _chatHistory = [];
  bool _isAiSidebarMode = true;
  double _sidebarWidth = 350.0;
  String _activeTabName = 'OVERVIEW';
  bool _isAiLoading = false;
  List<Map> _aiAlerts = [];
  
  List<CustomChannel> _customChannels = [];
  List<CustomChannel> get customChannels => _customChannels;

  DaqProvider() {
    _initProvider();
  }
  
  void forceRefresh() {
    notifyListeners();
  }

  Future<void> reloadSettings() async {
    await SettingsService().init();
    
    _loadCustomChannels();

    if (SettingsService().autoLoadLastSession) {
      _autoLoadLastSession();
    }
  }
  
  Future<void> _initProvider() async {
    await SettingsService().init();
    
    _loadCustomChannels();

    if (SettingsService().autoLoadLastSession) {
      _autoLoadLastSession();
    }
  }

  void _loadCustomChannels() {
    try {
      final jsonList = SettingsService().customChannelsJson;
      _customChannels = jsonList.map((e) => CustomChannel.fromJson(e)).toList();
      MathChannelService().compileChannels(_customChannels);
    } catch (e) {
      debugPrint('Failed to load custom channels: $e');
    }
  }

  void refreshCustomChannels() {
    _loadCustomChannels();
    if (_loadedLogData.isNotEmpty) {
      // Re-evaluate the entire log dataset with the new custom channels
      MathChannelService().resetDerivatives();
      for (var item in _loadedLogData) {
        final Map<String, double> rawValues = {};
        item.forEach((key, val) {
          if (val is num) rawValues[key] = val.toDouble();
        });
        
        final derived = MathChannelService().evaluateAll(_customChannels, rawValues);
        item.addAll(derived);
      }
      
      // Update available channels list
      _availableChannels = _loadedLogData.first.keys.where((k) => k != 'Time_ms').toList();
      _availableChannels.sort();
      
      _calculateStats();
      _generateAlerts();
      _generateHistograms();
    }
    notifyListeners();
  }

  Future<void> _autoLoadLastSession() async {
    try {
      final history = SettingsService().getSessionHistory();
      if (history.isNotEmpty) {
        final session = history.first;
        final filename = session['filename'];
        final filepath = session['filepath'] ?? filename;
        final fileService = FileService();
        final data = await fileService.parseCsvLog(filepath);
        if (data.isNotEmpty) {
          int duration = data.last['Time_ms']?.toInt() ?? 0;
          loadLogData(data, duration, filename: filename, filepath: filepath);
        }
      }
    } catch (e) {
      debugPrint('Auto-load failed: $e');
    }
  }

  // Getters
  bool get isPlaying => _isPlaying;

  double get playbackSpeed => _playbackSpeed;
  int get currentTimestampMs => _currentTimestampMs;
  int get totalDurationMs => _totalDurationMs;
  Map<String, double?> get currentSensorValues => _currentSensorValues;
  List<Map<String, dynamic>> get loadedLogData => _loadedLogData;
  List<String> get availableChannels => _availableChannels;
  List<String> get selectedOverlayChannels => _selectedOverlayChannels;
  
  List<String> get rawSerialLogs => _rawSerialLogs;
  bool get pauseAutoScroll => _pauseAutoScroll;

  // Stats Getters
  double? get maxTps => _maxTps;
  double? get minTps => _minTps;
  double? get avgTps => _avgTps;
  double get wotTime => _wotTime;
  
  double? get maxBrake => _maxBrake;
  double? get minBrake => _minBrake;
  double? get avgBrake => _avgBrake;
  int get brakeSpikeCount => _brakeSpikeCount;
  
  double? get maxAngle => _maxAngle;
  double? get minAngle => _minAngle;
  double? get avgAngle => _avgAngle;
  double? get rangeAngle => _rangeAngle;
  
  int get sampleCount => _sampleCount;
  double get sampleRate => _sampleRate;

  Map<String, double> get tpsHistogram => _tpsHistogram;
  Map<String, double> get brakeHistogram => _brakeHistogram;
  Map<String, double> get steeringHistogram => _steeringHistogram;

  List<Map<String, dynamic>> get alerts => _alertsEnabled ? _alerts : [];
  bool get alertsEnabled => _alertsEnabled;

  List<Offset> get ggTrail => List.unmodifiable(_ggTrail);
  double? get crosshairTime => _crosshairTime;

  List<ChatMessage> get chatHistory => _chatHistory;
  bool get isAiSidebarMode => _isAiSidebarMode;
  double get sidebarWidth => _sidebarWidth;
  String get activeTabName => _activeTabName;
  bool get isAiLoading => _isAiLoading;
  List<Map> get aiAlerts => _aiAlerts;

  // Generic channel statistics
  final Map<String, Map<String, double>> _channelStats = {};
  Map<String, Map<String, double>> get channelStats => _channelStats;



  void setCrosshairTime(double? time) {
    if (_crosshairTime != time) {
      _crosshairTime = time;
      notifyListeners();
    }
  }

  bool _hasShownSmartDetection = false;
  bool get hasShownSmartDetection => _hasShownSmartDetection;
  void markSmartDetectionShown() {
    _hasShownSmartDetection = true;
    notifyListeners();
  }

  // File contextrol methods


  void togglePlayback() {
    if (_loadedLogData.isEmpty) return;
    if (_currentTimestampMs >= _totalDurationMs) {
      _currentTimestampMs = 0;
    }
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _startTimer();
    } else {
      _playbackTimer?.cancel();
    }
    notifyListeners();
  }

  void stopPlayback() {
    _playbackTimer?.cancel();
    _isPlaying = false;
    seekTo(0);
  }

  void restartPlayback() {
    _playbackTimer?.cancel();
    _currentTimestampMs = 0;
    _isPlaying = true;
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    // 120Hz update rate (~8ms per tick)
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 8), (timer) {
      _currentTimestampMs += (8 * _playbackSpeed).round();
      if (_currentTimestampMs > _totalDurationMs) {
        _currentTimestampMs = _totalDurationMs;
        _isPlaying = false;
        timer.cancel();
      }
      
      if (_loadedLogData.isNotEmpty) {
        final targetData = _loadedLogData.firstWhere(
            (d) => (d['Time_ms'] as double) >= _currentTimestampMs, 
            orElse: () => _loadedLogData.last
        );
        _updateLiveSensorValuesInternal(targetData);
      }
      
      _crosshairTime = _currentTimestampMs.toDouble();
      
      notifyListeners();
    });
  }

  void setPlaybackSpeed(double speed) {
    if (const [0.25, 0.5, 1.0, 2.0, 5.0].contains(speed)) {
      _playbackSpeed = speed;
      notifyListeners();
    }
  }

  void seekTo(int timestampMs) {
    _currentTimestampMs = timestampMs.clamp(0, _totalDurationMs);
    if (_loadedLogData.isNotEmpty) {
        final targetData = _loadedLogData.firstWhere(
            (d) => (d['Time_ms'] as double) >= _currentTimestampMs, 
            orElse: () => _loadedLogData.last
        );
        _updateLiveSensorValuesInternal(targetData);
    }
    _crosshairTime = _currentTimestampMs.toDouble();
    notifyListeners();
  }
  
  void _updateLiveSensorValuesInternal(Map<String, dynamic> newValues) {
    Map<String, double> rawValues = {};
    Map<String, double?> newDoubles = {};

    newValues.forEach((key, val) {
      if (val is num) {
        rawValues[key] = val.toDouble();
        newDoubles[key] = val.toDouble();
      } else if (key == 'Vehicle_State' && val is String) {
        _currentVehicleState = val;
      }
    });

    final derived = MathChannelService().evaluateAll(_customChannels, rawValues);
    
    _currentSensorValues = {..._currentSensorValues, ...newDoubles, ...derived};
    
    double? gyroX = _currentSensorValues['Gyro_X'];
    double? gyroY = _currentSensorValues['Gyro_Y'];
    if (gyroX != null && gyroY != null) {
      double latG = gyroX / 131.0;
      double longG = gyroY / 131.0;
      _ggTrail.add(Offset(latG, longG));
      if (_ggTrail.length > 100) {
        _ggTrail.removeAt(0);
      }
    }
  }

  void updateLiveSensorValues(Map<String, dynamic> newValues) {
    _updateLiveSensorValuesInternal(newValues);
    notifyListeners();
  }

  void toggleOverlayChannel(String channel) {
    if (_selectedOverlayChannels.contains(channel)) {
      _selectedOverlayChannels.remove(channel);
    } else {
      if (_selectedOverlayChannels.length < 18) {
        _selectedOverlayChannels.add(channel);
      }
    }
    notifyListeners();
  }

  void clearOverlayChannels() {
    _selectedOverlayChannels.clear();
    notifyListeners();
  }

  void toggleAiSidebarMode() {
    _isAiSidebarMode = !_isAiSidebarMode;
    notifyListeners();
  }
  
  void setAiSidebarMode(bool isAi) {
    if (_isAiSidebarMode != isAi) {
      _isAiSidebarMode = isAi;
      notifyListeners();
    }
  }

  void setSidebarWidth(double width) {
    if (_sidebarWidth != width) {
      if (width < 200.0) width = 200.0;
      if (width > 600.0) width = 600.0;
      _sidebarWidth = width;
      notifyListeners();
    }
  }

  void setActiveTabName(String name) {
    _activeTabName = name;
    // Don't notify listeners just for this to avoid rebuild loops, it's just state for context.
  }

  void addChatMessage(ChatMessage msg) {
    _chatHistory.add(msg);
    notifyListeners();
  }

  String buildAiContext() {
    return """
ARION DAQ SESSION CONTEXT
Car: AR25 | Driver: ${SettingsService().driverName} #${SettingsService().driverNumber}
File: ${SettingsService().getSessionHistory().isNotEmpty ? SettingsService().getSessionHistory().first['filename'] : 'Current Session'} | Duration: ${_totalDurationMs / 1000}s
Sample Rate: ${_sampleRate.toStringAsFixed(1)}Hz | Samples: $_sampleCount

CHANNEL STATISTICS:
${_channelStats.entries.map((e) => '${e.key}: min=${e.value['min']?.toStringAsFixed(1) ?? 'N/A'} max=${e.value['max']?.toStringAsFixed(1) ?? 'N/A'} avg=${e.value['avg']?.toStringAsFixed(1) ?? 'N/A'}').join('\n')}

DETECTED ALERT EVENTS:
${_alerts.map((a) => '${a['time'] / 1000}s: ${a['event']}').join('\n')}

CURRENT TAB: $_activeTabName
CURRENT REPLAY TIME: ${(_currentTimestampMs / 1000).toStringAsFixed(2)}s

You are an expert Formula Student data engineer for Team Arion AR25.
Analyze telemetry data and answer questions about driver performance,
car setup, and sensor anomalies. Be concise and precise.
Reference specific timestamps and values from the data.
Use engineering terminology appropriate for FSAE competition.
  """;
  }

  void loadLogData(List<Map<String, dynamic>> data, int durationMs, {String filename = 'LOG_1.CSV', String? filepath}) {
    _hasShownSmartDetection = false;
    _loadedLogData = data;
    _totalDurationMs = durationMs;
    
    if (data.isNotEmpty) {
      MathChannelService().resetDerivatives();
      
      // Register unknown channels
      for (String key in data.first.keys) {
        if (key != 'Time_ms') {
          ParameterRegistry().getParameter(key);
        }
      }

      // Compute derived channels
      _computeDerivedChannelsForDataset();

      for (var item in _loadedLogData) {
        final Map<String, double> rawValues = {};
        item.forEach((key, val) {
          if (val is num) rawValues[key] = val.toDouble();
        });
        
        final derived = MathChannelService().evaluateAll(_customChannels, rawValues);
        item.addAll(derived);
      }

      _availableChannels = _loadedLogData.first.keys.where((k) => k != 'Time_ms' && _loadedLogData.first[k] is! String).toList();
      _availableChannels.sort();
    } else {
      _availableChannels = [];
    }
    
    _calculateStats();
    _generateAlerts();
    _generateHistograms();
    _chatHistory.clear(); // Clear chat on new CSV
    
    // Auto AI Analysis
    // _triggerAutoAnalysis();
    
    // Save to history
    SettingsService().addSessionToHistory({
      'filename': filename,
      'filepath': filepath ?? filename,
      'date': DateTime.now().toIso8601String(),
      'duration': _totalDurationMs,
      'peak_tps': _maxTps ?? 0.0,
      'peak_brake': _maxBrake ?? 0.0,
      'samples': _sampleCount,
    });
    
    seekTo(0);
    notifyListeners();
  }


  Future<void> _triggerAutoAnalysis() async {
    if (SettingsService().groqApiKey.isEmpty) {
      addChatMessage(ChatMessage(role: 'ai', content: 'Set API key in Settings → AI Configuration to enable AI', model: 'groq', timestamp: DateTime.now()));
      _isAiLoading = false;
      notifyListeners();
      return;
    }
    _isAiLoading = true;
    _aiAlerts.clear();
    notifyListeners();

    String contextStr = buildAiContext();
    
    // 1. 3-point analysis
    String res1 = await AiService.ask('', contextStr, [], 'Provide a concise 3-point session analysis covering:\n1. Throttle usage patterns\n2. Braking events and efficiency\n3. Any anomalies or concerns detected\nKeep each point to 1-2 sentences.');
    if (res1.isNotEmpty && !res1.startsWith('Error')) {
      addChatMessage(ChatMessage(role: 'assistant', content: res1, model: 'groq', timestamp: DateTime.now()));
    }

    String res2 = await AiService.ask('', contextStr, [], 'Identify concerning patterns in this telemetry.\nFormat each as: [SEVERITY] [CHANNEL] @[TIME]s: [description]\nSeverity options: INFO, WARNING, DANGER\nMaximum 5 findings.');
    if (!res2.startsWith("Error")) {
      final lines = res2.split('\n');
      for (var line in lines) {
        if (line.contains('[') && line.contains('] @') && line.contains('s:')) {
           try {
             final sevMatch = RegExp(r'\[(.*?)\]').firstMatch(line);
             final chanMatch = RegExp(r'\] \[(.*?)\] @').firstMatch(line);
             final timeMatch = RegExp(r'@(.*?)s:').firstMatch(line);
             final descMatch = RegExp(r's: (.*)').firstMatch(line);
             
             if (sevMatch != null && chanMatch != null && timeMatch != null && descMatch != null) {
               _aiAlerts.add({
                 'time': (double.parse(timeMatch.group(1)!.trim()) * 1000).toDouble(),
                 'channel': chanMatch.group(1),
                 'event': '🤖 AI: ${descMatch.group(1)}',
                 'severity': sevMatch.group(1)!.trim(),
               });
             }
           } catch(e) {
             debugPrint('Error parsing AI alert: $line');
           }
        }
      }
    }

    _isAiLoading = false;
    notifyListeners();

    // Small toast notification bottom right
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('AI Analysis Complete ✦', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: RacingTheme.primaryAccent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, right: 20, left: 600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  void _calculateStats() {
    if (_loadedLogData.isEmpty) return;
    
    _sampleCount = _loadedLogData.length;
    _sampleRate = _sampleCount / (_totalDurationMs / 1000.0);
    
    double sumTps = 0;
    double sumBrake = 0;
    double sumAngle = 0;
    
    int tpsCount = 0;
    int brakeCount = 0;
    int angleCount = 0;
    
    _maxTps = null; _minTps = null; _avgTps = null; _wotTime = 0;
    _maxBrake = null; _minBrake = null; _avgBrake = null; _brakeSpikeCount = 0;
    _maxAngle = null; _minAngle = null; _avgAngle = null; _rangeAngle = null;
    
    double wotThreshold = SettingsService().tpsWotThreshold;
    double brakeWarn = SettingsService().brakeWarningThreshold;

    _channelStats.clear();
    Map<String, double> sumMap = {};
    Map<String, int> countMap = {};

    for (var item in _loadedLogData) {
      for (var entry in item.entries) {
        if (entry.key == 'Time_ms' || entry.value == null) continue;
        if (entry.value is num) {
          double val = (entry.value as num).toDouble();
          if (!_channelStats.containsKey(entry.key)) {
            _channelStats[entry.key] = {'min': val, 'max': val};
            sumMap[entry.key] = 0;
            countMap[entry.key] = 0;
          }
          var stats = _channelStats[entry.key]!;
          if (val < stats['min']!) stats['min'] = val;
          if (val > stats['max']!) stats['max'] = val;
          sumMap[entry.key] = sumMap[entry.key]! + val;
          countMap[entry.key] = countMap[entry.key]! + 1;
        }
      }

      double? tps = item['TPS_Deg'] as double?;
      double? brake = item['Brake_Bar'] as double?;
      double? angle = item['Angle'] as double?;
      
      if (tps != null) {
        if (_maxTps == null || tps > _maxTps!) _maxTps = tps;
        if (_minTps == null || tps < _minTps!) _minTps = tps;
        sumTps += tps;
        tpsCount++;
        if (tps >= wotThreshold) _wotTime += (1.0 / _sampleRate);
      }
      
      if (brake != null) {
        if (_maxBrake == null || brake > _maxBrake!) _maxBrake = brake;
        if (_minBrake == null || brake < _minBrake!) _minBrake = brake;
        sumBrake += brake;
        brakeCount++;
        if (brake > brakeWarn) _brakeSpikeCount++; // rough estimation
      }
      
      if (angle != null) {
        if (_maxAngle == null || angle > _maxAngle!) _maxAngle = angle;
        if (_minAngle == null || angle < _minAngle!) _minAngle = angle;
        sumAngle += angle;
        angleCount++;
      }
    }

    sumMap.forEach((key, sum) {
      if (countMap[key]! > 0) {
        _channelStats[key]!['avg'] = sum / countMap[key]!;
      }
    });

    
    if (tpsCount > 0) _avgTps = sumTps / tpsCount;
    if (brakeCount > 0) _avgBrake = sumBrake / brakeCount;
    if (angleCount > 0) {
      _avgAngle = sumAngle / angleCount;
      _rangeAngle = (_maxAngle ?? 0) - (_minAngle ?? 0);
    }
  }

  void _computeDerivedChannelsForDataset() {
    if (_loadedLogData.isEmpty) return;
    
    double sampleRate = _loadedLogData.length / (_totalDurationMs / 1000.0);
    double dt = 1.0 / (sampleRate > 0 ? sampleRate : 1.0);

    bool calcThrottleRate = SettingsService().getDerivedChannelToggle('Throttle Rate');
    bool calcBrakeRate = SettingsService().getDerivedChannelToggle('Brake Rate');
    bool calcTotalBrake = SettingsService().getDerivedChannelToggle('Total Brake Effort');
    bool calcBrakeBias = SettingsService().getDerivedChannelToggle('Brake Bias (Front %)');
    bool calcLongG = SettingsService().getDerivedChannelToggle('Longitudinal G');
    bool calcLatG = SettingsService().getDerivedChannelToggle('Lateral G');
    bool calcTotalG = SettingsService().getDerivedChannelToggle('Total G');
    bool calcJerk = SettingsService().getDerivedChannelToggle('Longitudinal Jerk');
    bool calcSpeed = SettingsService().getDerivedChannelToggle('Vehicle Speed');
    bool calcSpeedDiff = SettingsService().getDerivedChannelToggle('Wheel Speed Diff');
    bool calcPitch = SettingsService().getDerivedChannelToggle('Pitch Estimate');
    bool calcSuspComp = SettingsService().getDerivedChannelToggle('FL Compression');
    bool calcTireDiff = SettingsService().getDerivedChannelToggle('Tire Temp Diff (L-R)');
    bool calcTireRate = SettingsService().getDerivedChannelToggle('L Tire Heating Rate');
    bool calcBatDrop = SettingsService().getDerivedChannelToggle('Voltage Drop');
    bool calcState = SettingsService().getDerivedChannelToggle('Vehicle_State');
    
    double maxBattery = 0.0;
    if (calcBatDrop) {
      for (var row in _loadedLogData) {
        double? v = row['Battery_V'] as double?;
        if (v != null && v > maxBattery) maxBattery = v;
      }
    }
    
    Map<String, double> rhMeans = {};
    if (calcSuspComp) {
      for (String rh in ['RideHeight_FL', 'RideHeight_FR', 'RideHeight_RL', 'RideHeight_RR']) {
        double sum = 0;
        int count = 0;
        for (var row in _loadedLogData) {
          if (row[rh] != null) {
            sum += (row[rh] as num).toDouble();
            count++;
          }
        }
        rhMeans[rh] = count > 0 ? sum / count : 0.0;
      }
    }

    double prevTps = 0;
    double prevBrake = 0;
    double prevSpeed = 0;
    double prevLongG = 0;
    Map<String, double> prevTire = {'L': 0, 'R': 0};

    for (int i = 0; i < _loadedLogData.length; i++) {
      var row = _loadedLogData[i];
      
      double? getD(String k) => row[k] != null ? (row[k] as num).toDouble() : null;

      double? tps = getD('TPS_Deg') ?? getD('Throttle_percent');
      double? brakeF = getD('Brake_Bar') ?? getD('FrontBrake_bar');
      double? brakeR = getD('Brake_Rear') ?? getD('RearBrake_bar');
      double? gyroY = getD('Gyro_Y') ?? getD('Gy');
      double? gyroZ = getD('Gyro_Z') ?? getD('Gz');
      double? accelX = getD('Accel_X') ?? getD('Ax') ?? getD('LongAccel_G');
      double? accelY = getD('Accel_Y') ?? getD('Ay') ?? getD('LatAccel_G');
      double? speedBase = getD('Wheel_Speed') ?? getD('Vehicle_Speed');
      double? speedL = getD('Wheel_Speed_L') ?? getD('WheelLeft_kph') ?? getD('WheelLeft_Hz');
      double? speedR = getD('Wheel_Speed_R') ?? getD('WheelRight_kph') ?? getD('WheelRight_Hz');

      if (calcThrottleRate && tps != null) {
        row['Throttle Rate'] = (tps - prevTps) / dt;
        prevTps = tps;
      }
      if (calcBrakeRate && brakeF != null) {
        row['Brake Rate'] = (brakeF - prevBrake) / dt;
        prevBrake = brakeF;
      }
      if (calcTotalBrake && brakeF != null) {
        row['Total Brake Effort'] = brakeF;
      }
      if (calcBrakeBias && brakeF != null && brakeR != null) {
        row['Brake Bias (Front %)'] = (brakeF / (brakeF + brakeR)) * 100.0;
      }
      
      double? speedToUse = speedBase;
      if (speedToUse == null && speedL != null && speedR != null) {
        speedToUse = (speedL + speedR) / 2.0;
      }
      if (calcSpeed && speedToUse != null && getD('GPS_Speed') == null) {
         row['Vehicle Speed'] = speedToUse;
      }
      if (calcSpeedDiff && speedL != null && speedR != null) {
         row['Wheel Speed Diff'] = (speedL - speedR).abs();
      }

      double? currentLongG;
      if (calcLongG) {
        if (gyroY != null) currentLongG = gyroY / 131.0;
        if (accelX != null) currentLongG = accelX;
        if (currentLongG == null && speedToUse != null) {
          double v1 = prevSpeed / 3.6;
          double v2 = speedToUse / 3.6;
          currentLongG = ((v2 - v1) / dt) / 9.81;
        }
        if (currentLongG != null) {
          row['Longitudinal G'] = currentLongG;
        }
        if (speedToUse != null) prevSpeed = speedToUse;
      }
      
      double? currentLatG;
      if (calcLatG) {
        if (accelY != null) currentLatG = accelY;
        if (currentLatG != null) row['Lateral G'] = currentLatG;
      }

      if (calcTotalG && currentLongG != null && currentLatG != null) {
        row['Total G'] = math.sqrt(currentLongG * currentLongG + currentLatG * currentLatG);
      }
      
      if (calcJerk && currentLongG != null) {
        row['Longitudinal Jerk'] = (currentLongG - prevLongG) / dt;
        prevLongG = currentLongG;
      }

      if (calcPitch) {
        double? fl = getD('RideHeight_FL');
        double? fr = getD('RideHeight_FR');
        if (fl != null && fr != null) {
           row['Pitch Estimate'] = math.atan2(fl - fr, 1200.0) * 180.0 / math.pi;
        }
      }

      if (calcSuspComp) {
        for (String rh in ['FL', 'FR', 'RL', 'RR']) {
          double? v = getD('RideHeight_$rh');
          if (v != null) row['$rh Compression'] = v - (rhMeans['RideHeight_$rh'] ?? 0);
        }
      }

      double? tL = getD('TireTemp_L_Obj');
      double? tR = getD('TireTemp_R_Obj');
      if (calcTireDiff && tL != null && tR != null) {
        row['Tire Temp Diff (L-R)'] = tL - tR;
      }
      if (calcTireRate) {
        if (tL != null) { row['L Tire Heating Rate'] = (tL - prevTire['L']!) / dt; prevTire['L'] = tL; }
        if (tR != null) { row['R Tire Heating Rate'] = (tR - prevTire['R']!) / dt; prevTire['R'] = tR; }
      }

      if (calcBatDrop) {
        double? bat = getD('Battery_V');
        if (bat != null) {
          row['Voltage Drop'] = maxBattery - bat;
        }
      }
      
      if (calcState) {
        String state = 'STATIONARY';
        double s = speedToUse ?? 0;
        double t = tps ?? 0;
        double b = brakeF ?? 0;
        double z = gyroZ ?? 0;
        
        if (s < 2) {
          state = 'STATIONARY';
        } else if (b > 10 && z.abs() > 30) {
          state = 'COMBINED_BRAKE_CORNER';
        } else if (t > 60 && z.abs() > 30) {
          state = 'COMBINED_ACCEL_CORNER';
        } else if (b > 10 && t < 10) {
          state = 'BRAKING';
        } else if (t > 60 && b < 2) {
          state = 'ACCELERATING';
        } else if (z > 30) {
          state = 'CORNERING_L';
        } else if (z < -30) {
          state = 'CORNERING_R';
        } else if (t < 10 && b < 2 && s > 5) {
          state = 'COASTING';
        }
        row['Vehicle_State'] = state;
      }
    }
  }

  void reScanAlerts() {
    _generateAlerts();
    notifyListeners();
  }

  void _generateAlerts() {
    _alerts.clear();
    if (!_alertsEnabled) return;
    if (_loadedLogData.isEmpty) return;
    if (!SettingsService().enableAlertDetection) return;

    double warnBrake = SettingsService().brakeWarningThreshold;
    double dangerBrake = SettingsService().brakeDangerThreshold;
    double extremeSteer = SettingsService().steeringExtremeThreshold;
    double wotThreshold = SettingsService().tpsWotThreshold;
    
    double prevTps = 0.0;
    double prevTime = 0.0;
    double prevAngle = 0.0;
    bool wasWot = false;
    bool wasBraking = false;

    for (var item in _loadedLogData) {
      double t = item['Time_ms'] as double;
      double? brake = item['Brake_Bar'] as double?;
      double? angle = item['Angle'] as double?;
      double? tps = item['TPS_Deg'] as double?;
      double? gyroZ = item['Gyro_Z'] as double?;
      double? diff = item['Wheel Speed Diff'] as double?;

      if (brake != null) {
        if (brake > 5.0 && !wasBraking) {
          _alerts.add({'time': t, 'channel': 'Brake_Bar', 'event': 'BRAKE_APPLIED', 'value': brake, 'severity': 'info'});
          wasBraking = true;
        } else if (brake < 5.0 && wasBraking) {
          _alerts.add({'time': t, 'channel': 'Brake_Bar', 'event': 'BRAKE_RELEASED', 'value': brake, 'severity': 'info'});
          wasBraking = false;
        }

        if (brake > dangerBrake) {
          _alerts.add({'time': t, 'channel': 'Brake_Bar', 'event': 'DANGER SPIKE', 'value': brake, 'severity': 'danger'});
        } else if (brake > warnBrake) {
          _alerts.add({'time': t, 'channel': 'Brake_Bar', 'event': 'HEAVY_BRAKING', 'value': brake, 'severity': 'warning'});
        }
      }

      if (angle != null) {
        if (angle.abs() > extremeSteer) {
          _alerts.add({'time': t, 'channel': 'Angle', 'event': 'HARD CORNERING', 'value': angle, 'severity': 'warning'});
        }
        if ((angle - prevAngle).abs() / ((t - prevTime) / 1000.0) > 100.0 && t - prevTime > 0) {
          _alerts.add({'time': t, 'channel': 'Angle', 'event': 'RAPID_STEERING', 'value': angle, 'severity': 'warning'});
        }
        prevAngle = angle;
      }

      if (gyroZ != null && gyroZ.abs() > 50.0) {
         _alerts.add({'time': t, 'channel': 'Gyro_Z', 'event': 'HARD_CORNER', 'value': gyroZ, 'severity': 'warning'});
      }

      if (diff != null && diff > 5.0) {
         _alerts.add({'time': t, 'channel': 'Wheel Speed Diff', 'event': 'WHEEL_MISMATCH', 'value': diff, 'severity': 'warning'});
      }

      if (tps != null) {
        if (tps >= wotThreshold && !wasWot) {
          _alerts.add({'time': t, 'channel': 'TPS_Deg', 'event': 'FULL_THROTTLE', 'value': tps, 'severity': 'info'});
          wasWot = true;
        } else if (tps < wotThreshold) {
          wasWot = false;
        }

        if (prevTps > 60.0 && tps < 20.0 && (t - prevTime) < 500.0) {
          _alerts.add({'time': t, 'channel': 'TPS_Deg', 'event': 'LIFT_OFF', 'value': tps, 'severity': 'warning'});
        }
        
        // update prev for tps and time here for accurate rate calculation
        if (tps != prevTps) { // to not divide by small dt if identical sample
          prevTps = tps;
          prevTime = t;
        }
      }
    }
  }

  void _generateHistograms() {
    _tpsHistogram.clear();
    _brakeHistogram.clear();
    _steeringHistogram.clear();
    if (_loadedLogData.isEmpty || _sampleRate == 0) return;

    double timePerSample = 1.0 / _sampleRate;

    for (var item in _loadedLogData) {
      double? tps = item['TPS_Deg'] as double?;
      if (tps != null) {
        int bin = (tps / 10).floor() * 10;
        String key = '$bin-${bin + 10}°';
        _tpsHistogram[key] = (_tpsHistogram[key] ?? 0.0) + timePerSample;
      }

      double? brake = item['Brake_Bar'] as double?;
      if (brake != null) {
        int bin = (brake / 5).floor() * 5;
        String key = '$bin-${bin + 5}bar';
        _brakeHistogram[key] = (_brakeHistogram[key] ?? 0.0) + timePerSample;
      }

      double? angle = item['Angle'] as double?;
      if (angle != null) {
        int bin = (angle / 20).floor() * 20;
        String key = '$bin-${bin + 20}°';
        _steeringHistogram[key] = (_steeringHistogram[key] ?? 0.0) + timePerSample;
      }
    }
  }

  void addRawSerialLog(String log) {
    _rawSerialLogs.add(log);
    if (_rawSerialLogs.length > 2000) {
      _rawSerialLogs.removeAt(0);
    }
    notifyListeners();
  }
  
  void toggleLightMode() {
    _isLightMode = !_isLightMode;
    RacingTheme.setLightMode(_isLightMode);
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  void toggleAlerts() {
    _alertsEnabled = !_alertsEnabled;
    if (_alertsEnabled) {
      _generateAlerts();
    } else {
      _alerts.clear();
    }
    notifyListeners();
  }
  
  void clearSerialLogs() {
    _rawSerialLogs.clear();
    notifyListeners();
  }
  
  void setPauseAutoScroll(bool pause) {
    _pauseAutoScroll = pause;
    notifyListeners();
  }
  
  Future<void> askAi(String text) async {
    final provider = SettingsService().aiProvider;
    
    String contextStr = buildAiContext();
    List<Map<String, String>> messages = _chatHistory
        .where((m) => m.role != 'error')
        .map((m) => {
          'role': (m.role == 'ai' || m.role == 'assistant') ? 'assistant' : 'user',
          'content': m.content,
        }).toList();

    addChatMessage(ChatMessage(role: 'user', content: text, model: provider, timestamp: DateTime.now()));
    
    _isAiLoading = true;
    notifyListeners();

    String response = await AiService.ask('', contextStr, messages, text);
    
    if (response.startsWith("Error")) {
      addChatMessage(ChatMessage(role: 'error', content: response, model: provider, timestamp: DateTime.now()));
    } else {
      addChatMessage(ChatMessage(role: 'assistant', content: response, model: provider, timestamp: DateTime.now()));
    }
    
    _isAiLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }
}
