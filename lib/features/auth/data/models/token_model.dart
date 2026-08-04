class TokenModel {
  const TokenModel({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.issuedAt,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final DateTime issuedAt;

  DateTime get expiresAt => issuedAt.add(Duration(seconds: expiresIn));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Ready-to-send `Authorization` header value, e.g. `"Bearer ob_563F..."`.
  String get authorizationHeader =>
      '${tokenType.isEmpty ? 'Bearer' : tokenType} $accessToken';

  static TokenModel? fromJson(Map<String, dynamic> json, {DateTime? issuedAt}) {
    final accessToken = json['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) return null;

    return TokenModel(
      accessToken: accessToken,
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '') ?? 0,
      issuedAt: issuedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toStorageJson() => {
    'access_token': accessToken,
    'token_type': tokenType,
    'expires_in': expiresIn,
    'issued_at': issuedAt.toIso8601String(),
  };

  static TokenModel? fromStorageJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final accessToken = json['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) return null;

    return TokenModel(
      accessToken: accessToken,
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '') ?? 0,
      issuedAt:
          DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  String toString() =>
      'TokenModel(tokenType: $tokenType, expiresAt: $expiresAt, isExpired: $isExpired)';
}
