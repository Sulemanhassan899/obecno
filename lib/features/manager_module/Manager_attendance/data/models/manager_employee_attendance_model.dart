import 'package:obecno/core/api/constants.dart';

class ManagerEmployeeAttendanceData {
  const ManagerEmployeeAttendanceData({
    this.employeeId,
    this.employeeName,
    this.employeePhoto,
    this.dateFrom,
    this.dateTo,
    this.history = const [],
    this.actualHours,
    this.actualMinutes,
  });

  final int? employeeId;
  final String? employeeName;
  final String? employeePhoto;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final List<ManagerEmployeeAttendanceDay> history;
  final String? actualHours;
  final int? actualMinutes;

  factory ManagerEmployeeAttendanceData.fromJson(Map<String, dynamic> json) {
    final employeeRaw = json['employee'];
    final employee = employeeRaw is Map
        ? Map<String, dynamic>.from(employeeRaw)
        : const <String, dynamic>{};

    final hoursRaw = json['hours_totals'];
    final hours = hoursRaw is Map
        ? Map<String, dynamic>.from(hoursRaw)
        : const <String, dynamic>{};

    return ManagerEmployeeAttendanceData(
      employeeId: _asIntOrNull(
        employee['id'] ?? json['user_id'] ?? json['employee_id'],
      ),
      employeeName: _asNullableString(
        employee['name'] ?? json['employee_name'] ?? json['name'],
      ),
      employeePhoto: _absoluteUrl(
        _asNullableString(
          employee['photo_url'] ??
              employee['profile_picture'] ??
              employee['photo'] ??
              employee['avatar'] ??
              json['photo_url'] ??
              json['profile_picture'] ??
              json['photo'],
        ),
      ),
      dateFrom: _asDate(json['date_from']),
      dateTo: _asDate(json['date_to']),
      history: ManagerEmployeeAttendanceDay.listFrom(json['history']),
      actualHours: _asNullableString(
        hours['actual_hours'] ?? json['actual_hours'],
      ),
      actualMinutes: _asIntOrNull(
        hours['actual_minutes'] ?? json['actual_minutes'],
      ),
    );
  }
}

class ManagerEmployeeAttendanceDay {
  const ManagerEmployeeAttendanceDay({
    this.id,
    this.date,
    this.checkin,
    this.checkout,
    this.hoursWorked,
    this.isOpen = false,
    this.currentLocation,
    this.lat,
    this.lon,
    this.details = const [],
  });

  final int? id;
  final DateTime? date;
  final String? checkin;
  final String? checkout;
  final String? hoursWorked;
  final bool isOpen;
  final String? currentLocation;
  final double? lat;
  final double? lon;
  final List<ManagerEmployeeAttendanceDetail> details;

  factory ManagerEmployeeAttendanceDay.fromJson(Map<String, dynamic> json) {
    final nestedRaw = json['attendance'];
    final nested = nestedRaw is Map
        ? Map<String, dynamic>.from(nestedRaw)
        : const <String, dynamic>{};

    return ManagerEmployeeAttendanceDay(
      id: _asIntOrNull(
        json['attendance_id'] ??
            json['id'] ??
            nested['attendance_id'] ??
            nested['id'],
      ),
      date: _asDate(json['date'] ?? json['attendance_date'] ?? nested['date']),
      checkin: _asNullableString(json['checkin'] ?? nested['checkin']),
      checkout: _asNullableString(json['checkout'] ?? nested['checkout']),
      hoursWorked: _asNullableString(json['hours_worked']),
      isOpen: _asBool(json['is_open']),
      currentLocation: _asNullableString(json['current_location']),
      lat: _asDoubleOrNull(json['lat']),
      lon: _asDoubleOrNull(json['lon']),
      details: ManagerEmployeeAttendanceDetail.listFrom(
        json['attendance_details'],
      ),
    );
  }

  static List<ManagerEmployeeAttendanceDay> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => ManagerEmployeeAttendanceDay.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }
}

class ManagerEmployeeAttendanceDetail {
  const ManagerEmployeeAttendanceDetail({
    this.id,
    required this.type,
    this.attendanceTime,
    this.occurredAt,
    this.currentLocation,
    this.lat,
    this.lon,
  });

  final int? id;
  final String type;
  final String? attendanceTime;
  final DateTime? occurredAt;
  final String? currentLocation;
  final double? lat;
  final double? lon;

  factory ManagerEmployeeAttendanceDetail.fromJson(Map<String, dynamic> json) {
    final lat = _asDoubleOrNull(json['lat']);
    final lon = _asDoubleOrNull(json['lon']);
    final location = _asNullableString(json['current_location']);
    final parsed = _latLonFrom(location);

    return ManagerEmployeeAttendanceDetail(
      id: _asIntOrNull(json['id']),
      type: _asString(json['type']),
      attendanceTime: _asNullableString(json['attendance_time']),
      occurredAt: _asDateTime(json['occurred_at_iso'] ?? json['created_at']),
      currentLocation: location,
      lat: lat ?? parsed?.$1,
      lon: lon ?? parsed?.$2,
    );
  }

  static List<ManagerEmployeeAttendanceDetail> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => ManagerEmployeeAttendanceDetail.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }
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

String _asString(dynamic raw) => raw?.toString().trim() ?? '';

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

DateTime? _asDate(dynamic raw) {
  final parsed = _asDateTime(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _asDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  final normalized = value.contains('T') ? value : value.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized)?.toLocal() ?? DateTime.tryParse(value);
}

String? _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (path.startsWith('//')) return 'https:$path';
  final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
}

(double, double)? _latLonFrom(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lon = double.tryParse(parts[1].trim());
  if (lat == null || lon == null) return null;
  if (lat == 0 && lon == 0) return null;
  return (lat, lon);
}
