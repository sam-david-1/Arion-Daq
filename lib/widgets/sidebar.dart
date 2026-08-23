import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../services/parameter_registry.dart';
import 'ai_chat_panel.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  void _toggleGroup(String group) {
    SettingsService().toggleSidebarGroup(group).then((_) => setState(() {}));
  }

  Widget _buildGroupHeader(BuildContext context, String title, bool isCollapsed) {
    return InkWell(
      onTap: () => _toggleGroup(title),
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, letterSpacing: 1.0, color: RacingTheme.primaryAccent, fontWeight: FontWeight.bold),
            ),
            Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 14, color: RacingTheme.primaryAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, ParameterDefinition def, double? val) {
    String valText = val != null ? '${val.toStringAsFixed(1)}${def.unit}' : '—';
    Color valColor = val != null ? RacingTheme.primaryAccent : RacingTheme.textMuted;
    
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(def.displayName, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, color: RacingTheme.textPrimary), overflow: TextOverflow.ellipsis)),
          InkWell(
            onTap: val != null ? () {
              Clipboard.setData(ClipboardData(text: val.toStringAsFixed(2)));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Copied!'), duration: const Duration(milliseconds: 500), backgroundColor: RacingTheme.success));
            } : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: Text(
                valText,
                key: ValueKey(valText),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14, color: valColor, fontFamily: 'JetBrains Mono'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateBadge(String state) {
    Color bg = Colors.grey;
    if (state == 'STATIONARY') bg = Colors.black45;
    if (state == 'ACCELERATING') bg = Colors.green;
    if (state == 'BRAKING') bg = Colors.red;
    if (state == 'COASTING') bg = Colors.blueGrey;
    if (state.contains('CORNERING')) bg = Colors.orange;
    if (state.contains('COMBINED')) bg = Colors.purple;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      child: Text(state.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0)),
    );
  }

  Widget _buildParamsList(DaqProvider provider, Map<String, double?> data, BuildContext context) {
    Map<String, List<ParameterDefinition>> grouped = {};
    for (String key in provider.availableChannels) {
      if (key == 'Time_ms' || key == 'Vehicle_State') continue;
      var def = ParameterRegistry().getParameter(key);
      if (!grouped.containsKey(def.group)) {
        grouped[def.group] = [];
      }
      grouped[def.group]!.add(def);
    }

    List<Widget> children = [];
    
    children.add(_buildStateBadge(provider.currentVehicleState));

    List<String> collapsedGroups = SettingsService().collapsedSidebarGroups;

    var sortedKeys = grouped.keys.toList()..sort();
    for (String group in sortedKeys) {
      bool isCollapsed = collapsedGroups.contains(group);
      children.add(_buildGroupHeader(context, group, isCollapsed));
      
      if (!isCollapsed) {
        for (var def in grouped[group]!) {
          children.add(_buildRow(context, def, data[def.rawName]));
        }
      }
    }
    
    // Add SESSION group
    children.add(_buildGroupHeader(context, 'SESSION', false));
    children.add(Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('Status', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, color: RacingTheme.textPrimary))),
          Text(provider.loadedLogData.isNotEmpty ? (provider.isPlaying ? 'PLAYING' : 'PAUSED') : 'IDLE', 
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14, color: RacingTheme.textMuted, fontFamily: 'JetBrains Mono')),
        ],
      ),
    ));
    children.add(Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('Time', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, color: RacingTheme.textPrimary))),
          Text('${(provider.currentTimestampMs / 1000).toStringAsFixed(2)}s', 
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14, color: RacingTheme.primaryAccent, fontFamily: 'JetBrains Mono')),
        ],
      ),
    ));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        bool isSidebarCollapsed = SettingsService().isSidebarCollapsed;
        double targetWidth = isSidebarCollapsed ? 48.0 : provider.sidebarWidth;
        final data = provider.currentSensorValues;
        
        return GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! > 200) {
                provider.setAiSidebarMode(true);
              } else if (details.primaryVelocity! < -200) {
                provider.setAiSidebarMode(false);
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: targetWidth,
            decoration: BoxDecoration(
              color: RacingTheme.panel,
              border: Border(right: BorderSide(color: RacingTheme.border, width: 1)),
            ),
            child: ClipRect(
              child: OverflowBox(
                minWidth: provider.sidebarWidth,
                maxWidth: provider.sidebarWidth,
                alignment: Alignment.topLeft,
                child: Column(
                  children: [
                  // Toggle Row
                Container(
                  height: 40,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: RacingTheme.border))),
                  child: Row(
                    children: [
                      if (!isSidebarCollapsed) Expanded(
                        child: InkWell(
                          onTap: () {
                            provider.setAiSidebarMode(false);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            color: !provider.isAiSidebarMode ? RacingTheme.primaryAccent.withValues(alpha: 0.2) : Colors.transparent,
                            child: Text('PARAMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !provider.isAiSidebarMode ? RacingTheme.primaryAccent : RacingTheme.textMuted)),
                          ),
                        ),
                      ),
                      if (!isSidebarCollapsed) Expanded(
                        child: InkWell(
                          onTap: () {
                            provider.setAiSidebarMode(true);
                          },
                          child: Container(
                            alignment: Alignment.center,
                            color: provider.isAiSidebarMode ? RacingTheme.primaryAccent.withValues(alpha: 0.2) : Colors.transparent,
                            child: Text('AI ✦', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: provider.isAiSidebarMode ? RacingTheme.primaryAccent : RacingTheme.textMuted)),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          SettingsService().setIsSidebarCollapsed(!isSidebarCollapsed).then((_) => setState((){}));
                        },
                        child: Container(
                          width: isSidebarCollapsed ? 48.0 : 40.0,
                          alignment: Alignment.center,
                          child: Icon(isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left, size: 16, color: RacingTheme.primaryAccent),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: isSidebarCollapsed 
                    ? _buildCollapsedSidebar(provider)
                    : (provider.isAiSidebarMode 
                        ? const AiChatPanel()
                        : _buildParamsList(provider, data, context)),
                ),
                  ),
                ],
              ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildCollapsedSidebar(DaqProvider provider) {
    return Column(
      children: [
         const SizedBox(height: 16),
         InkWell(
           onTap: () {
             SettingsService().setIsSidebarCollapsed(false).then((_) => setState((){}));
             provider.setAiSidebarMode(false);
           },
           child: Icon(Icons.list, color: !provider.isAiSidebarMode ? RacingTheme.primaryAccent : RacingTheme.textMuted),
         ),
         const SizedBox(height: 24),
         InkWell(
           onTap: () {
             SettingsService().setIsSidebarCollapsed(false).then((_) => setState((){}));
             provider.setAiSidebarMode(true);
           },
           child: Icon(Icons.smart_toy, color: provider.isAiSidebarMode ? RacingTheme.primaryAccent : RacingTheme.textMuted),
         ),
      ],
    );
  }
}
