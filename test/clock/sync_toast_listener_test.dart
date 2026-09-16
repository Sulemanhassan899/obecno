import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/clock/services/sync_service.dart';
import 'package:obecno/features/clock/services/sync_toast_listener.dart';

void main() {
  test('SyncToastListener shows Syncing then Synced', () async {
    var syncing = 0;
    var syncedOk = 0;
    final listener = SyncToastListener(
      minSyncingVisible: Duration.zero,
      onSyncing: () => syncing++,
      onSynced: ({required bool success}) {
        if (success) syncedOk++;
      },
    );

    listener.handle(SyncState.syncing);
    listener.handle(SyncState.success);
    listener.handle(SyncState.idle);
    await Future<void>.delayed(Duration.zero);

    expect(syncing, 1);
    expect(syncedOk, 1);
    listener.dispose();
  });

  test('SyncToastListener shows failure as unsuccessful sync', () async {
    var syncedCalls = <bool>[];
    final listener = SyncToastListener(
      minSyncingVisible: Duration.zero,
      onSyncing: () {},
      onSynced: ({required bool success}) => syncedCalls.add(success),
    );

    listener.handle(SyncState.syncing);
    listener.handle(SyncState.failure);
    await Future<void>.delayed(Duration.zero);

    expect(syncedCalls, [false]);
    listener.dispose();
  });
}
