import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ReminderHealth {
  const ReminderHealth({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
    this.nextFireAt,
    this.nextTitle,
    this.sdk,
  });

  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;
  final bool batteryUnrestricted;
  final DateTime? nextFireAt;
  final String? nextTitle;
  final int? sdk;

  bool get needsFix =>
      !notificationsAllowed || !exactAlarmsAllowed || !batteryUnrestricted;

  factory ReminderHealth.fromMap(Map<dynamic, dynamic> map) {
    final next = map['nextFireAt'];
    DateTime? nextFireAt;
    if (next is num && next > 0) {
      nextFireAt = DateTime.fromMillisecondsSinceEpoch(next.toInt());
    }
    return ReminderHealth(
      notificationsAllowed: map['notificationsAllowed'] == true,
      exactAlarmsAllowed: map['exactAlarmsAllowed'] != false,
      batteryUnrestricted: map['batteryUnrestricted'] != false,
      nextFireAt: nextFireAt,
      nextTitle: map['nextTitle']?.toString(),
      sdk: (map['sdk'] as num?)?.toInt(),
    );
  }

  static const unavailable = ReminderHealth(
    notificationsAllowed: true,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
  );
}

class FiredReminderNotice {
  const FiredReminderNotice({
    required this.type,
    required this.title,
    required this.message,
    required this.fireAtMillis,
  });

  final String type;
  final String title;
  final String message;
  final int fireAtMillis;
}

class NativeReminderScheduler {
  NativeReminderScheduler._();

  static const channel = MethodChannel('com.obecno/attendance_reminders');
  static const testId = 7399;

  static void Function(String? payload)? onNotificationTap;
  static bool _handlerBound = false;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void bindTapHandler() {
    if (_handlerBound || !isAndroid) return;
    _handlerBound = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        onNotificationTap?.call(call.arguments as String?);
      }
    });
  }

  static Map<String, Object?> _alarmMap({
    required int id,
    required String type,
    required String title,
    required String message,
    required DateTime fireAt,
    required String payload,
    bool isTest = false,
  }) {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'fireAt': fireAt.millisecondsSinceEpoch,
      'payload': payload,
      'isTest': isTest,
    };
  }

  static Future<void> replaceAll(List<Map<String, Object?>> alarms) async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('replaceAll', {'alarms': alarms});
  }

  static Future<void> upsert(List<Map<String, Object?>> alarms) async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('upsert', {'alarms': alarms});
  }

  static Future<void> cancelIds(List<int> ids) async {
    if (!isAndroid || ids.isEmpty) return;
    await channel.invokeMethod<void>('cancelIds', {'ids': ids});
  }

  /// Cancels AlarmManager entries without clearing an on-screen banner.
  static Future<void> cancelAlarmsOnly(List<int> ids) async {
    if (!isAndroid || ids.isEmpty) return;
    await channel.invokeMethod<void>('cancelAlarmsOnly', {'ids': ids});
  }

  static Future<void> cancelAll() async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('cancelAll');
  }

  /// Returns false when the OS rejected the banner (permission / OEM block).
  static Future<bool> show({
    required int id,
    required String title,
    required String message,
    String? payload,
  }) async {
    if (!isAndroid) return false;
    final posted = await channel.invokeMethod<bool>('show', {
      'id': id,
      'title': title,
      'message': message,
      'payload': payload,
    });
    return posted == true;
  }

  static Future<DateTime> scheduleTest({
    required String title,
    required String message,
    Duration delay = const Duration(minutes: 1),
  }) async {
    final fireAt = DateTime.now().add(delay);
    if (!isAndroid) return fireAt;
    final millis = await channel.invokeMethod<num>('scheduleTest', {
      'title': title,
      'message': message,
      'fireAt': fireAt.millisecondsSinceEpoch,
    });
    if (millis == null) return fireAt;
    return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  }

  static Future<ReminderHealth> health() async {
    if (!isAndroid) return ReminderHealth.unavailable;
    final raw = await channel.invokeMethod<Map<dynamic, dynamic>>('health');
    if (raw == null) return ReminderHealth.unavailable;
    return ReminderHealth.fromMap(raw);
  }

  static Future<void> ensureUnrestricted() async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('ensureUnrestricted');
  }

  static Future<void> openNotificationSettings() async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('openNotificationSettings');
  }

  static Future<void> openExactAlarmSettings() async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('openExactAlarmSettings');
  }

  static Future<void> openBatterySettings() async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('openBatterySettings');
  }

  static Future<void> openAppDetails() async {
    if (!isAndroid) return;
    await channel.invokeMethod<void>('openAppDetails');
  }

  static Future<List<FiredReminderNotice>> consumeFired() async {
    if (!isAndroid) return const [];
    final raw = await channel.invokeMethod<List<dynamic>>('consumeFired');
    if (raw == null) return const [];
    final notices = <FiredReminderNotice>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final fireAt = item['fireAt'];
      if (fireAt is! num) continue;
      final type = (item['type'] ?? item['payload'])?.toString() ?? '';
      if (type.isEmpty) continue;
      notices.add(
        FiredReminderNotice(
          type: type,
          title: item['title']?.toString() ?? '',
          message: item['message']?.toString() ?? '',
          fireAtMillis: fireAt.toInt(),
        ),
      );
    }
    return notices;
  }

  static Future<String?> consumeLaunchPayload() async {
    if (!isAndroid) return null;
    return channel.invokeMethod<String>('getLaunchPayload');
  }

  static Map<String, Object?> alarmFrom({
    required int id,
    required String type,
    required String title,
    required String message,
    required DateTime fireAt,
    required String payload,
    bool isTest = false,
  }) => _alarmMap(
    id: id,
    type: type,
    title: title,
    message: message,
    fireAt: fireAt,
    payload: payload,
    isTest: isTest,
  );
}
