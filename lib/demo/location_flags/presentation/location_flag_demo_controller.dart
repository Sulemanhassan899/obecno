import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:obecno/demo/location_flags/presentation/widgets/location_flag_checks_card.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/auth/providers/permission_provider.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_timeline.dart';
import 'package:obecno/features/clock/location_flags/providers/location_flag_provider.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/main.dart';

class LocationFlagHourCycle {
  const LocationFlagHourCycle({
    required this.hourStart,
    required this.flags,
    required this.isCurrent,
  });

  final DateTime hourStart;
  final List<bool?> flags;
  final bool isCurrent;

  DateTime get hourEnd => hourStart.add(const Duration(hours: 1));
}

class LocationFlagDemoController extends ChangeNotifier {
  LocationFlagDemoController({
    required TickerProvider vsync,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _controller = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 2400),
       ) {
    _controller.addListener(notifyListeners);
  }

  final DateTime Function() _now;
  final AnimationController _controller;
  Timer? _tick;
  bool _filling = false;

  PolicyDayWindow policyWindow = PolicyDayWindow(
    start: DateTime(2026, 9, 21, 9),
    end: DateTime(2026, 9, 21, 18),
  );

  PolicyDayWindow window = PolicyDayWindow(
    start: DateTime(2026, 9, 21, 8),
    end: DateTime(2026, 9, 21, 19),
  );

  List<LocationFlagObservation> observations = const [];

  double get progress => _controller.value;

  DateTime get clockNow => _now();

  /// Progress through the full policy day, clipped to now.
  double get liveProgress {
    final total = window.duration.inMilliseconds;
    if (total <= 0) return 0;
    final elapsed = clockNow.difference(window.start).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  DateTime get playhead {
    final now = clockNow;
    if (now.isBefore(window.start)) return window.start;
    if (now.isAfter(window.end)) return window.end;
    return now;
  }

  List<LocationFlagObservation> get revealed {
    return observations.where((o) => !o.at.isAfter(playhead)).toList();
  }

  LocationCycleVerdict get verdict {
    return LocationFlagEvaluator.evaluate(
      checkInStatus: sessionCheckedIn,
      observations: revealed,
    );
  }

  bool get sessionCheckedIn {
    if (bindings.locationFlagMonitor.isMonitoring) return true;
    return observations.any((o) => o.checkInStatus);
  }

  List<LocationTimelineSegment> get segments {
    return LocationFlagTimeline.segments(
      window: window,
      observations: revealed,
      until: playhead,
      fillMissing: sessionCheckedIn,
    );
  }

  List<LocationOutsideInterval> get outsideIntervals {
    return LocationFlagTimeline.outsideIntervals(observations: revealed);
  }

  DateTime get currentHourStart {
    return LocationFlagEvaluator.cycleStartFor(playhead);
  }

  DateTime get currentHourEnd =>
      currentHourStart.add(const Duration(hours: 1));

  List<bool?> get currentFlags => flagsForHour(currentHourStart);

  List<LocationFlagHourCycle> get hourCycles {
    final current = currentHourStart;
    var cursor = LocationFlagEvaluator.cycleStartFor(window.start);
    if (cursor.isBefore(window.start) && window.start.minute > 0) {
      cursor = cursor.add(const Duration(hours: 1));
    }
    if (cursor.isAfter(current)) return const [];

    final cycles = <LocationFlagHourCycle>[];
    while (!cursor.isAfter(current) && cursor.isBefore(window.end)) {
      cycles.add(
        LocationFlagHourCycle(
          hourStart: cursor,
          flags: flagsForHour(cursor),
          isCurrent: cursor == current,
        ),
      );
      cursor = cursor.add(const Duration(hours: 1));
    }
    return cycles.reversed.toList();
  }

  /// Flat list of every 5-min slot from window start through the current hour.
  List<LocationFlagCheckEntry> get allFlagEntries {
    final now = playhead;
    final slots = <LocationFlagCheckEntry>[];
    var cursor = LocationFlagEvaluator.flagSlotStart(window.start);
    if (cursor.isBefore(window.start)) {
      cursor = cursor.add(LocationFlagEvaluator.flagInterval);
    }
    final lastHour = currentHourStart.add(const Duration(hours: 1));
    while (cursor.isBefore(window.end) && cursor.isBefore(lastHour)) {
      final obs = observations.where((o) {
        final slot = LocationFlagEvaluator.flagSlotStart(o.at);
        return slot.year == cursor.year &&
            slot.month == cursor.month &&
            slot.day == cursor.day &&
            slot.hour == cursor.hour &&
            slot.minute == cursor.minute;
      });
      final match = obs.isEmpty ? null : obs.last;
      slots.add(
        LocationFlagCheckEntry(
          at: cursor,
          flag: match?.inside,
          pending: now.isBefore(cursor),
        ),
      );
      cursor = cursor.add(LocationFlagEvaluator.flagInterval);
    }
    return slots;
  }

  List<bool?> flagsForHour(DateTime hourStart) {
    final inHour = observations
        .where(
          (o) =>
              o.at.year == hourStart.year &&
              o.at.month == hourStart.month &&
              o.at.day == hourStart.day &&
              o.at.hour == hourStart.hour,
        )
        .toList();
    return LocationFlagEvaluator.cycleFlags(inHour);
  }

  int get currentFlagNumber =>
      LocationFlagEvaluator.flagNumberFor(playhead);

  Future<void> load({
    required PermissionProvider permissions,
    required LocationFlagProvider liveFlags,
    ReminderSettingsProvider? reminders,
  }) async {
    await permissions.refresh();
    final serviceCheckIn = await bindings.companyPolicyService.valueFor(
      'attendance',
      'check_in_time',
    );
    final serviceCheckOut = await bindings.companyPolicyService.valueFor(
      'attendance',
      'check_out_time',
    );
    await liveFlags.reloadForDay(clockNow);
    _applyPolicy(
      permissions,
      reminders: reminders,
      serviceCheckIn: serviceCheckIn,
      serviceCheckOut: serviceCheckOut,
    );
    observations = liveFlags.observations;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_nudgeToNow());
    });
    unawaited(_fillToNow());
    notifyListeners();
  }

  void syncLive(LocationFlagProvider liveFlags) {
    observations = liveFlags.observations;
    notifyListeners();
    if (!_filling) {
      unawaited(_nudgeToNow());
    }
  }

  Future<void> _fillToNow() async {
    _filling = true;
    _controller.stop();
    _controller.value = 0;
    try {
      await _controller.animateTo(
        liveProgress,
        duration: const Duration(milliseconds: 2400),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _filling = false;
    }
  }

  Future<void> _nudgeToNow() async {
    if (_filling) return;
    final target = liveProgress;
    if ((_controller.value - target).abs() < 0.002) return;
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
    );
  }

  void _applyPolicy(
    PermissionProvider permissions, {
    ReminderSettingsProvider? reminders,
    String? serviceCheckIn,
    String? serviceCheckOut,
  }) {
    final day = DateTime(clockNow.year, clockNow.month, clockNow.day);
    final checkInRaw =
        _permissionTime(permissions, 'check_in_time') ?? serviceCheckIn;
    final checkOutRaw =
        _permissionTime(permissions, 'check_out_time') ?? serviceCheckOut;
    final reminder = reminders ?? bindings.reminderSettingsProvider;

    var next = LocationFlagEvaluator.policyWindow(
      day: day,
      checkInRaw: checkInRaw,
      checkOutRaw: checkOutRaw,
      fallbackStartHour: reminder.policyCheckInTime.hour,
      fallbackStartMinute: reminder.policyCheckInTime.minute,
      fallbackEndHour: reminder.policyCheckOutTime.hour,
      fallbackEndMinute: reminder.policyCheckOutTime.minute,
    );

    if (next.duration < const Duration(hours: 1)) {
      next = LocationFlagEvaluator.policyWindow(
        day: day,
        checkInRaw: null,
        checkOutRaw: null,
        fallbackStartHour: reminder.policyCheckInTime.hour == 0 &&
                reminder.policyCheckInTime.minute == 0
            ? 9
            : reminder.policyCheckInTime.hour,
        fallbackStartMinute: reminder.policyCheckInTime.minute,
        fallbackEndHour: reminder.policyCheckOutTime.hour == 0
            ? 18
            : reminder.policyCheckOutTime.hour,
        fallbackEndMinute: reminder.policyCheckOutTime.minute,
      );
    }
    if (next.duration < const Duration(hours: 1)) {
      next = LocationFlagEvaluator.policyWindow(day: day);
    }
    policyWindow = next;
    window = next.padded();
  }

  String? _permissionTime(PermissionProvider permissions, String key) {
    final items = permissions.sections['attendance'] ?? const <PermissionItemModel>[];
    for (final item in items) {
      if (item.key != key) continue;
      for (final candidate in [
        item.value,
        item.locationValue,
        item.companyValue,
        item.employeeValue,
        item.inheritedValue,
      ]) {
        if (LocationFlagEvaluator.parsePolicyTime(candidate) != null) {
          return candidate;
        }
      }
    }
    return permissions.valueOf('attendance', key);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
