import 'package:obecno/core/api/constants.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';

class ManagerCompanyModel {
  const ManagerCompanyModel({
    required this.id,
    required this.name,
    this.slug,
    this.website,
    this.description,
    this.teamSize,
    this.founded,
    this.expertise,
    this.cityName,
    this.countryName,
    this.locationLabel,
    this.photoUrl,
    this.status,
    this.statusLabel,
  });

  final String id;
  final String name;
  final String? slug;
  final String? website;
  final String? description;
  final String? teamSize;
  final String? founded;
  final String? expertise;
  final String? cityName;
  final String? countryName;
  final String? locationLabel;
  final String? photoUrl;
  final String? status;
  final String? statusLabel;

  factory ManagerCompanyModel.fromJson(Map<String, dynamic> json) {
    return ManagerCompanyModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      slug: _asNullableString(json['slug']),
      website: _asNullableString(json['website']),
      description: _asNullableString(json['description']),
      teamSize: _asNullableString(json['team_size']),
      founded: _asNullableString(json['founded']),
      expertise: _asNullableString(json['expertise']),
      cityName: _asNullableString(json['city_name']),
      countryName: _asNullableString(json['country_name']),
      locationLabel: _asNullableString(json['location_label']),
      photoUrl: _absoluteUrl(_asNullableString(json['photo_url'])),
      status: _asNullableString(json['status']),
      statusLabel: _asNullableString(json['status_label']),
    );
  }
}

class ManagerTeamAttendanceItem {
  const ManagerTeamAttendanceItem({
    this.attendanceId,
    this.userId,
    this.employeeName,
    this.departmentId,
    this.departmentTitle,
    this.locationId,
    this.locationName,
    this.photoUrl,
    this.date,
    this.checkin,
    this.checkout,
    this.breakout,
    this.breakin,
    this.isOpen = false,
    this.currentLocation,
    this.lat,
    this.lon,
    this.status,
    this.statusLabel,
    this.isLate = false,
    this.isEarlyCheckout = false,
    this.isShortHours = false,
    this.isBreakExceeded = false,
    this.isOnBreak = false,
    this.isOnTime = false,
    this.hoursVsExpected,
    this.isEdited = false,
    this.isOutsideLocation = false,
  });

  final int? attendanceId;
  final int? userId;
  final String? employeeName;
  final int? departmentId;
  final String? departmentTitle;
  final String? locationId;
  final String? locationName;
  final String? photoUrl;
  final DateTime? date;
  final String? checkin;
  final String? checkout;
  final String? breakout;
  final String? breakin;
  final bool isOpen;
  final String? currentLocation;
  final double? lat;
  final double? lon;
  final String? status;
  final String? statusLabel;
  final bool isLate;
  final bool isEarlyCheckout;
  final bool isShortHours;
  final bool isBreakExceeded;
  final bool isOnBreak;
  final bool isOnTime;
  final String? hoursVsExpected;
  /// Check-in / break / check-out edited or edit requested.
  final bool isEdited;
  /// Check-in or check-out outside office geofence.
  final bool isOutsideLocation;

  bool get hasCheckIn => checkin != null && checkin!.trim().isNotEmpty;

  bool get hasCheckOut => checkout != null && checkout!.trim().isNotEmpty;

  /// Live break: API flag, status text, or an open breakout without breakin.
  bool get isCurrentlyOnBreak {
    if (isOnBreak) return true;
    if (_looksBreak(status) || _looksBreak(statusLabel)) return true;
    return _hasOpenBreak(breakout, breakin);
  }

  /// Clocked in right now. Team-attendance payloads often omit `is_open`,
  /// so a check-in with no check-out is treated as an open session.
  bool get isActive =>
      (isOpen || (hasCheckIn && !hasCheckOut)) && !isCurrentlyOnBreak;

  bool get isOnLeave {
    final raw = '${status ?? ''} ${statusLabel ?? ''}'.toLowerCase();
    return raw.contains('leave');
  }

  bool get isAbsent {
    if (isOnLeave) return false;
    final key = (status ?? '').trim().toLowerCase();
    return key == 'absent' || !hasCheckIn;
  }

  ManagerTeamAttendanceItem copyWith({
    int? attendanceId,
    int? userId,
    String? employeeName,
    int? departmentId,
    String? departmentTitle,
    String? locationId,
    String? locationName,
    String? photoUrl,
    DateTime? date,
    String? checkin,
    String? checkout,
    String? breakout,
    String? breakin,
    bool? isOpen,
    String? currentLocation,
    double? lat,
    double? lon,
    String? status,
    String? statusLabel,
    bool? isLate,
    bool? isEarlyCheckout,
    bool? isShortHours,
    bool? isBreakExceeded,
    bool? isOnBreak,
    bool? isOnTime,
    String? hoursVsExpected,
    bool? isEdited,
    bool? isOutsideLocation,
  }) {
    return ManagerTeamAttendanceItem(
      attendanceId: attendanceId ?? this.attendanceId,
      userId: userId ?? this.userId,
      employeeName: employeeName ?? this.employeeName,
      departmentId: departmentId ?? this.departmentId,
      departmentTitle: departmentTitle ?? this.departmentTitle,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      photoUrl: photoUrl ?? this.photoUrl,
      date: date ?? this.date,
      checkin: checkin ?? this.checkin,
      checkout: checkout ?? this.checkout,
      breakout: breakout ?? this.breakout,
      breakin: breakin ?? this.breakin,
      isOpen: isOpen ?? this.isOpen,
      currentLocation: currentLocation ?? this.currentLocation,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      isLate: isLate ?? this.isLate,
      isEarlyCheckout: isEarlyCheckout ?? this.isEarlyCheckout,
      isShortHours: isShortHours ?? this.isShortHours,
      isBreakExceeded: isBreakExceeded ?? this.isBreakExceeded,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      isOnTime: isOnTime ?? this.isOnTime,
      hoursVsExpected: hoursVsExpected ?? this.hoursVsExpected,
      isEdited: isEdited ?? this.isEdited,
      isOutsideLocation: isOutsideLocation ?? this.isOutsideLocation,
    );
  }

  factory ManagerTeamAttendanceItem.fromJson(Map<String, dynamic> json) {
    final liveStatus = _asNullableString(
      json['live_status'] ??
          json['status'] ??
          json['filter_status'] ??
          json['attendance_status'] ??
          json['current_status'],
    );
    final statusLabel = _asNullableString(json['status_label']);
    final breakout = _asNullableString(
      json['breakout'] ??
          json['break_out'] ??
          json['break_start'] ??
          json['break_started_at'],
    );
    final breakin = _asNullableString(
      json['breakin'] ??
          json['break_in'] ??
          json['break_end'] ??
          json['break_ended_at'],
    );
    final nestedTimes = _timesFromDetails(json['attendance_details']);
    final checkin = _asNullableString(
      json['checkin'] ??
          json['check_in'] ??
          json['check_in_time'] ??
          json['first_check_in'] ??
          json['clock_in'] ??
          nestedTimes.$1,
    );
    final checkout = _asNullableString(
      json['checkout'] ??
          json['check_out'] ??
          json['check_out_time'] ??
          json['last_check_out'] ??
          json['clock_out'] ??
          nestedTimes.$2,
    );
    final onBreak =
        _asBool(json['is_on_break']) ||
        _asBool(json['on_break']) ||
        _asBool(json['is_break']) ||
        _looksBreak(liveStatus) ||
        _looksBreak(statusLabel) ||
        _hasOpenBreak(breakout, breakin);
    final flags = json['flags'] is Map
        ? Map<String, dynamic>.from(json['flags'] as Map)
        : const <String, dynamic>{};
    final currentLocation = _asNullableString(json['current_location']);
    return ManagerTeamAttendanceItem(
      attendanceId: _asIntOrNull(json['attendance_id'] ?? json['id']),
      userId: _asIntOrNull(
        json['user_id'] ??
            json['employee_id'] ??
            (json['employee'] is Map ? json['employee']['id'] : null),
      ),
      employeeName: _asNullableString(
        json['employee_name'] ??
            json['name'] ??
            (json['employee'] is Map ? json['employee']['name'] : null),
      ),
      departmentId: _asIntOrNull(json['department_id']),
      departmentTitle: _asNullableString(json['department_title']),
      locationId: _asNullableString(
        json['location_id'] ?? json['office_id'] ?? json['site_id'],
      ),
      locationName: _asNullableString(
        json['location_name'] ?? json['office_name'] ?? json['site_name'],
      ),
      photoUrl: _absoluteUrl(
        _asNullableString(
          json['photo_url'] ??
              json['profile_picture'] ??
              json['photo'] ??
              json['avatar'],
        ),
      ),
      date: _asDate(json['date']),
      checkin: checkin,
      checkout: checkout,
      breakout: breakout,
      breakin: breakin,
      isOpen:
          _asBool(json['is_open']) ||
          _isLiveClockedIn(liveStatus) ||
          onBreak ||
          _hasOpenSession(checkin, checkout),
      currentLocation: currentLocation,
      lat: _asDoubleOrNull(json['lat']),
      lon: _asDoubleOrNull(json['lon']),
      status: liveStatus,
      statusLabel: statusLabel,
      isLate:
          _asBool(json['is_late']) ||
          _asBool(json['late_check_in']) ||
          _asBool(json['is_late_check_in']) ||
          _asBool(flags['is_late']) ||
          _asBool(flags['late_check_in']) ||
          _asBool(flags['is_late_check_in']) ||
          _looksLate(liveStatus) ||
          _looksLate(statusLabel),
      isEarlyCheckout: _asBool(json['is_early_checkout']),
      isShortHours: _asBool(json['is_short_hours']),
      isBreakExceeded: _asBool(json['is_break_exceeded']),
      isOnBreak: onBreak,
      isOnTime: _asBool(json['is_on_time']),
      hoursVsExpected: _asNullableString(json['hours_vs_expected']),
      isEdited:
          AttendanceEditRequest.historyItemHasTimeEdit(json) ||
          _asBool(json['is_edited']) ||
          _asBool(json['edited']) ||
          _asBool(json['has_edit_request']) ||
          _asBool(json['edit_requested']) ||
          _asBool(json['is_edit_requested']) ||
          _asBool(flags['is_edited']) ||
          _asBool(flags['edited']) ||
          _asBool(flags['has_edit_request']),
      isOutsideLocation:
          _asBool(json['is_outside']) ||
          _asBool(json['is_outside_office']) ||
          _asBool(json['outside_office']) ||
          _asBool(json['is_out_of_range']) ||
          _asBool(json['out_of_range']) ||
          _asBool(json['location_alert']) ||
          _asBool(json['is_location_alert']) ||
          _asBool(flags['is_outside']) ||
          _asBool(flags['is_outside_office']) ||
          _asBool(flags['outside_office']) ||
          _asBool(flags['location_alert']) ||
          _looksOutsideLocation(currentLocation) ||
          _detailsHaveOutsideLocation(json['attendance_details']),
    );
  }

  /// Pull first check-in / last check-out from nested attendance_details when
  /// the bulk team-attendance payload omits top-level punch times.
  static (String?, String?) _timesFromDetails(dynamic raw) {
    if (raw is! List) return (null, null);
    String? checkin;
    String? checkout;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final type = _normStatus(
        _asNullableString(map['type'] ?? map['action'] ?? map['event']),
      );
      final time = _asNullableString(
        map['attendance_time'] ??
            map['time'] ??
            map['punch_time'] ??
            map['created_at'] ??
            map['occurred_at'],
      );
      if (time == null) continue;
      if (type.contains('checkin') ||
          type == 'in' ||
          type == 'clockin' ||
          type == 'check_in') {
        checkin ??= time;
      } else if (type.contains('checkout') ||
          type == 'out' ||
          type == 'clockout' ||
          type == 'check_out') {
        checkout = time;
      }
    }
    return (checkin, checkout);
  }

  static List<ManagerTeamAttendanceItem> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) =>
              ManagerTeamAttendanceItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList(growable: false);
  }
}

class ManagerTeamLeaveItem {
  const ManagerTeamLeaveItem({
    this.id,
    this.userId,
    this.employeeName,
    this.dateFrom,
    this.dateTo,
    this.status,
    this.statusLabel,
    this.leaveType,
    this.note,
    this.documentName,
    this.employeePhoto,
    this.sourceId,
    this.requestedAt,
  });

  final int? id;
  final int? userId;
  final String? employeeName;
  final String? dateFrom;
  final String? dateTo;
  final String? status;
  final String? statusLabel;
  final String? leaveType;
  final String? note;
  final String? documentName;
  final String? employeePhoto;

  /// Stable string id (e.g. employee leave request id) when [id] is absent.
  final String? sourceId;

  /// When the leave was requested (ISO / API datetime) — newest first in Alerts.
  final String? requestedAt;

  factory ManagerTeamLeaveItem.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : null;
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final member = json['member'] is Map
        ? Map<String, dynamic>.from(json['member'] as Map)
        : null;
    return ManagerTeamLeaveItem(
      id: _asIntOrNull(json['id'] ?? json['leave_id']),
      userId: _asIntOrNull(
        json['user_id'] ??
            json['employee_id'] ??
            json['member_id'] ??
            json['staff_id'] ??
            employee?['id'] ??
            employee?['user_id'] ??
            user?['id'] ??
            user?['user_id'] ??
            member?['id'] ??
            member?['user_id'],
      ),
      employeeName: _asNullableString(
        json['employee_name'] ??
            json['name'] ??
            json['user_name'] ??
            json['full_name'] ??
            employee?['name'] ??
            employee?['full_name'] ??
            user?['name'] ??
            member?['name'],
      ),
      dateFrom: _asNullableString(
        json['date_from'] ??
            json['from_date'] ??
            json['start_date'] ??
            json['leave_from'] ??
            json['from'] ??
            json['start'] ??
            json['date'],
      ),
      dateTo: _asNullableString(
        json['date_to'] ??
            json['to_date'] ??
            json['end_date'] ??
            json['leave_to'] ??
            json['to'] ??
            json['end'],
      ),
      status: _asNullableString(
        json['status'] ??
            json['leave_status'] ??
            json['approval_status'] ??
            json['state'],
      ),
      statusLabel: _asNullableString(
        json['status_label'] ??
            json['leave_status_label'] ??
            json['approval_status_label'],
      ),
      leaveType: _asNullableString(
        json['leave_type'] ??
            json['leave_type_title'] ??
            json['leave_type_name'] ??
            json['type'] ??
            json['type_name'],
      ),
      note: _asNullableString(
        json['note'] ??
            json['reason'] ??
            json['remarks'] ??
            json['comment'] ??
            json['description'] ??
            json['leave_note'] ??
            json['leave_reason'],
      ),
      documentName: _asNullableString(
        json['document_name'] ??
            json['document'] ??
            json['attachment_name'] ??
            json['file_name'] ??
            json['attachment'],
      ),
      employeePhoto: _asNullableString(
        json['employee_photo'] ??
            json['photo_url'] ??
            json['photo'] ??
            json['avatar'] ??
            json['profile_picture'] ??
            employee?['photo_url'] ??
            employee?['photo'] ??
            employee?['avatar'] ??
            user?['photo_url'] ??
            user?['photo'] ??
            member?['photo_url'] ??
            member?['photo'],
      ),
      sourceId: _asNullableString(
        json['source_id'] ?? json['request_id'] ?? json['client_key'],
      ),
      requestedAt: _asNullableString(
        json['requested_at'] ??
            json['created_at'] ??
            json['applied_at'] ??
            json['submitted_at'] ??
            json['updated_at'],
      ),
    );
  }

  static List<ManagerTeamLeaveItem> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ManagerTeamLeaveItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Parses API leave dates (`2026-10-17`, `17-Oct-2026`, `17/10/2026`, …).
  static DateTime? parseLeaveDate(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final named = RegExp(
      r'^(\d{1,2})[\s\-/]+([A-Za-z]{3,9})[\s\-/]+(\d{2,4})$',
    ).firstMatch(value);
    if (named != null) {
      final day = int.tryParse(named.group(1)!);
      final month = months[named.group(2)!.toLowerCase().substring(0, 3)];
      var year = int.tryParse(named.group(3)!);
      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    }

    final slash = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$')
        .firstMatch(value);
    if (slash != null) {
      final a = int.tryParse(slash.group(1)!);
      final b = int.tryParse(slash.group(2)!);
      var year = int.tryParse(slash.group(3)!);
      if (a != null && b != null && year != null) {
        if (year < 100) year += 2000;
        // Prefer D/M/Y when first number looks like a day.
        if (a > 12) return DateTime(year, b, a);
        if (b > 12) return DateTime(year, a, b);
        return DateTime(year, b, a);
      }
    }
    return null;
  }

  bool coversDay(DateTime day) {
    final start = parseLeaveDate(dateFrom);
    if (start == null) return false;
    final end = parseLeaveDate(dateTo) ?? start;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool get isRejectedLeave {
    final raw = _statusBlob;
    return raw.contains('reject') ||
        raw.contains('deny') ||
        raw.contains('decline') ||
        raw.contains('cancel');
  }

  bool get isPendingLeave {
    if (isRejectedLeave) return false;
    final raw = _statusBlob;
    if (raw.contains('approv') ||
        raw.contains('accept') ||
        raw == '1' ||
        raw == 'true') {
      return false;
    }
    // Backends often use requested / submitted / awaiting / 0 instead of
    // "pending". Blank status is ambiguous — use [isPendingInInbox].
    if (raw == '0' || raw == 'false') return true;
    return raw.contains('pend') ||
        raw.contains('request') ||
        raw.contains('await') ||
        raw.contains('submit') ||
        raw.contains('review') ||
        raw == 'new';
  }

  /// Pending review inbox rows: explicit pending, or undecided blank status.
  bool get isPendingInInbox {
    if (isRejectedLeave || countsAsOnLeave) return false;
    if (isPendingLeave) return true;
    return _statusBlob.isEmpty;
  }

  String get _statusBlob =>
      '${status ?? ''} ${statusLabel ?? ''}'.toLowerCase().trim();

  /// True when the leave is approved for On Leave counting.
  bool get countsAsOnLeave {
    if (isRejectedLeave || isPendingLeave) return false;
    final raw = _statusBlob;
    return raw.contains('approv') ||
        raw.contains('accept') ||
        raw == '1' ||
        raw == 'true';
  }

  /// Like [countsAsOnLeave], but blank status counts when the query was
  /// already scoped to approved leaves.
  bool countsAsOnLeaveOrBlank({required bool assumeApprovedQuery}) {
    if (isRejectedLeave || isPendingLeave) return false;
    if (countsAsOnLeave) return true;
    final raw = '${status ?? ''} ${statusLabel ?? ''}'.trim();
    return assumeApprovedQuery && raw.isEmpty;
  }

  /// Stable key for Alerts inbox + notification dedupe.
  String get alertKey {
    final src = (sourceId ?? '').trim();
    if (src.isNotEmpty) {
      return src.startsWith('leave_') ? src : 'leave_$src';
    }
    if (id != null) return 'leave_$id';
    return 'leave_${userId ?? ''}_${dateFrom ?? ''}_${dateTo ?? ''}';
  }

  /// Leave request id for employee detail sheets (`leave_12` → `12`).
  String get leaveRequestId {
    final src = (sourceId ?? '').trim();
    if (src.isNotEmpty) {
      return src.startsWith('leave_') ? src.substring(6) : src;
    }
    if (id != null) return '$id';
    final key = alertKey;
    return key.startsWith('leave_') ? key.substring(6) : key;
  }

  /// Sort key for Alerts — newest request first.
  DateTime get alertSortTime {
    final requested = DateTime.tryParse((requestedAt ?? '').trim());
    if (requested != null) return requested;
    final from = parseLeaveDate(dateFrom);
    if (from != null) return from;
    if (id != null) return DateTime.fromMillisecondsSinceEpoch(id!);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  ManagerTeamLeaveItem copyWith({
    int? id,
    int? userId,
    String? employeeName,
    String? dateFrom,
    String? dateTo,
    String? status,
    String? statusLabel,
    String? leaveType,
    String? note,
    String? documentName,
    String? employeePhoto,
    String? sourceId,
    String? requestedAt,
  }) {
    return ManagerTeamLeaveItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employeeName: employeeName ?? this.employeeName,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      leaveType: leaveType ?? this.leaveType,
      note: note ?? this.note,
      documentName: documentName ?? this.documentName,
      employeePhoto: employeePhoto ?? this.employeePhoto,
      sourceId: sourceId ?? this.sourceId,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'employee_name': employeeName,
    'date_from': dateFrom,
    'date_to': dateTo,
    'status': status,
    'status_label': statusLabel,
    'leave_type': leaveType,
    'note': note,
    'document_name': documentName,
    'employee_photo': employeePhoto,
    'source_id': sourceId,
    'requested_at': requestedAt,
  };
}

class ManagerDashboardModel {
  const ManagerDashboardModel({
    this.today,
    this.company,
    this.teamMemberCount = 0,
    this.pendingTeamLeaveCount = 0,
    this.teamAttendanceToday = const [],
    this.pendingTeamLeaves = const [],
    this.teamMonthLeaves = const [],
  });

  final DateTime? today;
  final ManagerCompanyModel? company;
  final int teamMemberCount;
  final int pendingTeamLeaveCount;
  final List<ManagerTeamAttendanceItem> teamAttendanceToday;
  final List<ManagerTeamLeaveItem> pendingTeamLeaves;
  final List<ManagerTeamLeaveItem> teamMonthLeaves;

  factory ManagerDashboardModel.fromJson(Map<String, dynamic> json) {
    final companyRaw = json['company'];
    return ManagerDashboardModel(
      today: _asDate(json['today']),
      company: companyRaw is Map
          ? ManagerCompanyModel.fromJson(Map<String, dynamic>.from(companyRaw))
          : null,
      teamMemberCount: _asInt(json['team_member_count']),
      pendingTeamLeaveCount: _asInt(json['pending_team_leave_count']),
      teamAttendanceToday: ManagerTeamAttendanceItem.listFrom(
        json['team_attendance_today'],
      ),
      pendingTeamLeaves: ManagerTeamLeaveItem.listFrom(
        json['pending_team_leaves'],
      ),
      teamMonthLeaves: ManagerTeamLeaveItem.listFrom(json['team_month_leaves']),
    );
  }
}

class ManagerTeamAttendanceData {
  const ManagerTeamAttendanceData({
    this.date,
    this.departmentId,
    this.filter,
    this.search,
    this.total = 0,
    this.attendance = const [],
    this.members = const [],
  });

  final DateTime? date;
  final int? departmentId;
  final String? filter;
  final String? search;
  final int total;
  final List<ManagerTeamAttendanceItem> attendance;
  final List<ManagerEmployeeModel> members;

  factory ManagerTeamAttendanceData.fromJson(Map<String, dynamic> json) {
    return ManagerTeamAttendanceData(
      date: _asDate(json['date']),
      departmentId: _asIntOrNull(json['department_id']),
      filter: _asNullableString(json['filter']),
      search: _asNullableString(json['search']),
      total: _asInt(json['total']),
      attendance: ManagerTeamAttendanceItem.listFrom(json['attendance']),
    );
  }
}

int _asInt(dynamic raw, {int fallback = 0}) {
  return _asIntOrNull(raw) ?? fallback;
}

int? _asIntOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim());
}

double? _asDoubleOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString().trim());
}

bool _asBool(dynamic raw, {bool fallback = false}) {
  if (raw == true || raw == 1 || raw == '1' || raw == 'true') return true;
  if (raw == false || raw == 0 || raw == '0' || raw == 'false') return false;
  return fallback;
}

String _normStatus(String? raw) =>
    (raw ?? '').toLowerCase().trim().replaceAll(RegExp(r'[\s\-_\/]+'), '');

bool _looksLate(String? raw) {
  final value = _normStatus(raw);
  if (value.isEmpty) return false;
  if (value.contains('checkout') || value.contains('early')) return false;
  return value == 'late' ||
      value.contains('latecheckin') ||
      value == 'latecheck';
}

bool _looksOutsideLocation(String? raw) {
  final value = (raw ?? '').toLowerCase().trim();
  if (value.isEmpty) return false;
  return value.contains('outside') ||
      value.contains('out of range') ||
      value.contains('not in') ||
      value.contains('out_of_range');
}

bool _detailsHaveOutsideLocation(dynamic raw) {
  if (raw is! List) return false;
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final flags = map['flags'] is Map
        ? Map<String, dynamic>.from(map['flags'] as Map)
        : const <String, dynamic>{};
    if (_asBool(map['is_outside']) ||
        _asBool(map['is_outside_office']) ||
        _asBool(map['outside_office']) ||
        _asBool(map['is_out_of_range']) ||
        _asBool(map['location_alert']) ||
        _asBool(flags['is_outside']) ||
        _asBool(flags['outside_office']) ||
        _asBool(flags['location_alert']) ||
        _looksOutsideLocation(
          _asNullableString(
            map['current_location'] ?? map['location_label'] ?? map['address'],
          ),
        )) {
      return true;
    }
  }
  return false;
}

bool _looksBreak(String? raw) {
  final value = _normStatus(raw);
  if (value.isEmpty || value.contains('exceed')) return false;
  return value == 'break' ||
      value == 'onbreak' ||
      value == 'breakout' ||
      value == 'breakstart' ||
      value.contains('onbreak');
}

bool _hasOpenBreak(String? breakout, String? breakin) {
  final out = (breakout ?? '').trim();
  if (out.isEmpty) return false;
  return (breakin ?? '').trim().isEmpty;
}

bool _hasOpenSession(String? checkin, String? checkout) {
  return (checkin ?? '').trim().isNotEmpty && (checkout ?? '').trim().isEmpty;
}

bool _isLiveClockedIn(String? raw) {
  final value = _normStatus(raw);
  if (value.isEmpty) return false;
  if (value.contains('absent') ||
      value.contains('checkout') ||
      value == 'leave' ||
      value.contains('onleave')) {
    return false;
  }
  return value == 'working' ||
      value == 'active' ||
      value == 'present' ||
      value == 'late' ||
      value == 'latecheckin' ||
      value == 'clockedin' ||
      value == 'checkedin' ||
      value == 'checkin' ||
      value == 'in' ||
      value == 'onduty' ||
      value.contains('checkedin') ||
      value.contains('clockedin') ||
      _looksBreak(raw);
}

String _asString(dynamic raw) => raw?.toString().trim() ?? '';

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

DateTime? _asDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
}
