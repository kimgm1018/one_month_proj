import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();
  static bool _testMode = false;

  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _timezoneInitialised = false;

  static void setTestMode(bool enabled) {
    _testMode = enabled;
  }

  Future<void> initialize() async {
    if (_testMode) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> cancelAll() async {
    if (_testMode) return;
    await _plugin.cancelAll();
  }

  Future<void> cancelTodoReminders(String todoId) async {
    if (_testMode) return;
    await _plugin.cancel(_notificationId(todoId, _ReminderType.start));
    await _plugin.cancel(_notificationId(todoId, _ReminderType.end));
  }

  Future<void> scheduleTodoReminder({
    required String todoId,
    required String title,
    String? memo,
    DateTime? startDateTime,
    DateTime? endDateTime,
    required Duration leadTime,
  }) async {
    if (_testMode) return;
    await cancelTodoReminders(todoId);

    if (startDateTime != null) {
      await _scheduleSingle(
        id: _notificationId(todoId, _ReminderType.start),
        scheduledDate: startDateTime,
        leadTime: leadTime,
        title: title,
        body: '${_formatDateTime(startDateTime)} 시작 예정입니다.',
        memo: memo,
        payload: _buildPayload(todoId, memo),
      );
    }

    if (endDateTime != null) {
      await _scheduleSingle(
        id: _notificationId(todoId, _ReminderType.end),
        scheduledDate: endDateTime,
        leadTime: leadTime,
        title: title,
        body: '${_formatDateTime(endDateTime)} 마감 예정입니다.',
        memo: memo,
        payload: _buildPayload(todoId, memo),
      );
    }
  }

  Future<void> _scheduleSingle({
    required int id,
    required DateTime scheduledDate,
    required Duration leadTime,
    required String title,
    required String body,
    String? memo,
    required String payload,
  }) async {
    if (_testMode) return;
    await _ensureTimezoneInitialised();

    var fireTime = scheduledDate.subtract(leadTime);
    final now = DateTime.now();
    if (fireTime.isBefore(now)) {
      if (scheduledDate.isBefore(now)) {
        return;
      }
      fireTime = now.add(const Duration(seconds: 5));
    }

    final tzScheduled = tz.TZDateTime.from(fireTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'todo_reminders',
      '할 일 알림',
      channelDescription: '할 일 시작/마감 알림',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      styleInformation: memo != null && memo.trim().isNotEmpty
          ? BigTextStyleInformation(
              memo,
              contentTitle: title,
              summaryText: '메모',
            )
          : null,
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static const int _idModulus = 100000000;

  int _notificationId(String todoId, _ReminderType type) {
    final base = todoId.hashCode & 0x7fffffff;
    final compact = base % _idModulus;
    return compact * 10 + type.index;
  }

  String _buildPayload(String todoId, String? memo) {
    final map = <String, dynamic>{
      'id': todoId,
      if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
    };
    return jsonEncode(map);
  }
}

enum _ReminderType { start, end }

String _formatDateTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour시 $minute분';
}

extension on NotificationService {
  Future<void> _ensureTimezoneInitialised() async {
    if (NotificationService._testMode) return;
    if (_timezoneInitialised) return;
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
    _timezoneInitialised = true;
  }
}

