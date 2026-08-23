import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/serial_service.dart';

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  String _memoryUsage = '0 MB';

  @override
  void initState() {
    super.initState();
    _updateStats();
  }

  void _updateStats() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) break;
      int bytes = ProcessInfo.currentRss;
      setState(() {
        _memoryUsage = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool isConnected = SerialService().isConnected;
        String statusText = isConnected ? 'Status: Connected' : 'Status: Disconnected';
        Color statusColor = isConnected ? RacingTheme.success : RacingTheme.danger;

        String filename = provider.loadedLogData.isNotEmpty ? 'Session_Data.csv' : 'None';

        return Container(
          height: 24,
          width: double.infinity,
          decoration: BoxDecoration(
            color: RacingTheme.panel,
            border: Border(top: BorderSide(color: RacingTheme.border, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Left
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(statusText, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
                  const SizedBox(width: 16),
                  if (provider.availablePorts.isNotEmpty)
                    SizedBox(
                      width: 90,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: provider.selectedPort,
                          dropdownColor: RacingTheme.panel,
                          hint: Text('COM', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                          items: provider.availablePorts.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            provider.setSelectedPort(val);
                          },
                        ),
                      ),
                    ),
                ],
              ),
              
              const Spacer(),
              
              // Middle
              Text('Loaded: $filename', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: RacingTheme.primaryAccent)),
              
              const Spacer(),
              
              // Right
              Text('FPS: 120 | Memory: ~$_memoryUsage', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, color: RacingTheme.textMuted)),
            ],
          ),
        );
      },
    );
  }
}
