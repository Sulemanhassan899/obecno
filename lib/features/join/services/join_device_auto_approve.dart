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

  /// Previously marked the device approved in memory for local-invite
  /// sessions. That bypassed server device approval and is intentionally
  /// disabled — approval must come from `/employee/devices` only.
  static void sync({
    required AuthProvider auth,
    required JoinInviteProvider join,
    required DeviceProvider devices,
  }) {
    // No-op: never trust client-only device approval.
  }
}
