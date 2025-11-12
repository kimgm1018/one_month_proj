import 'package:flutter/material.dart';

extension TimeOfDayX on TimeOfDay {
  int get hourMinuteValue => hour * 60 + minute;

  static TimeOfDay? fromMinutes(Object? value) {
    if (value == null) return null;
    int? minutes;
    if (value is int) {
      minutes = value;
    } else if (value is num) {
      minutes = value.toInt();
    } else {
      minutes = int.tryParse(value.toString());
    }
    if (minutes == null) return null;
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }
}

class TodoItem {
  TodoItem({
    required this.id,
    required this.seriesId,
    required this.date,
    required this.title,
    required this.themeId,
    this.memo,
    this.startTime,
    this.endTime,
    this.notify = true,
    this.isSeriesStart = false,
    this.isSeriesEnd = false,
    this.isDone = false,
    this.sourceSessionId,
    this.sourceTaskId,
  });

  final String id;
  final String seriesId;
  final DateTime date;
  final String title;
  final String themeId;
  final String? memo;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool notify;
  final bool isSeriesStart;
  final bool isSeriesEnd;
  final bool isDone;
  final String? sourceSessionId;
  final String? sourceTaskId;

  bool get hasAnyTime => startTime != null || endTime != null;

  TodoItem copyWith({
    String? title,
    String? memo,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? notify,
    bool? isSeriesStart,
    bool? isSeriesEnd,
    bool? isDone,
    String? themeId,
    String? sourceSessionId,
    String? sourceTaskId,
  }) {
    return TodoItem(
      id: id,
      seriesId: seriesId,
      date: date,
      title: title ?? this.title,
      themeId: themeId ?? this.themeId,
      memo: memo ?? this.memo,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notify: notify ?? this.notify,
      isSeriesStart: isSeriesStart ?? this.isSeriesStart,
      isSeriesEnd: isSeriesEnd ?? this.isSeriesEnd,
      isDone: isDone ?? this.isDone,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceTaskId: sourceTaskId ?? this.sourceTaskId,
    );
  }

  factory TodoItem.fromDb(Map<String, Object?> map) {
    final dateValue = map['date'];
    final date = dateValue is int
        ? DateTime.fromMillisecondsSinceEpoch(dateValue)
        : DateTime.now();
    return TodoItem(
      id: map['id'] as String,
      seriesId: map['series_id'] as String,
      date: DateUtils.dateOnly(date),
      title: map['title'] as String,
      themeId: map['theme_id'] as String? ?? 'default',
      memo: map['memo'] as String?,
      startTime: TimeOfDayX.fromMinutes(map['start_time_minutes']),
      endTime: TimeOfDayX.fromMinutes(map['end_time_minutes']),
      notify: (map['notify'] as int? ?? 0) == 1,
      isSeriesStart: (map['is_series_start'] as int? ?? 0) == 1,
      isSeriesEnd: (map['is_series_end'] as int? ?? 0) == 1,
      isDone: (map['is_done'] as int? ?? 0) == 1,
      sourceSessionId: map['source_session_id'] as String?,
      sourceTaskId: map['source_task_id'] as String?,
    );
  }

  Map<String, Object?> toDb({int? createdAt, int? updatedAt}) {
    final data = <String, Object?>{
      'id': id,
      'series_id': seriesId,
      'date': DateUtils.dateOnly(date).millisecondsSinceEpoch,
      'title': title,
      'memo': memo,
      'theme_id': themeId,
      'start_time_minutes': startTime?.hourMinuteValue,
      'end_time_minutes': endTime?.hourMinuteValue,
      'notify': notify ? 1 : 0,
      'is_series_start': isSeriesStart ? 1 : 0,
      'is_series_end': isSeriesEnd ? 1 : 0,
      'is_done': isDone ? 1 : 0,
      'source_session_id': sourceSessionId,
      'source_task_id': sourceTaskId,
    };
    if (createdAt != null) {
      data['created_at'] = createdAt;
    }
    if (updatedAt != null) {
      data['updated_at'] = updatedAt;
    }
    return data;
  }
}
