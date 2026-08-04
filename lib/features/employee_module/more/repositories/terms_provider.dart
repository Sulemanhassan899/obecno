import 'package:Obecno/core/api/base_provider.dart';
import 'package:Obecno/features/employee_module/more/data/models/terms_model.dart';
import 'package:Obecno/features/employee_module/more/services/terms_service.dart';

class TermsProvider extends BaseProvider {
  TermsProvider(this._service);

  final TermsService _service;

  TermsModel? _terms;
  TermsModel? get terms => _terms;
  bool get hasContent => (_terms?.content.trim().isNotEmpty) ?? false;

  Future<void> preloadOnLogin() async {
    final cached = await _service.getCached();
    if (cached != null) {
      _terms = cached;
      notifyListeners();
    }

    await _syncFromApi();
  }

  Future<void> load() async {
    if (_terms == null) {
      final cached = await _service.getCached();
      if (cached != null) _terms = cached;
    }

    if (_terms != null) {
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
      final changed = _terms == null || !_terms!.isSameAs(fresh);

      if (changed) {
        _terms = fresh;
        await _service.cache(fresh);
      }
      setSuccess();
      return;
    }

    if (_terms == null) {
      setError('Content not available');
    } else {
      setSuccess();
    }
  }
}
