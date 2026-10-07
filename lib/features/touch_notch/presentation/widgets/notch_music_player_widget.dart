import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/touch_notch_providers.dart';
import 'notch_waveform_widget.dart';

class NotchMusicPlayerWidget extends ConsumerWidget {
  const NotchMusicPlayerWidget({super.key});

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final remainingSeconds = track.durationSeconds - track.positionSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Album Art with Spotify Badge
          Stack(
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF0F1E2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.music_note_2,
                        size: 38,
                        color: Color(0xCCFFFFFF),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.album,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0x88FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Spotify badge
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1ED760),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.waveform,
                    size: 9,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),

          // Metadata & Controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title, Artist, & Live Waveform Indicator
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xAAFFFFFF),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    NotchWaveformWidget(
                      isPlaying: track.isPlaying,
                      barCount: 5,
                      maxHeight: 16,
                      color: const Color(0xFF1ED760),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Playback Control Buttons (Shuffle, Prev, Play/Pause, Next, Repeat)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    _ControlButton(
                      icon: CupertinoIcons.shuffle,
                      size: 14,
                      isActive: track.isShuffle,
                      onTap: controller.toggleShuffle,
                    ),
                    const SizedBox(width: 14),

                    // Previous
                    _ControlButton(
                      icon: CupertinoIcons.backward_fill,
                      size: 16,
                      onTap: controller.previous,
                    ),
                    const SizedBox(width: 14),

                    // Play / Pause (Large circular button)
                    GestureDetector(
                      onTap: controller.togglePlayPause,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            track.isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 18,
                            color: CupertinoColors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Next
                    _ControlButton(
                      icon: CupertinoIcons.forward_fill,
                      size: 16,
                      onTap: controller.next,
                    ),
                    const SizedBox(width: 14),

                    // Repeat / Lyrics
                    _ControlButton(
                      icon: CupertinoIcons.repeat,
                      size: 14,
                      isActive: track.isRepeat,
                      onTap: controller.toggleRepeat,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Seekbar & Times
                Row(
                  children: [
                    Text(
                      _formatDuration(track.positionSeconds),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0x99FFFFFF),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 18,
                        child: CupertinoSlider(
                          value: track.positionSeconds
                              .toDouble()
                              .clamp(0, track.durationSeconds.toDouble()),
                          min: 0,
                          max: track.durationSeconds.toDouble(),
                          activeColor: const Color(0xFF1ED760),
                          thumbColor: CupertinoColors.white,
                          onChanged: (val) => controller.seek(val.round()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '-${_formatDuration(remainingSeconds.clamp(0, track.durationSeconds))}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0x99FFFFFF),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    this.size = 16,
    this.isActive = false,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0x331ED760) : const Color(0x00000000),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: size,
          color: isActive
              ? const Color(0xFF1ED760)
              : const Color(0xCCFFFFFF),
        ),
      ),
    );
  }
}
