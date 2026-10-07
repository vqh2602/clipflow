import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/touch_notch_models.dart';
import 'touch_notch_service.dart';

final touchNotchServiceProvider = Provider<TouchNotchService>((ref) {
  // We can obtain SharedPreferences synchronously if stored in container or throw if uninitialized
  throw UnimplementedError('Initialize touchNotchServiceProvider in ProviderScope');
});

final touchNotchTabProvider = StateProvider<TouchNotchTab>(
  (ref) => TouchNotchTab.clipboard,
);

final touchNotchExpandedProvider = StateProvider<bool>(
  (ref) => false,
);

// --- Music Controller ---
class MusicPlayerController extends StateNotifier<MusicTrack> {
  MusicPlayerController(this._service)
      : _tracks = _service.getSampleTracks(),
        super(_service.getSampleTracks().first) {
    _startTimer();
  }

  final TouchNotchService _service;
  final List<MusicTrack> _tracks;
  int _currentIndex = 0;
  Timer? _ticker;

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isPlaying) return;
      if (state.positionSeconds >= state.durationSeconds) {
        next();
      } else {
        state = state.copyWith(
          positionSeconds: state.positionSeconds + 1,
        );
      }
    });
  }

  void togglePlayPause() {
    final nextState = !state.isPlaying;
    state = state.copyWith(isPlaying: nextState);
    _service.sendMediaKey(nextState ? 'play' : 'pause');
  }

  void next() {
    if (_tracks.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _tracks.length;
    final track = _tracks[_currentIndex];
    state = track.copyWith(isPlaying: state.isPlaying);
    _service.sendMediaKey('next');
  }

  void previous() {
    if (_tracks.isEmpty) return;
    if (state.positionSeconds > 3) {
      state = state.copyWith(positionSeconds: 0);
      return;
    }
    _currentIndex = (_currentIndex - 1 + _tracks.length) % _tracks.length;
    final track = _tracks[_currentIndex];
    state = track.copyWith(isPlaying: state.isPlaying);
    _service.sendMediaKey('previous');
  }

  void seek(int seconds) {
    state = state.copyWith(
      positionSeconds: seconds.clamp(0, state.durationSeconds),
    );
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeat() {
    state = state.copyWith(isRepeat: !state.isRepeat);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerController, MusicTrack>((ref) {
  final service = ref.watch(touchNotchServiceProvider);
  return MusicPlayerController(service);
});

// --- Timer / Pomodoro Controller ---
class PomodoroController extends StateNotifier<PomodoroState> {
  PomodoroController({
    int initialWorkMinutes = 25,
    int initialBreakMinutes = 5,
  })  : _workMinutes = initialWorkMinutes,
        _breakMinutes = initialBreakMinutes,
        super(PomodoroState(
          mode: PomodoroMode.task,
          targetSeconds: initialWorkMinutes * 60,
          remainingSeconds: initialWorkMinutes * 60,
          title: 'Tập trung làm việc',
        )) {
    _startTicker();
  }

  final int _workMinutes;
  final int _breakMinutes;
  Timer? _ticker;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;
      if (state.remainingSeconds > 0) {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
        );
      } else {
        // Timer completed
        state = state.copyWith(isRunning: false);
      }
    });
  }

  void setMode(PomodoroMode mode) {
    int minutes;
    String title;
    switch (mode) {
      case PomodoroMode.task:
        minutes = _workMinutes;
        title = 'Tập trung làm việc';
        break;
      case PomodoroMode.reminder:
        minutes = 10;
        title = 'Lời nhắc nhanh';
        break;
      case PomodoroMode.breakTime:
        minutes = _breakMinutes;
        title = 'Nghỉ ngơi thư giãn';
        break;
      case PomodoroMode.custom:
        minutes = (state.targetSeconds ~/ 60).clamp(1, 120);
        title = 'Thời gian tùy chỉnh';
        break;
    }

    state = state.copyWith(
      mode: mode,
      targetSeconds: minutes * 60,
      remainingSeconds: minutes * 60,
      isRunning: false,
      title: title,
    );
  }

  void toggleStartPause() {
    state = state.copyWith(isRunning: !state.isRunning);
  }

  void adjustMinutes(int deltaMinutes) {
    final currentMinutes = (state.remainingSeconds / 60).round();
    final newMinutes = (currentMinutes + deltaMinutes).clamp(1, 180);
    state = state.copyWith(
      targetSeconds: newMinutes * 60,
      remainingSeconds: newMinutes * 60,
    );
  }

  void reset() {
    state = state.copyWith(
      remainingSeconds: state.targetSeconds,
      isRunning: false,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final pomodoroProvider =
    StateNotifierProvider<PomodoroController, PomodoroState>((ref) {
  return PomodoroController();
});

// --- Calendar Events Controller ---
class NotchEventsController extends StateNotifier<List<NotchCalendarEvent>> {
  NotchEventsController(this._service) : super([]) {
    _init();
  }

  final TouchNotchService _service;

  void _init() {
    state = _service.loadEvents();
  }

  Future<void> toggleDone(String eventId) async {
    state = state.map((event) {
      if (event.id == eventId) {
        return event.copyWith(isDone: !event.isDone);
      }
      return event;
    }).toList();
    await _service.saveEvents(state);
  }

  Future<void> addEvent(String title, String timeString, String colorHex) async {
    final newEvent = NotchCalendarEvent(
      id: 'ev-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      timeString: timeString,
      colorHex: colorHex,
      date: DateTime.now(),
    );
    state = [...state, newEvent];
    await _service.saveEvents(state);
  }

  Future<void> removeEvent(String eventId) async {
    state = state.where((e) => e.id != eventId).toList();
    await _service.saveEvents(state);
  }
}

final notchEventsProvider =
    StateNotifierProvider<NotchEventsController, List<NotchCalendarEvent>>((ref) {
  final service = ref.watch(touchNotchServiceProvider);
  return NotchEventsController(service);
});

// --- Quick Notes Controller ---
class TouchNotesController extends StateNotifier<List<TouchNote>> {
  TouchNotesController(this._service) : super([]) {
    _init();
  }

  final TouchNotchService _service;

  void _init() {
    state = _service.loadNotes();
  }

  Future<void> addNote(String text) async {
    if (text.trim().isEmpty) return;
    final newNote = TouchNote(
      id: 'note-${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      createdAt: DateTime.now(),
      colorHex: '#3E7EFF',
    );
    state = [newNote, ...state];
    await _service.saveNotes(state);
  }

  Future<void> removeNote(String noteId) async {
    state = state.where((n) => n.id != noteId).toList();
    await _service.saveNotes(state);
  }
}

final touchNotesProvider =
    StateNotifierProvider<TouchNotesController, List<TouchNote>>((ref) {
  final service = ref.watch(touchNotchServiceProvider);
  return TouchNotesController(service);
});
