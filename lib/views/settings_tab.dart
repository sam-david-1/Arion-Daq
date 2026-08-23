import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../theme/racing_theme.dart';
import '../services/settings_service.dart';
import '../services/parameter_registry.dart';
import '../state/daq_provider.dart';
import '../services/ai_service.dart';
import '../widgets/custom_channel_editor.dart';
import '../widgets/channel_configuration_dialog.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _obscureApiKey = true;
  bool _isTestingAi = false;
  String _aiTestResult = '';

  Future<void> _testAiConnection(String model) async {
    setState(() {
      _isTestingAi = true;
      _aiTestResult = 'Testing $model...';
    });
    String res = await AiService.ask(model, "You are a helpful AI.", [], "Say 'hello'.");
    setState(() {
      _isTestingAi = false;
      if (!res.startsWith("Error")) {
        _aiTestResult = 'Connected';
      } else {
        _aiTestResult = 'Failed: $res';
      }
    });
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 14, letterSpacing: 1.0, color: RacingTheme.primaryAccent)),
    );
  }

  Widget _buildTextInput(String label, String value, Function(String) onChanged, {bool isNumber = false, bool isPassword = false}) {
    TextEditingController ctrl = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Row(
            children: [
              SizedBox(
                width: isNumber ? 60 : 150,
                height: 32,
                child: TextField(
                  controller: ctrl,
                  obscureText: isPassword && _obscureApiKey,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    filled: true,
                    fillColor: RacingTheme.background,
                    border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                  ),
                  onChanged: onChanged,
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off, size: 16, color: RacingTheme.textMuted),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdInput(String label, double value, Function(double) onChanged) {
    TextEditingController ctrl = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(
            width: 80,
            height: 32,
            child: TextField(
              controller: ctrl,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
                filled: true,
                fillColor: RacingTheme.background,
                border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
              ),
              onSubmitted: (val) {
                double? v = double.tryParse(val);
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Switch(
            value: value,
            activeThumbColor: RacingTheme.primaryAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, int divisions, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: RacingTheme.primaryAccent,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 40, child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, SettingsService s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('DRIVER PROFILE'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    children: [
                      _buildTextInput('Driver Name', s.driverName, (v) => s.setDriverName(v)),
                      _buildTextInput('Driver Number', s.driverNumber, (v) => s.setDriverNumber(v), isNumber: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle('AI CONFIGURATION'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('AI Provider', style: Theme.of(context).textTheme.bodyMedium),
                          DropdownButton<String>(
                            value: s.aiProvider,
                            dropdownColor: RacingTheme.panel,
                            style: TextStyle(color: Colors.white, fontSize: 13),
                            items: const [
                              DropdownMenuItem(value: 'gemini', child: Text('Gemini 2.5 Flash')),
                              DropdownMenuItem(value: 'groq', child: Text('Groq llama-3.1')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                s.setAiProvider(val).then((_) => setState(() {}));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // API Keys
                      _buildTextInput('Gemini API Key', s.geminiApiKey, (v) => s.setGeminiApiKey(v), isPassword: true),
                      _buildTextInput('Groq API Key', s.groqApiKey, (v) => s.setGroqApiKey(v), isPassword: true),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: _isTestingAi ? null : () => _testAiConnection(s.aiProvider),
                            style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.primaryAccent, foregroundColor: Colors.black, minimumSize: const Size(100, 32)),
                            child: _isTestingAi ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('Test Connection', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (_aiTestResult.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_aiTestResult, style: TextStyle(color: _aiTestResult == 'Connected' ? RacingTheme.success : RacingTheme.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle('THRESHOLDS'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    children: [
                      _buildThresholdInput('Brake Pressure Warning (bar)', s.brakeWarningThreshold, (v) {
                        s.setBrakeWarningThreshold(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),
                      _buildThresholdInput('Brake Pressure Danger (bar)', s.brakeDangerThreshold, (v) {
                        s.setBrakeDangerThreshold(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),
                      _buildThresholdInput('TPS WOT Threshold (°)', s.tpsWotThreshold, (v) {
                        s.setTpsWotThreshold(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),
                      _buildThresholdInput('Steering Extreme Threshold (°)', s.steeringExtremeThreshold, (v) {
                        s.setSteeringExtremeThreshold(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle('DISPLAY'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    children: [
                      _buildSlider('Chart Line Thickness', s.chartLineThickness, 1.0, 3.0, 4, (v) {
                        s.setChartLineThickness(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),

                      _buildToggle('Show Data Points on Charts', s.showDataPoints, (v) {
                        s.setShowDataPoints(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),
                      _buildToggle('Smoothing Filter (Moving Average)', s.enableTelemetrySmoothing, (v) {
                        s.setEnableTelemetrySmoothing(v).then((_) {
                          setState(() {});
                          Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                        });
                      }),
                      _buildToggle('Global Light Mode', Provider.of<DaqProvider>(context).isLightMode, (v) {
                        Provider.of<DaqProvider>(context, listen: false).toggleLightMode();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 32),
          
          // Right Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('SESSION'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    children: [
                      _buildToggle('Auto-load last session on startup', s.autoLoadLastSession, (v) {
                        s.setAutoLoadLastSession(v);
                        setState(() {});
                      }),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Max Session History Count', style: Theme.of(context).textTheme.bodySmall),
                            DropdownButton<int>(
                              value: s.maxSessionHistory,
                              dropdownColor: RacingTheme.panel,
                              style: Theme.of(context).textTheme.bodySmall,
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5')),
                                DropdownMenuItem(value: 10, child: Text('10')),
                                DropdownMenuItem(value: 20, child: Text('20')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  s.setMaxSessionHistory(val).then((_) => setState(() {}));
                                }
                              },
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              s.clearSessionHistory();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache and Session History Cleared')));
                            },
                            icon: Icon(Icons.delete_outline, size: 16, color: Colors.white),
                            label: Text('CLEAR LOCAL CACHE', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildSectionTitle('DATA PIPELINE'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Channel Renames Map', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('e.g., {"EngineTemp": "Water (°C)"}', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: TextField(
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Add new rename (Orig:New)',
                            hintStyle: TextStyle(color: RacingTheme.textMuted),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            filled: true,
                            fillColor: RacingTheme.background,
                            border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                          ),
                          onSubmitted: (val) {
                            if (val.contains(':')) {
                              final parts = val.split(':');
                              setState(() => s.setChannelRename(parts[0].trim(), parts[1].trim()));
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const ChannelConfigurationDialog(),
                            );
                          },
                          icon: Icon(Icons.settings_input_component, size: 14, color: RacingTheme.primaryAccent),
                          label: Text('Channel Configuration', style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: RacingTheme.primaryAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const CustomChannelEditor(),
                            );
                          },
                          icon: Icon(Icons.calculate, size: 14, color: RacingTheme.primaryAccent),
                          label: Text('Math Channels', style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: RacingTheme.primaryAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle('ABOUT'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Name: ARION DAQ', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('Version: 1.0.0', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('Platform: Windows x64 + Android', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('Car: AR25', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Text('Season: 2026', style: Theme.of(context).textTheme.bodySmall),
                      const Divider(height: 32),
                      Center(
                        child: Text('© 2026 Arion. All rights reserved.', style: Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, SettingsService s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('DRIVER PROFILE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: Column(
              children: [
                _buildTextInput('Driver Name', s.driverName, (v) => s.setDriverName(v)),
                _buildTextInput('Driver Number', s.driverNumber, (v) => s.setDriverNumber(v), isNumber: true),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('THRESHOLDS'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: Column(
              children: [
                _buildThresholdInput('Brake Warning (bar)', s.brakeWarningThreshold, (v) {
                  s.setBrakeWarningThreshold(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),
                _buildThresholdInput('Brake Danger (bar)', s.brakeDangerThreshold, (v) {
                  s.setBrakeDangerThreshold(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),
                _buildThresholdInput('TPS WOT Threshold (°)', s.tpsWotThreshold, (v) {
                  s.setTpsWotThreshold(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),
                _buildThresholdInput('Steering Extreme (°)', s.steeringExtremeThreshold, (v) {
                  s.setSteeringExtremeThreshold(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('DISPLAY'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: Column(
              children: [
                _buildSlider('Chart Line Thickness', s.chartLineThickness, 1.0, 3.0, 4, (v) {
                  s.setChartLineThickness(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),

                _buildToggle('Show Data Points on Charts', s.showDataPoints, (v) {
                  s.setShowDataPoints(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),
                _buildToggle('Smoothing Filter', s.enableTelemetrySmoothing, (v) {
                  s.setEnableTelemetrySmoothing(v).then((_) {
                    setState(() {});
                    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
                  });
                }),
                _buildToggle('Global Light Mode', Provider.of<DaqProvider>(context).isLightMode, (v) {
                  Provider.of<DaqProvider>(context, listen: false).toggleLightMode();
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildSectionTitle('SESSION'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: Column(
              children: [
                _buildToggle('Auto-load last session', s.autoLoadLastSession, (v) {
                  s.setAutoLoadLastSession(v).then((_) => setState(() {}));
                }),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Max Session History', style: Theme.of(context).textTheme.bodyMedium),
                      DropdownButton<int>(
                        value: s.maxSessionHistory,
                        dropdownColor: RacingTheme.panel,
                        style: Theme.of(context).textTheme.bodySmall,
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 20, child: Text('20')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            s.setMaxSessionHistory(val).then((_) => setState(() {}));
                          }
                        },
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        s.clearSessionHistory();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache Cleared')));
                      },
                      icon: Icon(Icons.delete_outline, size: 16, color: Colors.white),
                      label: Text('CLEAR CACHE', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildSectionTitle('DATA PIPELINE'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Channel Renames Map', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('e.g., {"EngineTemp": "Water (°C)"}', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: TextField(
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add new rename (Orig:New)',
                      hintStyle: TextStyle(color: RacingTheme.textMuted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      filled: true,
                      fillColor: RacingTheme.background,
                      border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                    ),
                      onSubmitted: (val) {
                        if (val.contains(':')) {
                          final parts = val.split(':');
                          setState(() => s.setChannelRename(parts[0].trim(), parts[1].trim()));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const CustomChannelEditor(),
                        );
                      },
                      icon: Icon(Icons.calculate, size: 14, color: RacingTheme.primaryAccent),
                      label: Text('Math Channels', style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: RacingTheme.primaryAccent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          _buildSectionTitle('ABOUT'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: RacingTheme.panel, border: Border.all(color: RacingTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App Name: ARION DAQ', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Version: 1.0.0', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Platform: Windows x64 + Android', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Car: AR25', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Season: 2026', style: Theme.of(context).textTheme.bodySmall),
                const Divider(height: 32),
                Center(
                  child: Text('© 2026 Arion. All rights reserved.', style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsService();

    if (!kIsWeb && Platform.isAndroid) {
      return _buildMobileLayout(context, s);
    }
    return _buildDesktopLayout(context, s);
  }
}
