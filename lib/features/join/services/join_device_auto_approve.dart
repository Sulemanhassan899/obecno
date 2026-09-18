import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/more/providers/device_provider.dart';

/// Join-invite only: account approval also covers the first device.
///
/// Does not create a separate device-request alert or call the normal
/// device-request register/check APIs.
class JoinDeviceAutoApprove {
  JoinDeviceAutoApprove._();

  static bool isAccountApproved(JoinInviteRecord? invite) {
    if (invite == null) return false;
    return invite.status == JoinInviteStatus.autoApproved ||
        invite.status == JoinInviteStatus.approved;
  }

  /// When this phone is a local-invite employee session and the invite
  /// account is already approved (manual auto-approve, or manager approved
  /// a via-link join), mark the current device approved locally.
  static void sync({
    required AuthProvider auth,
    required JoinInviteProvider join,
    required DeviceProvider devices,
  }) {
    if (!auth.isLocalInviteSession) return;
    if (!isAccountApproved(join.activeInvite)) return;
    devices.markApprovedForLocalInvite();
  }
}
