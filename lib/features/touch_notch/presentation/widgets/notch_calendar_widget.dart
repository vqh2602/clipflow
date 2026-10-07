import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/touch_notch_providers.dart';

class NotchCalendarWidget extends ConsumerStatefulWidget {
  const NotchCalendarWidget({super.key});

  @override
  ConsumerState<NotchCalendarWidget> createState() =>
      _NotchCalendarWidgetState();
}

class _NotchCalendarWidgetState extends ConsumerState<NotchCalendarWidget> {
  int _selectedDayOffset = 0;

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final timeController = TextEditingController(text: '10:00');
    String selectedColor = '#F56300';

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Thêm sự kiện mới'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: titleController,
                placeholder: 'Tên sự kiện / lịch trình',
                autofocus: true,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: timeController,
                placeholder: 'Thời gian (vd: 14:30)',
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in [
                    '#F56300',
                    '#3E7EFF',
                    '#00CA75',
                    '#AF52DE',
                  ])
                    GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color
                                ? CupertinoColors.white
                                : const Color(0x00000000),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Hủy'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Thêm'),
              onPressed: () {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  ref.read(notchEventsProvider.notifier).addEvent(
                        text,
                        timeController.text.trim(),
                        selectedColor,
                      );
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return '';
    }
  }

  String _fullDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Thứ Hai';
      case 2:
        return 'Thứ Ba';
      case 3:
        return 'Thứ Tư';
      case 4:
        return 'Thứ Năm';
      case 5:
        return 'Thứ Sáu';
      case 6:
        return 'Thứ Bảy';
      case 7:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(notchEventsProvider);
    final now = DateTime.now().add(Duration(days: _selectedDayOffset));
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date, lunar info, and add button
          Row(
            children: [
              Text(
                '${_fullDayName(now.weekday)} •',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'thg ${now.month} ${now.year}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xAAFFFFFF),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showAddEventDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.plus,
                        size: 11,
                        color: CupertinoColors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Thêm sự kiện',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Horizontal Weekly Date Strip (12 CN, 13 T2, 14 T3, etc.)
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 9,
              itemBuilder: (context, index) {
                final dayOffset = index - 4; // -4 to +4 days around today
                final dayDate = today.add(Duration(days: dayOffset));
                final isSelected = dayOffset == _selectedDayOffset;

                return GestureDetector(
                  onTap: () => setState(() => _selectedDayOffset = dayOffset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.only(right: 6),
                    width: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF56300)
                          : const Color(0x18FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF9D42)
                            : const Color(0x00000000),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${dayDate.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: CupertinoColors.white,
                          ),
                        ),
                        Text(
                          _weekdayName(dayDate.weekday),
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected
                                ? CupertinoColors.white
                                : const Color(0x88FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Events List
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: Text(
                      'Không có sự kiện nào hôm nay',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0x88FFFFFF),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final color = Color(
                        int.parse(event.colorHex.replaceFirst('#', '0xFF')),
                      );

                      return GestureDetector(
                        onTap: () => ref
                            .read(notchEventsProvider.notifier)
                            .toggleDone(event.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x18FFFFFF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: event.isDone
                                        ? const Color(0x66FFFFFF)
                                        : CupertinoColors.white,
                                    decoration: event.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                event.timeString,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0x88FFFFFF),
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
