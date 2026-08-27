import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';

class ManagerEmployeeFormData {
  const ManagerEmployeeFormData({
    this.employee,
    this.departments = const [],
    this.countries = const [],
    this.cities = const [],
    this.locations = const [],
    this.genders = const [],
    this.statuses = const [],
    this.reportsTo = const [],
  });

  final ManagerEmployeeModel? employee;
  final List<ManagerDepartmentOption> departments;
  final List<ManagerDepartmentOption> countries;
  final List<ManagerDepartmentOption> cities;
  final List<ManagerDepartmentOption> locations;
  final List<ManagerDepartmentOption> genders;
  final List<ManagerDepartmentOption> statuses;
  final List<ManagerDepartmentOption> reportsTo;

  factory ManagerEmployeeFormData.fromJson(Map<String, dynamic> json) {
    final employee = ManagerEmployeeModel.fromApiJson(json);
    return ManagerEmployeeFormData(
      employee: employee.id.isEmpty ? null : employee,
      departments: _optionsFrom(json, const [
        'departments',
        'department_options',
      ]),
      countries: _optionsFrom(json, const ['countries', 'country_options']),
      cities: _optionsFrom(json, const ['cities', 'city_options']),
      locations: _optionsFrom(json, const [
        'locations',
        'offices',
        'location_options',
      ]),
      genders: _optionsFrom(json, const ['genders', 'gender_options']),
      statuses: _optionsFrom(json, const ['statuses', 'status_options']),
      reportsTo: _optionsFrom(json, const [
        'reports_to',
        'managers',
        'employees',
      ]),
    );
  }
}

class ManagerEmployeeSalaryRecord {
  const ManagerEmployeeSalaryRecord({
    required this.id,
    this.amount,
    this.currency,
    this.effectiveDate,
    this.month,
    this.type,
    this.status,
    this.note,
  });

  final String id;
  final String? amount;
  final String? currency;
  final String? effectiveDate;
  final String? month;
  final String? type;
  final String? status;
  final String? note;

  factory ManagerEmployeeSalaryRecord.fromJson(Map<String, dynamic> json) {
    return ManagerEmployeeSalaryRecord(
      id: _asString(json['id'] ?? json['salary_id']),
      amount: _asNullableString(
        json['amount'] ??
            json['net_salary'] ??
            json['basic_salary'] ??
            json['gross_salary'] ??
            json['salary'],
      ),
      currency: _asNullableString(json['currency'] ?? json['currency_code']),
      effectiveDate: _asNullableString(
        json['effective_date'] ?? json['paid_on'] ?? json['date'],
      ),
      month: _asNullableString(json['month'] ?? json['year_month']),
      type: _asNullableString(json['type'] ?? json['salary_type']),
      status: _asNullableString(json['status']),
      note: _asNullableString(
        json['note'] ?? json['remarks'] ?? json['comment'],
      ),
    );
  }

  static List<ManagerEmployeeSalaryRecord> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'salary',
      'salaries',
      'history',
      'records',
      'items',
    ]).map(ManagerEmployeeSalaryRecord.fromJson).toList(growable: false);
  }
}

class ManagerEmployeeAppraisal {
  const ManagerEmployeeAppraisal({
    required this.id,
    this.amount,
    this.percentage,
    this.effectiveDate,
    this.type,
    this.reason,
  });

  final String id;
  final String? amount;
  final String? percentage;
  final String? effectiveDate;
  final String? type;
  final String? reason;

  factory ManagerEmployeeAppraisal.fromJson(Map<String, dynamic> json) {
    return ManagerEmployeeAppraisal(
      id: _asString(json['id'] ?? json['appraisal_id']),
      amount: _asNullableString(
        json['amount'] ?? json['increment'] ?? json['new_salary'],
      ),
      percentage: _asNullableString(
        json['percentage'] ?? json['increment_percentage'],
      ),
      effectiveDate: _asNullableString(
        json['effective_date'] ?? json['date'] ?? json['appraisal_date'],
      ),
      type: _asNullableString(json['type'] ?? json['appraisal_type']),
      reason: _asNullableString(
        json['reason'] ?? json['remarks'] ?? json['comment'] ?? json['note'],
      ),
    );
  }

  static List<ManagerEmployeeAppraisal> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'appraisals',
      'history',
      'records',
      'items',
    ]).map(ManagerEmployeeAppraisal.fromJson).toList(growable: false);
  }
}

class ManagerEmployeeLeaveRequest {
  const ManagerEmployeeLeaveRequest({
    required this.id,
    this.type,
    this.status,
    this.fromDate,
    this.toDate,
    this.days,
    this.reason,
  });

  final String id;
  final String? type;
  final String? status;
  final String? fromDate;
  final String? toDate;
  final String? days;
  final String? reason;

  factory ManagerEmployeeLeaveRequest.fromJson(Map<String, dynamic> json) {
    return ManagerEmployeeLeaveRequest(
      id: _asString(json['id'] ?? json['leave_id']),
      type: _asNullableString(
        json['type'] ??
            json['leave_type'] ??
            json['leave_type_name'] ??
            json['name'],
      ),
      status: _asNullableString(json['status'] ?? json['leave_status']),
      fromDate: _asNullableString(
        json['from_date'] ?? json['start_date'] ?? json['from'] ?? json['date'],
      ),
      toDate: _asNullableString(
        json['to_date'] ?? json['end_date'] ?? json['to'],
      ),
      days: _asNullableString(
        json['days'] ?? json['total_days'] ?? json['duration'],
      ),
      reason: _asNullableString(
        json['reason'] ?? json['remarks'] ?? json['comment'] ?? json['note'],
      ),
    );
  }

  static List<ManagerEmployeeLeaveRequest> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'leaves',
      'requests',
      'history',
      'records',
      'items',
    ]).map(ManagerEmployeeLeaveRequest.fromJson).toList(growable: false);
  }
}

class ManagerEmployeeLeaveBalance {
  const ManagerEmployeeLeaveBalance({
    required this.type,
    this.entitled,
    this.used,
    this.remaining,
    this.year,
  });

  final String type;
  final String? entitled;
  final String? used;
  final String? remaining;
  final String? year;

  factory ManagerEmployeeLeaveBalance.fromJson(Map<String, dynamic> json) {
    return ManagerEmployeeLeaveBalance(
      type: _asString(
        json['type'] ??
            json['leave_type'] ??
            json['leave_type_name'] ??
            json['name'] ??
            json['id'],
      ),
      entitled: _asNullableString(
        json['entitled'] ??
            json['total'] ??
            json['allocated'] ??
            json['quota'] ??
            json['days'],
      ),
      used: _asNullableString(json['used'] ?? json['taken'] ?? json['availed']),
      remaining: _asNullableString(
        json['remaining'] ?? json['available'] ?? json['balance'],
      ),
      year: _asNullableString(json['year']),
    );
  }

  static List<ManagerEmployeeLeaveBalance> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'balances',
      'leave_balances',
      'records',
      'items',
    ]).map(ManagerEmployeeLeaveBalance.fromJson).toList(growable: false);
  }
}

class ManagerEmployeeLeaveQuota {
  const ManagerEmployeeLeaveQuota({
    required this.type,
    this.days,
    this.year,
    this.isOverride = false,
  });

  final String type;
  final String? days;
  final String? year;
  final bool isOverride;

  factory ManagerEmployeeLeaveQuota.fromJson(Map<String, dynamic> json) {
    return ManagerEmployeeLeaveQuota(
      type: _asString(
        json['type'] ??
            json['leave_type'] ??
            json['leave_type_name'] ??
            json['name'] ??
            json['key'] ??
            json['id'],
      ),
      days: _asNullableString(
        json['days'] ??
            json['quota'] ??
            json['value'] ??
            json['employee_value'] ??
            json['entitled'],
      ),
      year: _asNullableString(json['year']),
      isOverride:
          json['is_override'] == true ||
          json['is_override'] == 1 ||
          json['is_override']?.toString() == '1',
    );
  }

  static List<ManagerEmployeeLeaveQuota> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'quotas',
      'leave_quota',
      'overrides',
      'records',
      'items',
    ]).map(ManagerEmployeeLeaveQuota.fromJson).toList(growable: false);
  }
}

List<ManagerDepartmentOption> _optionsFrom(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final items = _lookupOptions(json[key]);
    if (items.isNotEmpty) return items;
  }
  return const [];
}

List<ManagerDepartmentOption> _lookupOptions(dynamic raw) {
  if (raw is Map) {
    raw = raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['options'] ?? raw;
  }
  if (raw is! List) return const [];
  final items = <ManagerDepartmentOption>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final id = _asString(
      map['id'] ??
          map['department_id'] ??
          map['country_id'] ??
          map['city_id'] ??
          map['location_id'] ??
          map['user_id'] ??
          map['value'],
    );
    final name = _asString(
      map['name'] ?? map['title'] ?? map['label'] ?? map['email'],
    );
    if (id.isEmpty || id.toLowerCase() == 'all') continue;
    items.add(ManagerDepartmentOption(id: id, name: name.isEmpty ? id : name));
  }
  return items;
}

List<Map<String, dynamic>> _mapsFrom(dynamic json, List<String> keys) {
  dynamic raw = json;
  if (json is Map) {
    final map = Map<String, dynamic>.from(json);
    raw = map['data'] ?? json;
    if (raw is Map) {
      final inner = Map<String, dynamic>.from(raw);
      for (final key in keys) {
        if (inner[key] is List) {
          raw = inner[key];
          break;
        }
      }
    }
    if (raw is! List) {
      for (final key in keys) {
        if (map[key] is List) {
          raw = map[key];
          break;
        }
      }
    }
  }
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _asString(dynamic raw) => raw?.toString().trim() ?? '';

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}
