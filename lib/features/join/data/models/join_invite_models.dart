enum JoinInviteChannel { email, phone }

enum JoinInviteSource { manual, link }

enum JoinInviteStatus {
  invited,
  pendingApproval,
  autoApproved,
  approved,
  rejected,
}

class JoinInviteRecord {
  const JoinInviteRecord({
    required this.id,
    required this.contact,
    required this.channel,
    required this.source,
    required this.password,
    required this.status,
    required this.createdAt,
    this.locationId,
    this.locationName,
    this.companyName = 'Acme Corporation',
    this.joinedAt,
    this.reviewedAt,
  });

  final String id;
  final String contact;
  final JoinInviteChannel channel;
  final JoinInviteSource source;
  final String password;
  final JoinInviteStatus status;
  final DateTime createdAt;
  final String? locationId;
  final String? locationName;
  final String companyName;
  final DateTime? joinedAt;
  final DateTime? reviewedAt;

  bool get isEmail => channel == JoinInviteChannel.email;
  bool get isPendingApproval => status == JoinInviteStatus.pendingApproval;
  bool get isUnverified =>
      status == JoinInviteStatus.pendingApproval ||
      status == JoinInviteStatus.invited;

  String get displayContact => contact.trim();

  JoinInviteRecord copyWith({
    String? contact,
    JoinInviteStatus? status,
    String? locationId,
    String? locationName,
    DateTime? joinedAt,
    DateTime? reviewedAt,
  }) {
    return JoinInviteRecord(
      id: id,
      contact: contact ?? this.contact,
      channel: channel,
      source: source,
      password: password,
      status: status ?? this.status,
      createdAt: createdAt,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      companyName: companyName,
      joinedAt: joinedAt ?? this.joinedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contact': contact,
        'channel': channel.name,
        'source': source.name,
        'password': password,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'location_id': locationId,
        'location_name': locationName,
        'company_name': companyName,
        'joined_at': joinedAt?.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
      };

  factory JoinInviteRecord.fromJson(Map<String, dynamic> json) {
    return JoinInviteRecord(
      id: (json['id'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      channel: JoinInviteChannel.values.firstWhere(
        (e) => e.name == json['channel'],
        orElse: () => JoinInviteChannel.email,
      ),
      source: JoinInviteSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => JoinInviteSource.manual,
      ),
      password: (json['password'] ?? '').toString(),
      status: JoinInviteStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => JoinInviteStatus.invited,
      ),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      locationId: json['location_id']?.toString(),
      locationName: json['location_name']?.toString(),
      companyName: (json['company_name'] ?? 'Acme Corporation').toString(),
      joinedAt: DateTime.tryParse((json['joined_at'] ?? '').toString()),
      reviewedAt: DateTime.tryParse((json['reviewed_at'] ?? '').toString()),
    );
  }
}

class JoinShareLinks {
  JoinShareLinks._();

  static const downloadApk =
      'https://drive.google.com/file/d/1M34OvC4qk5AoNaruwvDwVD_3PseDqW2A/view?usp=share_link';

  /// Shown in the Add Employee sheet and registered as an app deep link.
  /// Tapping this after install offers "Open with Obecno".
  static const displayInviteLink = 'http://www.obecno.com/download';

  static const appDeepLink = 'obecno://join';

  /// Valid temporary login email (matches app email validation).
  static String generateTempEmail() {
    final stamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final suffix = (stamp.hashCode.abs() % 9000 + 1000).toString();
    return 'invite.$stamp$suffix@obecno.app';
  }

  static String shareMessage({
    required String email,
    required String password,
    String companyName = 'Acme Corporation',
  }) {
    return '''
You're invited to join $companyName on Obecno.

Install the app:
$downloadApk

After installing, open the app and sign in with:
Email: $email
Password: $password
'''.trim();
  }
}
