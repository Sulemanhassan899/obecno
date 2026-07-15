import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the raw `set-cookie` string for the http-based auth flow.
///
/// Kept separate from `api/cookie_service.dart`, which owns a Dio-flavored
/// `PersistCookieJar` used by `CookieManager` on the existing Dio
/// `ApiClient`. That class stays untouched — other modules (attendance,
/// employee, ...) still run on Dio and keep working exactly as before.
/// This store only feeds `HttpApiClient` (see `api/api.dart`), used by
/// the auth module.
class SessionCookieStore {
  SessionCookieStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const String _cookieKey = 'auth_session_cookie';

  final FlutterSecureStorage _storage;

  Future<void> save(String cookie) => _storage.write(key: _cookieKey, value: cookie);

  Future<String?> read() => _storage.read(key: _cookieKey);

  Future<void> clear() => _storage.delete(key: _cookieKey);
}
