import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/models/device_model.dart';

void main() {
  group('DeviceModel current-device matching', () {
    test('matches by persistent device_id even when server id differs', () {
      final device = DeviceModel.fromJson({
        'id': '12',
        'device_id': 'stable-uuid',
        'name': 'A36',
        'approval_status': 'approved',
      });

      expect(device.matchesDeviceId('stable-uuid'), isTrue);
      expect(device.matchesDeviceId('12'), isTrue);
      expect(device.matchesDeviceId('other'), isFalse);
    });

    test('treats Samsung A36 as the same phone when device_id is missing', () {
      final approved = DeviceModel.fromJson({
        'id': '4',
        'name': 'A36',
        'model': 'SM-A366B',
        'manufacturer': 'samsung',
        'platform': 'android',
        'approval_status': 'approved',
      });

      expect(
        approved.matchesPhysicalDevice(
          currentDeviceId: 'new-uuid-after-reopen',
          model: 'SM-A366B',
          manufacturer: 'samsung',
          platform: 'android',
          name: 'a36xq',
        ),
        isTrue,
      );
      expect(approved.hasExistingRegistration, isTrue);
      expect(approved.isApproved, isTrue);
    });

    test('does not treat A36 and an emulator as the same device', () {
      final a36 = DeviceModel.fromJson({
        'id': '4',
        'name': 'A36',
        'approval_status': 'approved',
        'platform': 'android',
      });

      expect(
        a36.matchesPhysicalDevice(
          currentDeviceId: 'emu-uuid',
          name: 'emu64xa16k',
          platform: 'android',
        ),
        isFalse,
      );
    });

    test('picks the approved A36 over a newer pending row for the same phone', () {
      final devices = [
        DeviceModel.fromJson({
          'id': '1',
          'device_id': 'fresh-uuid',
          'name': 'A36',
          'model': 'SM-A366B',
          'platform': 'android',
          'approval_status': 'pending',
        }),
        DeviceModel.fromJson({
          'id': '2',
          'device_id': 'old-uuid',
          'name': 'A36',
          'model': 'SM-A366B',
          'platform': 'android',
          'approval_status': 'approved',
        }),
      ];

      final marked = DeviceModel.markCurrentDevice(
        devices,
        currentDeviceId: 'fresh-uuid',
        model: 'SM-A366B',
        manufacturer: 'samsung',
        platform: 'android',
        name: 'a36xq',
      );

      final current = marked.firstWhere((d) => d.isCurrent);
      expect(current.id, '2');
      expect(current.isApproved, isTrue);
      expect(marked.where((d) => d.isCurrent), hasLength(1));
    });

    test('does not register again when this phone is already Active', () {
      final listed = DeviceModel.fromJson({
        'id': '2',
        'name': 'A36',
        'model': 'SM-A366B',
        'platform': 'android',
        'approval_status': 'approved',
      });
      final current = DeviceModel.pickCurrent(
        [listed],
        currentDeviceId: 'phone-uuid',
        model: 'SM-A366B',
        manufacturer: 'samsung',
        platform: 'android',
        name: 'a36xq',
      );

      expect(current, isNotNull);
      expect(current!.hasExistingRegistration, isTrue);
      expect(current.isApproved, isTrue);
    });

    test('does not register again when a request is already pending', () {
      final listed = DeviceModel.fromJson({
        'id': '9',
        'name': 'A36',
        'platform': 'android',
        'approval_status': 'pending',
      });
      final current = DeviceModel.pickCurrent(
        [listed],
        currentDeviceId: 'phone-uuid',
        name: 'A36',
        platform: 'android',
      );

      expect(current, isNotNull);
      expect(current!.isPending, isTrue);
      expect(current.hasExistingRegistration, isTrue);
    });
  });
}
