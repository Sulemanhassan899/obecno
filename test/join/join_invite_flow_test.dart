import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/join/data/join_invite_store.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('manual invite flow', () {
    test('send invite stores credentials and auto-approves on join', () async {
      final created = await provider.sendManualInvites(
        rows: [
          (
            contact: 'employee@email.com',
            channel: JoinInviteChannel.email,
            locationId: 'head',
            locationName: 'Head Office',
          ),
        ],
        companyName: 'Acme Corporation',
      );

      expect(created, hasLength(1));
      expect(created.first.password, isEmpty);
      expect(created.first.source, JoinInviteSource.manual);
      expect(created.first.status, JoinInviteStatus.invited);

      // Local passwords are not stored — credential match always fails.
      final match = provider.matchCredentials(
        contact: 'employee@email.com',
        password: 'any-password',
      );
      expect(match, isNull);

      final joined = await provider.completeJoin(
        created.first.id,
        contact: 'employee@email.com',
      );
      expect(joined?.status, JoinInviteStatus.autoApproved);
      expect(provider.showUnverifiedBanner, isFalse);

      final alerts = provider.managerAlerts();
      expect(alerts, hasLength(1));
      expect(alerts.first.status, JoinInviteStatus.autoApproved);
    });
  });

  group('via-link flow', () {
    test(
      'share creates temp email+password and stays pending until approve',
      () async {
        final link = await provider.prepareLinkShare(companyName: 'TheDemo');
        expect(link.source, JoinInviteSource.link);
        expect(AddEmployeePayloadish.isValidEmail(link.contact), isTrue);
        expect(link.password, isEmpty);
        expect(provider.hasOpenLinkInvite, isTrue);

        final match = provider.matchCredentials(
          contact: link.contact,
          password: 'any-password',
        );
        expect(match, isNull);

        final joined = await provider.completeJoin(link.id);
        expect(joined?.status, JoinInviteStatus.pendingApproval);
        expect(provider.showUnverifiedBanner, isTrue);

        final approved = await provider.reviewJoin(id: link.id, approve: true);
        expect(approved?.status, JoinInviteStatus.approved);

        await provider.assignLocation(
          id: link.id,
          locationId: 'north',
          locationName: 'North Office',
        );
        expect(provider.byIdSafe(link.id)?.locationName, 'North Office');
        expect(provider.showUnverifiedBanner, isFalse);
      },
    );

    test('reject removes pending verification banner path', () async {
      final link = await provider.prepareLinkShare();
      await provider.completeJoin(link.id);
      expect(provider.showUnverifiedBanner, isTrue);

      await provider.reviewJoin(id: link.id, approve: false);
      expect(provider.activeInvite?.status, JoinInviteStatus.rejected);
      expect(provider.showUnverifiedBanner, isFalse);
    });
  });

  test('share message has install/invite links and no credentials', () {
    final message = JoinShareLinks.shareMessage(companyName: 'TheDemo');
    expect(message, contains(JoinShareLinks.downloadApk));
    expect(message, contains(JoinShareLinks.displayInviteLink));
    expect(message, contains(JoinShareLinks.appDeepLink));
    expect(message, isNot(contains('Password:')));
    expect(message, isNot(contains('Email:')));
    expect(message, isNot(contains('obecno.com/download/demo')));
    expect(message, contains("You're invited to join TheDemo on Obecno."));
  });
}

/// Local helper so the test file does not import the payload module.
class AddEmployeePayloadish {
  static final emailPattern = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
  static bool isValidEmail(String email) => emailPattern.hasMatch(email.trim());
}

extension on JoinInviteProvider {
  JoinInviteRecord? byIdSafe(String id) {
    for (final record in records) {
      if (record.id == id) return record;
    }
    return null;
  }
}
