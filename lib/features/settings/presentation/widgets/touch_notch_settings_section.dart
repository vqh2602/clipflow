import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../touch_notch/presentation/touch_notch_overlay.dart';
import 'settings_helpers.dart';

class TouchNotchSettingsSection extends ConsumerWidget {
  const TouchNotchSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Interactive Live Preview Card
        Container(
          width: double.infinity,
          height: 200,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF14171F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0x228FA9C8),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Simulated top menu bar background
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    color: Color(0x18FFFFFF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        CupertinoIcons.macwindow,
                        size: 13,
                        color: Color(0xCCFFFFFF),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Touch Note',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                      Spacer(),
                      Icon(
                        CupertinoIcons.wifi,
                        size: 12,
                        color: Color(0xAAFFFFFF),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.battery_100,
                        size: 14,
                        color: Color(0xAAFFFFFF),
                      ),
                    ],
                  ),
                ),
              ),

              // The Notch Live Interactive Widget
              const Positioned(
                top: 0,
                child: TouchNotchOverlay(isEmbedded: true),
              ),

              // Hint label at bottom
              Positioned(
                bottom: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.hand_point_right,
                      size: 12,
                      color: Color(0x88FFFFFF),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Khung xem trước tương tác: Nhấp hoặc rê chuột vào tai thỏ để thử nghiệm',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0x88FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action button to launch Touch Notch in floating mode
        Center(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFF3E7EFF),
            borderRadius: BorderRadius.circular(12),
            onPressed: () {
              ref.read(desktopIntegrationProvider).toggleTouchNotch(
                    style: settings.touchNotchStyle,
                  );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.macwindow, size: 16),
                SizedBox(width: 8),
                Text(
                  'Kích hoạt Touch Note trên màn hình ngay',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Master Switch
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'Bật tính năng Touch Note (Tai thỏ)',
              subtitle:
                  'Hiển thị thanh tai thỏ thông minh phía trên cùng màn hình tích hợp Clipboard, Sóng nhạc, Hẹn giờ và Lịch trình',
              value: settings.touchNotchEnabled,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchEnabled: val),
                );
                final desktop = ref.read(desktopIntegrationProvider);
                if (val) {
                  desktop.showTouchNotch(style: settings.touchNotchStyle);
                } else {
                  desktop.hideTouchNotch();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Appearance & Behavior
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: 'Kiểu dáng Tai thỏ',
              subtitle: 'Lựa chọn hình dáng hiển thị thanh tương tác',
              trailing: CupertinoSlidingSegmentedControl<String>(
                groupValue: settings.touchNotchStyle,
                children: const {
                  'macbook_notch': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text('Tai thỏ MacBook', style: TextStyle(fontSize: 12)),
                  ),
                  'dynamic_island': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text('Đảo thích ứng', style: TextStyle(fontSize: 12)),
                  ),
                },
                onValueChanged: (val) {
                  if (val != null) {
                    updateSettings(
                      ref,
                      (current) => current.copyWith(touchNotchStyle: val),
                    );
                    if (settings.touchNotchEnabled) {
                      ref
                          .read(desktopIntegrationProvider)
                          .showTouchNotch(style: val);
                    }
                  }
                },
              ),
            ),
            SwitchRowWidget(
              title: 'Tự động mở rộng khi rê chuột (Hover to expand)',
              subtitle: 'Mở rộng bảng tiện ích ngay khi con trỏ di chuyển qua tai thỏ',
              value: settings.touchNotchHoverExpand,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchHoverExpand: val),
                );
              },
            ),
            SwitchRowWidget(
              title: 'Tự động thu gọn khi mất tiêu điểm (Auto collapse)',
              subtitle: 'Thu nhỏ lại về kích thước tai thỏ ban đầu khi nhấp ra ngoài',
              value: settings.touchNotchAutoCollapse,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchAutoCollapse: val),
                );
              },
            ),
            SwitchRowWidget(
              title: 'Hiển thị sóng nhạc động (Real-time Waveform)',
              subtitle: 'Hiệu ứng các cột sóng âm nhảy theo điệu nhạc khi đang phát',
              value: settings.touchNotchShowWaveform,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchShowWaveform: val),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Modules Management
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'CÁC TIỆN ÍCH TRÊN TAI THỎ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0x88FFFFFF),
              letterSpacing: 0.8,
            ),
          ),
        ),
        SettingsGroupWidget(
          children: [
            SwitchRowWidget(
              title: 'Lịch sử Clipboard (clipbroad)',
              subtitle: 'Lướt xem thẻ nội dung sao chép, bộ lọc danh mục và bấm dán tức thì',
              value: settings.touchNotchShowClipboard,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchShowClipboard: val),
                );
              },
            ),
            SwitchRowWidget(
              title: 'Trình phát nhạc & Sóng nhạc (sóng nhạc)',
              subtitle: 'Xem ảnh bìa album, điều khiển Spotify/Apple Music và sóng nhạc thời gian thực',
              value: settings.touchNotchShowMusic,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchShowMusic: val),
                );
              },
            ),
            SwitchRowWidget(
              title: 'Hẹn giờ & Pomodoro (nhắc nhở, hẹn giờ)',
              subtitle: 'Vòng đo dạng cong với các mốc thời gian Task, Reminder, Break',
              value: settings.touchNotchShowTimer,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchShowTimer: val),
                );
              },
            ),
            SwitchRowWidget(
              title: 'Lịch trình & Sự kiện (thêm sự kiện, lịch trình)',
              subtitle: 'Dải ngày trong tuần và danh sách công việc sắp tới trong ngày',
              value: settings.touchNotchShowCalendar,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchShowCalendar: val),
                );
              },
            ),
            SwitchRowWidget(
              title: 'Ghi chú nhanh (Touch Note)',
              subtitle: 'Khu vực lưu nhanh ý tưởng tức thì và dán vào bất cứ nơi nào',
              value: settings.touchNotchShowNotes,
              onChanged: (val) {
                updateSettings(
                  ref,
                  (current) => current.copyWith(touchNotchShowNotes: val),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pomodoro Duration Config
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'THỜI LƯỢNG HẸN GIỜ (POMODORO)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0x88FFFFFF),
              letterSpacing: 0.8,
            ),
          ),
        ),
        SettingsGroupWidget(
          children: [
            SettingsTileWidget(
              title: 'Thời gian tập trung (Task)',
              subtitle: '${settings.touchNotchPomodoroWorkMinutes} phút',
              trailing: SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: settings.touchNotchPomodoroWorkMinutes > 5
                          ? () {
                              updateSettings(
                                ref,
                                (current) => current.copyWith(
                                  touchNotchPomodoroWorkMinutes:
                                      current.touchNotchPomodoroWorkMinutes - 5,
                                ),
                              );
                            }
                          : null,
                      child: const Icon(CupertinoIcons.minus_circle, size: 22),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: settings.touchNotchPomodoroWorkMinutes < 90
                          ? () {
                              updateSettings(
                                ref,
                                (current) => current.copyWith(
                                  touchNotchPomodoroWorkMinutes:
                                      current.touchNotchPomodoroWorkMinutes + 5,
                                ),
                              );
                            }
                          : null,
                      child: const Icon(CupertinoIcons.plus_circle, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            SettingsTileWidget(
              title: 'Thời gian nghỉ ngơi (Break)',
              subtitle: '${settings.touchNotchPomodoroBreakMinutes} phút',
              trailing: SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: settings.touchNotchPomodoroBreakMinutes > 1
                          ? () {
                              updateSettings(
                                ref,
                                (current) => current.copyWith(
                                  touchNotchPomodoroBreakMinutes:
                                      current.touchNotchPomodoroBreakMinutes - 1,
                                ),
                              );
                            }
                          : null,
                      child: const Icon(CupertinoIcons.minus_circle, size: 22),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: settings.touchNotchPomodoroBreakMinutes < 30
                          ? () {
                              updateSettings(
                                ref,
                                (current) => current.copyWith(
                                  touchNotchPomodoroBreakMinutes:
                                      current.touchNotchPomodoroBreakMinutes + 1,
                                ),
                              );
                            }
                          : null,
                      child: const Icon(CupertinoIcons.plus_circle, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
