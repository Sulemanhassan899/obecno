/// Provides Authorization headers for network profile/location images.
///
/// Wired from [AppBindings] so UI widgets do not import `main.dart`.
class NetworkImageAuth {
  NetworkImageAuth._();

  static Future<Map<String, String>> Function()? _provider;

  static void configure(Future<Map<String, String>> Function()? provider) {
    _provider = provider;
  }

  static Future<Map<String, String>> headers() async {
    final provider = _provider;
    if (provider == null) return const {};
    try {
      return await provider();
    } catch (_) {
      return const {};
    }
  }
}
