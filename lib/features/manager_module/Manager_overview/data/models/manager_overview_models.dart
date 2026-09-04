import 'package:obecno/core/api/constants.dart';
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

  bool get hasCheckIn => checkin != null && checkin!.isNotEmpty;

  /// Live break: API flag, status text, or an open breakout without breakin.
  bool get isCurrentlyOnBreak {
    if (isOnBreak) return true;
    if (_looksBreak(status) || _looksBreak(statusLabel)) return true;
    return _hasOpenBreak(breakout, breakin);
  }

  bool get isActive => isOpen && !isCurrentlyOnBreak;

  bool get isOnLeave {
    final raw = '${status ?? ''} ${statusLabel ?? ''}'.toLowerCase();
    return raw.contains('leave');
  }

  bool get isAbsent {
    final key = (status ?? '').trim().toLowerCase();
    return key == 'absent' || isOnLeave || !hasCheckIn;
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
    );
  }

  factory ManagerTeamAttendanceItem.fromJson(Map<String, dynamic> json) {
    final liveStatus = _asNullableString(
      json['live_status'] ?? json['status'] ?? json['filter_status'],
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
    final onBreak =
        _asBool(json['is_on_break']) ||
        _asBool(json['on_break']) ||
        _asBool(json['is_break']) ||
        _looksBreak(liveStatus) ||
        _looksBreak(statusLabel) ||
        _hasOpenBreak(breakout, breakin);
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
      checkin: _asNullableString(
        json['checkin'] ??
            json['check_in'] ??
            json['check_in_time'] ??
            json['first_check_in'],
      ),
      checkout: _asNullableString(
        json['checkout'] ??
            json['check_out'] ??
            json['check_out_time'] ??
            json['last_check_out'],
      ),
      breakout: breakout,
      breakin: breakin,
      isOpen:
          _asBool(json['is_open']) || _isLiveClockedIn(liveStatus) || onBreak,
      currentLocation: _asNullableString(json['current_location']),
      lat: _asDoubleOrNull(json['lat']),
      lon: _asDoubleOrNull(json['lon']),
      status: liveStatus,
      statusLabel: statusLabel,
      isLate:
          _asBool(json['is_late']) ||
          _asBool(json['late_check_in']) ||
          _asBool(json['is_late_check_in']) ||
          _looksLate(liveStatus) ||
          _looksLate(statusLabel),
      isEarlyCheckout: _asBool(json['is_early_checkout']),
      isShortHours: _asBool(json['is_short_hours']),
      isBreakExceeded: _asBool(json['is_break_exceeded']),
      isOnBreak: onBreak,
      isOnTime: _asBool(json['is_on_time']),
      hoursVsExpected: _asNullableString(json['hours_vs_expected']),
    );
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
  });

  final int? id;
  final int? userId;
  final String? employeeName;
  final String? dateFrom;
  final String? dateTo;
  final String? status;
  final String? statusLabel;
  final String? leaveType;

  factory ManagerTeamLeaveItem.fromJson(Map<String, dynamic> json) {
    return ManagerTeamLeaveItem(
      id: _asIntOrNull(json['id'] ?? json['leave_id']),
      userId: _asIntOrNull(json['user_id']),
      employeeName: _asNullableString(
        json['employee_name'] ?? json['name'] ?? json['user_name'],
      ),
      dateFrom: _asNullableString(json['date_from'] ?? json['from']),
      dateTo: _asNullableString(json['date_to'] ?? json['to']),
      status: _asNullableString(json['status']),
      statusLabel: _asNullableString(json['status_label']),
      leaveType: _asNullableString(
        json['leave_type'] ?? json['leave_type_title'] ?? json['type'],
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

bool _isLiveClockedIn(String? raw) {
  final value = _normStatus(raw);
  return value == 'working' ||
      value == 'active' ||
      value == 'late' ||
      value == 'latecheckin' ||
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
