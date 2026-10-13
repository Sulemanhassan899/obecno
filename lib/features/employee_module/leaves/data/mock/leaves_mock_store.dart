import 'package:flutter/foundation.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

/// In-memory employee leaves data for UI-only builds.
class LeavesMockStore extends ChangeNotifier {
  LeavesMockStore._() {
    _seed();
  }

  static final LeavesMockStore instance = LeavesMockStore._();

  final List<LeaveTypeInfo> _types = [];
  final List<LeaveRequest> _requests = [];
  final List<LeaveHoliday> _holidays = [];
  String quotaResetLabel = 'Leaves quota will be reset on 01 Jan 2027';
  int _seq = 100;

  List<LeaveTypeInfo> get types => List.unmodifiable(_types);
  List<LeaveRequest> get requests {
    final sorted = List<LeaveRequest>.from(_requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<LeaveHoliday> get holidays => List.unmodifiable(_holidays);

  int get totalAvailable =>
      _types.fold<int>(0, (sum, type) => sum + type.available);

  LeaveBalancesSummary get balances {
    LeaveTypeInfo? byName(String needle) {
      for (final type in _types) {
        if (type.name.toLowerCase().contains(needle)) return type;
      }
      return null;
    }

    final casual = byName('casual');
    final sick = byName('sick');
    final allAvailable = totalAvailable;
    final allTotal = _types.fold<int>(0, (sum, type) => sum + type.total);
    return LeaveBalancesSummary(
      allAvailable: allAvailable,
      allTotal: allTotal,
      casualAvailable: casual?.available ?? 0,
      casualTotal: casual?.total ?? 0,
      sickAvailable: sick?.available ?? 0,
      sickTotal: sick?.total ?? 0,
    );
  }

  LeaveTypeInfo? typeById(String id) {
    for (final type in _types) {
      if (type.id == id) return type;
    }
    return null;
  }

  LeaveRequest? requestById(String id) {
    for (final request in _requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  /// All timeline-worthy leave cards for a calendar day (stacked, never merged).
  List<LeaveTimelineEvent> timelineEventsForDay(DateTime day) {
    final events = <LeaveTimelineEvent>[];
    for (final request in requests) {
      if (!request.coversDate(day)) continue;
      events.addAll(request.timeline);
    }
    events.sort((a, b) => b.at.compareTo(a.at));
    return events;
  }

  List<LeaveRequest> requestsForDay(DateTime day) {
    return [
      for (final request in requests)
        if (request.coversDate(day)) request,
    ];
  }

  LeaveRequest? requestForTimelineEvent(String eventId) {
    for (final request in _requests) {
      for (final event in request.timeline) {
        if (event.id == eventId) return request;
      }
    }
    return null;
  }

  LeaveRequest applyLeave({
    required String typeId,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? documentName,
  }) {
    final type = typeById(typeId);
    if (type == null) {
      throw StateError('Unknown leave type: $typeId');
    }
    final now = DateTime.now();
    final id = 'leave_${_seq++}';
    final request = LeaveRequest(
      id: id,
      typeId: type.id,
      typeName: type.name,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      status: LeaveRequestStatus.pending,
      note: note.trim().isEmpty
          ? "I've been feeling unwell due to frequent business trips."
          : note.trim(),
      createdAt: now,
      documentName: documentName,
      timeline: [
        LeaveTimelineEvent(
          id: '${id}_requested',
          kind: LeaveTimelineKind.requested,
          at: now,
        ),
      ],
    );
    _requests.insert(0, request);
    notifyListeners();
    return request;
  }

  LeaveRequest? updateLeave({
    required String requestId,
    required String typeId,
    required DateTime startDate,
    required DateTime endDate,
    required String note,
    String? documentName,
    bool clearDocument = false,
  }) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return null;
    final existing = _requests[index];
    if (!existing.isPending) return existing;

    final type = typeById(typeId);
    if (type == null) return existing;

    final updated = existing.copyWith(
      typeId: type.id,
      typeName: type.name,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      note: note.trim(),
      documentName: documentName,
      clearDocument: clearDocument,
    );
    _requests[index] = updated;
    notifyListeners();
    return updated;
  }

  bool deleteLeave(String requestId) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return false;
    if (!_requests[index].isPending) return false;
    _requests.removeAt(index);
    notifyListeners();
    return true;
  }

  void _seed() {
    _types.addAll(const [
      LeaveTypeInfo(
        id: 'casual',
        name: 'Casual Leaves',
        available: 1,
        total: 10,
        accent: LeaveTypeAccent.red,
      ),
      LeaveTypeInfo(
        id: 'sick',
        name: 'Sick Leaves',
        available: 6,
        total: 10,
        requiresDocument: true,
        accent: LeaveTypeAccent.purple,
      ),
      LeaveTypeInfo(
        id: 'emergency',
        name: 'Emergency Leaves',
        available: 6,
        total: 10,
        accent: LeaveTypeAccent.green,
      ),
      LeaveTypeInfo(
        id: 'marriage',
        name: 'Marriage',
        available: 10,
        total: 10,
        resetLabel: 'One time',
        accent: LeaveTypeAccent.grey,
      ),
      LeaveTypeInfo(
        id: 'misc',
        name: 'Miscellaneous leave',
        available: 10,
        total: 10,
        accent: LeaveTypeAccent.blue,
      ),
      LeaveTypeInfo(
        id: 'paternity',
        name: 'Paternity leave',
        available: 2,
        total: 5,
        accent: LeaveTypeAccent.purple,
      ),
      LeaveTypeInfo(
        id: 'bereavement',
        name: 'Bereavement leave',
        available: 1,
        total: 3,
        accent: LeaveTypeAccent.red,
      ),
    ]);

    _holidays.addAll([
      LeaveHoliday(
        date: DateTime(2026, 1, 1),
        name: "New Year's Day",
      ),
      LeaveHoliday(
        date: DateTime(2026, 3, 21),
        name: 'Eid-ul-Fitr (Expected)',
        days: 3,
      ),
      LeaveHoliday(
        date: DateTime(2026, 3, 23),
        name: 'Pakistan Day',
      ),
      LeaveHoliday(
        date: DateTime(2026, 5, 1),
        name: 'Labour Day',
      ),
      LeaveHoliday(
        date: DateTime(2026, 8, 14),
        name: 'Independence Day',
      ),
      LeaveHoliday(
        date: DateTime(2026, 12, 25),
        name: 'Christmas Day',
      ),
      LeaveHoliday(
        date: DateTime(2027, 1, 1),
        name: "New Year's Day",
      ),
    ]);

    final approved = LeaveRequest(
      id: 'leave_seed_approved',
      typeId: 'sick',
      typeName: 'Sick Leave',
      startDate: DateTime(2025, 10, 12),
      endDate: DateTime(2025, 10, 14),
      status: LeaveRequestStatus.approved,
      note: "I've been feeling unwell due to frequent business trips.",
      createdAt: DateTime(2025, 10, 10, 10, 23),
      documentName: 'Filename etc.',
      timeline: [
        LeaveTimelineEvent(
          id: 'leave_seed_approved_ok',
          kind: LeaveTimelineKind.approved,
          at: DateTime(2025, 10, 17, 22, 23),
          actorName: 'James May',
        ),
        LeaveTimelineEvent(
          id: 'leave_seed_approved_req',
          kind: LeaveTimelineKind.requested,
          at: DateTime(2025, 10, 10, 10, 23),
        ),
      ],
    );

    final pending = LeaveRequest(
      id: 'leave_seed_pending',
      typeId: 'sick',
      typeName: 'Sick Leave',
      startDate: DateTime(2025, 10, 12),
      endDate: DateTime(2025, 10, 14),
      status: LeaveRequestStatus.pending,
      note: "I've been feeling unwell due to frequent business trips.",
      createdAt: DateTime(2025, 10, 11, 9, 0),
      documentName: 'Filename etc.',
      timeline: [
        LeaveTimelineEvent(
          id: 'leave_seed_pending_req',
          kind: LeaveTimelineKind.requested,
          at: DateTime(2025, 10, 17, 22, 23),
        ),
      ],
    );

    final rejected = LeaveRequest(
      id: 'leave_seed_rejected',
      typeId: 'casual',
      typeName: 'Casual Leave',
      startDate: DateTime(2025, 8, 12),
      endDate: DateTime(2025, 8, 14),
      status: LeaveRequestStatus.rejected,
      note: 'Need time off for personal errands.',
      createdAt: DateTime(2025, 8, 8, 12, 0),
      timeline: [
        LeaveTimelineEvent(
          id: 'leave_seed_rejected_rej',
          kind: LeaveTimelineKind.rejected,
          at: DateTime(2025, 8, 10, 22, 23),
          actorName: 'James May',
          reason:
              'The deadline cannot be extended due to previously scheduled business travel.',
        ),
        LeaveTimelineEvent(
          id: 'leave_seed_rejected_req',
          kind: LeaveTimelineKind.requested,
          at: DateTime(2025, 8, 8, 12, 0),
        ),
      ],
    );

    // Extra stacked events on Oct 17 for attendance day sheet demos.
    final stackedA = LeaveRequest(
      id: 'leave_seed_oct17_a',
      typeId: 'sick',
      typeName: 'Sick Leave',
      startDate: DateTime(2025, 10, 17),
      endDate: DateTime(2025, 10, 17),
      status: LeaveRequestStatus.approved,
      note: 'Feeling unwell.',
      createdAt: DateTime(2025, 10, 16, 8, 0),
      timeline: [
        LeaveTimelineEvent(
          id: 'leave_seed_oct17_a_ok',
          kind: LeaveTimelineKind.approved,
          at: DateTime(2025, 10, 17, 22, 23),
          actorName: 'James May',
        ),
        LeaveTimelineEvent(
          id: 'leave_seed_oct17_a_req',
          kind: LeaveTimelineKind.requested,
          at: DateTime(2025, 10, 16, 10, 23),
        ),
      ],
    );

    final stackedB = LeaveRequest(
      id: 'leave_seed_oct17_b',
      typeId: 'casual',
      typeName: 'Casual Leave',
      startDate: DateTime(2025, 10, 17),
      endDate: DateTime(2025, 10, 17),
      status: LeaveRequestStatus.rejected,
      note: 'Family matter.',
      createdAt: DateTime(2025, 10, 15, 11, 0),
      timeline: [
        LeaveTimelineEvent(
          id: 'leave_seed_oct17_b_rej',
          kind: LeaveTimelineKind.rejected,
          at: DateTime(2025, 10, 17, 22, 23),
          actorName: 'James May',
          reason:
              'The deadline cannot be extended due to previously scheduled business travel.',
        ),
        LeaveTimelineEvent(
          id: 'leave_seed_oct17_b_req',
          kind: LeaveTimelineKind.requested,
          at: DateTime(2025, 10, 15, 11, 0),
        ),
      ],
    );

    final stackedC = LeaveRequest(
      id: 'leave_seed_oct17_c',
      typeId: 'emergency',
      typeName: 'Emergency Leave',
      startDate: DateTime(2025, 10, 17),
      endDate: DateTime(2025, 10, 17),
      status: LeaveRequestStatus.pending,
      note: 'Urgent personal matter.',
      createdAt: DateTime(2025, 10, 17, 9, 0),
      timeline: [
        LeaveTimelineEvent(
          id: 'leave_seed_oct17_c_req',
          kind: LeaveTimelineKind.requested,
          at: DateTime(2025, 10, 17, 22, 23),
        ),
      ],
    );

    _requests.addAll([
      pending,
      approved,
      rejected,
      stackedA,
      stackedB,
      stackedC,
    ]);
  }
}
