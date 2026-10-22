import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

void _leaveLog(String message) {
  debugPrint('ℹ️ [Leaves] $message');
  AppLogger.info('[Leaves] $message');
}

void _leaveError(String path, Object error, {StackTrace? stackTrace}) {
  debugPrint('❌ [Leaves] $path -> $error');
  AppLogger.error('POST', path, error, stackTrace: stackTrace);
}

/// Employee leave HTTP calls (`/employee/leaves*`).
class LeavesService extends BaseRepository {
  LeavesService(super.apiClient);

  Future<ApiResponse<List<LeaveRequest>>> getLeaves({
    String? dateFrom,
    String? dateTo,
    String? status,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    return getRequest<List<LeaveRequest>>(
      EmployeeApiEndpoints.employeeLeaves,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: LeaveRequest.listFrom,
    );
  }

  Future<ApiResponse<LeaveBalancesPayload>> getBalances({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<LeaveBalancesPayload>(
      EmployeeApiEndpoints.employeeLeaveBalances,
      cancelToken: cancelToken,
      parser: LeaveBalancesPayload.fromJson,
    );
  }

  Future<ApiResponse<List<LeaveTypeInfo>>> getTypes({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<List<LeaveTypeInfo>>(
      EmployeeApiEndpoints.employeeLeaveTypes,
      cancelToken: cancelToken,
      parser: LeaveTypeInfo.listFrom,
    );
  }

  Future<ApiResponse<LeaveRequest?>> applyLeave({
    required String typeId,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? typeName,
    String? documentName,
    String? leaveId,
    ApiCancelToken? cancelToken,
  }) async {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final leaveTypeId = int.tryParse(typeId) ?? typeId;
    final from = ymd(startDate);
    final to = ymd(endDate);

    // Keep the body to fields most leave APIs validate.
    final body = <String, dynamic>{
      'leave_type_id': leaveTypeId,
      'from_date': from,
      'to_date': to,
      'start_date': from,
      'end_date': to,
      'reason': note,
      'note': note,
      if (typeName != null && typeName.trim().isNotEmpty) 'leave_type': typeName,
      if (leaveId != null && leaveId.isNotEmpty) 'leave_id': leaveId,
      if (documentName != null && documentName.isNotEmpty)
        'document_name': documentName,
    };

    _leaveLog(
      'APPLY request typeId=$leaveTypeId from=$from to=$to noteLen=${note.length}',
    );
    AppLogger.request('POST', EmployeeApiEndpoints.employeeLeaveApply, data: body);

    try {
      var path = EmployeeApiEndpoints.employeeLeaveApply;
      var raw = await apiClient.post(
        path,
        data: body,
        cancelToken: cancelToken,
      );

      // Some backends expose create on the collection path only.
      if (raw.statusCode == 404) {
        _leaveLog('APPLY /leaves/apply returned 404 — retrying POST /employee/leaves');
        path = EmployeeApiEndpoints.employeeLeaves;
        raw = await apiClient.post(
          path,
          data: body,
          cancelToken: cancelToken,
        );
      }

      AppLogger.response('POST', path, raw.statusCode, raw.data);
      debugPrint('ℹ️ [Leaves] APPLY response [${raw.statusCode}] ${raw.data}');

      if (raw.statusCode >= 400) {
        final err = ApiError.fromResponse(
          statusCode: raw.statusCode,
          decodedBody: raw.data is Map
              ? Map<String, dynamic>.from(raw.data as Map)
              : null,
        );
        _leaveError(path, err.message);
        return ApiResponse.failure(
          err.message,
          statusCode: raw.statusCode,
          fieldErrors: err.fieldErrors,
        );
      }

      final map = raw.data is Map
          ? Map<String, dynamic>.from(raw.data as Map)
          : null;
      if (map != null && map['success'] == false) {
        final message =
            (map['message'] ?? map['error'] ?? 'Failed to apply leave')
                .toString();
        _leaveError(path, message);
        return ApiResponse.failure(
          message,
          statusCode: raw.statusCode,
          fieldErrors: map['errors'] is Map
              ? Map<String, dynamic>.from(map['errors'] as Map)
              : null,
        );
      }

      final parsed = _parseApplyResponse(raw.data);
      String? message;
      if (map != null) {
        final rawMessage = map['message'];
        if (rawMessage != null && rawMessage.toString().trim().isNotEmpty) {
          message = rawMessage.toString().trim();
        } else if (map['data'] is Map) {
          final nested = (map['data'] as Map)['message'];
          if (nested != null && nested.toString().trim().isNotEmpty) {
            message = nested.toString().trim();
          }
        }
      }

      _leaveLog(
        'APPLY success status=${raw.statusCode} '
        'leaveId=${parsed?.id ?? '(message-only)'} '
        'message=${message ?? ''}',
      );

      return ApiResponse.success(
        parsed,
        message: message,
        statusCode: raw.statusCode,
      );
    } on ApiError catch (e) {
      _leaveError(EmployeeApiEndpoints.employeeLeaveApply, e.message);
      return ApiResponse.failure(
        e.message,
        statusCode: e.statusCode,
        fieldErrors: e.fieldErrors,
      );
    } catch (e, st) {
      _leaveError(
        EmployeeApiEndpoints.employeeLeaveApply,
        e,
        stackTrace: st,
      );
      return ApiResponse.failure(e.toString());
    }
  }

  LeaveRequest? _parseApplyResponse(dynamic json) {
    if (json == null) return null;
    if (json is! Map) {
      final list = LeaveRequest.listFrom(json);
      return list.isEmpty ? null : list.first;
    }

    final map = Map<String, dynamic>.from(json);

    LeaveRequest? fromMap(Map<String, dynamic> source) {
      if (!_looksLikeLeavePayload(source)) {
        for (final key in const [
          'leave',
          'request',
          'leave_request',
          'record',
          'item',
        ]) {
          final nested = source[key];
          if (nested is Map) {
            final nestedMap = Map<String, dynamic>.from(nested);
            if (_looksLikeLeavePayload(nestedMap)) {
              return LeaveRequest.fromJson(nestedMap);
            }
          }
        }
        return null;
      }
      return LeaveRequest.fromJson(source);
    }

    final data = map['data'];
    if (data is Map) {
      final parsed = fromMap(Map<String, dynamic>.from(data));
      if (parsed != null) return parsed;
    } else if (data is List) {
      final list = LeaveRequest.listFrom({'leaves': data});
      if (list.isNotEmpty) return list.first;
    }

    final direct = fromMap(map);
    if (direct != null) return direct;

    final list = LeaveRequest.listFrom(json);
    return list.isEmpty ? null : list.first;
  }

  bool _looksLikeLeavePayload(Map<String, dynamic> map) {
    final hasId = map['id'] != null || map['leave_id'] != null;
    final hasDate = map['from_date'] != null ||
        map['start_date'] != null ||
        map['date_from'] != null ||
        map['from'] != null ||
        map['date'] != null;
    final hasType = map['leave_type_id'] != null ||
        map['type_id'] != null ||
        map['leave_type'] != null ||
        map['type'] != null ||
        map['type_name'] != null;
    return hasId || (hasDate && hasType) || (hasDate && map['status'] != null);
  }

  /// Company holidays for a calendar year (permissive parse for Leaves UI).
  Future<ApiResponse<List<LeaveHoliday>>> getCompanyHolidaysForYear(
    int year, {
    ApiCancelToken? cancelToken,
  }) async {
    try {
      final raw = await apiClient.get(
        EmployeeApiEndpoints.companyCalendar,
        queryParameters: {
          'year': year.toString(),
          'month': '$year-01',
        },
        cancelToken: cancelToken,
      );
      if (raw.statusCode >= 400) {
        return ApiResponse.success(const [], statusCode: raw.statusCode);
      }
      return ApiResponse.success(
        _parseHolidaysLoose(raw.data),
        statusCode: raw.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(
        e.message,
        statusCode: e.statusCode,
        fieldErrors: e.fieldErrors,
      );
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  List<LeaveHoliday> _parseHolidaysLoose(dynamic json) {
    final out = <LeaveHoliday>[];
    final seen = <String>{};

    void add(DateTime date, String name, {int days = 1}) {
      final key = '${date.year}-${date.month}-${date.day}';
      if (!seen.add(key)) return;
      final trimmed = name.trim();
      out.add(
        LeaveHoliday(
          date: DateTime(date.year, date.month, date.day),
          name: trimmed.isEmpty ? 'Public Holiday' : trimmed,
          days: days < 1 ? 1 : days,
        ),
      );
    }

    DateTime? asDate(dynamic raw) {
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString().trim());
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    void consumeMap(Map<String, dynamic> map) {
      final date = asDate(
        map['date'] ??
            map['holiday_date'] ??
            map['day'] ??
            map['start_date'] ??
            map['from_date'],
      );
      if (date != null) {
        add(
          date,
          (map['name'] ??
                  map['title'] ??
                  map['label'] ??
                  map['holiday_name'] ??
                  map['event_name'] ??
                  'Public Holiday')
              .toString(),
          days: int.tryParse('${map['days'] ?? map['duration'] ?? 1}') ?? 1,
        );
      }

      for (final key in const [
        'holidays',
        'public_holidays',
        'company_holidays',
        'holiday_dates',
        'events',
        'items',
        'days',
        'entries',
        'calendar',
      ]) {
        final nested = map[key];
        if (nested is List) {
          for (final item in nested) {
            if (item is Map) {
              consumeMap(Map<String, dynamic>.from(item));
            } else {
              final d = asDate(item);
              if (d != null) add(d, 'Public Holiday');
            }
          }
        } else if (nested is Map) {
          Map<String, dynamic>.from(nested).forEach((k, v) {
            final keyDate = asDate(k);
            if (v is Map) {
              final m = Map<String, dynamic>.from(v);
              if (keyDate != null && m['date'] == null) m['date'] = k;
              consumeMap(m);
            } else if (keyDate != null) {
              add(keyDate, v?.toString() ?? 'Public Holiday');
            }
          });
        }
      }
    }

    if (json is List) {
      for (final item in json) {
        if (item is Map) consumeMap(Map<String, dynamic>.from(item));
      }
      return out;
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final data = map['data'];
      if (data is Map) {
        consumeMap(Map<String, dynamic>.from(data));
      } else if (data is List) {
        for (final item in data) {
          if (item is Map) consumeMap(Map<String, dynamic>.from(item));
        }
      }
      consumeMap(map);
    }
    return out;
  }
}

class LeaveBalancesPayload {
  const LeaveBalancesPayload({
    required this.types,
    required this.summary,
    this.resetLabel,
  });

  final List<LeaveTypeInfo> types;
  final LeaveBalancesSummary summary;
  final String? resetLabel;

  factory LeaveBalancesPayload.fromJson(dynamic json) {
    final parsed = LeaveBalancesSummary.parseEnvelope(json);
    return LeaveBalancesPayload(
      types: parsed.types,
      summary: parsed.summary,
      resetLabel: parsed.resetLabel,
    );
  }
}
