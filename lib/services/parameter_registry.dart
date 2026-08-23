import 'package:flutter/material.dart';
import 'dart:math' as math;

class ParameterDefinition {
  final String rawName;
  String displayName;
  String group;
  String unit;
  Color color;
  bool isDerived;
  String? description;

  ParameterDefinition({
    required this.rawName,
    required this.displayName,
    required this.group,
    required this.unit,
    required this.color,
    this.isDerived = false,
    this.description,
  });
}

class ParameterRegistry {
  static final ParameterRegistry _instance = ParameterRegistry._internal();
  factory ParameterRegistry() => _instance;
  ParameterRegistry._internal();

  final Map<String, ParameterDefinition> _knownParameters = {
    // RAW SENSORS
    'Wheel_Speed': ParameterDefinition(rawName: 'Wheel_Speed', displayName: 'Vehicle Speed', group: 'SPEED', unit: 'km/h', color: Colors.blueAccent),
    'WheelLeft_kph': ParameterDefinition(rawName: 'WheelLeft_kph', displayName: 'Left Wheel Speed', group: 'SPEED', unit: 'km/h', color: Colors.lightBlue),
    'WheelRight_kph': ParameterDefinition(rawName: 'WheelRight_kph', displayName: 'Right Wheel Speed', group: 'SPEED', unit: 'km/h', color: Colors.cyan),
    'WheelLeft_Hz': ParameterDefinition(rawName: 'WheelLeft_Hz', displayName: 'Left Wheel Speed (Hz)', group: 'SPEED', unit: 'Hz', color: Colors.lightBlue),
    'WheelRight_Hz': ParameterDefinition(rawName: 'WheelRight_Hz', displayName: 'Right Wheel Speed (Hz)', group: 'SPEED', unit: 'Hz', color: Colors.cyan),
    'FrontBrake_bar': ParameterDefinition(rawName: 'FrontBrake_bar', displayName: 'Front Brake Pressure', group: 'BRAKES', unit: 'bar', color: Colors.redAccent),
    'RearBrake_bar': ParameterDefinition(rawName: 'RearBrake_bar', displayName: 'Rear Brake Pressure', group: 'BRAKES', unit: 'bar', color: Colors.deepOrange),
    'Throttle_percent': ParameterDefinition(rawName: 'Throttle_percent', displayName: 'Throttle Position', group: 'THROTTLE', unit: '%', color: Colors.greenAccent),
    'EngineRPM': ParameterDefinition(rawName: 'EngineRPM', displayName: 'Engine RPM', group: 'ENGINE', unit: 'rpm', color: Colors.pinkAccent),
    'LongAccel_G': ParameterDefinition(rawName: 'LongAccel_G', displayName: 'Longitudinal G', group: 'IMU', unit: 'g', color: Colors.amberAccent),
    'LatAccel_G': ParameterDefinition(rawName: 'LatAccel_G', displayName: 'Lateral G', group: 'IMU', unit: 'g', color: Colors.amber),
    'Ax': ParameterDefinition(rawName: 'Ax', displayName: 'Longitudinal G', group: 'IMU', unit: 'g', color: Colors.amberAccent),
    'Ay': ParameterDefinition(rawName: 'Ay', displayName: 'Lateral G', group: 'IMU', unit: 'g', color: Colors.amber),
    'Az': ParameterDefinition(rawName: 'Az', displayName: 'Vertical G', group: 'IMU', unit: 'g', color: Colors.yellowAccent),
    'Gx': ParameterDefinition(rawName: 'Gx', displayName: 'Roll Rate (Gx)', group: 'IMU', unit: '°/s', color: Colors.orangeAccent),
    'Gy': ParameterDefinition(rawName: 'Gy', displayName: 'Pitch Rate (Gy)', group: 'IMU', unit: '°/s', color: Colors.orange),
    'Gz': ParameterDefinition(rawName: 'Gz', displayName: 'Yaw Rate (Gz)', group: 'IMU', unit: '°/s', color: Colors.deepOrangeAccent),
    'RideHeight_FL': ParameterDefinition(rawName: 'RideHeight_FL', displayName: 'Ride Height FL', group: 'SUSPENSION', unit: 'mm', color: Colors.indigoAccent),
    'RideHeight_FR': ParameterDefinition(rawName: 'RideHeight_FR', displayName: 'Ride Height FR', group: 'SUSPENSION', unit: 'mm', color: Colors.indigo),
    'RideHeight_RL': ParameterDefinition(rawName: 'RideHeight_RL', displayName: 'Ride Height RL', group: 'SUSPENSION', unit: 'mm', color: Colors.blueGrey),
    'RideHeight_RR': ParameterDefinition(rawName: 'RideHeight_RR', displayName: 'Ride Height RR', group: 'SUSPENSION', unit: 'mm', color: Colors.grey),
    'BrakeTemp_FL': ParameterDefinition(rawName: 'BrakeTemp_FL', displayName: 'Brake Temp FL', group: 'TEMPERATURES', unit: '°C', color: Colors.red),
    'BrakeTemp_FR': ParameterDefinition(rawName: 'BrakeTemp_FR', displayName: 'Brake Temp FR', group: 'TEMPERATURES', unit: '°C', color: Colors.redAccent),
    'TireTemp_L_Obj': ParameterDefinition(rawName: 'TireTemp_L_Obj', displayName: 'Tire Temp Left', group: 'TEMPERATURES', unit: '°C', color: Colors.orange),
    'TireTemp_R_Obj': ParameterDefinition(rawName: 'TireTemp_R_Obj', displayName: 'Tire Temp Right', group: 'TEMPERATURES', unit: '°C', color: Colors.deepOrange),
    'TireTemp_L_Amb': ParameterDefinition(rawName: 'TireTemp_L_Amb', displayName: 'Ambient Temp Left', group: 'TEMPERATURES', unit: '°C', color: Colors.lightGreen),
    'TireTemp_R_Amb': ParameterDefinition(rawName: 'TireTemp_R_Amb', displayName: 'Ambient Temp Right', group: 'TEMPERATURES', unit: '°C', color: Colors.green),
    'Battery_V': ParameterDefinition(rawName: 'Battery_V', displayName: 'Battery Voltage', group: 'ELECTRICAL', unit: 'V', color: Colors.yellow),
    'RPM': ParameterDefinition(rawName: 'RPM', displayName: 'Engine RPM', group: 'ENGINE', unit: 'rpm', color: Colors.pinkAccent),
    'Coolant_Temp': ParameterDefinition(rawName: 'Coolant_Temp', displayName: 'Coolant Temp', group: 'ENGINE', unit: '°C', color: Colors.pink),
    'LAT': ParameterDefinition(rawName: 'LAT', displayName: 'GPS Latitude', group: 'GPS', unit: '°', color: Colors.teal),
    'LON': ParameterDefinition(rawName: 'LON', displayName: 'GPS Longitude', group: 'GPS', unit: '°', color: Colors.tealAccent),
    'GPS_Speed': ParameterDefinition(rawName: 'GPS_Speed', displayName: 'GPS Speed', group: 'GPS', unit: 'km/h', color: Colors.lightBlueAccent),

    // CUSTOM EXCEL HEADERS (from user screenshot)
    'FrontBrake': ParameterDefinition(rawName: 'FrontBrake', displayName: 'Front Brake Pressure', group: 'BRAKES', unit: 'bar', color: Colors.redAccent),
    'RearBrake': ParameterDefinition(rawName: 'RearBrake', displayName: 'Rear Brake Pressure', group: 'BRAKES', unit: 'bar', color: Colors.deepOrange),
    'Throttle_pc': ParameterDefinition(rawName: 'Throttle_pc', displayName: 'Throttle Position', group: 'THROTTLE', unit: '%', color: Colors.greenAccent),
    'Battery_V': ParameterDefinition(rawName: 'Battery_V', displayName: 'Battery Voltage', group: 'ELECTRICAL', unit: 'V', color: Colors.yellow),
    'WheelLeft_': ParameterDefinition(rawName: 'WheelLeft_', displayName: 'Left Wheel Speed', group: 'SPEED', unit: 'km/h', color: Colors.lightBlue),
    'WheelRight_': ParameterDefinition(rawName: 'WheelRight_', displayName: 'Right Wheel Speed', group: 'SPEED', unit: 'km/h', color: Colors.cyan),
    'WheelRigh': ParameterDefinition(rawName: 'WheelRigh', displayName: 'Right Wheel Speed (alt)', group: 'SPEED', unit: 'km/h', color: Colors.cyanAccent),
    'EngineRPM': ParameterDefinition(rawName: 'EngineRPM', displayName: 'Engine RPM', group: 'ENGINE', unit: 'rpm', color: Colors.pinkAccent),
    'RideHeight': ParameterDefinition(rawName: 'RideHeight', displayName: 'Ride Height', group: 'SUSPENSION', unit: 'mm', color: Colors.indigoAccent),
    'LongAccel_': ParameterDefinition(rawName: 'LongAccel_', displayName: 'Longitudinal G', group: 'IMU', unit: 'g', color: Colors.amberAccent),
    'LatAccel_G': ParameterDefinition(rawName: 'LatAccel_G', displayName: 'Lateral G', group: 'IMU', unit: 'g', color: Colors.amber),
    'VertAccel_': ParameterDefinition(rawName: 'VertAccel_', displayName: 'Vertical G', group: 'IMU', unit: 'g', color: Colors.yellowAccent),
    'RollRate_d': ParameterDefinition(rawName: 'RollRate_d', displayName: 'Roll Rate (Gx)', group: 'IMU', unit: '°/s', color: Colors.orangeAccent),
    'PitchRate_': ParameterDefinition(rawName: 'PitchRate_', displayName: 'Pitch Rate (Gy)', group: 'IMU', unit: '°/s', color: Colors.orange),
    'YawRate_c': ParameterDefinition(rawName: 'YawRate_c', displayName: 'Yaw Rate (Gz)', group: 'IMU', unit: '°/s', color: Colors.deepOrangeAccent),
    'Roll_deg': ParameterDefinition(rawName: 'Roll_deg', displayName: 'Roll Angle', group: 'IMU', unit: '°', color: Colors.orangeAccent),
    'Pitch_deg': ParameterDefinition(rawName: 'Pitch_deg', displayName: 'Pitch Angle', group: 'IMU', unit: '°', color: Colors.orange),
    'Yaw_deg': ParameterDefinition(rawName: 'Yaw_deg', displayName: 'Yaw Angle', group: 'IMU', unit: '°', color: Colors.deepOrangeAccent),
    'IMUTemp_': ParameterDefinition(rawName: 'IMUTemp_', displayName: 'IMU Temp', group: 'TEMPERATURES', unit: '°C', color: Colors.white70),
    'TireTempL_': ParameterDefinition(rawName: 'TireTempL_', displayName: 'Tire Temp Left', group: 'TEMPERATURES', unit: '°C', color: Colors.orange),
    'TireTempRight_C': ParameterDefinition(rawName: 'TireTempRight_C', displayName: 'Tire Temp Right', group: 'TEMPERATURES', unit: '°C', color: Colors.deepOrange),

    // DERIVED CHANNELS (pre-registered so they have consistent styling/names)
    'Throttle Rate': ParameterDefinition(rawName: 'Throttle Rate', displayName: 'Throttle Rate', group: 'THROTTLE', unit: '°/s', color: Colors.lightGreenAccent, isDerived: true),
    'Brake Rate': ParameterDefinition(rawName: 'Brake Rate', displayName: 'Brake Rate', group: 'BRAKES', unit: 'bar/s', color: Colors.redAccent, isDerived: true),
    'Total Brake Effort': ParameterDefinition(rawName: 'Total Brake Effort', displayName: 'Total Brake Effort', group: 'BRAKES', unit: 'bar', color: Colors.red, isDerived: true),
    'Brake Bias (Front %)': ParameterDefinition(rawName: 'Brake Bias (Front %)', displayName: 'Brake Bias (Front %)', group: 'BRAKES', unit: '%', color: Colors.deepOrange, isDerived: true),
    'Longitudinal G': ParameterDefinition(rawName: 'Longitudinal G', displayName: 'Longitudinal G', group: 'IMU', unit: 'g', color: Colors.amberAccent, isDerived: true),
    'Lateral G': ParameterDefinition(rawName: 'Lateral G', displayName: 'Lateral G', group: 'IMU', unit: 'g', color: Colors.amber, isDerived: true),
    'Total G': ParameterDefinition(rawName: 'Total G', displayName: 'Total G', group: 'IMU', unit: 'g', color: Colors.yellowAccent, isDerived: true),
    'Longitudinal Jerk': ParameterDefinition(rawName: 'Longitudinal Jerk', displayName: 'Longitudinal Jerk', group: 'IMU', unit: 'g/s', color: Colors.orangeAccent, isDerived: true),
    'Vehicle Speed': ParameterDefinition(rawName: 'Vehicle Speed', displayName: 'Vehicle Speed', group: 'SPEED', unit: 'km/h', color: Colors.blueAccent, isDerived: true),
    'Wheel Speed Diff': ParameterDefinition(rawName: 'Wheel Speed Diff', displayName: 'Wheel Speed Diff', group: 'SPEED', unit: 'km/h', color: Colors.lightBlue, isDerived: true),
    'Pitch Estimate': ParameterDefinition(rawName: 'Pitch Estimate', displayName: 'Pitch Estimate', group: 'SUSPENSION', unit: '°', color: Colors.indigoAccent, isDerived: true),
    'FL Compression': ParameterDefinition(rawName: 'FL Compression', displayName: 'FL Compression', group: 'SUSPENSION', unit: 'mm', color: Colors.indigo, isDerived: true),
    'FR Compression': ParameterDefinition(rawName: 'FR Compression', displayName: 'FR Compression', group: 'SUSPENSION', unit: 'mm', color: Colors.blueGrey, isDerived: true),
    'RL Compression': ParameterDefinition(rawName: 'RL Compression', displayName: 'RL Compression', group: 'SUSPENSION', unit: 'mm', color: Colors.grey, isDerived: true),
    'RR Compression': ParameterDefinition(rawName: 'RR Compression', displayName: 'RR Compression', group: 'SUSPENSION', unit: 'mm', color: Colors.white70, isDerived: true),
    'Tire Temp Diff (L-R)': ParameterDefinition(rawName: 'Tire Temp Diff (L-R)', displayName: 'Tire Temp Diff (L-R)', group: 'TEMPERATURES', unit: '°C', color: Colors.deepOrange, isDerived: true),
    'L Tire Heating Rate': ParameterDefinition(rawName: 'L Tire Heating Rate', displayName: 'L Tire Heating Rate', group: 'TEMPERATURES', unit: '°C/s', color: Colors.orange, isDerived: true),
    'R Tire Heating Rate': ParameterDefinition(rawName: 'R Tire Heating Rate', displayName: 'R Tire Heating Rate', group: 'TEMPERATURES', unit: '°C/s', color: Colors.orangeAccent, isDerived: true),
    'Voltage Drop': ParameterDefinition(rawName: 'Voltage Drop', displayName: 'Voltage Drop', group: 'ELECTRICAL', unit: 'V', color: Colors.yellowAccent, isDerived: true),
    'Vehicle_State': ParameterDefinition(rawName: 'Vehicle_State', displayName: 'Vehicle State', group: 'STATE', unit: '', color: Colors.white, isDerived: true),
  };

  // Additional dynamic mappings (from user settings or auto-detection)
  final Map<String, ParameterDefinition> _dynamicParameters = {};

  void clearDynamicParameters() {
    _dynamicParameters.clear();
  }

  void addDynamicParameter(ParameterDefinition param) {
    _dynamicParameters[param.rawName] = param;
  }

  ParameterDefinition getParameter(String rawName) {
    if (_knownParameters.containsKey(rawName)) {
      return _knownParameters[rawName]!;
    }
    if (_dynamicParameters.containsKey(rawName)) {
      return _dynamicParameters[rawName]!;
    }

    // Try fuzzy match
    String? matched = _fuzzyMatch(rawName);
    if (matched != null) {
      // Create a dynamic mapping pointing to the known definition but with this raw name
      final known = _knownParameters[matched]!;
      final newDef = ParameterDefinition(
        rawName: rawName,
        displayName: known.displayName,
        group: known.group,
        unit: known.unit,
        color: known.color,
        isDerived: known.isDerived,
        description: known.description,
      );
      _dynamicParameters[rawName] = newDef;
      return newDef;
    }

    // Auto generate definition
    final newDef = ParameterDefinition(
      rawName: rawName,
      displayName: _prettify(rawName),
      group: 'UNKNOWN',
      unit: '',
      color: _autoColor(rawName),
    );
    _dynamicParameters[rawName] = newDef;
    debugPrint('Auto-generated definition for unknown parameter: $rawName');
    return newDef;
  }

  String _prettify(String name) {
    String pretty = name.replaceAll('_', ' ');
    // Simple title case
    if (pretty.isNotEmpty) {
      pretty = pretty.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
    return pretty;
  }

  Color _autoColor(String name) {
    final colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.cyan, Colors.indigo];
    int hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  String? _fuzzyMatch(String target) {
    String normalize(String s) => s.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    String normTarget = normalize(target);

    String? bestMatch;
    int bestDist = 3; // Max distance threshold

    for (String key in _knownParameters.keys) {
      String normKey = normalize(key);
      if (normKey == normTarget) return key;

      int dist = _levenshtein(normKey, normTarget);
      if (dist < bestDist) {
        bestDist = dist;
        bestMatch = key;
      }
    }
    return bestMatch;
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List.filled(b.length + 1, 0);
    List<int> v1 = List.filled(b.length + 1, 0);

    for (int i = 0; i <= b.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  List<String> get unknownRawNames {
    return _dynamicParameters.values.where((p) => p.group == 'UNKNOWN').map((p) => p.rawName).toList();
  }

  List<String> getAllKeys() {
    return {..._knownParameters.keys, ..._dynamicParameters.keys}.toList();
  }
}
