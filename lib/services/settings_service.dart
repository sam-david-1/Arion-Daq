import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Thresholds
  double get brakeWarningThreshold => _prefs.getDouble('brakeWarningThreshold') ?? 40.0;
  Future<void> setBrakeWarningThreshold(double value) async => await _prefs.setDouble('brakeWarningThreshold', value);

  double get brakeDangerThreshold => _prefs.getDouble('brakeDangerThreshold') ?? 55.0;
  Future<void> setBrakeDangerThreshold(double value) async => await _prefs.setDouble('brakeDangerThreshold', value);

  double get tpsWotThreshold => _prefs.getDouble('tpsWotThreshold') ?? 80.0;
  Future<void> setTpsWotThreshold(double value) async => await _prefs.setDouble('tpsWotThreshold', value);

  double get steeringExtremeThreshold => _prefs.getDouble('steeringExtremeThreshold') ?? 90.0;
  Future<void> setSteeringExtremeThreshold(double value) async => await _prefs.setDouble('steeringExtremeThreshold', value);

  // Display
  double get chartLineThickness => _prefs.getDouble('chartLineThickness') ?? 1.5;
  Future<void> setChartLineThickness(double value) async => await _prefs.setDouble('chartLineThickness', value);

  bool get showDataPoints => _prefs.getBool('showDataPoints') ?? false;
  Future<void> setShowDataPoints(bool value) async => await _prefs.setBool('showDataPoints', value);

  String get animationSpeed => _prefs.getString('animationSpeed') ?? 'normal'; // fast, normal, slow
  Future<void> setAnimationSpeed(String value) async => await _prefs.setString('animationSpeed', value);

  bool get enableAlertDetection => _prefs.getBool('enableAlertDetection') ?? true;
  Future<void> setEnableAlertDetection(bool value) async => await _prefs.setBool('enableAlertDetection', value);
  
  bool get enableTelemetrySmoothing => _prefs.getBool('enableTelemetrySmoothing') ?? false;
  Future<void> setEnableTelemetrySmoothing(bool value) async => await _prefs.setBool('enableTelemetrySmoothing', value);
  
  List<String> getSelectedChannels(String tab) {
    String? jsonStr = _prefs.getString('selectedChannels_$tab');
    if (jsonStr == null) return [];
    return List<String>.from(jsonDecode(jsonStr));
  }
  
  Future<void> setSelectedChannels(String tab, List<String> channels) async {
    await _prefs.setString('selectedChannels_$tab', jsonEncode(channels));
  }

  bool getChartBackgroundLight(String channel) => _prefs.getBool('chart_bg_$channel') ?? false;
  Future<void> setChartBackgroundLight(String channel, bool value) async => await _prefs.setBool('chart_bg_$channel', value);

  // Session
  bool get autoLoadLastSession => _prefs.getBool('autoLoadLastSession') ?? true;
  Future<void> setAutoLoadLastSession(bool value) async => await _prefs.setBool('autoLoadLastSession', value);

  int get maxSessionHistory => _prefs.getInt('maxSessionHistory') ?? 10;
  Future<void> setMaxSessionHistory(int value) async => await _prefs.setInt('maxSessionHistory', value);

  // Sidebar
  bool get isSidebarCollapsed => _prefs.getBool('isSidebarCollapsed') ?? false;
  Future<void> setIsSidebarCollapsed(bool value) async => await _prefs.setBool('isSidebarCollapsed', value);

  bool get isAiPanelCollapsed => _prefs.getBool('isAiPanelCollapsed') ?? false;
  Future<void> setIsAiPanelCollapsed(bool value) async => await _prefs.setBool('isAiPanelCollapsed', value);

  bool get isAiSidebarMode => _prefs.getBool('isAiSidebarMode') ?? true;
  Future<void> setIsAiSidebarMode(bool value) async => await _prefs.setBool('isAiSidebarMode', value);

  List<String> get collapsedSidebarGroups => _prefs.getStringList('collapsedSidebarGroups') ?? [];
  Future<void> toggleSidebarGroup(String group) async {
    List<String> groups = collapsedSidebarGroups;
    if (groups.contains(group)) {
      groups.remove(group);
    } else {
      groups.add(group);
    }
    await _prefs.setStringList('collapsedSidebarGroups', groups);
  }

  // Derived Channels Toggles
  bool getDerivedChannelToggle(String channel) => _prefs.getBool('derived_$channel') ?? true;
  Future<void> setDerivedChannelToggle(String channel, bool value) async => await _prefs.setBool('derived_$channel', value);


  // Driver Profile
  String get driverName => _prefs.getString('driverName') ?? 'Unknown Driver';
  Future<void> setDriverName(String value) async => await _prefs.setString('driverName', value);

  String get driverNumber => _prefs.getString('driverNumber') ?? '00';
  Future<void> setDriverNumber(String value) async => await _prefs.setString('driverNumber', value);

  // AI Configuration
  String get groqApiKey => _prefs.getString('groqApiKey') ?? '';
  Future<void> setGroqApiKey(String value) async => await _prefs.setString('groqApiKey', value);
  
  String get geminiApiKey => _prefs.getString('geminiApiKey') ?? '';
  Future<void> setGeminiApiKey(String value) async => await _prefs.setString('geminiApiKey', value);

  String get aiProvider => _prefs.getString('aiProvider') ?? 'gemini';
  Future<void> setAiProvider(String value) async => await _prefs.setString('aiProvider', value);
  


  Map<String, String> get channelRenames {
    String? jsonStr = _prefs.getString('channelRenames');
    if (jsonStr == null) return {};
    return Map<String, String>.from(jsonDecode(jsonStr));
  }
  Future<void> setChannelRename(String original, String newName) async {
    final map = channelRenames;
    map[original] = newName;
    await _prefs.setString('channelRenames', jsonEncode(map));
  }

  Map<String, List<String>> get sessionTags {
    String? jsonStr = _prefs.getString('sessionTags');
    if (jsonStr == null) return {};
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, List<String>.from(v)));
  }
  Future<void> setSessionTags(String filename, List<String> tags) async {
    final map = sessionTags;
    map[filename] = tags;
    await _prefs.setString('sessionTags', jsonEncode(map));
  }

  Map<String, String> get sessionNotes {
    String? jsonStr = _prefs.getString('sessionNotes');
    if (jsonStr == null) return {};
    return Map<String, String>.from(jsonDecode(jsonStr));
  }
  Future<void> setSessionNote(String filename, String note) async {
    final map = sessionNotes;
    map[filename] = note;
    await _prefs.setString('sessionNotes', jsonEncode(map));
  }

  // Custom Channels
  List<dynamic> get customChannelsJson {
    String? jsonStr = _prefs.getString('customChannels');
    if (jsonStr == null) return [];
    try {
      return jsonDecode(jsonStr);
    } catch (e) {
      return [];
    }
  }

  Future<void> setCustomChannelsJson(List<dynamic> channelsJson) async {
    await _prefs.setString('customChannels', jsonEncode(channelsJson));
  }


  // Session History
  List<Map<String, dynamic>> getSessionHistory() {
    String? jsonStr = _prefs.getString('sessionHistory');
    if (jsonStr == null) return [];
    try {
      List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addSessionToHistory(Map<String, dynamic> sessionData) async {
    List<Map<String, dynamic>> history = getSessionHistory();
    history.removeWhere((e) => e['filename'] == sessionData['filename']);
    history.insert(0, sessionData);
    if (history.length > maxSessionHistory) {
      history = history.sublist(0, maxSessionHistory);
    }
    await _prefs.setString('sessionHistory', jsonEncode(history));
  }
  
  Future<void> saveSessionHistory(List<Map<String, dynamic>> history) async {
    await _prefs.setString('sessionHistory', jsonEncode(history));
  }
  
  Future<void> deleteSessionHistory(String filename) async {
    List<Map<String, dynamic>> history = getSessionHistory();
    history.removeWhere((e) => e['filename'] == filename);
    await _prefs.setString('sessionHistory', jsonEncode(history));
  }
  
  Future<void> clearSessionHistory() async {
    await _prefs.remove('sessionHistory');
  }
}
