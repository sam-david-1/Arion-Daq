import 'dart:io';
import 'package:flutter/foundation.dart';

class FileService {
  /// Parses the CSV in an isolate to prevent UI thread stuttering.
  Future<List<Map<String, dynamic>>> parseCsvLog(String filePath) async {
    return compute(_processFile, filePath);
  }

  static Future<List<Map<String, dynamic>>> _processFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found at $filePath');
    }

    final csvString = await file.readAsString();
    final lines = csvString.split(RegExp(r'\r\n|\n|\r'));
    if (lines.isEmpty) return [];

    final fields = lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.split(',').map((e) => e.trim()).toList())
        .toList();

    if (fields.isEmpty) return [];

    final headerRow = fields.first.map((e) => e.toString().trim()).toList();
    
    // Find time column
    int timeIndex = -1;
    for (int i = 0; i < headerRow.length; i++) {
      final h = headerRow[i].toLowerCase();
      if (h == 'time' || h == 'ms' || h == 'time_ms' || h == 'timestamp') {
        timeIndex = i;
        break;
      }
    }

    if (timeIndex == -1) {
      throw Exception('Could not find a valid time column in the header.');
    }

    List<Map<String, dynamic>> parsedData = [];

    for (int i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.length != headerRow.length) continue; // skip malformed rows

      Map<String, dynamic> rowData = {};
      
      // Parse time specifically to double then int or double
      var timeRaw = row[timeIndex];
      double timeVal = double.tryParse(timeRaw.toString()) ?? 0.0;
      rowData['Time_ms'] = timeVal;

      for (int c = 0; c < headerRow.length; c++) {
        if (c == timeIndex) continue; // already parsed time
        
        final key = headerRow[c];
        final valRaw = row[c];
        
        double parsedVal = double.tryParse(valRaw.toString()) ?? 0.0;
        rowData[key] = parsedVal;
      }
      parsedData.add(rowData);
    }
    
    // Sort chronologically
    parsedData.sort((a, b) => (a['Time_ms'] as double).compareTo(b['Time_ms'] as double));

    return parsedData;
  }
}
