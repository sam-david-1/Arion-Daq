import 'package:flutter/material.dart';
import '../theme/racing_theme.dart';
import '../services/parameter_registry.dart';
import '../state/daq_provider.dart';
import 'package:provider/provider.dart';

class SmartDetectionDialog extends StatefulWidget {
  final List<String> unknownChannels;
  const SmartDetectionDialog({super.key, required this.unknownChannels});

  @override
  State<SmartDetectionDialog> createState() => _SmartDetectionDialogState();
}

class _SmartDetectionDialogState extends State<SmartDetectionDialog> {
  final Map<String, String> _groups = {};
  final Map<String, String> _names = {};
  final Map<String, String> _units = {};

  final List<String> _groupOptions = [
    'SPEED', 'ENGINE', 'BRAKES', 'DRIVER', 'IMU', 'AERO', 'TEMPERATURES', 'SUSPENSION', 'BATTERY', 'UNKNOWN', 'SESSION'
  ];

  @override
  void initState() {
    super.initState();
    for (var ch in widget.unknownChannels) {
      var def = ParameterRegistry().getParameter(ch);
      _groups[ch] = def.group;
      if (!_groupOptions.contains(def.group)) {
        _groups[ch] = 'UNKNOWN';
      }
      _names[ch] = def.displayName;
      _units[ch] = def.unit;
    }
  }

  void _save() {
    for (var ch in widget.unknownChannels) {
      var def = ParameterRegistry().getParameter(ch);
      def.group = _groups[ch]!;
      def.displayName = _names[ch]!;
      def.unit = _units[ch]!;
    }
    // Force rebuild
    Provider.of<DaqProvider>(context, listen: false).forceRefresh();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RacingTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: RacingTheme.border)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: RacingTheme.primaryAccent),
                const SizedBox(width: 8),
                Text('Smart Channel Detection', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: RacingTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            Text('We detected ${widget.unknownChannels.length} new parameters in your CSV. Review the auto-generated names and groupings below:', style: TextStyle(color: RacingTheme.textSecondary)),
            const SizedBox(height: 24),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.unknownChannels.length,
                separatorBuilder: (context, index) => Divider(color: RacingTheme.border),
                itemBuilder: (context, index) {
                  String ch = widget.unknownChannels[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(ch, style: TextStyle(color: RacingTheme.textMuted, fontFamily: 'JetBrains Mono', fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: _names[ch],
                            style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Display Name',
                              labelStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                              isDense: true,
                              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            ),
                            onChanged: (val) => _names[ch] = val,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _groups[ch],
                            dropdownColor: RacingTheme.panel,
                            style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Group',
                              labelStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                              isDense: true,
                              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            ),
                            isExpanded: true,
                            items: _groupOptions.map((g) => DropdownMenuItem(value: g, child: Text(g, style: TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _groups[ch] = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: _units[ch],
                            style: TextStyle(color: RacingTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              labelStyle: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                              isDense: true,
                              border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            ),
                            onChanged: (val) => _units[ch] = val,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Skip', style: TextStyle(color: RacingTheme.textSecondary)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.primaryAccent, foregroundColor: Colors.black),
                  onPressed: _save,
                  child: const Text('Save Parameters'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
