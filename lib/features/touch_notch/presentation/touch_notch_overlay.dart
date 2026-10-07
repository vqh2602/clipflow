import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../data/touch_notch_providers.dart';
import '../domain/touch_notch_models.dart';
import 'widgets/notch_calendar_widget.dart';
import 'widgets/notch_capsule_shape.dart';
import 'widgets/notch_clipboard_widget.dart';
import 'widgets/notch_music_player_widget.dart';
import 'widgets/notch_notes_widget.dart';
import 'widgets/notch_timer_dial_widget.dart';
import 'widgets/notch_waveform_widget.dart';

class TouchNotchOverlay extends ConsumerStatefulWidget {
  const TouchNotchOverlay({
    super.key,
    this.isEmbedded = false,
    this.onClose,
    this.onOpenSettings,
  });

  final bool isEmbedded;
  final VoidCallback? onClose;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<TouchNotchOverlay> createState() => _TouchNotchOverlayState();
}

class _TouchNotchOverlayState extends ConsumerState<TouchNotchOverlay> {
  void _handleCopyItem(ClipboardItem item) {
    ref.read(historyControllerProvider.notifier).copy(item);
    if (!widget.isEmbedded) {
      ref.read(touchNotchExpandedProvider.notifier).state = false;
      final desktop = ref.read(desktopIntegrationProvider);
      desktop.pasteToPreviousApplication();
    }
  }

  void _handleCopyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!widget.isEmbedded) {
      ref.read(touchNotchExpandedProvider.notifier).state = false;
      final desktop = ref.read(desktopIntegrationProvider);
      desktop.pasteToPreviousApplication();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final activeTab = ref.watch(touchNotchTabProvider);
    final isExpanded = ref.watch(touchNotchExpandedProvider);
    final track = ref.watch(musicPlayerProvider);
    final timer = ref.watch(pomodoroProvider);

    ref.listen<bool>(touchNotchExpandedProvider, (previous, next) {
      if (!widget.isEmbedded && previous != next) {
        ref.read(desktopIntegrationProvider).updateTouchNotchBounds(
              isExpanded: next,
              style: settings.touchNotchStyle,
            );
      }
    });

    final isDynamicIsland = settings.touchNotchStyle == 'dynamic_island';
    final collapsedWidth = isDynamicIsland ? 220.0 : 260.0;
    const collapsedHeight = 36.0;
    const expandedWidth = 660.0;
    const expandedHeight = 220.0;

    final currentWidth = isExpanded ? expandedWidth : collapsedWidth;
    final currentHeight = isExpanded ? expandedHeight : collapsedHeight;

    final fillColor = isExpanded
        ? const Color(0xF50D0E12)
        : (isDynamicIsland
            ? const Color(0xEE0B0C10)
            : const Color(0xFF000000)); // Seamless MacBook notch bezel!

    final borderColor = isExpanded
        ? const Color(0x338FA9C8)
        : (isDynamicIsland
            ? const Color(0x228FA9C8)
            : const Color(0x00000000)); // Zero border when collapsed on MacBook!

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: isDynamicIsland ? 8.0 : 0.0),
        child: MouseRegion(
          onEnter: (_) {
            if (settings.touchNotchHoverExpand && !isExpanded) {
              ref.read(touchNotchExpandedProvider.notifier).state = true;
            }
          },
          onExit: (_) {
            if (settings.touchNotchAutoCollapse && isExpanded && !widget.isEmbedded) {
              ref.read(touchNotchExpandedProvider.notifier).state = false;
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: currentWidth,
            height: currentHeight,
            child: CustomPaint(
              painter: NotchCapsulePainter(
                isExpanded: isExpanded,
                isDynamicIsland: isDynamicIsland,
                fillColor: fillColor,
                borderColor: borderColor,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isDynamicIsland ? 20 : 16),
                child: isExpanded
                    ? _buildExpandedContent(context, activeTab, settings)
                    : _buildCollapsedContent(context, track, timer),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Collapsed Notch State (Screenshot 1) ---
  Widget _buildCollapsedContent(
    BuildContext context,
    MusicTrack track,
    PomodoroState timer,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(touchNotchExpandedProvider.notifier).state = true;
      },
      child: Container(
        color: const Color(0x00000000),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Spotify / Music logo badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 17,
                  height: 17,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1ED760),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.waveform,
                      size: 10,
                      color: CupertinoColors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    track.title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Center: simulated camera cutout
            Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: Color(0xFF030305),
                shape: BoxShape.circle,
              ),
            ),

            // Right: Animated live waveform visualizer or timer badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timer.isRunning) ...[
                  Text(
                    '${timer.remainingSeconds ~/ 60}:${(timer.remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF56300),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                NotchWaveformWidget(
                  isPlaying: track.isPlaying,
                  barCount: 4,
                  maxHeight: 12,
                  minHeight: 3,
                  color: const Color(0xFF1ED760),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Expanded Notch State (Screenshots 2-5) ---
  Widget _buildExpandedContent(
    BuildContext context,
    TouchNotchTab activeTab,
    dynamic settings,
  ) {
    return Column(
      children: [
        // Top Header inside the Notch: Window controls & Tab switcher
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color(0x18FFFFFF),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 3-dots window pill (Red, Yellow, Green subtle or Collapse)
              GestureDetector(
                onTap: () {
                  ref.read(touchNotchExpandedProvider.notifier).state = false;
                  widget.onClose?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5F56),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFBD2E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF27C93F),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tab Switcher Buttons
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (settings.touchNotchShowClipboard) ...[
                        _TabHeaderButton(
                          title: 'Clipboard',
                          icon: CupertinoIcons.doc_on_clipboard,
                          isSelected: activeTab == TouchNotchTab.clipboard,
                          onTap: () => ref
                              .read(touchNotchTabProvider.notifier)
                              .state = TouchNotchTab.clipboard,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (settings.touchNotchShowMusic) ...[
                        _TabHeaderButton(
                          title: 'Sóng nhạc',
                          icon: CupertinoIcons.waveform,
                          isSelected: activeTab == TouchNotchTab.music,
                          onTap: () => ref
                              .read(touchNotchTabProvider.notifier)
                              .state = TouchNotchTab.music,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (settings.touchNotchShowTimer) ...[
                        _TabHeaderButton(
                          title: 'Hẹn giờ',
                          icon: CupertinoIcons.timer,
                          isSelected: activeTab == TouchNotchTab.timer,
                          onTap: () => ref
                              .read(touchNotchTabProvider.notifier)
                              .state = TouchNotchTab.timer,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (settings.touchNotchShowCalendar) ...[
                        _TabHeaderButton(
                          title: 'Lịch trình',
                          icon: CupertinoIcons.calendar,
                          isSelected: activeTab == TouchNotchTab.calendar,
                          onTap: () => ref
                              .read(touchNotchTabProvider.notifier)
                              .state = TouchNotchTab.calendar,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (settings.touchNotchShowNotes) ...[
                        _TabHeaderButton(
                          title: 'Ghi chú',
                          icon: CupertinoIcons.pencil_ellipsis_rectangle,
                          isSelected: activeTab == TouchNotchTab.notes,
                          onTap: () => ref
                              .read(touchNotchTabProvider.notifier)
                              .state = TouchNotchTab.notes,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Right Actions: Settings & Collapse chevron
              if (widget.onOpenSettings != null) ...[
                GestureDetector(
                  onTap: widget.onOpenSettings,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      CupertinoIcons.gear_alt,
                      size: 14,
                      color: Color(0xAAFFFFFF),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: () {
                  ref.read(touchNotchExpandedProvider.notifier).state = false;
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    CupertinoIcons.chevron_up,
                    size: 14,
                    color: Color(0xAAFFFFFF),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body Content based on active tab
        Expanded(
          child: switch (activeTab) {
            TouchNotchTab.clipboard =>
              NotchClipboardWidget(onItemPasted: _handleCopyItem),
            TouchNotchTab.music => const NotchMusicPlayerWidget(),
            TouchNotchTab.timer => const NotchTimerDialWidget(),
            TouchNotchTab.calendar => const NotchCalendarWidget(),
            TouchNotchTab.notes =>
              NotchNotesWidget(onCopyText: _handleCopyText),
          },
        ),
      ],
    );
  }
}

class _TabHeaderButton extends StatelessWidget {
  const _TabHeaderButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x33FFFFFF) : const Color(0x00000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected
                  ? CupertinoColors.white
                  : const Color(0x88FFFFFF),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? CupertinoColors.white
                    : const Color(0x88FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
