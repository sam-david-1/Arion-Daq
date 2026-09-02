import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';

class ZoomableChart extends StatefulWidget {
  final double originalMinX;
  final double originalMaxX;
  final String channelName;
  final Widget Function(BuildContext context, double minX, double maxX) builder;

  const ZoomableChart({
    super.key,
    required this.originalMinX,
    required this.originalMaxX,
    required this.channelName,
    required this.builder,
  });

  @override
  State<ZoomableChart> createState() => _ZoomableChartState();
}

class _ZoomableChartState extends State<ZoomableChart> {
  late double _minX;
  late double _maxX;
  double _lastMinX = 0;
  double _lastMaxX = 0;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _minX = widget.originalMinX;
    _maxX = widget.originalMaxX;
  }

  @override
  void didUpdateWidget(ZoomableChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originalMaxX != widget.originalMaxX || oldWidget.originalMinX != widget.originalMinX) {
      _minX = widget.originalMinX;
      _maxX = widget.originalMaxX;
    }
  }

  void _askAi(BuildContext context) {
    final provider = Provider.of<DaqProvider>(context, listen: false);
    provider.setAiSidebarMode(true);
    provider.askAi('Analyze the ${widget.channelName} channel specifically for this session.');
  }

  void _applyZoom(double zoomFactor, double focalX) {
    setState(() {
      double range = _maxX - _minX;
      
      RenderBox? box = context.findRenderObject() as RenderBox?;
      double center = (_maxX + _minX) / 2;
      double percentX = 0.5;
      if (box != null) {
        double width = box.size.width;
        percentX = (focalX / width).clamp(0.0, 1.0);
        center = _minX + (range * percentX);
      }
      
      range = range * (1 - zoomFactor);
      
      if (box != null) {
        _minX = center - (range * percentX);
        _maxX = center + (range * (1 - percentX));
      } else {
        _minX = center - (range / 2);
        _maxX = center + (range / 2);
      }

      // Clamp to limits
      if (_minX < widget.originalMinX) _minX = widget.originalMinX;
      if (_maxX > widget.originalMaxX) _maxX = widget.originalMaxX;
      if (_minX >= _maxX) _minX = _maxX - 100;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Only zoom when Ctrl is held — let normal scroll pass through
      if (!HardwareKeyboard.instance.isControlPressed) {
        return;
      }
      GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          double zoomFactor = event.scrollDelta.dy < 0 ? 0.10 : -0.10;
          _applyZoom(zoomFactor, event.localPosition.dx);
        }
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Only pan when Ctrl is held and left button is down
    if (event.buttons == 1 && HardwareKeyboard.instance.isControlPressed) {
      setState(() {
        double range = _maxX - _minX;
        RenderBox? box = context.findRenderObject() as RenderBox?;
        double width = box?.size.width ?? 1000.0;
        
        double delta = -event.localDelta.dx * (range / width);
        _minX = _minX + delta;
        _maxX = _maxX + delta;

        // Clamp to limits
        if (_minX < widget.originalMinX) _minX = widget.originalMinX;
        if (_maxX > widget.originalMaxX) _maxX = widget.originalMaxX;
        if (_minX >= _maxX) _minX = _maxX - 100;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isZoomed = _minX > widget.originalMinX + 1 || _maxX < widget.originalMaxX - 1;

    return Stack(
      children: [
        ClipRect(
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              onPointerMove: _handlePointerMove,
              child: Padding(
                padding: const EdgeInsets.only(top: 32.0, right: 16.0, bottom: 8.0),
                child: widget.builder(context, _minX, _maxX),
              ),
            ),
          ),
        ),
        // Header row: title + zoom hint on left, actions on right
        Positioned(
          top: 6, left: 8, right: 8,
          child: Row(
            children: [
              Text(
                widget.channelName, 
                style: TextStyle(color: RacingTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: _isHovering ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: RacingTheme.background.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: RacingTheme.border.withValues(alpha: 0.5)),
                  ),
                  child: Text('Ctrl + Scroll to zoom', style: TextStyle(color: RacingTheme.textMuted, fontSize: 9)),
                ),
              ),
              const Spacer(),
              if (isZoomed)
                InkWell(
                  onTap: () {
                    setState(() {
                      _minX = widget.originalMinX;
                      _maxX = widget.originalMaxX;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: RacingTheme.panel, borderRadius: BorderRadius.circular(4), border: Border.all(color: RacingTheme.border)),
                    child: Text('⊙ RESET', style: TextStyle(color: RacingTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              InkWell(
                onTap: () => _askAi(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: RacingTheme.primaryAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: RacingTheme.primaryAccent)),
                  child: Text('✦ Ask AI', style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
