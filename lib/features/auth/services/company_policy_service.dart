import 'dart:async';

import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/data/models/permission_item_model.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';

class CompanyPolicyService {
  CompanyPolicyService(this._tokenService, this._authRepository);

  final TokenService _tokenService;
  final AuthRepository _authRepository;

  // ---------------------------------------------------------------------------
  // Deduplication: only one in-flight /employee/permissions request at a time.
  // All concurrent callers await the same Completer future.
  // ---------------------------------------------------------------------------
  Completer<bool>? _refreshInFlight;

  // ---------------------------------------------------------------------------
  // TTL cache: skip the network entirely if a successful refresh happened
  // recently (default: 5 minutes).  Reset on logout via invalidate().
  // ---------------------------------------------------------------------------
  DateTime? _lastRefreshedAt;
  static const Duration _cacheTtl = Duration(minutes: 5);

  bool get _isCacheValid {
    final last = _lastRefreshedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _cacheTtl;
  }

  /// Invalidate the TTL cache.  Call this on logout so the next session
  /// always fetches fresh permissions from the network.
  void invalidate() {
    _lastRefreshedAt = null;
  }

  /// Fetch permissions from the network.
  ///
  /// - Returns immediately if the TTL cache is still valid.
  /// - Deduplicates concurrent calls: all callers that arrive while a request
  ///   is already in-flight await the same [Completer] future.
  Future<bool> refreshFromNetwork() async {
    // 1. TTL guard — skip network if cache is fresh.
    if (_isCacheValid) return true;

    // 2. Deduplication — if a request is already in-flight, join it.
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshInFlight = completer;

    try {
      final response = await _authRepository.fetchPermissions();
      final success = response.success && response.data != null;

      if (success) {
        await _tokenService.cachePermissions(response.data!);
        _lastRefreshedAt = DateTime.now();
      }

      completer.complete(success);
      return success;
    } catch (e) {
      completer.complete(false);
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<List<PermissionItemModel>> all() async {
    final raw = await _tokenService.cachedPermissions;
    return raw.map(PermissionItemModel.fromJson).toList(growable: false);
  }

  Future<Map<String, List<PermissionItemModel>>> bySection() async {
    return PermissionItemModel.groupBySection(await all());
  }

  Future<String?> valueFor(String section, String key) async {
    final items = await all();
    for (final item in items) {
      if (item.section == section && item.key == key) return item.value;
    }
    return null;
  }
}

