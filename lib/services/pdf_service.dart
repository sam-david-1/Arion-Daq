import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../state/daq_provider.dart';
import '../services/settings_service.dart';

class PdfService {
  static Future<void> exportPdf(DaqProvider provider, String outputPath, String filename) async {
    final pdf = pw.Document();
    final s = SettingsService();

    // Theme Colors
    final primaryColor = PdfColor.fromHex('#7DD3FC');
    final darkBg = PdfColor.fromHex('#0A0C10');
    final panelBg = PdfColor.fromHex('#0D1014');
    final textMuted = PdfColor.fromHex('#475569');
    
    // Calculate global stats for all channels
    Map<String, Map<String, dynamic>> channelStats = {};
    if (provider.availableChannels.isNotEmpty && provider.loadedLogData.isNotEmpty) {
      for (String channel in provider.availableChannels) {
        double minVal = double.infinity;
        double maxVal = double.negativeInfinity;
        double sum = 0;
        int count = 0;
        
        for (var item in provider.loadedLogData) {
          if (item[channel] != null) {
            double v = item[channel] as double;
            if (v < minVal) minVal = v;
            if (v > maxVal) maxVal = v;
            sum += v;
            count++;
          }
        }
        
        if (count > 0) {
          double avg = sum / count;
          // Calculate std dev
          double sumSqDiff = 0;
          for (var item in provider.loadedLogData) {
            if (item[channel] != null) {
              double v = item[channel] as double;
              sumSqDiff += pow(v - avg, 2);
            }
          }
          double stdDev = sqrt(sumSqDiff / count);
          
          channelStats[channel] = {
            'min': minVal,
            'max': maxVal,
            'avg': avg,
            'stdDev': stdDev,
            'unit': _getUnitForChannel(channel),
          };
        }
      }
    }

    // Page 1: Header
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: darkBg,
                  border: pw.Border(bottom: pw.BorderSide(color: primaryColor, width: 4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ARION DAQ', style: pw.TextStyle(color: primaryColor, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                    pw.Text('SESSION REPORT', style: pw.TextStyle(color: PdfColors.white, fontSize: 24)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              _buildMetaRow('Driver', '${s.driverName} #${s.driverNumber}'),
              _buildMetaRow('Car', 'AR25'),
              _buildMetaRow('Date', DateTime.now().toIso8601String().split('T')[0]),
              _buildMetaRow('Session File', filename),
              _buildMetaRow('Duration', '${(provider.totalDurationMs/1000).toStringAsFixed(1)}s'),
              _buildMetaRow('Samples', '${provider.sampleCount}'),
              _buildMetaRow('Sample Rate', '${provider.sampleRate.toStringAsFixed(0)}Hz'),
            ],
          );
        },
      ),
    );

    // Page 2: All Channel Statistics
    if (channelStats.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, text: 'CHANNEL STATISTICS', textStyle: pw.TextStyle(color: primaryColor, fontSize: 18)),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Channel', 'Min', 'Max', 'Average', 'Std Dev', 'Unit'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: darkBg),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {0: pw.Alignment.centerLeft},
                data: channelStats.entries.map((e) {
                  return [
                    e.key,
                    e.value['min'].toStringAsFixed(2),
                    e.value['max'].toStringAsFixed(2),
                    e.value['avg'].toStringAsFixed(2),
                    e.value['stdDev'].toStringAsFixed(2),
                    e.value['unit'],
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );
    }

    // Page 3+: Charts (2 charts per page)
    if (provider.availableChannels.isNotEmpty && provider.loadedLogData.isNotEmpty) {
      List<pw.Widget> charts = [];
      
      for (String channel in provider.availableChannels) {
        if (!channelStats.containsKey(channel)) continue;
        
        // Downsample data for chart
        List<pw.PointChartValue> points = [];
        int totalPoints = provider.loadedLogData.length;
        int maxPoints = 300;
        int step = max(1, (totalPoints / maxPoints).floor());
        
        for (int i = 0; i < totalPoints; i += step) {
          var item = provider.loadedLogData[i];
          if (item[channel] != null) {
            points.add(pw.PointChartValue(item['Time_ms'] / 1000.0, (item[channel] as num).toDouble()));
          }
        }
        
        if (points.isEmpty) continue;
        
        double minV = channelStats[channel]!['min'];
        double maxV = channelStats[channel]!['max'];
        // add padding
        double range = maxV - minV;
        if (range == 0) range = 10;
        
        charts.add(
          pw.Container(
            height: 250,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(channel, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Min: ${minV.toStringAsFixed(2)} | Max: ${maxV.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.SizedBox(height: 5),
                pw.Expanded(
                  child: pw.Chart(
                    grid: pw.CartesianGrid(
                      xAxis: pw.FixedAxis(
                        List.generate(6, (i) => (provider.totalDurationMs / 1000.0) * (i / 5)),
                        buildLabel: (v) => pw.Text(v.toStringAsFixed(1), style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        ticks: true,
                        margin: 10,
                      ),
                      yAxis: pw.FixedAxis(
                        List.generate(5, (i) => (minV - range*0.1) + ((range*1.2) * (i / 4))),
                        buildLabel: (v) => pw.Text(v.toStringAsFixed(1), style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                        ticks: true,
                        margin: 10,
                      ),
                    ),
                    datasets: [
                      pw.LineDataSet(
                        legend: channel,
                        drawSurface: false,
                        color: primaryColor,
                        data: points,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        );
      }
      
      // Group charts into pages
      for (int i = 0; i < charts.length; i += 2) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  if (i == 0) pw.Header(level: 0, text: 'TELEMETRY CHARTS', textStyle: pw.TextStyle(color: primaryColor, fontSize: 18)),
                  charts[i],
                  if (i + 1 < charts.length) charts[i + 1],
                ],
              );
            },
          ),
        );
      }
    }

    // Last Page: Alerts Summary
    if (provider.alerts.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, text: 'ALERTS SUMMARY', textStyle: pw.TextStyle(color: primaryColor, fontSize: 18)),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Time (s)', 'Channel', 'Event', 'Value'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: darkBg),
                cellAlignment: pw.Alignment.centerLeft,
                data: provider.alerts.map((a) {
                  return [
                    (a['time'] / 1000.0).toStringAsFixed(2),
                    a['channel'],
                    a['event'],
                    (a['value'] as double).toStringAsFixed(2),
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );
    }

    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }
  
  static pw.Widget _buildMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
          pw.Text(value, style: pw.TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
  
  static String _getUnitForChannel(String channel) {
    if (channel.contains('TPS')) return '%';
    if (channel.contains('Brake_Bar')) return 'bar';
    if (channel.contains('Brake_V')) return 'V';
    if (channel.contains('Angle')) return '°';
    if (channel.contains('Gyro')) return '°/s';
    if (channel.contains('RideHeight')) return 'mm';
    if (channel.contains('Temp')) return '°C';
    return '';
  }
}
