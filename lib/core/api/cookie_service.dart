import 'dart:io';

import 'package:Obecno/core/api/constants.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';


/// Owns the [PersistCookieJar] used by [ApiClient]'s `CookieManager`.
///
/// The backend authenticates via session cookies, so this is the single
/// source of truth for "is there a session on disk" and is what gets wiped
/// on logout. It must be initialized (`init()`) before the Dio client is
/// built, since the cookie manager interceptor needs a ready jar.
class CookieService {
  CookieService._(this._jar);

  final PersistCookieJar _jar;

  static CookieService? _instance;

  /// Must be awaited once at app startup (e.g. in `main()`) before any
  /// API call is made.
  static Future<CookieService> init() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    final cookiePath = '${dir.path}/${AppConstants.cookieDirName}';
    await Directory(cookiePath).create(recursive: true);

    final jar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage(cookiePath),
    );

    AppLogger.info('CookieService initialized at $cookiePath');
    _instance = CookieService._(jar);
    return _instance!;
  }

  /// Throws if [init] hasn't been called — surfaces setup bugs immediately
  /// instead of silently sending unauthenticated requests.
  static CookieService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('CookieService.init() must be called before CookieService.instance is used.');
    }
    return i;
  }

  PersistCookieJar get jar => _jar;

  Future<bool> get hasSessionCookie async {
    final uri = Uri.parse(AppConstants.baseUrl);
    final cookies = await _jar.loadForRequest(uri);
    return cookies.isNotEmpty;
  }

  Future<void> clear() async {
    await _jar.deleteAll();
    AppLogger.info('CookieService: all cookies cleared (logout).');
  }
}
