import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/join/data/join_invite_store.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scenario matrix mirroring the two-device manager/employee QA scripts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JoinInviteStore store;
  late JoinInviteProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = JoinInviteStore.instance;
    await store.debugReset();
    provider = JoinInviteProvider(store: store);
    await provider.ensureLoaded();
  });

  tearDown(() async {
    await store.debugReset();
  });

  /// Scenario 1 — via-link: pending → manager approve + assign location
  test('S1 link invite stays pending until manager approves and assigns office',
      () async {
    final link = await provider.prepareLinkShare(companyName: 'Acme');
    final message = provider.buildShareMessage(companyName: 'Acme');
    expect(message, contains(JoinShareLinks.downloadApk));
    expect(message, contains(JoinShareLinks.displayInviteLink));
    expect(message, isNot(contains('Password:')));
    expect(message, isNot(contains('Email: ${link.contact}')));

    // Local invite passwords are no longer stored — credentials match fails.
    expect(
      provider.matchCredentials(
        contact: link.contact,
        password: 'any',
      ),
      isNull,
    );

    final joined = await provider.completeJoin(link.id);
    expect(joined?.status, JoinInviteStatus.pendingApproval);
    expect(provider.showUnverifiedBanner, isTrue);

    final alerts = provider.managerAlerts();
    expect(alerts.any((a) => a.status == JoinInviteStatus.pendingApproval),
        isTrue);

    await provider.reviewJoin(id: link.id, approve: true);
    await provider.assignLocation(
      id: link.id,
      locationId: 'head',
      locationName: 'Head Office',
    );

    expect(provider.byId(link.id)?.status, JoinInviteStatus.approved);
    expect(provider.byId(link.id)?.locationName, 'Head Office');
    expect(provider.showUnverifiedBanner, isFalse);
  });

  /// Scenario 2 — manual email + default location → auto-approved → dashboard
  test('S2 manual invite with default location auto-approves on join',
      () async {
    final created = await provider.sendManualInvites(
      rows: [
        (
          contact: 'employee@email.com',
          channel: JoinInviteChannel.email,
          locationId: 'head',
          locationName: 'Head Office',
        ),
      ],
      companyName: 'Acme',
    );
    final invite = created.first;

    final joined = await provider.completeJoin(
      invite.id,
      contact: 'employee@email.com',
    );
    expect(joined?.status, JoinInviteStatus.autoApproved);
    expect(provider.showUnverifiedBanner, isFalse);

    final alerts = provider.managerAlerts();
    expect(alerts, hasLength(1));
    expect(alerts.first.status, JoinInviteStatus.autoApproved);
    expect(alerts.first.locationName, 'Head Office');
  });

  /// Scenario 3 — via-link: manager rejects join request
  test('S3 link invite rejected clears unverified banner', () async {
    final link = await provider.prepareLinkShare();
    await provider.completeJoin(link.id);
    expect(provider.showUnverifiedBanner, isTrue);

    await provider.reviewJoin(id: link.id, approve: false);
    expect(provider.byId(link.id)?.status, JoinInviteStatus.rejected);
    expect(provider.showUnverifiedBanner, isFalse);

    // Local passwords are not stored — match never succeeds.
    expect(
      provider.matchCredentials(
        contact: link.contact,
        password: 'any',
      ),
      isNull,
    );
  });

  /// Scenario 4 — local invite credentials are never matched
  test('S4 invite credentials are not stored locally', () async {
    await provider.sendManualInvites(
      rows: [
        (
          contact: 'worker@acme.com',
          channel: JoinInviteChannel.email,
          locationId: 'north',
          locationName: 'North Office',
        ),
      ],
    );

    expect(
      provider.matchCredentials(
        contact: 'worker@acme.com',
        password: 'TotallyWrong',
      ),
      isNull,
    );
    expect(
      provider.matchCredentials(
        contact: 'worker@acme.com',
        password: '',
      ),
      isNull,
    );
  });

  /// Scenario 5 — approve without assigning location (dismiss sheet)
  test('S5 approve without location assignment leaves location empty',
      () async {
    final link = await provider.prepareLinkShare();
    await provider.completeJoin(link.id);
    await provider.reviewJoin(id: link.id, approve: true);

    expect(provider.byId(link.id)?.status, JoinInviteStatus.approved);
    expect(provider.byId(link.id)?.locationName, isNull);
    expect(provider.showUnverifiedBanner, isFalse);
  });

  /// Scenario 6 — re-join after already approved overwrites status
  test('S6 re-joining after approval can overwrite approved status', () async {
    final created = await provider.sendManualInvites(
      rows: [
        (
          contact: 'again@acme.com',
          channel: JoinInviteChannel.email,
          locationId: 'head',
          locationName: 'Head Office',
        ),
      ],
    );
    final id = created.first.id;
    await provider.completeJoin(id, contact: 'again@acme.com');
    expect(provider.byId(id)?.status, JoinInviteStatus.autoApproved);

    // Simulate signing in again / completeJoin again.
    final again = await provider.completeJoin(id, contact: 'again@acme.com');
    expect(again?.status, JoinInviteStatus.autoApproved);
  });

  /// Scenario 7 — open link invite gates any email past checkEmail
  test('S7 open link invite sets hasOpenLinkInvite gate', () async {
    expect(provider.hasOpenLinkInvite, isFalse);
    await provider.prepareLinkShare();
    expect(provider.hasOpenLinkInvite, isTrue);
  });

  /// Scenario 8 — share payload shape for WhatsApp handoff
  test('S8 share message has apk + invite links and no credentials', () {
    final message = JoinShareLinks.shareMessage(companyName: 'TheDemo');
    expect(message, contains(JoinShareLinks.downloadApk));
    expect(message, contains(JoinShareLinks.displayInviteLink));
    expect(message, contains(JoinShareLinks.appDeepLink));
    expect(message, isNot(contains('Password:')));
    expect(message, isNot(contains('Email:')));
    expect(message, contains("You're invited to join TheDemo on Obecno."));
  });
}

extension on JoinInviteProvider {
  JoinInviteRecord? byId(String id) {
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }
}
