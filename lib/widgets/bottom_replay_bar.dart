import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';

class BottomReplayBar extends StatefulWidget {
  const BottomReplayBar({super.key});

  @override
  State<BottomReplayBar> createState() => _BottomReplayBarState();
}

class _BottomReplayBarState extends State<BottomReplayBar> {
  final TextEditingController _jumpTimeController = TextEditingController();

  String _formatTime(int ms) {
    double sec = ms / 1000.0;
    return '${sec.toStringAsFixed(2)}s';
  }

  @override
  void dispose() {
    _jumpTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<DaqProvider>(
        builder: (context, provider, child) {
          bool hasData = provider.loadedLogData.isNotEmpty;
          
          return Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: RacingTheme.panel,
              border: Border(top: BorderSide(color: RacingTheme.border, width: 1)),
            ),
            child: Row(
              children: [
                // Left: Playback Controls
                Row(
                  children: [
                  _buildIconButton(
                    icon: provider.isPlaying ? Icons.pause : Icons.play_arrow,
                    onPressed: hasData ? provider.togglePlayback : null,
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.stop,
                    onPressed: hasData ? provider.stopPlayback : null,
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.replay,
                    onPressed: hasData ? provider.restartPlayback : null,
                  ),
                ],
              ),
              
              const SizedBox(width: 24),
              
              // Center: Timeline Slider
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 20,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: RacingTheme.primaryAccent,
                          inactiveTrackColor: RacingTheme.border,
                          thumbColor: RacingTheme.primaryAccent,
                          overlayColor: RacingTheme.primaryAccent.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: provider.currentTimestampMs.toDouble(),
                          min: 0,
                          max: hasData ? provider.totalDurationMs.toDouble() : 100,
                          onChanged: hasData ? (val) {
                            provider.seekTo(val.round());
                          } : null,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatTime(provider.currentTimestampMs), style: Theme.of(context).textTheme.bodySmall),
                          Text(_formatTime(provider.totalDurationMs), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 24),
              
              // Right: Speed & Jump
              Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: provider.playbackSpeed,
                      dropdownColor: RacingTheme.panel,
                      style: Theme.of(context).textTheme.bodySmall,
                      items: const [
                        DropdownMenuItem(value: 0.25, child: Text('0.25x')),
                        DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                        DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                        DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                        DropdownMenuItem(value: 5.0, child: Text('5.0x')),
                      ],
                      onChanged: hasData ? (val) {
                        if (val != null) provider.setPlaybackSpeed(val);
                      } : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 70,
                    height: 30,
                    child: TextField(
                      controller: _jumpTimeController,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: RacingTheme.textPrimary),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        hintText: 'Time(s)',
                        hintStyle: Theme.of(context).textTheme.bodySmall,
                        filled: true,
                        fillColor: RacingTheme.background,
                        border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                      ),
                      enabled: hasData,
                      onSubmitted: (val) {
                        if (hasData) {
                          double? sec = double.tryParse(val);
                          if (sec != null) provider.seekTo((sec * 1000).round());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: hasData ? () {
                      double? sec = double.tryParse(_jumpTimeController.text);
                      if (sec != null) provider.seekTo((sec * 1000).round());
                    } : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text('GO'),
                  ),
                ],
              ),
            ],
          ), // closes Row
          ); // closes Container
        },
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: RacingTheme.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RacingTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: RacingTheme.primaryAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          child: Icon(icon, size: 20, color: onPressed == null ? RacingTheme.border : RacingTheme.textPrimary),
        ),
      ),
    );
  }
}
