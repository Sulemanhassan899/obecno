import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';

class SmartDecision {
  const SmartDecision({
    this.autoPunch,
    this.premisesAlert,
    this.skipPremisesBecauseAuto = false,
  });

  final AutoPunchKind? autoPunch;
  final AlertDecision? premisesAlert;
  final bool skipPremisesBecauseAuto;

  bool get hasAutoPunch => autoPunch != null;
  bool get hasPremisesAlert =>
      !skipPremisesBecauseAuto && premisesAlert != null && premisesAlert!.send;
}

PresenceZone? presenceFrom(FlagValue? value) {
  if (value == FlagValue.inside) return PresenceZone.inside;
  if (value == FlagValue.outside) return PresenceZone.outside;
  return null;
}

/// Decides auto-punch + premises reminders from one GPS match (shared path).
SmartDecision decideSmartAttendance({
  required SmartAttendanceSettings settings,
  required MatchResult match,
  required AttendancePhase phase,
  required PolicyWindow policy,
  required DateTime now,
  required PresenceZone? previousPresence,
}) {
  final current = presenceFrom(match.value);
  AutoPunchKind? autoPunch;
  var skipPremises = false;

  if (settings.smartAttendance && current != null) {
    // Already on premises (or first fix / enter) while not punched → check in.
    if (current == PresenceZone.inside &&
        phase == AttendancePhase.notCheckedIn) {
      autoPunch = AutoPunchKind.checkIn;
      skipPremises = true;
    } else if (current == PresenceZone.outside &&
        (phase == AttendancePhase.working || phase == AttendancePhase.onBreak) &&
        (previousPresence == null ||
            previousPresence == PresenceZone.inside)) {
      // Leave checkout (grace does not block). Also covers restart while outside.
      autoPunch = AutoPunchKind.checkOut;
      skipPremises = true;
    }
  }

  AlertDecision? premises;
  if (settings.premisesNotifications && match.value == FlagValue.inside) {
    final name = (match.matched == null || match.matched!.name.isEmpty)
        ? 'assigned office'
        : match.matched!.name;
    if (phase == AttendancePhase.notCheckedIn) {
      premises = AlertDecision(
        violation: false,
        type: AlertType.premisesCheckIn,
        message: 'You are in office $name premises please check in',
      );
    } else if ((phase == AttendancePhase.working ||
            phase == AttendancePhase.onBreak) &&
        policy.pastCheckoutWithGrace(now)) {
      premises = AlertDecision(
        violation: false,
        type: AlertType.premisesCheckOut,
        message: 'You are in office $name premises please check out',
      );
    }
  }

  return SmartDecision(
    autoPunch: autoPunch,
    premisesAlert: premises,
    skipPremisesBecauseAuto: skipPremises,
  );
}

/// Premises banners are once per 5-minute slot — not again on shade swipe/resume.
bool premisesNotifiedInSlot({
  required AlertType type,
  required DateTime now,
  DateTime? lastNotifySlot,
  AlertType? lastNotifyType,
  Iterable<FlagAlert> existingAlerts = const [],
}) {
  final slotMs = slotStart(now).millisecondsSinceEpoch;
  if (lastNotifySlot?.millisecondsSinceEpoch == slotMs &&
      lastNotifyType == type) {
    return true;
  }
  for (final alert in existingAlerts) {
    if (alert.type != type) continue;
    if (slotStart(alert.timestamp).millisecondsSinceEpoch == slotMs) {
      return true;
    }
  }
  return false;
}
