import 'package:flutter/material.dart';
import '../theme/racing_theme.dart';
import '../services/parameter_registry.dart';

class ChannelSelectorList extends StatelessWidget {
  final List<String> availableChannels;
  final List<String> selectedChannels;
  final Function(String, bool?) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectNone;
  final VoidCallback onSelectRaw;
  final VoidCallback onSelectDerived;

  const ChannelSelectorList({
    super.key,
    required this.availableChannels,
    required this.selectedChannels,
    required this.onToggle,
    required this.onSelectAll,
    required this.onSelectNone,
    required this.onSelectRaw,
    required this.onSelectDerived,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, List<String>> grouped = {};
    for (String ch in availableChannels) {
      if (ch == 'Time_ms' || ch == 'Vehicle_State') continue;
      String group = ParameterRegistry().getParameter(ch).group;
      if (!grouped.containsKey(group)) grouped[group] = [];
      grouped[group]!.add(ch);
    }
    
    var sortedKeys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: RacingTheme.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHANNELS', style: TextStyle(color: RacingTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _ActionChip('ALL', onSelectAll),
                  _ActionChip('NONE', onSelectNone),
                  _ActionChip('RAW', onSelectRaw),
                  _ActionChip('DERIVED', onSelectDerived),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              String group = sortedKeys[index];
              List<String> channels = grouped[group]!;
              channels.sort();
              return Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(group, style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  initiallyExpanded: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                  childrenPadding: EdgeInsets.zero,
                  children: channels.map((channel) {
                    var def = ParameterRegistry().getParameter(channel);
                    return CheckboxListTile(
                      title: Text(def.displayName, style: TextStyle(color: RacingTheme.textPrimary, fontSize: 12)),
                      value: selectedChannels.contains(channel),
                      onChanged: (val) => onToggle(channel, val),
                      activeColor: def.color,
                      checkColor: RacingTheme.background,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      dense: true,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: RacingTheme.primaryAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: RacingTheme.primaryAccent)),
        child: Text(label, style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
