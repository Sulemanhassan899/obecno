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

  LeaveTypeInfo copyWith({int? available}) {
    return LeaveTypeInfo(
      id: id,
      name: name,
      available: available ?? this.available,
      total: total,
      resetLabel: resetLabel,
      requiresDocument: requiresDocument,
      accent: accent,
    );
  }
}

enum LeaveTypeAccent { red, purple, green, blue, grey }

class LeaveHoliday {
  const LeaveHoliday({
    required this.date,
    required this.name,
    this.days = 1,
  });

  final DateTime date;
  final String name;
  final int days;
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

  bool coversDate(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  LeaveRequest copyWith({
    String? typeId,
    String? typeName,
    DateTime? startDate,
    DateTime? endDate,
    LeaveRequestStatus? status,
    String? note,
    List<LeaveTimelineEvent>? timeline,
    String? documentName,
    bool clearDocument = false,
  }) {
    return LeaveRequest(
      id: id,
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt,
      timeline: timeline ?? this.timeline,
      documentName: clearDocument ? null : (documentName ?? this.documentName),
    );
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
}
