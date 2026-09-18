import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/join/data/join_invite_store.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/join/services/join_device_auto_approve.dart';
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

  test('manual join is account-approved so first device can auto-approve',
      () async {
    final created = await provider.sendManualInvites(
      rows: [
        (
          contact: 'a@b.com',
          channel: JoinInviteChannel.email,
          locationId: 'head',
          locationName: 'Head Office',
        ),
      ],
    );
    final joined = await provider.completeJoin(
      created.first.id,
      contact: 'a@b.com',
    );
    expect(JoinDeviceAutoApprove.isAccountApproved(joined), isTrue);
  });

  test('via-link join waits for account approve before device can auto-approve',
      () async {
    final link = await provider.prepareLinkShare();
    final joined = await provider.completeJoin(link.id);
    expect(JoinDeviceAutoApprove.isAccountApproved(joined), isFalse);

    final approved = await provider.reviewJoin(id: link.id, approve: true);
    expect(JoinDeviceAutoApprove.isAccountApproved(approved), isTrue);
  });

  test('rejected account is not treated as approved for device', () async {
    final link = await provider.prepareLinkShare();
    await provider.completeJoin(link.id);
    await provider.reviewJoin(id: link.id, approve: false);
    expect(
      JoinDeviceAutoApprove.isAccountApproved(provider.activeInvite),
      isFalse,
    );
  });
}
