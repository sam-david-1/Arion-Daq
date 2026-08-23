import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/file_service.dart';
import '../../services/parameter_registry.dart';
import '../../state/daq_provider.dart';
import '../../theme/mobile_theme.dart';
import '../../widgets/smart_detection_dialog.dart';
import 'package:intl/intl.dart';

class MobileHistoryScreen extends StatefulWidget {
  const MobileHistoryScreen({super.key});

  @override
  State<MobileHistoryScreen> createState() => _MobileHistoryScreenState();
}

class _MobileHistoryScreenState extends State<MobileHistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _history = SettingsService().getSessionHistory();
    });
  }

  Future<void> _loadSession(String filepath, String filename) async {
    try {
      final fileService = FileService();
      final data = await fileService.parseCsvLog(filepath);
      if (data.isNotEmpty) {
        int duration = data.last['Time_ms']?.toInt() ?? 0;
        Provider.of<DaqProvider>(context, listen: false).loadLogData(data, duration, filename: filename, filepath: filepath);
        
        var unknown = ParameterRegistry().unknownRawNames;
        if (unknown.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => SmartDetectionDialog(unknownChannels: unknown),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded $filename'), backgroundColor: MobileTheme.successGlow));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading $filename'), backgroundColor: MobileTheme.dangerGlow));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_history.isEmpty) {
      return const Center(
        child: Text('No saved sessions.', style: TextStyle(color: MobileTheme.textMuted, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final session = _history[index];
        final date = DateTime.tryParse(session['date'] ?? '') ?? DateTime.now();
        final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(date);
        final duration = ((session['duration'] as num?) ?? 0) / 1000.0;

        return GestureDetector(
          onTap: () => _loadSession(session['filepath'] ?? session['filename'], session['filename']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: MobileTheme.glassDecoration(radius: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MobileTheme.primaryNeon.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: MobileTheme.primaryNeon.withOpacity(0.2), blurRadius: 10)],
                  ),
                  child: const Icon(Icons.history, color: MobileTheme.primaryNeon),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session['filename'] ?? 'Unknown', style: const TextStyle(color: MobileTheme.textBright, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(formattedDate, style: const TextStyle(color: MobileTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${duration.toStringAsFixed(1)}s', style: const TextStyle(color: MobileTheme.primaryNeon, fontSize: 15, fontFamily: 'Fira Code', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('${session['samples']} pts', style: const TextStyle(color: MobileTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
