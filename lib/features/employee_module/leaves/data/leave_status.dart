import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';

/// Canonical leave status vocabulary for employee + manager leave UIs.
///
/// Contract (product):
/// - pending  → waiting for manager action
/// - approved → counts as on leave
/// - rejected → cancelled / denied / declined
///
/// Unknown raw strings map to [LeaveRequestStatus.pending] only when they
/// clearly look pending; otherwise prefer approved for blank historical rows
/// only when [assumeApprovedQuery] is true (query already filtered).
class LeaveStatusCanon {
  LeaveStatusCanon._();

  static LeaveRequestStatus fromRaw(
    String? raw, {
    bool assumeApprovedQuery = false,
  }) {
    final value = (raw ?? '').trim().toLowerCase().replaceAll(' ', '_');
    if (value.isEmpty) {
      return assumeApprovedQuery
          ? LeaveRequestStatus.approved
          : LeaveRequestStatus.pending;
    }
    if (value.contains('reject') ||
        value.contains('denied') ||
        value.contains('deny') ||
        value.contains('decline') ||
        value.contains('cancel')) {
      return LeaveRequestStatus.rejected;
    }
    if (value.contains('pend') ||
        value.contains('request') ||
        value.contains('await') ||
        value.contains('submit') ||
        value == '0' ||
        value == 'false' ||
        value == 'new') {
      return LeaveRequestStatus.pending;
    }
    if (value.contains('approv') ||
        value.contains('accept') ||
        value == '1' ||
        value == 'true') {
      return LeaveRequestStatus.approved;
    }
    return LeaveRequestStatus.pending;
  }
}
