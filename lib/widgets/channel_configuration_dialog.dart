import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/racing_theme.dart';
import '../services/parameter_registry.dart';
import '../state/daq_provider.dart';

class ChannelConfigurationDialog extends StatefulWidget {
  const ChannelConfigurationDialog({super.key});
  @override
  State<ChannelConfigurationDialog> createState() => _ChannelConfigurationDialogState();
}

class _ChannelConfigurationDialogState extends State<ChannelConfigurationDialog> {
  final List<String> _groupOptions = [
    'SPEED', 'ENGINE', 'BRAKES', 'DRIVER', 'IMU', 'AERO', 'TEMPERATURES', 'SUSPENSION', 'BATTERY', 'UNKNOWN', 'SESSION'
  ];

  @override
  Widget build(BuildContext context) {
    var registry = ParameterRegistry();
    var allKeys = registry.getAllKeys()..sort();
    
    return Dialog(
      backgroundColor: RacingTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: RacingTheme.border)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_input_component, color: RacingTheme.primaryAccent),
                    const SizedBox(width: 8),
                    Text('Channel Configuration', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: RacingTheme.textPrimary)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: RacingTheme.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: allKeys.length,
                separatorBuilder: (context, index) => Divider(color: RacingTheme.border),
                itemBuilder: (context, index) {
                  String key = allKeys[index];
                  var def = registry.getParameter(key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(key, style: TextStyle(color: RacingTheme.textMuted, fontFamily: 'JetBrains Mono', fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: def.displayName,
                            style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Display Name',
                              labelStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                              isDense: true,
                              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            ),
                            onChanged: (val) {
                              def.displayName = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _groupOptions.contains(def.group) ? def.group : 'UNKNOWN',
                            dropdownColor: RacingTheme.panel,
                            style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Group',
                              labelStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                              isDense: true,
                              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            ),
                            items: _groupOptions.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => def.group = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: def.unit,
                            style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              labelStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                              isDense: true,
                              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            ),
                            onChanged: (val) => def.unit = val,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.primaryAccent, foregroundColor: Colors.black),
                onPressed: () {
                  Provider.of<DaqProvider>(context, listen: false).forceRefresh();
                  Navigator.of(context).pop();
                },
                child: const Text('Save & Close'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
