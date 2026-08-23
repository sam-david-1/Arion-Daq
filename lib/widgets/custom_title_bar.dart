import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/racing_theme.dart';

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximizeState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximizeState() async {
    bool isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: RacingTheme.background,
        border: Border(bottom: BorderSide(color: RacingTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          // Left: App Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'ARION DAQ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Text(
                  'AR25',
                  style: TextStyle(color: RacingTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          
          // Center: Drag Area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                windowManager.startDragging();
              },
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
          ),
          
          // Right: Window Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WindowControlButton(
                icon: Icons.remove,
                onPressed: () => windowManager.minimize(),
              ),
              _WindowControlButton(
                icon: _isMaximized ? Icons.crop_square_outlined : Icons.crop_square,
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
              _WindowControlButton(
                icon: Icons.close,
                isClose: true,
                onPressed: () => windowManager.close(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovered 
            ? (widget.isClose ? const Color(0xFFE81123) : const Color(0xFF333333))
            : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered ? Colors.white : RacingTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
