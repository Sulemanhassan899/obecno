import 'package:flutter/foundation.dart';

import 'package:Obecno/features/auth/data/models/permission_item_model.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/features/auth/services/company_policy_service.dart';

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

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      await _rebuildFromCache();
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
      final fetched = await _policyService.refreshFromNetwork();

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
