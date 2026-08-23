import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  String _filter = 'ALL'; // ALL, WARNING, DANGER
  
  final TextEditingController _warnBrakeCtrl = TextEditingController();
  final TextEditingController _dangerBrakeCtrl = TextEditingController();
  final TextEditingController _wotCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _warnBrakeCtrl.text = SettingsService().brakeWarningThreshold.toString();
    _dangerBrakeCtrl.text = SettingsService().brakeDangerThreshold.toString();
    _wotCtrl.text = SettingsService().tpsWotThreshold.toString();
  }

  @override
  void dispose() {
    _warnBrakeCtrl.dispose();
    _dangerBrakeCtrl.dispose();
    _wotCtrl.dispose();
    super.dispose();
  }

  void _applySettings() async {
    double? warn = double.tryParse(_warnBrakeCtrl.text);
    double? danger = double.tryParse(_dangerBrakeCtrl.text);
    double? wot = double.tryParse(_wotCtrl.text);
    
    if (warn != null) await SettingsService().setBrakeWarningThreshold(warn);
    if (danger != null) await SettingsService().setBrakeDangerThreshold(danger);
    if (wot != null) await SettingsService().setTpsWotThreshold(wot);
    
    // Quick reload for provider to re-generate alerts
    // But provider generates on file load. We will just let it be for next load.
    // Ideally we re-scan immediately. For now, settings are applied.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thresholds applied. Reload file to regenerate past alerts.')),
    );
  }

  void _exportAlerts(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) return;
    try {
      String csv = 'Time_ms,Channel,Event,Value,Severity\n';
      for (var a in alerts) {
        csv += '${a['time']},${a['channel']},${a['event']},${a['value']},${a['severity']}\n';
      }
      File('arion_alerts_export.csv').writeAsStringSync(csv);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to arion_alerts_export.csv')),
      );
    } catch (e) {
      debugPrint('Export error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        List<Map<String, dynamic>> alerts = provider.alerts;
        if (_filter == 'WARNING') alerts = alerts.where((a) => a['severity'] == 'warning').toList();
        if (_filter == 'DANGER') alerts = alerts.where((a) => a['severity'] == 'danger').toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top Settings Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RacingTheme.panel,
                  border: Border.all(color: RacingTheme.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('THRESHOLDS:', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 16),
                    _buildInput('Brake Warning (bar)', _warnBrakeCtrl),
                    const SizedBox(width: 16),
                    _buildInput('Brake Danger (bar)', _dangerBrakeCtrl),
                    const SizedBox(width: 16),
                    _buildInput('TPS WOT (%)', _wotCtrl),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _applySettings,
                      child: Text('APPLY'),
                    ),
                    const Spacer(),
                    // Filters
                    _buildFilterButton('ALL'),
                    const SizedBox(width: 8),
                    _buildFilterButton('WARNING', color: RacingTheme.warning),
                    const SizedBox(width: 8),
                    _buildFilterButton('DANGER', color: RacingTheme.danger),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _exportAlerts(alerts),
                      icon: Icon(Icons.download, size: 16),
                      label: Text('EXPORT CSV'),
                      style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.border, foregroundColor: RacingTheme.textPrimary),
                    ),
                    const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          provider.reScanAlerts();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Re-scanned session for alerts')));
                        },
                        icon: Icon(Icons.refresh, size: 16),
                        label: Text('RE-SCAN'),
                        style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.border, foregroundColor: RacingTheme.textPrimary),
                      ),
                    const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => provider.toggleAlerts(),
                        icon: Icon(provider.alertsEnabled ? Icons.notifications_off : Icons.notifications_active, size: 16),
                        label: Text(provider.alertsEnabled ? 'DISABLE ALERTS' : 'ENABLE ALERTS'),
                        style: ElevatedButton.styleFrom(backgroundColor: provider.alertsEnabled ? RacingTheme.border : RacingTheme.success, foregroundColor: RacingTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Table Header
              Container(
                color: RacingTheme.border.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text('#', style: Theme.of(context).textTheme.labelSmall)),
                    SizedBox(width: 100, child: Text('TIMESTAMP', style: Theme.of(context).textTheme.labelSmall)),
                    SizedBox(width: 150, child: Text('CHANNEL', style: Theme.of(context).textTheme.labelSmall)),
                    Expanded(child: Text('EVENT TYPE', style: Theme.of(context).textTheme.labelSmall)),
                    SizedBox(width: 100, child: Text('VALUE', style: Theme.of(context).textTheme.labelSmall)),
                    SizedBox(width: 100, child: Text('SEVERITY', style: Theme.of(context).textTheme.labelSmall)),
                  ],
                ),
              ),
              
              // Table Body
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: RacingTheme.panel,
                    border: Border.all(color: RacingTheme.border),
                  ),
                  child: alerts.isEmpty
                    ? Center(child: Text('No alerts found for current filter.', style: Theme.of(context).textTheme.bodySmall))
                    : ListView.separated(
                        itemCount: alerts.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (context, index) {
                          var a = alerts[index];
                          bool isAck = a['acknowledged'] == true;
                          Color rowColor = isAck ? RacingTheme.success : (a['severity'] == 'danger' ? RacingTheme.danger : RacingTheme.warning);
                          return InkWell(
                            onTap: () {
                              provider.seekTo((a['time'] as double).round());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(width: 50, child: Text('${index + 1}', style: Theme.of(context).textTheme.bodySmall)),
                                  SizedBox(width: 100, child: Text('${(a['time']/1000).toStringAsFixed(2)}s', style: Theme.of(context).textTheme.bodySmall)),
                                  SizedBox(width: 150, child: Text(a['channel'], style: Theme.of(context).textTheme.bodySmall)),
                                  Expanded(child: Text(a['event'], style: Theme.of(context).textTheme.bodySmall?.copyWith(color: rowColor))),
                                  SizedBox(width: 100, child: Text((a['value'] as double).toStringAsFixed(2), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14))),
                                  SizedBox(width: 100, child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: rowColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: rowColor),
                                    ),
                                    child: Text(isAck ? 'ACKNOWLEDGED' : (a['severity'] as String).toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: rowColor)),
                                  )),
                                  const SizedBox(width: 16),
                                  if (!isAck)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: RacingTheme.success.withOpacity(0.2),
                                        foregroundColor: RacingTheme.success,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          a['acknowledged'] = true;
                                        });
                                      },
                                      child: Text('ACK', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          height: 30,
          child: TextField(
            controller: controller,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: RacingTheme.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: RacingTheme.background,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label, {Color? color}) {
    bool active = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? (color?.withOpacity(0.2) ?? RacingTheme.primaryAccent.withOpacity(0.2)) : RacingTheme.background,
          border: Border.all(color: active ? (color ?? RacingTheme.primaryAccent) : RacingTheme.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active ? (color ?? RacingTheme.primaryAccent) : RacingTheme.textSecondary,
        )),
      ),
    );
  }
}
