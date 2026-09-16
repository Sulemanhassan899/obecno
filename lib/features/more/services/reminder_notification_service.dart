import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/core/services/notification_helper.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';

class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  static const _channelId = 'attendance_reminders';
  static const _channelName = 'Attendance Reminders';
  static const _channelDescription =
      'Check-in, check-out, break, and attendance reminders.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      await _setLocalTimezone();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_obecno'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationTap?.call(response.payload);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
            ),
          );
      _initialized = true;
      unawaited(_dispatchLaunchPayload());
    } catch (e, st) {
      AppLogger.error('ReminderNotificationService', 'init', e, stackTrace: st);
    }
  }

  Future<void> _dispatchLaunchPayload() async {
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp != true || payload == null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      onNotificationTap?.call(payload);
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'launchPayload',
        e,
        stackTrace: st,
      );
    }
  }

  Future<bool> showCustom({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await init();
    if (!_initialized) return false;
    await _ensurePermission();
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details,
        payload: payload,
      );
      return true;
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'showCustom',
        e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      for (final id in ReminderNotificationPlan.allIds()) {
        await _plugin.cancel(id: id);
      }
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'cancelAll',
        e,
        stackTrace: st,
      );
    }
  }

  Future<ReminderNotificationSyncResult> sync({
    required DateTime now,
    required Map<ReminderType, bool> enabled,
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
    TimeOfDay? policyCheckInTime,
    TimeOfDay? policyCheckOutTime,
    TimeOfDay? breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    TimeOfDay? checkInMissedTime,
    TimeOfDay? checkOutMissedTime,
    required int graceMinutes,
    int? checkInMissedMinutes,
    int? checkOutMissedMinutes,
    int? longerBreakMinutes,
    required int breakMinutes,
    required int longAttendanceHours,
    required List<ReminderPunch> punches,
    Set<int> workingWeekdays = ReminderNotificationPlan.defaultWorkingWeekdays,
    Set<ReminderType> alreadyFired = const {},
    String locationName = 'work',
    bool requestPermission = true,
    bool rebuildSchedule = true,
  }) async {
    await init();
    if (!_initialized) {
      return const ReminderNotificationSyncResult(planned: [], seenTypes: {});
    }
    if (requestPermission) {
      await _ensurePermission();
    }

    final activeIds = await _activeNotificationIds();
    final activeTypes = {
      for (final id in activeIds)
        if (ReminderNotificationPlan.typeForId(id) != null)
          ReminderNotificationPlan.typeForId(id)!,
    };
    final seen = {...alreadyFired, ...activeTypes};

    final planned = ReminderNotificationPlan.build(
      now: now,
      enabled: enabled,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyCheckInTime,
      policyCheckOutTime: policyCheckOutTime,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      checkInMissedTime: checkInMissedTime,
      checkOutMissedTime: checkOutMissedTime,
      graceMinutes: graceMinutes,
      checkInMissedMinutes: checkInMissedMinutes,
      checkOutMissedMinutes: checkOutMissedMinutes,
      longerBreakMinutes: longerBreakMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceHours,
      punches: punches,
      workingWeekdays: workingWeekdays,
      alreadyFired: seen,
      locationName: locationName,
    );

    if (rebuildSchedule) {
      await _cancelPending();
    } else {
      await _cancelUnplannedBreakReminders(planned);
    }
    for (final item in planned) {
      if (item.deliverImmediately) {
        if (!ReminderNotificationPlan.shouldShowNow(
          type: item.type,
          id: item.id,
          alreadyFired: seen,
          activeIds: activeIds,
        )) {
          continue;
        }
        final shown = await showNow(
          type: item.type,
          id: item.id,
          locationName: locationName,
          title: item.title,
          body: item.body,
        );
        if (shown) seen.add(item.type);
      } else {
        await _schedule(item);
      }
    }
    return ReminderNotificationSyncResult(planned: planned, seenTypes: seen);
  }

  Future<bool> showNow({
    required ReminderType type,
    int? id,
    String locationName = 'work',
    String? title,
    String? body,
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
  }) async {
    await init();
    if (!_initialized) return false;
    await _ensurePermission();
    try {
      await _plugin.show(
        id: id ?? ReminderNotificationPlan.idFor(type),
        title: title ?? ReminderCopy.title(type, locationName: locationName),
        body:
            body ??
            ReminderCopy.message(
              type,
              checkInTime: checkInTime,
              checkOutTime: checkOutTime,
            ),
        notificationDetails: _details,
        payload: type.storageKey,
      );
      return true;
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'showNow',
        e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _schedule(ScheduledReminderNotification item) async {
    var scheduledDate = localScheduleTime(item.fireAt);
    final nowTz = tz.TZDateTime.now(tz.local);
    if (!scheduledDate.isAfter(nowTz)) {
      final deviceNow = DateTime.now();
      if (item.fireAt.isAfter(deviceNow.add(const Duration(seconds: 2)))) {
        scheduledDate = localScheduleTime(item.fireAt);
      }
      if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        if (!item.fireAt.isAfter(deviceNow)) {
          await showNow(
            type: item.type,
            id: item.id,
            title: item.title,
            body: item.body,
          );
        }
        return;
      }
    }

    Future<void> scheduleWith(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: scheduledDate,
        notificationDetails: _details,
        androidScheduleMode: mode,
        payload: item.type.storageKey,
      );
    }

    try {
      await scheduleWith(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'scheduleExact:${item.type.storageKey}',
        e,
        stackTrace: st,
      );
      try {
        await scheduleWith(AndroidScheduleMode.alarmClock);
      } catch (eAlarm, stAlarm) {
        AppLogger.error(
          'ReminderNotificationService',
          'scheduleAlarm:${item.type.storageKey}',
          eAlarm,
          stackTrace: stAlarm,
        );
        try {
          await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
        } catch (e2, st2) {
          AppLogger.error(
            'ReminderNotificationService',
            'scheduleInexact:${item.type.storageKey}',
            e2,
            stackTrace: st2,
          );
        }
      }
    }
  }

  Future<void> _cancelPending() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        await _plugin.cancel(id: request.id);
      }
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'cancelPending',
        e,
        stackTrace: st,
      );
      final keep = ReminderNotificationPlan.persistentIds(
        alreadyFired: {},
        activeIds: await _activeNotificationIds(),
      );
      try {
        for (final id in ReminderNotificationPlan.allIds()) {
          if (keep.contains(id)) continue;
          await _plugin.cancel(id: id);
        }
      } catch (e2, st2) {
        AppLogger.error(
          'ReminderNotificationService',
          'cancelPendingFallback',
          e2,
          stackTrace: st2,
        );
      }
    }
  }

  /// Watch ticks skip a full rebuild, so a leftover break-end alarm can fire
  /// after they already punched back in. Do not dismiss a banner that is
  /// already on screen — check-out reminders stay until swipe, and break-end
  /// should too.
  Future<void> _cancelUnplannedBreakReminders(
    List<ScheduledReminderNotification> planned,
  ) async {
    final plannedTypes = {for (final item in planned) item.type};
    final activeIds = await _activeNotificationIds();
    for (final type in const [
      ReminderType.breakTime,
      ReminderType.breakTimeEnded,
      ReminderType.longerBreak,
    ]) {
      if (plannedTypes.contains(type)) continue;
      final id = ReminderNotificationPlan.idFor(type);
      if ((type == ReminderType.breakTimeEnded ||
              type == ReminderType.breakTime) &&
          activeIds.contains(id)) {
        continue;
      }
      try {
        await _plugin.cancel(id: id);
        await _plugin.cancel(
          id: ReminderNotificationPlan.idFor(type, dayOffset: 1),
        );
      } catch (e, st) {
        AppLogger.error(
          'ReminderNotificationService',
          'cancelStale:${type.storageKey}',
          e,
          stackTrace: st,
        );
      }
    }
  }

  Future<Set<int>> _activeNotificationIds() async {
    try {
      final active = await _plugin.getActiveNotifications();
      return {
        for (final notification in active)
          if (notification.id != null) notification.id!,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _ensurePermission() async {
    await NotificationService.request();
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'ensurePermission',
        e,
        stackTrace: st,
      );
    }
  }

  Future<void> _setLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'timezone',
        e,
        stackTrace: st,
      );
    }
    _setTimezoneFromDeviceOffset();
  }

  void _setTimezoneFromDeviceOffset() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        final now = tz.TZDateTime.now(location);
        if (now.timeZoneOffset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'ReminderNotificationService',
        'timezoneFallback',
        e,
        stackTrace: st,
      );
    }
  }

  /// Same clock time the user picked (8:00 stays 8:00 in the phone timezone).
  static tz.TZDateTime localScheduleTime(
    DateTime fireAt, {
    tz.Location? location,
  }) {
    final loc = location ?? tz.local;
    final local = fireAt.isUtc ? fireAt.toLocal() : fireAt;
    var scheduled = tz.TZDateTime(
      loc,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    // When tz.local didn't initialize (some OEM clocks stay on UTC), keep the
    // phone's wall-clock time so 8:00 still fires at 8:00.
    if (location == null) {
      final skew = DateTime.now().timeZoneOffset - scheduled.timeZoneOffset;
      if (skew != Duration.zero) {
        scheduled = scheduled.subtract(skew);
      }
    }
    return scheduled;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      icon: 'ic_stat_obecno',
      importance: Importance.max,
      priority: Priority.max,
      color: kPrimaryColor,
      playSound: true,
      enableVibration: true,
      autoCancel: false,
      ongoing: false,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );
}
