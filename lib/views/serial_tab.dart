import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/serial_service.dart';

class SerialTab extends StatefulWidget {
  const SerialTab({super.key});

  @override
  State<SerialTab> createState() => _SerialTabState();
}

class _SerialTabState extends State<SerialTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _cmdController = TextEditingController();
  int _baudRate = 115200;
  
  @override
  void dispose() {
    _scrollController.dispose();
    _cmdController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        
        // Auto-scroll logic if not paused
        if (!provider.pauseAutoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top Bar
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: RacingTheme.panel,
                  border: Border.all(color: RacingTheme.border),
                ),
                child: Row(
                  children: [
                    Text('BAUD:', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _baudRate,
                        dropdownColor: RacingTheme.panel,
                        style: Theme.of(context).textTheme.bodySmall,
                        items: const [9600, 19200, 38400, 57600, 115200, 230400, 460800].map((b) => DropdownMenuItem(value: b, child: Text(b.toString()))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _baudRate = val);
                            SerialService().setBaudRate(val);
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    Text('LINES: ${provider.rawSerialLogs.length}/2000', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.setPauseAutoScroll(!provider.pauseAutoScroll),
                      icon: Icon(provider.pauseAutoScroll ? Icons.play_arrow : Icons.pause, size: 16),
                      label: Text(provider.pauseAutoScroll ? 'RESUME' : 'PAUSE'),
                      style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.border, foregroundColor: RacingTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: provider.clearSerialLogs,
                      icon: Icon(Icons.clear, size: 16),
                      label: Text('CLEAR'),
                      style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.border, foregroundColor: RacingTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Terminal Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF050608),
                    border: Border.all(color: RacingTheme.border),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: provider.rawSerialLogs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        provider.rawSerialLogs[index],
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: Color(0xFF00FF41),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Command Input
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: RacingTheme.panel,
                  border: Border.all(color: RacingTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cmdController,
                        style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter command...',
                          hintStyle: Theme.of(context).textTheme.bodySmall,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            SerialService().sendCommand(val);
                            _cmdController.clear();
                          }
                        },
                      ),
                    ),
                    Container(width: 1, color: RacingTheme.border),
                    InkWell(
                      onTap: () {
                        if (_cmdController.text.isNotEmpty) {
                          SerialService().sendCommand(_cmdController.text);
                          _cmdController.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        alignment: Alignment.center,
                        child: Text('SEND', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: RacingTheme.primaryAccent)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
