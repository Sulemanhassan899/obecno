import 'dart:async';

import 'package:Obecno/core/api/base_provider.dart';
import 'package:Obecno/features/employee_module/more/data/models/privacy_model.dart';
import 'package:Obecno/features/employee_module/more/services/privacy_service.dart';

class PrivacyProvider extends BaseProvider {
  PrivacyProvider(this._service);

  final PrivacyService _service;

  PrivacyModel? _privacy;
  PrivacyModel? get privacy => _privacy;
  bool get hasContent => (_privacy?.content.trim().isNotEmpty) ?? false;

  static const Duration _backgroundCheckInterval = Duration(minutes: 30);
  Timer? _backgroundTimer;

  void _startBackgroundVerification() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(
      _backgroundCheckInterval,
      (_) => _syncFromApi(),
    );
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    super.dispose();
  }

  Future<void> preloadOnLogin() async {
    final cached = await _service.getCached();
    if (cached != null) {
      _privacy = cached;
      notifyListeners();
    }

    await _syncFromApi();
    _startBackgroundVerification();
  }

  Future<void> load() async {
    if (_privacy == null) {
      final cached = await _service.getCached();
      if (cached != null) _privacy = cached;
    }

    if (_privacy != null) {
      setSuccess();
    } else {
      setLoading();
    }

    await _syncFromApi();
    _startBackgroundVerification();
  }

  Future<void> _syncFromApi() async {
    final response = await _service.fetchFromApi();

    if (response.success && response.data != null) {
      final fresh = response.data!;
      final changed = _privacy == null || !_privacy!.isSameAs(fresh);

      if (changed) {
        _privacy = fresh;
        await _service.cache(fresh);
      }
      setSuccess();
      return;
    }

    if (_privacy == null) {
      setError('Content not available');
    } else {
      setSuccess();
    }
  }
}
