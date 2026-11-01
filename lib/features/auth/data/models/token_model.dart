class TokenModel {
  const TokenModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.issuedAt,
    this.refreshToken,
  });

  /// Used when the API omits `expires_in` or sends 0. A zero TTL made
  /// [isExpired] true within the same second and cleared the session via
  /// [TokenService.tryRefreshSession].
  static const int defaultExpiresInSeconds = 60 * 60 * 24 * 30;

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final DateTime issuedAt;
  final String? refreshToken;

  DateTime get expiresAt => issuedAt.add(Duration(seconds: expiresIn));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Ready-to-send `Authorization` header value, e.g. `"Bearer ob_563F..."`.
  String get authorizationHeader =>
      '${tokenType.isEmpty ? 'Bearer' : tokenType} $accessToken';

  static int _parseExpiresIn(dynamic raw) {
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) return defaultExpiresInSeconds;
    return parsed;
  }

  static String? _parseRefreshToken(Map<String, dynamic> source, Map<String, dynamic> json) {
    final nested = source['refresh_token']?.toString();
    if (nested != null && nested.isNotEmpty) return nested;
    final flat = json['refresh_token']?.toString();
    if (flat != null && flat.isNotEmpty) return flat;
    return null;
  }

  static TokenModel? fromJson(Map<String, dynamic> json, {DateTime? issuedAt}) {
    // Support flat `{ access_token }` and nested `{ token: { access_token } }`.
    final nested = json['token'];
    final Map<String, dynamic> source = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;

    String? accessToken = source['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      accessToken = json['access_token']?.toString();
    }
    if (accessToken == null || accessToken.isEmpty) {
      if (nested is String && nested.isNotEmpty) {
        accessToken = nested;
      }
    }
    if (accessToken == null || accessToken.isEmpty) return null;

    final tokenType =
        (source['token_type'] ?? json['token_type'] ?? 'Bearer').toString();
    final expiresIn = _parseExpiresIn(
      source['expires_in'] ?? json['expires_in'],
    );

    return TokenModel(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      issuedAt: issuedAt ?? DateTime.now(),
      refreshToken: _parseRefreshToken(source, json),
    );
  }

  Map<String, dynamic> toStorageJson() => {
    'access_token': accessToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
    'issued_at': issuedAt.toIso8601String(),
    if (refreshToken != null && refreshToken!.isNotEmpty)
      'refresh_token': refreshToken,
  };

  static TokenModel? fromStorageJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final accessToken = json['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) return null;

    final refresh = json['refresh_token']?.toString();
    return TokenModel(
      accessToken: accessToken,
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      expiresIn: _parseExpiresIn(json['expires_in']),
      issuedAt:
          DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
          DateTime.now(),
      refreshToken: (refresh != null && refresh.isNotEmpty) ? refresh : null,
    );
  }

  TokenModel copyWith({
    String? accessToken,
    String? tokenType,
    int? expiresIn,
    DateTime? issuedAt,
    String? refreshToken,
  }) {
    return TokenModel(
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
      issuedAt: issuedAt ?? this.issuedAt,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  @override
  String toString() =>
      'TokenModel(tokenType: $tokenType, expiresAt: $expiresAt, isExpired: $isExpired)';
}
