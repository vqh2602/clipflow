import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/touch_notch_providers.dart';
import '../../domain/touch_notch_models.dart';

class NotchTimerDialWidget extends ConsumerWidget {
  const NotchTimerDialWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(pomodoroProvider);
    final controller = ref.read(pomodoroProvider.notifier);

    final minutes = timerState.remainingSeconds ~/ 60;
    final seconds = timerState.remainingSeconds % 60;
    final timeText = timerState.isRunning
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$minutes min';

    return Column(
      children: [
        // Top Mode Switcher Pills (Task, Reminder, Break, Tùy chỉnh)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModePill(
                label: 'Task',
                color: const Color(0xFFF56300),
                isSelected: timerState.mode == PomodoroMode.task,
                onTap: () => controller.setMode(PomodoroMode.task),
              ),
              const SizedBox(width: 8),
              _ModePill(
                label: 'Reminder',
                color: const Color(0xFF3E7EFF),
                isSelected: timerState.mode == PomodoroMode.reminder,
                onTap: () => controller.setMode(PomodoroMode.reminder),
              ),
              const SizedBox(width: 8),
              _ModePill(
                label: 'Break',
                color: const Color(0xFF00CA75),
                isSelected: timerState.mode == PomodoroMode.breakTime,
                onTap: () => controller.setMode(PomodoroMode.breakTime),
              ),
              const SizedBox(width: 8),
              _ModePill(
                label: 'Tùy chỉnh',
                color: const Color(0xFFAF52DE),
                isSelected: timerState.mode == PomodoroMode.custom,
                onTap: () => controller.setMode(PomodoroMode.custom),
              ),
            ],
          ),
        ),

        // Arc Dial & Central Countdown Display
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arc Ticks & Progress Canvas
              SizedBox(
                width: 320,
                height: 75,
                child: CustomPaint(
                  painter: _ArcDialPainter(
                    progress: timerState.progress,
                    accentColor: const Color(0xFFF56300),
                  ),
                ),
              ),

              // Big Center Time Readout
              Positioned(
                top: 4,
                child: Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: CupertinoColors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // Bottom Controls: [-] [▶/⏸] [+]
              Positioned(
                bottom: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // - Button
                    _DialButton(
                      icon: CupertinoIcons.minus,
                      size: 14,
                      onTap: () => controller.adjustMinutes(-1),
                    ),
                    const SizedBox(width: 18),

                    // Play / Pause Button
                    GestureDetector(
                      onTap: controller.toggleStartPause,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            timerState.isRunning
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 16,
                            color: CupertinoColors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // + Button
                    _DialButton(
                      icon: CupertinoIcons.plus,
                      size: 14,
                      onTap: () => controller.adjustMinutes(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x33FFFFFF) : const Color(0x11FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0x22FFFFFF),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? CupertinoColors.white
                    : const Color(0xAAFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialButton extends StatelessWidget {
  const _DialButton({
    required this.icon,
    this.size = 14,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: Color(0x2AFFFFFF),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: size,
            color: CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}

class _ArcDialPainter extends CustomPainter {
  const _ArcDialPainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.9;
    final radius = size.width * 0.45;

    // Draw arc ticks
    const tickCount = 45;
    const startAngle = math.pi * 0.85;
    const endAngle = math.pi * 2.15;
    final totalAngle = endAngle - startAngle;

    final inactivePaint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final t = i / (tickCount - 1);
      final angle = startAngle + t * totalAngle;
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 8.0 : 4.5;

      final x1 = cx + math.cos(angle) * (radius - tickLength);
      final y1 = cy + math.sin(angle) * (radius - tickLength);
      final x2 = cx + math.cos(angle) * radius;
      final y2 = cy + math.sin(angle) * radius;

      final isTickActive = t <= progress;
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        isTickActive ? activePaint : inactivePaint,
      );
    }

    // Glowing active progress arc
    if (progress > 0) {
      final sweepAngle = totalAngle * progress;
      final arcPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius + 2);
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}
