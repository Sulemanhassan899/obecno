enum AttendanceEditRequestStatus { pending, approved, rejected }

class AttendanceEditRequest {
  const AttendanceEditRequest({
    required this.status,
    required this.requestedAt,
    required this.originalTime,
    required this.newTime,
    this.actionedBy,
    this.actionedAt,
    this.eventType,
  });

  final AttendanceEditRequestStatus status;
  final DateTime requestedAt;
  final String originalTime;
  final String newTime;
  final String? actionedBy;
  final DateTime? actionedAt;

  /// checkIn | checkOut | breakStart | breakEnd
  final String? eventType;

  bool get isPending => status == AttendanceEditRequestStatus.pending;
  bool get isApproved => status == AttendanceEditRequestStatus.approved;
  bool get isRejected => status == AttendanceEditRequestStatus.rejected;

  /// Parses a clock label (`07:55 AM` / `07:55:00`) onto [date]'s calendar day.
  static DateTime? parseClockTime(String raw, {required DateTime date}) {
    final s = raw.trim();
    if (s.isEmpty || s == '--') return null;

    final ampm = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(s);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2)!);
      final second = int.tryParse(ampm.group(3) ?? '') ?? 0;
      final period = ampm.group(4)!.toUpperCase();
      if (period == 'AM') {
        if (hour == 12) hour = 0;
      } else if (hour != 12) {
        hour += 12;
      }
      return DateTime(date.year, date.month, date.day, hour, minute, second);
    }

    final parts = s.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  bool matchesClock(DateTime dt) {
    bool same(DateTime? parsed) =>
        parsed != null && parsed.hour == dt.hour && parsed.minute == dt.minute;
    return same(parseClockTime(originalTime, date: dt)) ||
        same(parseClockTime(newTime, date: dt));
  }

  /// Latest approved `new_time` on [original]'s date, or [original] if none.
  static DateTime applyApprovedTime(
    DateTime original,
    List<AttendanceEditRequest> requests,
  ) {
    AttendanceEditRequest? latest;
    for (final request in requests) {
      if (!request.isApproved) continue;
      if (latest == null) {
        latest = request;
        continue;
      }
      final requestAt = request.actionedAt ?? request.requestedAt;
      final latestAt = latest.actionedAt ?? latest.requestedAt;
      if (requestAt.isAfter(latestAt)) latest = request;
    }
    if (latest == null) return original;
    return parseClockTime(latest.newTime, date: original) ?? original;
  }

  AttendanceEditRequest copyWith({
    AttendanceEditRequestStatus? status,
    DateTime? requestedAt,
    String? originalTime,
    String? newTime,
    String? actionedBy,
    DateTime? actionedAt,
    String? eventType,
  }) {
    return AttendanceEditRequest(
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      originalTime: originalTime ?? this.originalTime,
      newTime: newTime ?? this.newTime,
      actionedBy: actionedBy ?? this.actionedBy,
      actionedAt: actionedAt ?? this.actionedAt,
      eventType: eventType ?? this.eventType,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'requested_at': requestedAt.toIso8601String(),
    'original_time': originalTime,
    'new_time': newTime,
    'actioned_by': actionedBy,
    'actioned_at': actionedAt?.toIso8601String(),
    'event_type': eventType,
  };

  factory AttendanceEditRequest.fromJson(Map<String, dynamic> json) {
    final statusRaw =
        (json['status'] ??
                json['state'] ??
                json['request_status'] ??
                json['approval_status'] ??
                'pending')
            .toString()
            .toLowerCase()
            .trim();

    final status = switch (statusRaw) {
      'approved' || 'approve' || 'accepted' || 'done' || 'completed' =>
        AttendanceEditRequestStatus.approved,
      'rejected' || 'reject' || 'declined' || 'denied' =>
        AttendanceEditRequestStatus.rejected,
      _ => AttendanceEditRequestStatus.pending,
    };

    DateTime? parseDt(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      // "2026-08-10 09:34:52" → make ISO-ish
      final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
      return DateTime.tryParse(normalized) ?? DateTime.tryParse(s);
    }

    String formatTime(dynamic raw) {
      if (raw == null) return '--';
      final s = raw.toString().trim();
      if (s.isEmpty) return '--';

      // Already a friendly label.
      if (s.toLowerCase().contains('am') || s.toLowerCase().contains('pm')) {
        return s;
      }

      final asDt = parseDt(s);
      if (asDt != null && (s.contains('-') || s.contains('T') || s.contains(' '))) {
        return _formatClock(asDt);
      }

      final parts = s.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return _formatClock(DateTime(2000, 1, 1, h, m));
      }
      return s;
    }

    return AttendanceEditRequest(
      status: status,
      requestedAt:
          parseDt(
            json['requested_at'] ??
                json['requestedAt'] ??
                json['created_at'] ??
                json['createdAt'],
          ) ??
          DateTime.now(),
      originalTime: formatTime(
        json['old_value_label'] ??
            json['original_time'] ??
            json['originalTime'] ??
            json['old_time'] ??
            json['from_time'] ??
            json['previous_time'] ??
            json['old_value'],
      ),
      newTime: formatTime(
        json['new_value_label'] ??
            json['new_time'] ??
            json['newTime'] ??
            json['requested_time'] ??
            json['proposed_time'] ??
            json['to_time'] ??
            json['attendance_time'] ??
            json['new_value'],
      ),
      actionedBy:
          (json['updated_by_name'] ??
                  json['actioned_by'] ??
                  json['actionedBy'] ??
                  json['reviewed_by'] ??
                  json['approved_by'] ??
                  json['rejected_by'] ??
                  json['reviewed_by_name'] ??
                  json['actioned_by_name'])
              ?.toString(),
      actionedAt: parseDt(
        json['actioned_at'] ??
            json['actionedAt'] ??
            json['reviewed_at'] ??
            json['approved_at'] ??
            json['rejected_at'] ??
            json['updated_at'],
      ),
      eventType: (json['event_type'] ?? json['eventType'] ?? json['type'])
          ?.toString(),
    );
  }

  /// Builds history rows from both `change_requests` and `changes` arrays
  /// on an attendance detail item. Newest first.
  static List<AttendanceEditRequest> fromDetailArrays({
    dynamic changeRequests,
    dynamic changes,
  }) {
    final out = <AttendanceEditRequest>[];
    final seenKeys = <String>{};

    void addAll(dynamic raw, {AttendanceEditRequestStatus? defaultStatus}) {
      if (raw is! List) return;
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final key = _dedupeKey(map);
        if (!seenKeys.add(key)) continue;
        var parsed = AttendanceEditRequest.fromJson(map);
        if (defaultStatus != null &&
            !map.containsKey('status') &&
            !map.containsKey('state') &&
            !map.containsKey('request_status') &&
            !map.containsKey('approval_status')) {
          parsed = parsed.copyWith(status: defaultStatus);
        }
        out.add(parsed);
      }
    }

    // Applied changes without an explicit status → treat as approved.
    addAll(changes, defaultStatus: AttendanceEditRequestStatus.approved);
    addAll(changeRequests);

    out.sort((a, b) {
      final aAt = a.actionedAt ?? a.requestedAt;
      final bAt = b.actionedAt ?? b.requestedAt;
      return bAt.compareTo(aAt);
    });
    return out;
  }

  static List<AttendanceEditRequest> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AttendanceEditRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static String _dedupeKey(Map<String, dynamic> map) {
    final id = map['id'];
    if (id != null) return 'id:$id';
    return [
      map['old_value'],
      map['new_value'],
      map['status'],
      map['created_at'],
    ].join('|');
  }

  static String _formatClock(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }
}
