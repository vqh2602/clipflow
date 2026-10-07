import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

class NotchWaveformWidget extends StatefulWidget {
  const NotchWaveformWidget({
    super.key,
    this.isPlaying = true,
    this.barCount = 4,
    this.barWidth = 2.5,
    this.barSpacing = 2.0,
    this.maxHeight = 14.0,
    this.minHeight = 4.0,
    this.color = const Color(0xFF1ED760), // Spotify green
  });

  final bool isPlaying;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final double maxHeight;
  final double minHeight;
  final Color color;

  @override
  State<NotchWaveformWidget> createState() => _NotchWaveformWidgetState();
}

class _NotchWaveformWidgetState extends State<NotchWaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant NotchWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.animateTo(0.2, duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final totalWidth = widget.barCount * widget.barWidth +
            (widget.barCount - 1) * widget.barSpacing;
        return SizedBox(
          width: totalWidth,
          height: widget.maxHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              final phase = (index / widget.barCount) * math.pi * 2;
              final t = _controller.value * math.pi * 2;
              final wave = widget.isPlaying
                  ? (math.sin(t + phase).abs() * 0.7 +
                          math.sin(t * 1.5 + phase * 0.5).abs() * 0.3)
                      .clamp(0.1, 1.0)
                  : 0.25;
              final height = widget.minHeight +
                  (widget.maxHeight - widget.minHeight) * wave;

              return Container(
                margin: EdgeInsets.only(
                  right: index < widget.barCount - 1 ? widget.barSpacing : 0,
                ),
                width: widget.barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.barWidth / 2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
