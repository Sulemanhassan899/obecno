import 'package:flutter/foundation.dart';

import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/auth/services/auth_service.dart';
import 'package:obecno/features/auth/services/company_policy_service.dart';

class PermissionProvider extends ChangeNotifier {
  PermissionProvider(this._policyService, this._authService);

  final CompanyPolicyService _policyService;
  final AuthService _authService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  Map<String, List<PermissionItemModel>> _sections = const {};
  Map<String, List<PermissionItemModel>> get sections => _sections;

  bool get isEmpty => _sections.isEmpty;

  int _overrideCount = 0;
  int get overrideCount => _overrideCount;

  String companyName = '';
  String locationName = '';

  /// Safe lookup — never throws on missing section/key.
  String? valueOf(String section, String key) {
    final items = _sections[section];
    if (items == null) return null;
    for (final item in items) {
      if (item.key == key) return item.value;
    }
    return null;
  }

  /// Safe boolean-style check for Allowed/On style permission values.
  bool isEnabled(String section, String key, {bool defaultValue = false}) {
    final items = _sections[section];
    if (items == null) return defaultValue;
    for (final item in items) {
      if (item.key == key) return item.isEnabled;
    }
    return defaultValue;
  }

  bool has(String section, String key) => valueOf(section, key) != null;

  // Convenience accessors used by UI / clock (future-proof, missing = safe).
  bool get canUsePhotoCapture =>
      isEnabled('attendance', 'is_photo_necessary');
  bool get canUseVideoCapture =>
      isEnabled('attendance', 'is_video_necessary');
  bool get allowLeaveOverQuota =>
      isEnabled('leave_policies', 'allow_leave_over_quota');
  String? get checkInTime => valueOf('attendance', 'check_in_time');
  String? get checkOutTime => valueOf('attendance', 'check_out_time');
  String? get breakTime => valueOf('attendance', 'break_time');
  String? get workingDays => valueOf('attendance', 'working_days');

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      await _rebuildFromCache();

      // Cache may be empty after login if nested permissions failed to parse
      // previously — force a network refresh so Account Settings isn't blank.
      if (_sections.isEmpty) {
        final fetched = await _policyService.refreshFromNetwork(force: true);
        await _rebuildFromCache();
        _hasError = !fetched && _sections.isEmpty;
      }
    } catch (_) {
      _hasError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final fetched = await _policyService.refreshFromNetwork(
        force: _sections.isEmpty,
      );
      // Always rebuild UI state from whatever is now in cache.
      await _rebuildFromCache();
      _hasError = !fetched && _sections.isEmpty;
    } catch (_) {
      _hasError = _sections.isEmpty;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _rebuildFromCache() async {
    final items = await _policyService.all();
    _sections = PermissionItemModel.groupBySection(items);
    _overrideCount = items.where((i) => i.isOverride).length;

    final company = await _authService.getCachedCompany();
    final permissionLocation = await _authService.getCachedPermissionLocation();
    companyName = company?.name ?? '';
    locationName = permissionLocation?.name ?? '';
  }
}
