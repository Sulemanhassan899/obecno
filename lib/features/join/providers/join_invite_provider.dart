import 'package:flutter/foundation.dart';
import 'package:obecno/features/join/data/join_invite_store.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';

class JoinInviteProvider extends ChangeNotifier {
  JoinInviteProvider({JoinInviteStore? store})
      : _store = store ?? JoinInviteStore.instance;

  final JoinInviteStore _store;
  bool _ready = false;

  bool get isReady => _ready;
  List<JoinInviteRecord> get records => _store.records;
  JoinInviteRecord? get activeInvite => _store.activeInvite;

  /// Banner only for pending via-link joins (per product decision).
  bool get showUnverifiedBanner {
    final invite = activeInvite;
    if (invite == null) return false;
    return invite.source == JoinInviteSource.link &&
        invite.status == JoinInviteStatus.pendingApproval;
  }

  Future<void> ensureLoaded() async {
    await _store.ensureLoaded();
    _ready = true;
    notifyListeners();
  }

  Future<List<JoinInviteRecord>> sendManualInvites({
    required List<
            ({
              String contact,
              JoinInviteChannel channel,
              String locationId,
              String locationName
            })>
        rows,
    String companyName = 'Acme Corporation',
  }) async {
    final created = await _store.createManualInvites(
      rows: rows,
      companyName: companyName,
    );
    notifyListeners();
    return created;
  }

  Future<JoinInviteRecord> prepareLinkShare({
    String companyName = 'Acme Corporation',
  }) async {
    final record = await _store.createLinkInvitePlaceholder(
      companyName: companyName,
    );
    notifyListeners();
    return record;
  }

  bool hasLocalAccount(String contact) => _store.hasContact(contact);

  bool get hasOpenLinkInvite {
    return _store.records.any(
      (r) =>
          r.source == JoinInviteSource.link &&
          r.status == JoinInviteStatus.invited,
    );
  }

  JoinInviteRecord? matchCredentials({
    required String contact,
    required String password,
  }) {
    return _store.findByCredentials(contact: contact, password: password);
  }

  Future<JoinInviteRecord?> completeJoin(
    String inviteId, {
    String? contact,
  }) async {
    JoinInviteRecord? updated;
    if (contact != null && contact.trim().isNotEmpty) {
      updated = await _store.bindContactAndJoin(
        id: inviteId,
        contact: contact,
      );
    } else {
      updated = await _store.markJoined(inviteId);
    }
    notifyListeners();
    return updated;
  }

  Future<JoinInviteRecord?> reviewJoin({
    required String id,
    required bool approve,
  }) async {
    final updated = await _store.review(id: id, approve: approve);
    notifyListeners();
    return updated;
  }

  Future<void> assignLocation({
    required String id,
    required String locationId,
    required String locationName,
  }) async {
    await _store.assignLocation(
      id: id,
      locationId: locationId,
      locationName: locationName,
    );
    notifyListeners();
  }

  Future<void> setActiveInvite(String? id) async {
    await _store.setActiveInvite(id);
    notifyListeners();
  }

  Future<void> clearActiveInvite() async {
    await _store.clearActiveInvite();
    notifyListeners();
  }

  List<JoinInviteRecord> managerAlerts() => _store.managerAlertItems();

  String buildShareMessage({
    required String email,
    required String password,
    String companyName = 'Acme Corporation',
  }) {
    return JoinShareLinks.shareMessage(
      email: email,
      password: password,
      companyName: companyName,
    );
  }
}
