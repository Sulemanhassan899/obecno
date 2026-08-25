import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/features/employee_module/more/data/models/privacy_model.dart';
import 'package:obecno/features/employee_module/more/services/privacy_service.dart';

class PrivacyProvider extends BaseProvider {
  PrivacyProvider(this._service);

  final PrivacyService _service;

  PrivacyModel? _privacy;
  PrivacyModel? get privacy => _privacy;
  bool get hasContent => (_privacy?.content.trim().isNotEmpty) ?? false;

  Future<void> preloadOnLogin() async {
    final cached = await _service.getCached();
    if (cached != null) {
      _privacy = cached;
      notifyListeners();
    }

    await _syncFromApi();
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
