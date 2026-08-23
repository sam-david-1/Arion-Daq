import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:usb_serial/usb_serial.dart';

class SerialService {
  static final SerialService _instance = SerialService._internal();
  factory SerialService() => _instance;
  SerialService._internal();

  SerialPort? _desktopPort;
  UsbPort? _androidPort;
  
  final StreamController<Map<String, double>> _telemetryController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get telemetryStream => _telemetryController.stream;
  
  final StreamController<String> _rawLogsController = StreamController<String>.broadcast();
  Stream<String> get rawLogsStream => _rawLogsController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  Timer? _reconnectTimer;
  String? _lastConnectedPortName;

  /// Get list of available ports depending on platform.
  Future<List<String>> getAvailablePorts() async {
    List<String> ports = [];
    if (kIsWeb) return ports;
    
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      ports = SerialPort.availablePorts;
    } else if (Platform.isAndroid) {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      ports = devices.map((d) => d.deviceName).whereType<String>().toList();
    }
    return ports;
  }

  /// Connects to a specified port and sets up the listener stream.
  Future<void> connect(String portName) async {
    if (_isConnected) disconnect();
    _lastConnectedPortName = portName;

    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        _desktopPort = SerialPort(portName);
        if (!_desktopPort!.openReadWrite()) {
          throw Exception('Failed to open port $portName');
        }
        
        SerialPortConfig config = _desktopPort!.config;
        config.baudRate = 115200;
        _desktopPort!.config = config;
        
        _isConnected = true;
        _startDesktopListener();
        
      } else if (Platform.isAndroid) {
        List<UsbDevice> devices = await UsbSerial.listDevices();
        final device = devices.firstWhere(
          (d) => d.deviceName == portName, 
          orElse: () => throw Exception('Device not found')
        );
        
        _androidPort = await device.create();
        if (_androidPort == null) {
          throw Exception('Failed to create USB port');
        }
        
        bool openResult = await _androidPort!.open();
        if (!openResult) {
          throw Exception('Failed to open USB port');
        }
        
        await _androidPort!.setDTR(true);
        await _androidPort!.setRTS(true);
        await _androidPort!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
        
        _isConnected = true;
        _startAndroidListener();
      }
      
      _startReconnectMonitor();
    } catch (e) {
      _isConnected = false;
      debugPrint('Connection error: $e');
      rethrow;
    }
  }

  void _startDesktopListener() {
    if (_desktopPort == null) return;
    
    final reader = SerialPortReader(_desktopPort!);
    String buffer = '';
    
    reader.stream.listen((data) {
      buffer += utf8.decode(data, allowMalformed: true);
      _processBuffer(buffer, (newBuffer) {
        buffer = newBuffer;
      });
    }, onError: (error) {
      _handleDisconnect();
    }, onDone: () {
      _handleDisconnect();
    });
  }

  void _startAndroidListener() {
    if (_androidPort == null) return;
    
    String buffer = '';
    _androidPort!.inputStream?.listen((data) {
      buffer += utf8.decode(data, allowMalformed: true);
      _processBuffer(buffer, (newBuffer) {
        buffer = newBuffer;
      });
    }, onError: (error) {
      _handleDisconnect();
    }, onDone: () {
      _handleDisconnect();
    });
  }

  void _processBuffer(String buffer, void Function(String newBuffer) updateBuffer) {
    int newlineIndex = buffer.indexOf('\n');
    while (newlineIndex != -1) {
      String line = buffer.substring(0, newlineIndex).trim();
      buffer = buffer.substring(newlineIndex + 1);
      
      if (line.isNotEmpty) {
        _rawLogsController.add(line);
      }
      _parseLine(line);
      newlineIndex = buffer.indexOf('\n');
    }
    updateBuffer(buffer);
  }

  void _parseLine(String line) {
    if (line.isEmpty) return;
    // Format: Time_ms,TPS_Deg,TPS_V,Brake_Bar,Brake_V,Angle
    List<String> parts = line.split(',');
    if (parts.length >= 6) {
      try {
        Map<String, double> telemetry = {
          'Time_ms': double.parse(parts[0]),
          'TPS_Deg': double.parse(parts[1]),
          'TPS_V': double.parse(parts[2]),
          'Brake_Bar': double.parse(parts[3]),
          'Brake_V': double.parse(parts[4]),
          'Angle': double.parse(parts[5]),
        };
        _telemetryController.add(telemetry);
      } catch (e) {
        // Skip malformed lines silently
      }
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _cleanupPorts();
  }

  void _cleanupPorts() {
    if (_desktopPort != null) {
      try {
        if (_desktopPort!.isOpen) _desktopPort!.close();
        _desktopPort!.dispose();
      } catch (_) {}
      _desktopPort = null;
    }
    if (_androidPort != null) {
      try {
        _androidPort!.close();
      } catch (_) {}
      _androidPort = null;
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _handleDisconnect();
  }

  void _startReconnectMonitor() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isConnected && _lastConnectedPortName != null) {
        debugPrint('Attempting auto-reconnect to $_lastConnectedPortName...');
        try {
          await connect(_lastConnectedPortName!);
        } catch (_) {}
      }
    });
  }

  void setBaudRate(int baudRate) {
    if (_desktopPort != null && _desktopPort!.isOpen) {
      SerialPortConfig config = _desktopPort!.config;
      config.baudRate = baudRate;
      _desktopPort!.config = config;
    } else if (_androidPort != null) {
      _androidPort!.setPortParameters(baudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    }
  }

  void sendCommand(String command) {
    if (!_isConnected) return;
    try {
      final bytes = utf8.encode('$command\r\n');
      if (_desktopPort != null) {
        _desktopPort!.write(Uint8List.fromList(bytes));
      } else if (_androidPort != null) {
        _androidPort!.write(Uint8List.fromList(bytes));
      }
    } catch (e) {
      debugPrint('Failed to send command: $e');
    }
  }
}
