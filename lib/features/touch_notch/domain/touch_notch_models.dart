enum TouchNotchTab {
  clipboard,
  music,
  timer,
  calendar,
  notes,
}

enum PomodoroMode {
  task,
  reminder,
  breakTime,
  custom,
}

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    required this.durationSeconds,
    this.positionSeconds = 0,
    this.isPlaying = false,
    this.isShuffle = false,
    this.isRepeat = false,
    this.source = 'spotify',
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final int durationSeconds;
  final int positionSeconds;
  final bool isPlaying;
  final bool isShuffle;
  final bool isRepeat;
  final String source;

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    int? durationSeconds,
    int? positionSeconds,
    bool? isPlaying,
    bool? isShuffle,
    bool? isRepeat,
    String? source,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
      source: source ?? this.source,
    );
  }
}

class PomodoroState {
  const PomodoroState({
    this.mode = PomodoroMode.task,
    this.targetSeconds = 25 * 60,
    this.remainingSeconds = 25 * 60,
    this.isRunning = false,
    this.title = 'Tập trung làm việc',
  });

  final PomodoroMode mode;
  final int targetSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final String title;

  PomodoroState copyWith({
    PomodoroMode? mode,
    int? targetSeconds,
    int? remainingSeconds,
    bool? isRunning,
    String? title,
  }) {
    return PomodoroState(
      mode: mode ?? this.mode,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      title: title ?? this.title,
    );
  }

  double get progress => targetSeconds > 0
      ? ((targetSeconds - remainingSeconds) / targetSeconds).clamp(0.0, 1.0)
      : 0.0;
}

class NotchCalendarEvent {
  const NotchCalendarEvent({
    required this.id,
    required this.title,
    required this.timeString,
    this.colorHex = '#F56300',
    this.isDone = false,
    required this.date,
  });

  final String id;
  final String title;
  final String timeString;
  final String colorHex;
  final bool isDone;
  final DateTime date;

  NotchCalendarEvent copyWith({
    String? id,
    String? title,
    String? timeString,
    String? colorHex,
    bool? isDone,
    DateTime? date,
  }) {
    return NotchCalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      timeString: timeString ?? this.timeString,
      colorHex: colorHex ?? this.colorHex,
      isDone: isDone ?? this.isDone,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'timeString': timeString,
    'colorHex': colorHex,
    'isDone': isDone,
    'date': date.toIso8601String(),
  };

  factory NotchCalendarEvent.fromJson(Map<String, dynamic> json) =>
      NotchCalendarEvent(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        timeString: json['timeString'] as String? ?? '09:00',
        colorHex: json['colorHex'] as String? ?? '#F56300',
        isDone: json['isDone'] as bool? ?? false,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
      );
}

class TouchNote {
  const TouchNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.colorHex = '#3E7EFF',
    this.isPinned = false,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String colorHex;
  final bool isPinned;

  TouchNote copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    String? colorHex,
    bool? isPinned,
  }) {
    return TouchNote(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      colorHex: colorHex ?? this.colorHex,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'colorHex': colorHex,
    'isPinned': isPinned,
  };

  factory TouchNote.fromJson(Map<String, dynamic> json) => TouchNote(
    id: json['id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    colorHex: json['colorHex'] as String? ?? '#3E7EFF',
    isPinned: json['isPinned'] as bool? ?? false,
  );
}
