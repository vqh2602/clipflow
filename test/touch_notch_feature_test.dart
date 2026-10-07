import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/features/touch_notch/data/touch_notch_service.dart';
import 'package:clipflow/features/touch_notch/domain/touch_notch_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TouchNotch Models & Settings', () {
    test('default Touch Notch settings values', () {
      const settings = AppSettings();
      expect(settings.touchNotchEnabled, isTrue);
      expect(settings.touchNotchStyle, 'macbook_notch');
      expect(settings.touchNotchShowWaveform, isTrue);
      expect(settings.touchNotchHoverExpand, isTrue);
      expect(settings.touchNotchAutoCollapse, isTrue);
      expect(settings.touchNotchShowMusic, isTrue);
      expect(settings.touchNotchShowClipboard, isTrue);
      expect(settings.touchNotchShowTimer, isTrue);
      expect(settings.touchNotchShowCalendar, isTrue);
      expect(settings.touchNotchShowNotes, isTrue);
      expect(settings.touchNotchPomodoroWorkMinutes, 25);
      expect(settings.touchNotchPomodoroBreakMinutes, 5);
    });

    test('Touch Notch settings serialize and deserialize correctly', () {
      final modified = const AppSettings().copyWith(
        touchNotchEnabled: false,
        touchNotchStyle: 'dynamic_island',
        touchNotchShowWaveform: false,
        touchNotchHoverExpand: false,
        touchNotchAutoCollapse: false,
        touchNotchShowMusic: false,
        touchNotchPomodoroWorkMinutes: 30,
        touchNotchPomodoroBreakMinutes: 10,
      );

      final json = modified.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.touchNotchEnabled, isFalse);
      expect(restored.touchNotchStyle, 'dynamic_island');
      expect(restored.touchNotchShowWaveform, isFalse);
      expect(restored.touchNotchHoverExpand, isFalse);
      expect(restored.touchNotchAutoCollapse, isFalse);
      expect(restored.touchNotchShowMusic, isFalse);
      expect(restored.touchNotchPomodoroWorkMinutes, 30);
      expect(restored.touchNotchPomodoroBreakMinutes, 10);
    });

    test('PomodoroState progress calculates correctly', () {
      const state1 = PomodoroState(
        mode: PomodoroMode.task,
        targetSeconds: 1500,
        remainingSeconds: 1500,
        isRunning: false,
      );
      expect(state1.progress, 0.0);

      const state2 = PomodoroState(
        mode: PomodoroMode.breakTime,
        targetSeconds: 300,
        remainingSeconds: 150,
        isRunning: true,
      );
      expect(state2.progress, 0.5);
    });

    test('TouchNotchService manages notes and events with SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = TouchNotchService(prefs);

      // Default sample tracks exist
      final tracks = service.getSampleTracks();
      expect(tracks.isNotEmpty, isTrue);
      expect(tracks.first.title, isNotEmpty);

      // Events
      final events = service.loadEvents();
      expect(events.isNotEmpty, isTrue);

      final newEvent = NotchCalendarEvent(
        id: 'test-event-1',
        title: 'Review Sprint',
        timeString: '16:00',
        date: DateTime.now(),
      );
      await service.saveEvents([...events, newEvent]);
      final updatedEvents = service.loadEvents();
      expect(updatedEvents.any((e) => e.id == 'test-event-1'), isTrue);

      // Notes
      final notes = service.loadNotes();
      expect(notes.isNotEmpty, isTrue);

      final newNote = TouchNote(
        id: 'test-note-1',
        text: 'Remember to commit code',
        createdAt: DateTime.now(),
      );
      await service.saveNotes([...notes, newNote]);
      var updatedNotes = service.loadNotes();
      expect(updatedNotes.any((n) => n.id == 'test-note-1'), isTrue);

      await service.saveNotes(updatedNotes.where((n) => n.id != 'test-note-1').toList());
      updatedNotes = service.loadNotes();
      expect(updatedNotes.any((n) => n.id == 'test-note-1'), isFalse);
    });
  });
}
