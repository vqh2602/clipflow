import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/touch_notch_models.dart';

class TouchNotchService {
  TouchNotchService(this._preferences);

  final SharedPreferences _preferences;
  static const _eventsKey = 'clipflow.touch_notch.events.v1';
  static const _notesKey = 'clipflow.touch_notch.notes.v1';
  static const _windowChannel = MethodChannel('clipflow/window');

  // --- Music & Media ---
  List<MusicTrack> getSampleTracks() {
    return [
      const MusicTrack(
        id: 'track-1',
        title: 'The Fate of Ophelia',
        artist: 'Taylor Swift',
        album: 'The Life of a Poet',
        durationSeconds: 208,
        positionSeconds: 87,
        isPlaying: true,
        source: 'spotify',
      ),
      const MusicTrack(
        id: 'track-2',
        title: 'Midnight Rain',
        artist: 'Taylor Swift',
        album: 'Midnights',
        durationSeconds: 174,
        positionSeconds: 45,
        isPlaying: false,
        source: 'spotify',
      ),
      const MusicTrack(
        id: 'track-3',
        title: 'Starboy',
        artist: 'The Weeknd, Daft Punk',
        album: 'Starboy',
        durationSeconds: 230,
        positionSeconds: 110,
        isPlaying: false,
        source: 'spotify',
      ),
    ];
  }

  Future<void> sendMediaKey(String action) async {
    if (!Platform.isMacOS) return;
    try {
      await _windowChannel.invokeMethod('mediaControl', action);
    } on Object {
      // Graceful fallback to in-app simulated player
    }
  }

  // --- Events ---
  List<NotchCalendarEvent> loadEvents() {
    final raw = _preferences.getString(_eventsKey);
    if (raw == null || raw.isEmpty) {
      final now = DateTime.now();
      return [
        NotchCalendarEvent(
          id: 'ev-1',
          title: 'Họp nhóm thiết kế',
          timeString: '09:30',
          colorHex: '#F56300',
          date: now,
        ),
        NotchCalendarEvent(
          id: 'ev-2',
          title: 'Review PR OneNotch',
          timeString: '15:00',
          colorHex: '#3E7EFF',
          date: now,
        ),
        NotchCalendarEvent(
          id: 'ev-3',
          title: 'Đồng bộ dữ liệu Clipboard',
          timeString: '17:30',
          colorHex: '#00CA75',
          date: now,
        ),
      ];
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) =>
              NotchCalendarEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> saveEvents(List<NotchCalendarEvent> events) async {
    final raw = jsonEncode(events.map((e) => e.toJson()).toList());
    await _preferences.setString(_eventsKey, raw);
  }

  // --- Quick Notes ---
  List<TouchNote> loadNotes() {
    final raw = _preferences.getString(_notesKey);
    if (raw == null || raw.isEmpty) {
      return [
        TouchNote(
          id: 'note-1',
          text: 'Ghi chú nhanh trên Notch: Liếc lên là thấy, bấm là dán ✨',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          colorHex: '#5F78FF',
          isPinned: true,
        ),
      ];
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => TouchNote.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> saveNotes(List<TouchNote> notes) async {
    final raw = jsonEncode(notes.map((n) => n.toJson()).toList());
    await _preferences.setString(_notesKey, raw);
  }
}
