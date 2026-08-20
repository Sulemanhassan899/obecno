import 'dart:convert';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/more/data/models/terms_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TermsService {
  TermsService(this._client, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _keyContent = 'terms_content_v1';
  static const _keyUpdatedAt = 'terms_updated_at_v1';

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  Map<String, dynamic>? _unwrapEnvelope(dynamic raw) {
    var current = raw;

    if (current is String) {
      final trimmed = current.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          current = jsonDecode(trimmed);
        } catch (_) {
          return null;
        }
      }
    }

    final map = _asMap(current);
    if (map == null) return null;

    if (map.containsKey('success')) return map;

    final inner = map['data'];
    if (inner is Map<String, dynamic> && inner.containsKey('success')) {
      return inner;
    }
    if (inner is String) {
      final trimmed = inner.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          // fall through
        }
      }
    }

    return map;
  }

  Future<ApiResponse<TermsModel>> fetchFromApi() async {
    try {
      final response = await _client.get(ApiEndpoints.termsAndConditions);
      final decoded = _unwrapEnvelope(response.data);
      if (decoded == null) {
        return ApiResponse.failure(
          'Unexpected response from server. Please try again.',
          statusCode: response.statusCode,
        );
      }

      final success = decoded['success'] != false;
      final body = decoded['data'];

      if (!success || body is! Map<String, dynamic>) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ??
              'Failed to load Terms & Conditions.',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.success(
        TermsModel.fromApiJson(body),
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  Future<TermsModel?> getCached() async {
    final content = await _storage.read(key: _keyContent);
    if (content == null || content.isEmpty) return null;

    final updatedAt = await _storage.read(key: _keyUpdatedAt);
    return TermsModel.fromCache(content: content, updatedAt: updatedAt);
  }

  Future<void> cache(TermsModel model) async {
    await _storage.write(key: _keyContent, value: model.content);
    if (model.updatedAt != null) {
      await _storage.write(key: _keyUpdatedAt, value: model.updatedAt!);
    } else {
      await _storage.delete(key: _keyUpdatedAt);
    }
  }

  Future<void> clearCache() async {
    await _storage.delete(key: _keyContent);
    await _storage.delete(key: _keyUpdatedAt);
  }
}
