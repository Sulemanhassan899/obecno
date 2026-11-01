enum LeaveRequestStatus { pending, approved, rejected }

enum LeaveTimelineKind { requested, approved, rejected }

class LeaveTypeInfo {
  const LeaveTypeInfo({
    required this.id,
    required this.name,
    required this.available,
    required this.total,
    this.resetLabel = 'Reset after year',
    this.requiresDocument = false,
    this.accent = LeaveTypeAccent.blue,
  });

  final String id;
  final String name;
  final int available;
  final int total;
  final String resetLabel;
  final bool requiresDocument;
  final LeaveTypeAccent accent;

  int get used => (total - available).clamp(0, total);

  double get progress => total <= 0 ? 0 : used / total;

  LeaveTypeInfo copyWith({
    String? id,
    String? name,
    int? available,
    int? total,
    String? resetLabel,
    bool? requiresDocument,
    LeaveTypeAccent? accent,
  }) {
    return LeaveTypeInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      available: available ?? this.available,
      total: total ?? this.total,
      resetLabel: resetLabel ?? this.resetLabel,
      requiresDocument: requiresDocument ?? this.requiresDocument,
      accent: accent ?? this.accent,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'available': available,
        'total': total,
        'reset_label': resetLabel,
        'requires_document': requiresDocument,
        'accent': accent.name,
      };

  factory LeaveTypeInfo.fromCacheJson(Map<String, dynamic> json) {
    final accentName = _asString(json['accent']);
    final accent = LeaveTypeAccent.values.firstWhere(
      (a) => a.name == accentName,
      orElse: () => LeaveTypeAccent.blue,
    );
    return LeaveTypeInfo.fromJson(json, accent: accent);
  }

  factory LeaveTypeInfo.fromJson(
    Map<String, dynamic> json, {
    LeaveTypeAccent accent = LeaveTypeAccent.blue,
  }) {
    final total = _asInt(
      json['total'] ??
          json['entitled'] ??
          json['allocated'] ??
          json['quota'] ??
          json['days'] ??
          json['max_days'],
    );
    final available = _asInt(
      json['available'] ??
          json['remaining'] ??
          json['balance'] ??
          json['left'],
      fallback: total -
          _asInt(json['used'] ?? json['taken'] ?? json['availed']),
    );
    final name = _asString(
      json['name'] ??
          json['title'] ??
          json['label'] ??
          json['leave_type'] ??
          json['leave_type_name'] ??
          json['type'],
    );
    final id = _asString(
      json['id'] ??
          json['leave_type_id'] ??
          json['type_id'] ??
          json['key'] ??
          name,
    );
    final safeTotal = total > 0 ? total : (available > 0 ? available : 0);
    var safeAvailable = available < 0 ? 0 : available;
    if (safeTotal > 0 && safeAvailable > safeTotal) safeAvailable = safeTotal;
    return LeaveTypeInfo(
      id: id.isEmpty ? name.toLowerCase().replaceAll(' ', '_') : id,
      name: name.isEmpty ? 'Leave' : name,
      available: safeAvailable,
      total: safeTotal,
      resetLabel: _asString(
        json['reset_label'] ??
            json['resetLabel'] ??
            json['reset_message'] ??
            json['period_label'],
        fallback: 'Reset after year',
      ),
      requiresDocument: _asBool(
        json['requires_document'] ??
            json['require_document'] ??
            json['document_required'] ??
            json['is_document_required'],
      ),
      accent: accent,
    );
  }

  static List<LeaveTypeInfo> listFrom(dynamic json) {
    final maps = _mapsFrom(json, const [
      'types',
      'leave_types',
      'balances',
      'leave_balances',
      'records',
      'items',
    ]);
    final accents = LeaveTypeAccent.values;
    return [
      for (var i = 0; i < maps.length; i++)
        LeaveTypeInfo.fromJson(
          maps[i],
          accent: accents[i % accents.length],
        ),
    ];
  }
}

enum LeaveTypeAccent { red, purple, green, blue, grey }

class LeaveHoliday {
  const LeaveHoliday({required this.date, required this.name, this.days = 1});

  final DateTime date;
  final String name;
  final int days;

  factory LeaveHoliday.fromJson(Map<String, dynamic> json) {
    final date =
        _asDate(
          json['date'] ??
              json['holiday_date'] ??
              json['day'] ??
              json['start_date'] ??
              json['from_date'],
        ) ??
        DateTime.now();
    return LeaveHoliday(
      date: date,
      name: _asString(
        json['name'] ??
            json['title'] ??
            json['label'] ??
            json['holiday_name'] ??
            json['event_name'],
        fallback: 'Public Holiday',
      ),
      days: _asInt(json['days'] ?? json['duration'] ?? json['total_days'],
          fallback: 1),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'name': name,
        'days': days,
      };
}

class LeaveTimelineEvent {
  const LeaveTimelineEvent({
    required this.id,
    required this.kind,
    required this.at,
    this.actorName,
    this.reason,
  });

  final String id;
  final LeaveTimelineKind kind;
  final DateTime at;
  final String? actorName;
  final String? reason;

  LeaveTimelineEvent copyWith({
    LeaveTimelineKind? kind,
    DateTime? at,
    String? actorName,
    String? reason,
  }) {
    return LeaveTimelineEvent(
      id: id,
      kind: kind ?? this.kind,
      at: at ?? this.at,
      actorName: actorName ?? this.actorName,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'kind': kind.name,
        'at': at.toIso8601String(),
        if (actorName != null) 'actor_name': actorName,
        if (reason != null) 'reason': reason,
      };

  factory LeaveTimelineEvent.fromJson(Map<String, dynamic> json) {
    final kindRaw = _asString(
      json['kind'] ?? json['type'] ?? json['status'] ?? json['action'],
    ).toLowerCase();
    final kind = switch (kindRaw) {
      'approved' || 'approve' || 'accepted' || 'accept' =>
        LeaveTimelineKind.approved,
      'rejected' || 'reject' || 'declined' || 'denied' =>
        LeaveTimelineKind.rejected,
      _ => LeaveTimelineKind.requested,
    };
    return LeaveTimelineEvent(
      id: _asString(json['id'] ?? json['event_id'], fallback: 'event'),
      kind: kind,
      at: _asDateTime(json['at'] ?? json['date'] ?? json['created_at']) ??
          DateTime.now(),
      actorName: _firstPersonName(json, const [
        'actor_name',
        'actioned_by_name',
        'actioned_by',
        'reviewer_name',
        'manager_name',
        'approver_name',
        'approved_by_name',
        'rejected_by_name',
        'reviewed_by_name',
        'updated_by_name',
        'performed_by',
        'causer',
        'user',
        'actor',
        'reviewer',
        'approver',
        'approved_by',
        'rejected_by',
        'reviewed_by',
        'manager',
        'updated_by',
        'by',
      ]),
      reason: _asNullableString(
        json['reason'] ??
            json['remarks'] ??
            json['comment'] ??
            json['note'] ??
            json['rejection_reason'] ??
            json['reject_reason'],
      ),
    );
  }
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.typeId,
    required this.typeName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.note,
    required this.createdAt,
    required this.timeline,
    this.documentName,
  });

  final String id;
  final String typeId;
  final String typeName;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveRequestStatus status;
  final String note;
  final DateTime createdAt;
  final List<LeaveTimelineEvent> timeline;
  final String? documentName;

  int get dayCount {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(start).inDays + 1;
  }

  bool get isPending => status == LeaveRequestStatus.pending;

  /// Optimistic / offline-queued leave that has not been confirmed by the API.
  bool get isLocal => id.startsWith('local_');

  bool coversDate(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  LeaveRequest copyWith({
    String? id,
    String? typeId,
    String? typeName,
    DateTime? startDate,
    DateTime? endDate,
    LeaveRequestStatus? status,
    String? note,
    DateTime? createdAt,
    List<LeaveTimelineEvent>? timeline,
    String? documentName,
    bool clearDocument = false,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      timeline: timeline ?? this.timeline,
      documentName: clearDocument ? null : (documentName ?? this.documentName),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'type_id': typeId,
        'type_name': typeName,
        'start_date':
            '${startDate.year.toString().padLeft(4, '0')}-'
            '${startDate.month.toString().padLeft(2, '0')}-'
            '${startDate.day.toString().padLeft(2, '0')}',
        'end_date':
            '${endDate.year.toString().padLeft(4, '0')}-'
            '${endDate.month.toString().padLeft(2, '0')}-'
            '${endDate.day.toString().padLeft(2, '0')}',
        'status': status.name,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        if (documentName != null) 'document_name': documentName,
        'timeline': [for (final e in timeline) e.toCacheJson()],
      };

  factory LeaveRequest.fromCacheJson(Map<String, dynamic> json) {
    final statusName = _asString(json['status']).toLowerCase();
    final status = switch (statusName) {
      'approved' => LeaveRequestStatus.approved,
      'rejected' => LeaveRequestStatus.rejected,
      _ => LeaveRequestStatus.pending,
    };
    final timelineRaw = json['timeline'];
    final timeline = timelineRaw is List
        ? timelineRaw
            .whereType<Map>()
            .map(
              (e) => LeaveTimelineEvent.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <LeaveTimelineEvent>[];
    return LeaveRequest(
      id: _asString(json['id'], fallback: 'local_unknown'),
      typeId: _asString(json['type_id'] ?? json['leave_type_id']),
      typeName: _asString(
        json['type_name'] ?? json['type'] ?? json['leave_type'],
        fallback: 'Leave',
      ),
      startDate: _asDate(json['start_date'] ?? json['from_date']) ??
          DateTime.now(),
      endDate: _asDate(json['end_date'] ?? json['to_date']) ??
          (_asDate(json['start_date'] ?? json['from_date']) ?? DateTime.now()),
      status: status,
      note: _asString(json['note'] ?? json['reason']),
      createdAt: _asDateTime(json['created_at']) ?? DateTime.now(),
      timeline: timeline,
      documentName: _asNullableString(json['document_name']),
    );
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    final id = _asString(json['id'] ?? json['leave_id'], fallback: '');
    final typeName = _asString(
      json['type'] ??
          json['leave_type'] ??
          json['leave_type_title'] ??
          json['leave_type_name'] ??
          json['name'] ??
          json['type_name'],
      fallback: 'Leave',
    );
    final typeId = _asString(
      json['type_id'] ??
          json['leave_type_id'] ??
          json['leave_type'] ??
          typeName,
    );
    final start =
        _asDate(
          json['from_date'] ??
              json['date_from'] ??
              json['start_date'] ??
              json['from'] ??
              json['date'],
        ) ??
        DateTime.now();
    final end =
        _asDate(
          json['to_date'] ??
              json['date_to'] ??
              json['end_date'] ??
              json['to'],
        ) ??
        start;
    final status = _resolveLeaveStatus(json);
    final note = _asString(
      json['note'] ??
          json['employee_note'] ??
          json['leave_note'] ??
          json['application_note'] ??
          json['leave_reason'] ??
          json['employee_reason'] ??
          json['reason'] ??
          json['remarks'] ??
          json['comment'] ??
          json['description'] ??
          json['message'],
    );
    final createdAt =
        _asDateTime(
          json['created_at'] ??
              json['requested_at'] ??
              json['applied_at'] ??
              json['submitted_at'],
        ) ??
        start;
    final documentName = _asNullableString(
      json['document_name'] ??
          json['document'] ??
          json['attachment'] ??
          json['file_name'] ??
          json['filename'],
    );

    final timelineRaw = json['timeline'] ?? json['events'] ?? json['history'];
    // Try each key until a real display name is found — an id-only
    // `reviewed_by: {id: N}` must not block `reviewed_by_name` / `actioned_by`.
    final reviewerName = _firstPersonName(json, const [
      'actioned_by_name',
      'actioned_by',
      'reviewed_by_name',
      'approver_name',
      'approved_by_name',
      'rejected_by_name',
      'manager_name',
      'updated_by_name',
      'actor_name',
      'reviewer_name',
      'reviewed_by',
      'approver',
      'approved_by',
      'rejected_by',
      'manager',
      'updated_by',
      'actor',
      'reviewer',
    ]);
    List<LeaveTimelineEvent> timeline;
    if (timelineRaw is List) {
      timeline = timelineRaw
          .whereType<Map>()
          .map((e) => LeaveTimelineEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (reviewerName != null && reviewerName.isNotEmpty) {
        timeline = [
          for (final event in timeline)
            (event.kind == LeaveTimelineKind.approved ||
                        event.kind == LeaveTimelineKind.rejected) &&
                    (event.actorName == null ||
                        event.actorName!.trim().isEmpty ||
                        event.actorName!.trim().toLowerCase() == 'manager')
                ? event.copyWith(actorName: reviewerName)
                : event,
        ];
      }
    } else {
      timeline = _synthesizeTimeline(
        id: id.isEmpty ? 'leave' : id,
        status: status,
        createdAt: createdAt,
        reviewer: reviewerName,
        reviewReason: _asNullableString(
          json['rejection_reason'] ??
              json['reject_reason'] ??
              json['review_note'] ??
              json['manager_note'] ??
              json['reviewer_note'] ??
              json['remarks'],
        ),
        reviewedAt: _asDateTime(
          json['reviewed_at'] ??
              json['approved_at'] ??
              json['rejected_at'] ??
              json['updated_at'],
        ),
      );
    }

    // If status text was missing/ambiguous, derive from timeline events.
    var resolvedStatus = status;
    if (resolvedStatus == LeaveRequestStatus.pending) {
      if (timeline.any((e) => e.kind == LeaveTimelineKind.approved)) {
        resolvedStatus = LeaveRequestStatus.approved;
      } else if (timeline.any((e) => e.kind == LeaveTimelineKind.rejected)) {
        resolvedStatus = LeaveRequestStatus.rejected;
      }
    }

    return LeaveRequest(
      id: id.isEmpty ? 'leave_${start.millisecondsSinceEpoch}' : id,
      typeId: typeId.isEmpty ? typeName.toLowerCase() : typeId,
      typeName: typeName,
      startDate: start,
      endDate: end,
      status: resolvedStatus,
      note: note,
      createdAt: createdAt,
      timeline: timeline,
      documentName: documentName,
    );
  }

  static List<LeaveRequest> listFrom(dynamic json) {
    return _mapsFrom(json, const [
      'leaves',
      'requests',
      'history',
      'records',
      'items',
    ]).map(LeaveRequest.fromJson).toList(growable: false);
  }
}

class LeaveBalancesSummary {
  const LeaveBalancesSummary({
    required this.allAvailable,
    required this.allTotal,
    required this.casualAvailable,
    required this.casualTotal,
    required this.sickAvailable,
    required this.sickTotal,
  });

  final int allAvailable;
  final int allTotal;
  final int casualAvailable;
  final int casualTotal;
  final int sickAvailable;
  final int sickTotal;

  static LeaveBalancesSummary fromTypes(List<LeaveTypeInfo> types) {
    LeaveTypeInfo? byName(String needle) {
      for (final type in types) {
        if (type.name.toLowerCase().contains(needle) ||
            type.id.toLowerCase().contains(needle)) {
          return type;
        }
      }
      return null;
    }

    final casual = byName('casual');
    final sick = byName('sick');
    final allAvailable = types.fold<int>(0, (sum, t) => sum + t.available);
    final allTotal = types.fold<int>(0, (sum, t) => sum + t.total);
    return LeaveBalancesSummary(
      allAvailable: allAvailable,
      allTotal: allTotal,
      casualAvailable: casual?.available ?? 0,
      casualTotal: casual?.total ?? 0,
      sickAvailable: sick?.available ?? 0,
      sickTotal: sick?.total ?? 0,
    );
  }

  /// Parses balances payload; also reads optional quota reset label from envelope.
  static ({LeaveBalancesSummary summary, String? resetLabel, List<LeaveTypeInfo> types})
      parseEnvelope(dynamic json) {
    final types = LeaveTypeInfo.listFrom(json);
    String? resetLabel;
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final data = map['data'];
      final source = data is Map
          ? Map<String, dynamic>.from(data)
          : map;
      resetLabel = _asNullableString(
        source['reset_label'] ??
            source['quota_reset_label'] ??
            source['quota_reset_message'] ??
            source['reset_message'] ??
            source['message'],
      );
    }
    return (
      summary: fromTypes(types),
      resetLabel: resetLabel,
      types: types,
    );
  }
}

List<LeaveTimelineEvent> _synthesizeTimeline({
  required String id,
  required LeaveRequestStatus status,
  required DateTime createdAt,
  String? reviewer,
  String? reviewReason,
  DateTime? reviewedAt,
}) {
  final events = <LeaveTimelineEvent>[
    LeaveTimelineEvent(
      id: '${id}_requested',
      kind: LeaveTimelineKind.requested,
      at: createdAt,
    ),
  ];
  if (status == LeaveRequestStatus.approved) {
    events.insert(
      0,
      LeaveTimelineEvent(
        id: '${id}_approved',
        kind: LeaveTimelineKind.approved,
        at: reviewedAt ?? createdAt,
        actorName: reviewer,
      ),
    );
  } else if (status == LeaveRequestStatus.rejected) {
    events.insert(
      0,
      LeaveTimelineEvent(
        id: '${id}_rejected',
        kind: LeaveTimelineKind.rejected,
        at: reviewedAt ?? createdAt,
        actorName: reviewer,
        reason: reviewReason,
      ),
    );
  }
  return events;
}

LeaveRequestStatus _resolveLeaveStatus(Map<String, dynamic> json) {
  // Explicit rejection / approval flags from the backend.
  if (_asBool(json['is_rejected']) ||
      _asBool(json['rejected']) ||
      json['rejected_at'] != null) {
    return LeaveRequestStatus.rejected;
  }
  if (_asBool(json['is_approved']) ||
      _asBool(json['approved']) ||
      json['approved_at'] != null) {
    return LeaveRequestStatus.approved;
  }
  if (_asBool(json['is_pending']) || _asBool(json['pending'])) {
    return LeaveRequestStatus.pending;
  }

  final raw = _pick(json, const [
    'approval_status',
    'leave_status',
    'status_label',
    'status_name',
    'status_text',
    'status',
    'state',
    'leave_state',
    'badge',
    'badge_status',
    'current_status',
  ]);
  final fromRaw = _parseStatus(raw);
  if (fromRaw != null) return fromRaw;

  final code = _pick(json, const [
    'status_id',
    'leave_status_id',
    'approval_status_id',
    'state_id',
  ]);
  final fromCode = _parseStatus(code);
  if (fromCode != null) return fromCode;

  // Same rule as [EmployeeLeave.isApproved]: missing / unknown status on
  // GET /employee/leaves means the leave is treated as approved (attendance
  // already overlays these days as On Leave).
  return LeaveRequestStatus.approved;
}

/// Returns null when [raw] is absent so callers can fall through.
LeaveRequestStatus? _parseStatus(dynamic raw) {
  if (raw == null) return null;
  if (raw == true) return LeaveRequestStatus.approved;
  if (raw == false) return LeaveRequestStatus.pending;

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    return _parseStatus(
      map['label'] ??
          map['name'] ??
          map['title'] ??
          map['status'] ??
          map['value'] ??
          map['key'] ??
          map['slug'] ??
          map['id'] ??
          map['code'],
    );
  }

  final value =
      _asString(raw).toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
  if (value.isEmpty) return null;

  if (value.contains('reject') ||
      value.contains('decline') ||
      value.contains('denied') ||
      value.contains('cancel')) {
    return LeaveRequestStatus.rejected;
  }
  if (value.contains('pend') ||
      value.contains('await') ||
      value == 'new' ||
      value == 'submitted' ||
      value == 'requested' ||
      value == 'leave_requested') {
    return LeaveRequestStatus.pending;
  }
  if (value.contains('approve') ||
      value.contains('accept') ||
      value == 'ok' ||
      value == 'done' ||
      value == 'success' ||
      value == 'active' ||
      value == 'granted') {
    return LeaveRequestStatus.approved;
  }

  // Numeric enums: match EmployeeLeave — only explicit pending/rejected
  // strings are non-approved; bare codes without those words are approved.
  if (int.tryParse(value) != null) {
    return LeaveRequestStatus.approved;
  }

  // Unknown label → approved (same as attendance overlay).
  return LeaveRequestStatus.approved;
}

dynamic _pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  // Case-insensitive fallback (some payloads use Status / Leave_Status).
  final lowerKeys = {for (final e in json.entries) e.key.toLowerCase(): e.value};
  for (final key in keys) {
    final value = lowerKeys[key.toLowerCase()];
    if (value != null) return value;
  }
  return null;
}

DateTime? _asDate(dynamic raw) {
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw.toString().trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _asDateTime(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString().trim());
}

String _asString(dynamic raw, {String fallback = ''}) {
  if (raw == null) return fallback;
  final value = raw.toString().trim();
  return value.isEmpty ? fallback : value;
}

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) return _personName(raw);
  final value = raw.toString().trim();
  if (value.isEmpty || value == 'null' || value.startsWith('Instance of')) {
    return null;
  }
  return value;
}

/// Tries [keys] in order; returns the first value that yields a display name.
String? _firstPersonName(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final name = _personName(json[key]);
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}

/// Extracts a display name from a string or nested `{ name / full_name }` map.
String? _personName(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return null;
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final direct = _personName(
      map['name'] ??
          map['full_name'] ??
          map['fullName'] ??
          map['user_name'] ??
          map['display_name'] ??
          map['username'],
    );
    if (direct != null) return direct;
    final first = _asString(map['first_name'] ?? map['firstName']);
    final last = _asString(map['last_name'] ?? map['lastName']);
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    // Nested `{ user: { name } }` / `{ data: { name } }` shapes.
    return _personName(map['user'] ?? map['data'] ?? map['person']);
  }
  final value = raw.toString().trim();
  if (value.isEmpty ||
      value == 'null' ||
      value.toLowerCase() == 'manager' ||
      int.tryParse(value) != null ||
      value.startsWith('Instance of') ||
      value.startsWith('{')) {
    return null;
  }
  return value;
}

int _asInt(dynamic raw, {int fallback = 0}) {
  if (raw == null) return fallback;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw.toString().trim().split('.').first) ?? fallback;
}

bool _asBool(dynamic raw) {
  if (raw == true || raw == 1 || raw == '1') return true;
  if (raw is String) {
    final value = raw.trim().toLowerCase();
    return value == 'true' || value == 'yes';
  }
  return false;
}

List<Map<String, dynamic>> _mapsFrom(dynamic json, List<String> keys) {
  dynamic raw = json;
  if (json is Map) {
    final map = Map<String, dynamic>.from(json);
    raw = map['data'] ?? json;
    if (raw is Map) {
      final inner = Map<String, dynamic>.from(raw);
      for (final key in keys) {
        if (inner[key] is List) {
          raw = inner[key];
          break;
        }
      }
    }
    if (raw is! List) {
      for (final key in keys) {
        if (map[key] is List) {
          raw = map[key];
          break;
        }
      }
    }
  }
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
