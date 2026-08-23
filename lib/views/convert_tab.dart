import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import '../theme/racing_theme.dart';

class ConvertTab extends StatefulWidget {
  const ConvertTab({super.key});

  @override
  State<ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends State<ConvertTab> {
  String? _sourceFilePath;
  String? _outputDirectory;
  String _conversionType = 'CSV→Excel';
  bool _isConverting = false;
  String? _statusMessage;
  bool _isSuccess = false;

  final List<String> _conversionTypes = [
    'CSV→Excel',
    'Excel→CSV',
    'TXT→CSV',
    'CSV→TXT'
  ];

  Future<void> _pickSourceFile() async {
    List<String> allowedExtensions = [];
    if (_conversionType.startsWith('CSV')) allowedExtensions = ['csv'];
    else if (_conversionType.startsWith('Excel')) allowedExtensions = ['xlsx', 'xls'];
    else if (_conversionType.startsWith('TXT')) allowedExtensions = ['txt'];

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _sourceFilePath = result.files.single.path!;
        _statusMessage = null;
      });
    }
  }

  Future<void> _pickOutputFolder() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _outputDirectory = result;
        _statusMessage = null;
      });
    }
  }

  Future<void> _convertAndSave() async {
    if (_sourceFilePath == null || _outputDirectory == null) {
      setState(() {
        _statusMessage = 'Please select both a source file and an output directory.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _statusMessage = 'Converting...';
      _isSuccess = false;
    });

    try {
      final file = File(_sourceFilePath!);
      final filename = file.uri.pathSegments.last;
      final baseName = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
      
      if (_conversionType == 'CSV→Excel') {
        final input = await file.readAsString();
        final rows = const CsvToListConverter().convert(input);
        
        var excel = Excel.createExcel();
        Sheet sheet = excel['Sheet1'];
        for (int i = 0; i < rows.length; i++) {
          List<CellValue> cellRow = rows[i].map((e) => TextCellValue(e.toString())).toList();
          sheet.insertRowIterables(cellRow, i);
        }
        
        final outPath = '$_outputDirectory\\$baseName.xlsx';
        final bytes = excel.encode();
        if (bytes != null) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes);
        }
      } else if (_conversionType == 'Excel→CSV') {
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);
        List<List<dynamic>> csvData = [];
        
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          for (var row in sheet.rows) {
            csvData.add(row.map((e) => e?.value?.toString() ?? '').toList());
          }
          break; // Only convert first sheet
        }
        
        String csv = const ListToCsvConverter().convert(csvData);
        final outPath = '$_outputDirectory\\$baseName.csv';
        await File(outPath).writeAsString(csv);
        
      } else if (_conversionType == 'TXT→CSV') {
        final input = await file.readAsString();
        // Assume space/tab delimited txt to comma separated
        final lines = input.split('\n');
        List<List<dynamic>> csvData = [];
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          // Split by whitespace
          var parts = line.trim().split(RegExp(r'\s+'));
          csvData.add(parts);
        }
        String csv = const ListToCsvConverter().convert(csvData);
        final outPath = '$_outputDirectory\\$baseName.csv';
        await File(outPath).writeAsString(csv);
        
      } else if (_conversionType == 'CSV→TXT') {
        final input = await file.readAsString();
        final rows = const CsvToListConverter().convert(input);
        
        StringBuffer sb = StringBuffer();
        for (var row in rows) {
          sb.writeln(row.join('\t'));
        }
        
        final outPath = '$_outputDirectory\\$baseName.txt';
        await File(outPath).writeAsString(sb.toString());
      }

      setState(() {
        _isConverting = false;
        _isSuccess = true;
        _statusMessage = 'Conversion successful!';
      });
    } catch (e) {
      setState(() {
        _isConverting = false;
        _isSuccess = false;
        _statusMessage = 'Error during conversion: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: RacingTheme.panel,
          border: Border.all(color: RacingTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('DATA CONVERTER', 
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: RacingTheme.primaryAccent, letterSpacing: 1.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Conversion Type
            Text('Conversion Type', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: RacingTheme.background,
                border: Border.all(color: RacingTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: RacingTheme.panel,
                  value: _conversionType,
                  items: _conversionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _conversionType = val;
                        _sourceFilePath = null; // reset file
                        _statusMessage = null;
                      });
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Source File
            Text('Source File', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: RacingTheme.background,
                      border: Border.all(color: RacingTheme.border),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                    ),
                    child: Text(_sourceFilePath ?? 'No file selected', 
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _sourceFilePath == null ? RacingTheme.textMuted : RacingTheme.textPrimary
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RacingTheme.border,
                      foregroundColor: RacingTheme.textPrimary,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(4))),
                    ),
                    onPressed: _pickSourceFile,
                    child: Text('BROWSE'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Output Directory
            Text('Output Folder', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: RacingTheme.background,
                      border: Border.all(color: RacingTheme.border),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                    ),
                    child: Text(_outputDirectory ?? 'No folder selected', 
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _outputDirectory == null ? RacingTheme.textMuted : RacingTheme.textPrimary
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RacingTheme.border,
                      foregroundColor: RacingTheme.textPrimary,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(4))),
                    ),
                    onPressed: _pickOutputFolder,
                    child: Text('BROWSE'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Convert Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RacingTheme.primaryAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _isConverting ? null : _convertAndSave,
                child: _isConverting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text('CONVERT & SAVE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ),
            ),
            
            // Status Message
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isConverting 
                      ? RacingTheme.primaryAccent.withOpacity(0.1)
                      : (_isSuccess ? RacingTheme.success.withOpacity(0.1) : RacingTheme.danger.withOpacity(0.1)),
                  border: Border.all(
                    color: _isConverting 
                        ? RacingTheme.primaryAccent.withOpacity(0.3)
                        : (_isSuccess ? RacingTheme.success : RacingTheme.danger),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isConverting 
                        ? RacingTheme.primaryAccent
                        : (_isSuccess ? RacingTheme.success : RacingTheme.danger),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
