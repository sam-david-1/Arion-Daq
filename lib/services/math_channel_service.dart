import 'package:math_expressions/math_expressions.dart';
import 'package:flutter/foundation.dart';

class CustomChannel {
  final String id;
  String name;
  String expression;
  String unit;

  CustomChannel({
    required this.id,
    required this.name,
    required this.expression,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'expression': expression,
    'unit': unit,
  };

  factory CustomChannel.fromJson(Map<String, dynamic> json) => CustomChannel(
    id: json['id'],
    name: json['name'],
    expression: json['expression'],
    unit: json['unit'],
  );
}

class MathChannelService {
  static final MathChannelService _instance = MathChannelService._internal();
  factory MathChannelService() => _instance;
  MathChannelService._internal();

  final Parser _parser = Parser();
  final Map<String, Expression> _compiledExpressions = {};
  
  // Track previous values for derivative calculations
  final Map<String, double> _prevValues = {};
  double _prevTime = 0.0;

  bool validateExpression(String expressionStr) {
    try {
      String processed = preprocessExpression(expressionStr);
      _parser.parse(processed);
      return true;
    } catch (e) {
      debugPrint('Invalid math expression: $e');
      return false;
    }
  }

  String preprocessExpression(String expr) {
    // Replace deriv(ChannelName) with deriv_ChannelName
    final regex = RegExp(r'deriv\(([a-zA-Z0-9_]+)\)');
    return expr.replaceAllMapped(regex, (match) {
      return 'deriv_${match.group(1)}';
    });
  }

  void compileChannels(List<CustomChannel> channels) {
    _compiledExpressions.clear();
    for (var channel in channels) {
      try {
        String processed = preprocessExpression(channel.expression);
        _compiledExpressions[channel.id] = _parser.parse(processed);
      } catch (e) {
        debugPrint('Failed to compile expression for ${channel.name}: $e');
      }
    }
  }

  // Used for batch processing or single live updates
  Map<String, double> evaluateAll(List<CustomChannel> channels, Map<String, double?> rawData) {
    Map<String, double> results = {};
    
    // Ensure time exists
    if (!rawData.containsKey('Time_ms') || rawData['Time_ms'] == null) return results;
    
    double currentTime = rawData['Time_ms']!;
    double dt = (currentTime - _prevTime) / 1000.0; // seconds
    if (dt <= 0) dt = 0.01; // Avoid divide by zero
    
    // Prepare context with derivations
    Map<String, double> context = {};
    rawData.forEach((key, val) {
      if (val != null) {
        context[key] = val;
        
        // Calculate deriv_X if we have a previous value
        if (_prevValues.containsKey(key)) {
          context['deriv_$key'] = (val - _prevValues[key]!) / dt;
        } else {
          context['deriv_$key'] = 0.0; // First sample
        }
        _prevValues[key] = val;
      }
    });
    
    _prevTime = currentTime;

    ContextModel cm = ContextModel();
    context.forEach((key, value) {
      cm.bindVariable(Variable(key), Number(value));
    });

    for (var channel in channels) {
      if (_compiledExpressions.containsKey(channel.id)) {
        try {
          double val = _compiledExpressions[channel.id]!.evaluate(EvaluationType.REAL, cm);
          if (val.isNaN || val.isInfinite) val = 0.0;
          results[channel.name] = val;
        } catch (e) {
          // Eval failed, maybe missing variables
        }
      }
    }
    
    return results;
  }
  
  void resetDerivatives() {
    _prevValues.clear();
    _prevTime = 0.0;
  }
}
