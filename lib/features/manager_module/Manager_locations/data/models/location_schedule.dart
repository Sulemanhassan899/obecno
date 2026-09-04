import 'package:flutter/material.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';

class LocationSchedule {
  const LocationSchedule({
    this.checkIn = const TimeOfDay(hour: 8, minute: 0),
    this.checkOut = const TimeOfDay(hour: 17, minute: 0),
    this.graceMinutes = 5,
    this.workingDays = const {
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    },
    this.weekStartDay = 'Monday',
    this.hoursPerDay = '08:00',
    this.hoursPerWeek = '40:00',
    this.workingWeekEnabled = true,
    this.maxBreakMinutes = 60,
    this.breakLocationTracking = true,
  });

  static const defaults = LocationSchedule();

  static const dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final TimeOfDay checkIn;
  final TimeOfDay checkOut;
  final int graceMinutes;
  final Set<String> workingDays;
  final String weekStartDay;
  final String hoursPerDay;
  final String hoursPerWeek;
  final bool workingWeekEnabled;
  final int maxBreakMinutes;
  final bool breakLocationTracking;

  String get breakLabel =>
      '${maxBreakMinutes.toString().padLeft(2, '0')}:00 mins';

  factory LocationSchedule.fromJson(
    Map<String, dynamic> json, {
    LocationSchedule? fallback,
  }) {
    final source = _flatten(json);
    final base = fallback ?? defaults;
    return LocationSchedule(
      checkIn:
          _asTime(
            _pick(source, const [
              'check_in',
              'check_in_time',
              'start_time',
              'office_start',
            ]),
          ) ??
          base.checkIn,
      checkOut:
          _asTime(
            _pick(source, const [
              'check_out',
              'check_out_time',
              'end_time',
              'office_end',
            ]),
          ) ??
          base.checkOut,
      graceMinutes:
          _asInt(
            _pick(source, const [
              'grace_minutes',
              'grace_period',
              'grace',
            ]),
          ) ??
          base.graceMinutes,
      workingDays: _asDays(source['working_days']) ?? base.workingDays,
      weekStartDay: _asDayName(
        _pick(source, const ['week_start_day', 'workweek_start_day']),
        fallback: base.weekStartDay,
      ),
      hoursPerDay: _asHours(
        _pick(source, const ['hours_per_day', 'hours_in_a_day', 'hours_in_day']),
        fallback: base.hoursPerDay,
      ),
      hoursPerWeek: _asHours(
        _pick(source, const [
          'hours_per_week',
          'hours_in_a_week',
          'hours_in_week',
        ]),
        fallback: base.hoursPerWeek,
      ),
      workingWeekEnabled:
          _asBoolOrNull(
            _pick(source, const [
              'working_week_enabled',
              'working_days_enabled',
            ]),
          ) ??
          base.workingWeekEnabled,
      maxBreakMinutes:
          _asInt(
            _pick(source, const [
              'max_break_minutes',
              'break_time',
              'max_break',
              'max_break_duration',
              'break_duration',
            ]),
          ) ??
          base.maxBreakMinutes,
      breakLocationTracking:
          _asBoolOrNull(
            _pick(source, const [
              'break_location_tracking',
              'track_location',
              'break_location_required',
            ]),
          ) ??
          base.breakLocationTracking,
    );
  }

  static LocationSchedule? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final flat = _flatten(map);
    if (!_hasScheduleKeys(flat) &&
        map['schedule'] is! Map &&
        map['attendance'] is! Map &&
        map['break_timing'] is! Map &&
        map['working_week'] is! Map) {
      return null;
    }
    return LocationSchedule.fromJson(map);
  }

  /// Merges an employee profile `schedule` with permission overrides.
  /// Employee-level permission values win; schedule fills everything else.
  factory LocationSchedule.fromEmployeeSources({
    Map<String, dynamic>? schedule,
    List<PermissionItemModel>? permissionItems,
  }) {
    final fromPerms = (permissionItems == null || permissionItems.isEmpty)
        ? null
        : LocationSchedule.fromPermissionItems(
            permissionItems,
            preferEmployeeValue: true,
          );
    final fromSchedule = (schedule != null && schedule.isNotEmpty)
        ? LocationSchedule.fromJson(schedule, fallback: fromPerms)
        : fromPerms;
    final base = fromSchedule ?? defaults;
    if (permissionItems == null || permissionItems.isEmpty) return base;
    if (!PermissionItemModel.hasEmployeeLevelPermissions(permissionItems)) {
      return base;
    }

    TimeOfDay? checkIn;
    TimeOfDay? checkOut;
    int? graceMinutes;
    Set<String>? workingDays;
    String? weekStartDay;
    String? hoursPerDay;
    String? hoursPerWeek;
    bool? workingWeekEnabled;
    int? maxBreakMinutes;
    bool? breakLocationTracking;

    for (final item in permissionItems) {
      if (!item.hasEmployeeLevel) continue;
      final raw = item.employeeValue ?? item.value;
      switch (item.key) {
        case 'check_in':
        case 'check_in_time':
          checkIn = _asTime(raw) ?? checkIn;
          break;
        case 'check_out':
        case 'check_out_time':
          checkOut = _asTime(raw) ?? checkOut;
          break;
        case 'grace_minutes':
        case 'grace_period':
          graceMinutes = _asInt(raw) ?? graceMinutes;
          break;
        case 'working_days':
          workingDays = _asDays(raw) ?? workingDays;
          break;
        case 'week_start_day':
          weekStartDay = raw == null
              ? weekStartDay
              : _asDayName(raw, fallback: weekStartDay ?? base.weekStartDay);
          break;
        case 'hours_per_day':
        case 'hours_in_a_day':
        case 'hours_in_day':
          hoursPerDay = raw == null
              ? hoursPerDay
              : _asHours(raw, fallback: hoursPerDay ?? base.hoursPerDay);
          break;
        case 'hours_per_week':
        case 'hours_in_a_week':
        case 'hours_in_week':
          hoursPerWeek = raw == null
              ? hoursPerWeek
              : _asHours(raw, fallback: hoursPerWeek ?? base.hoursPerWeek);
          break;
        case 'working_week_enabled':
          workingWeekEnabled = _asBoolOrNull(raw) ?? workingWeekEnabled;
          break;
        case 'max_break_minutes':
        case 'break_time':
        case 'max_break':
          maxBreakMinutes = _asInt(raw) ?? maxBreakMinutes;
          break;
        case 'break_location_tracking':
        case 'track_location':
          breakLocationTracking = _asBoolOrNull(raw) ?? breakLocationTracking;
          break;
      }
    }

    return base.copyWith(
      checkIn: checkIn,
      checkOut: checkOut,
      graceMinutes: graceMinutes,
      workingDays: workingDays,
      weekStartDay: weekStartDay,
      hoursPerDay: hoursPerDay,
      hoursPerWeek: hoursPerWeek,
      workingWeekEnabled: workingWeekEnabled,
      maxBreakMinutes: maxBreakMinutes,
      breakLocationTracking: breakLocationTracking,
    );
  }

  factory LocationSchedule.fromPermissionItems(
    List<PermissionItemModel> items, {
    bool preferEmployeeValue = false,
    bool locationOnly = false,
    LocationSchedule? fallback,
  }) {
    String? value(String section, String key) {
      for (final item in items) {
        if (item.section == section && item.key == key) {
          final resolved = _permissionValue(
            item,
            preferEmployeeValue: preferEmployeeValue,
            locationOnly: locationOnly,
          );
          if (resolved != null) return resolved;
        }
      }
      for (final item in items) {
        if (item.key == key) {
          final resolved = _permissionValue(
            item,
            preferEmployeeValue: preferEmployeeValue,
            locationOnly: locationOnly,
          );
          if (resolved != null) return resolved;
        }
      }
      return null;
    }

    String? first(String section, List<String> keys) {
      for (final key in keys) {
        final found = value(section, key);
        if (found != null) return found;
      }
      return null;
    }

    return LocationSchedule.fromJson({
      'check_in_time': first('attendance', const [
        'check_in_time',
        'check_in',
        'start_time',
      ]),
      'check_out_time': first('attendance', const [
        'check_out_time',
        'check_out',
        'end_time',
      ]),
      'grace_period': first('attendance', const [
        'grace_period',
        'grace_minutes',
        'grace',
      ]),
      'working_days':
          first('attendance', const ['working_days']) ??
          first('working_days', const ['working_days']),
      'week_start_day':
          first('attendance', const ['week_start_day', 'workweek_start_day']) ??
          first('working_days', const ['week_start_day', 'workweek_start_day']),
      'hours_per_day':
          first('attendance', const [
            'hours_per_day',
            'hours_in_a_day',
            'hours_in_day',
          ]) ??
          first('working_days', const [
            'hours_per_day',
            'hours_in_a_day',
            'hours_in_day',
          ]),
      'hours_per_week':
          first('attendance', const [
            'hours_per_week',
            'hours_in_a_week',
            'hours_in_week',
          ]) ??
          first('working_days', const [
            'hours_per_week',
            'hours_in_a_week',
            'hours_in_week',
          ]),
      'working_week_enabled':
          first('attendance', const [
            'working_week_enabled',
            'working_days_enabled',
          ]) ??
          first('working_days', const [
            'working_week_enabled',
            'working_days_enabled',
          ]),
      'break_time':
          first('attendance', const [
            'break_time',
            'max_break_minutes',
            'max_break',
            'max_break_duration',
          ]) ??
          first('break_timing', const [
            'break_time',
            'max_break_minutes',
            'max_break',
            'max_break_duration',
          ]),
      'break_location_tracking':
          first('attendance', const [
            'break_location_tracking',
            'track_location',
          ]) ??
          first('break_timing', const [
            'break_location_tracking',
            'track_location',
          ]),
    }, fallback: fallback);
  }

  Map<String, dynamic> toDebugMap() {
    final days = workingDays.map((day) => day.trim()).toList()..sort();
    return {
      'check_in': _hhmm(checkIn),
      'check_out': _hhmm(checkOut),
      'grace_minutes': graceMinutes,
      'working_days': days,
      'week_start_day': weekStartDay,
      'hours_per_day': hoursPerDay,
      'hours_per_week': hoursPerWeek,
      'working_week_enabled': workingWeekEnabled,
      'max_break_minutes': maxBreakMinutes,
      'break_location_tracking': breakLocationTracking,
    };
  }

  bool sameAs(LocationSchedule other) => samePolicyAs(other);

  Map<String, dynamic> toJson() {
    return {
      'check_in': _hms(checkIn),
      'check_out': _hms(checkOut),
      'grace_minutes': graceMinutes,
      'working_days': workingDays
          .map((day) => day.trim().toLowerCase())
          .where((day) => day.isNotEmpty)
          .toList(),
      'week_start_day': weekStartDay.trim().toLowerCase(),
      'hours_per_day': hoursPerDay,
      'hours_per_week': hoursPerWeek,
      'working_week_enabled': workingWeekEnabled,
      'max_break_minutes': maxBreakMinutes,
      'break_location_tracking': breakLocationTracking,
    };
  }

  /// Payload matching both the schedule spec and the web location-policy fields.
  Map<String, dynamic> writePayload() {
    final body = toJson();
    final checkInLabel = _hhmm(checkIn);
    final checkOutLabel = _hhmm(checkOut);
    final checkInAmPm = _ampm(checkIn);
    final checkOutAmPm = _ampm(checkOut);
    final days = (body['working_days'] as List).join(', ');
    final tracking = breakLocationTracking ? '1' : '0';
    final attendance = {
      'check_in': body['check_in'],
      'check_out': body['check_out'],
      'check_in_time': checkInLabel,
      'check_out_time': checkOutLabel,
      'grace_minutes': graceMinutes,
      'grace_period': graceMinutes,
    };
    final working = {
      'working_days': body['working_days'],
      'week_start_day': body['week_start_day'],
      'hours_per_day': hoursPerDay,
      'hours_per_week': hoursPerWeek,
      'working_week_enabled': workingWeekEnabled,
    };
    final breaks = {
      'max_break_minutes': maxBreakMinutes,
      'break_time': breakLabel,
      'break_location_tracking': breakLocationTracking,
    };
    final permissionItems = [
      _permissionItem('attendance', 'check_in_time', checkInAmPm),
      _permissionItem('attendance', 'check_out_time', checkOutAmPm),
      _permissionItem('attendance', 'grace_period', '$graceMinutes'),
      _permissionItem('attendance', 'working_days', days),
      _permissionItem('working_days', 'working_days', days),
      _permissionItem('attendance', 'week_start_day', weekStartDay),
      _permissionItem('working_days', 'week_start_day', weekStartDay),
      _permissionItem('attendance', 'hours_per_day', hoursPerDay),
      _permissionItem('working_days', 'hours_per_day', hoursPerDay),
      _permissionItem('attendance', 'hours_per_week', hoursPerWeek),
      _permissionItem('working_days', 'hours_per_week', hoursPerWeek),
      _permissionItem(
        'attendance',
        'working_week_enabled',
        workingWeekEnabled ? '1' : '0',
      ),
      _permissionItem(
        'working_days',
        'working_week_enabled',
        workingWeekEnabled ? '1' : '0',
      ),
      _permissionItem('attendance', 'break_time', breakLabel),
      _permissionItem('break_timing', 'break_time', breakLabel),
      _permissionItem('attendance', 'break_location_tracking', tracking),
      _permissionItem('break_timing', 'break_location_tracking', tracking),
    ];
    return {
      ...body,
      'check_in_time': checkInLabel,
      'check_out_time': checkOutLabel,
      'grace_period': graceMinutes,
      'schedule': body,
      'attendance': attendance,
      'working_week': working,
      'working_days_settings': working,
      'break_timing': breaks,
      'permissions': {
        'attendance': attendance,
        'working_days': working,
        'break_timing': breaks,
      },
      'permission_items': permissionItems,
    };
  }

  /// Body for PUT (first write) and PATCH (edit) on
  /// `/manager/locations/{id}/permissions`.
  Map<String, dynamic> permissionsApiPayload({required String locationId}) {
    final written = writePayload();
    final checkInLabel = _hhmm(checkIn);
    final checkOutLabel = _hhmm(checkOut);
    final locationIdValue = int.tryParse(locationId) ?? locationId;
    final locationSetting = {
      'check_in_time': checkInLabel,
      'check_out_time': checkOutLabel,
      'grace_period': '$graceMinutes-min',
      'break_time': breakLabel,
      'break_location_tracking': breakLocationTracking,
      'working_days': written['working_days'],
      'week_start_day': written['week_start_day'],
      'hours_per_day': hoursPerDay,
      'hours_per_week': hoursPerWeek,
    };
    return {
      'location_id': locationIdValue,
      'section': 'attendance',
      'permission_section': 'attendance',
      'import_company_settings': false,
      'field': 'check_in_time',
      'value': checkInLabel,
      'location_setting': locationSetting,
      'settings': written['permissions'],
      'permissions': written['permissions'],
      ...written,
    };
  }

  bool samePolicyAs(LocationSchedule other) {
    return checkIn.hour == other.checkIn.hour &&
        checkIn.minute == other.checkIn.minute &&
        checkOut.hour == other.checkOut.hour &&
        checkOut.minute == other.checkOut.minute &&
        graceMinutes == other.graceMinutes &&
        maxBreakMinutes == other.maxBreakMinutes &&
        breakLocationTracking == other.breakLocationTracking &&
        workingWeekEnabled == other.workingWeekEnabled &&
        weekStartDay.trim().toLowerCase() ==
            other.weekStartDay.trim().toLowerCase() &&
        hoursPerDay.trim() == other.hoursPerDay.trim() &&
        hoursPerWeek.trim() == other.hoursPerWeek.trim() &&
        _sameDaySet(workingDays, other.workingDays);
  }

  static bool _sameDaySet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    final other = {for (final day in b) day.trim().toLowerCase()};
    for (final day in a) {
      if (!other.contains(day.trim().toLowerCase())) return false;
    }
    return true;
  }

  LocationSchedule copyWith({
    TimeOfDay? checkIn,
    TimeOfDay? checkOut,
    int? graceMinutes,
    Set<String>? workingDays,
    String? weekStartDay,
    String? hoursPerDay,
    String? hoursPerWeek,
    bool? workingWeekEnabled,
    int? maxBreakMinutes,
    bool? breakLocationTracking,
  }) {
    return LocationSchedule(
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      workingDays: workingDays ?? this.workingDays,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      workingWeekEnabled: workingWeekEnabled ?? this.workingWeekEnabled,
      maxBreakMinutes: maxBreakMinutes ?? this.maxBreakMinutes,
      breakLocationTracking:
          breakLocationTracking ?? this.breakLocationTracking,
    );
  }
}

Map<String, dynamic> _flatten(Map<String, dynamic> json) {
  final out = <String, dynamic>{};

  void absorb(dynamic raw) {
    if (raw is! Map) return;
    Map<String, dynamic>.from(raw).forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (out[key] != null) return;
      out[key] = value;
    });
  }

  absorb(json);
  for (final key in const [
    'schedule',
    'attendance',
    'attendance_settings',
    'working_week',
    'working_days_settings',
    'break_timing',
    'break_settings',
    'policies',
    'settings',
    'permissions',
    'location_setting',
  ]) {
    absorb(json[key]);
  }
  final permissions = json['permissions'];
  if (permissions is Map) {
    absorb(permissions['attendance']);
    absorb(permissions['working_days']);
    absorb(permissions['break_timing']);
  }
  final policies = json['policies'];
  if (policies is Map) {
    absorb(policies['attendance']);
    absorb(policies['working_days']);
    absorb(policies['break_timing']);
    absorb(policies['schedule']);
  }
  final settings = json['settings'];
  if (settings is Map) {
    absorb(settings['attendance']);
    absorb(settings['schedule']);
  }
  return out;
}

bool _hasScheduleKeys(Map<String, dynamic> source) {
  const keys = [
    'check_in',
    'check_in_time',
    'check_out',
    'check_out_time',
    'grace_minutes',
    'grace_period',
    'working_days',
    'week_start_day',
    'hours_per_day',
    'hours_per_week',
    'working_week_enabled',
    'max_break_minutes',
    'break_time',
    'max_break',
    'break_location_tracking',
  ];
  return keys.any(source.containsKey);
}

String? _permissionValue(
  PermissionItemModel item, {
  required bool preferEmployeeValue,
  required bool locationOnly,
}) {
  if (preferEmployeeValue) {
    final override = item.employeeValue?.trim();
    if (override != null && override.isNotEmpty) return override;
  }
  final location = item.locationValue?.trim();
  if (location != null && location.isNotEmpty) return location;
  final source = (item.sourceLevel ?? item.source)?.trim().toLowerCase();
  final isLocation = source == 'location' || source == 'office';
  if (locationOnly && !isLocation) return null;
  final current = item.value?.trim();
  if (current != null && current.isNotEmpty) return current;
  if (locationOnly) return null;
  final inherited = item.inheritedValue?.trim();
  if (inherited != null && inherited.isNotEmpty) return inherited;
  final company = item.companyValue?.trim();
  if (company != null && company.isNotEmpty) return company;
  return null;
}

dynamic _pick(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (!source.containsKey(key)) continue;
    final value = source[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

String _hms(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
}

String _hhmm(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _ampm(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final min = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${hour.toString().padLeft(2, '0')}:$min $period';
}

Map<String, dynamic> _permissionItem(String section, String key, String value) {
  return {
    'section': section,
    'key': key,
    'value': value,
    'location_value': value,
    'source_level': 'location',
  };
}

TimeOfDay? _asTime(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  if (value.isEmpty || value == '—' || value == '-') return null;
  final ampm = RegExp(
    r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (ampm != null) {
    var hour = int.parse(ampm.group(1)!);
    final minute = int.parse(ampm.group(2)!);
    final period = ampm.group(4)!.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

int? _asInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  final value = raw.toString().trim().toLowerCase();
  if (value.isEmpty) return null;
  final leading = RegExp(r'^(\d+)').firstMatch(value);
  if (leading != null) return int.tryParse(leading.group(1)!);
  return int.tryParse(value);
}

bool? _asBoolOrNull(dynamic raw) {
  if (raw == true ||
      raw == 1 ||
      raw == '1' ||
      raw == 'true' ||
      raw == 'on' ||
      raw == 'active' ||
      raw == 'yes') {
    return true;
  }
  if (raw == false ||
      raw == 0 ||
      raw == '0' ||
      raw == 'false' ||
      raw == 'off' ||
      raw == 'inactive' ||
      raw == 'no') {
    return false;
  }
  return null;
}

Set<String>? _asDays(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final days = <String>{};
    raw.forEach((key, value) {
      final enabled = _asBoolOrNull(value);
      if (enabled == false) return;
      final name = _asDayName(key, fallback: '');
      if (name.isNotEmpty && enabled != false) days.add(name);
    });
    return days.isEmpty ? null : days;
  }
  Iterable<dynamic> items;
  if (raw is List) {
    items = raw;
  } else if (raw is String) {
    items = raw.split(RegExp(r'[,|]'));
  } else {
    return null;
  }
  final days = <String>{};
  for (final item in items) {
    final name = _asDayName(item, fallback: '');
    if (name.isNotEmpty) days.add(name);
  }
  return days.isEmpty ? null : days;
}

String _asDayName(dynamic raw, {required String fallback}) {
  if (raw == null) return fallback;
  if (raw is num) {
    final index = raw.toInt();
    if (index >= 1 && index <= 7) return LocationSchedule.dayNames[index - 1];
    if (index >= 0 && index <= 6) return LocationSchedule.dayNames[index];
    return fallback;
  }
  final value = raw.toString().trim().toLowerCase();
  if (value.isEmpty) return fallback;
  for (final day in LocationSchedule.dayNames) {
    if (day.toLowerCase() == value ||
        day.toLowerCase().startsWith(value) ||
        value.startsWith(day.toLowerCase())) {
      return day;
    }
  }
  return fallback;
}

String _asHours(dynamic raw, {required String fallback}) {
  if (raw == null) return fallback;
  if (raw is num) {
    final hours = raw.toInt();
    final minutes = ((raw - hours) * 60).round();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
  final value = raw.toString().trim();
  if (value.isEmpty) return fallback;
  final parts = value.split(':');
  if (parts.length >= 2) {
    final hour = int.tryParse(parts[0].trim()) ?? 0;
    final minute = int.tryParse(parts[1].trim()) ?? 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
  final minutes = _asInt(value);
  if (minutes == null) return fallback;
  return '${minutes.toString().padLeft(2, '0')}:00';
}
