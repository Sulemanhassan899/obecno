import 'dart:convert';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';

class TicketRepository {
  TicketRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  Map<String, dynamic>? _unwrap(dynamic raw) {
    var current = raw;

    if (current is String) {
      try {
        current = jsonDecode(current);
      } catch (_) {
        return null;
      }
    }

    final map = _asMap(current);
    if (map == null) return null;

    if (map.containsKey('success')) return map;

    final inner = map['data'];
    if (inner is Map<String, dynamic>) return inner;

    return map;
  }

  /// POST /api/employee/tickets
  Future<ApiResponse<bool>> submitTicket({
    required String userEmail,
    required String subject,
    required String content,
  }) async {
    try {
      final response = await _client.post(
        EmployeeApiEndpoints.tickets,
        data: {'user_email': userEmail, 'subject': subject, 'content': content},
      );

      final decoded = _unwrap(response.data);

      if (decoded == null) {
        final statusCode = response.statusCode;
        if (statusCode == 200 || statusCode == 201) {
          return ApiResponse.success(true);
        }
        return ApiResponse.failure("Invalid response");
      }

      final success = decoded['success'] != false;

      if (success) {
        return ApiResponse.success(true, message: decoded['message']);
      }

      return ApiResponse.failure(decoded['message'] ?? "Failed");
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure("Something went wrong");
    }
  }
}
