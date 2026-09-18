import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/alerts/data/models/device_alert_item.dart';
import 'package:obecno/features/more/data/models/device_model.dart';

void main() {
  DeviceModel device({String status = 'pending'}) {
    return DeviceModel(
      id: '1',
      deviceId: 'dev-1',
      name: 'iPhone 16',
      model: 'iPhone',
      manufacturer: 'Apple',
      os: 'iOS',
      osVersion: '18',
      appVersion: '1.0',
      ipAddress: '',
      timezone: 'UTC',
      platform: 'ios',
      status: status,
    );
  }

  test('device alert item describes pending and approved requests', () {
    final pending = DeviceAlertItem(
      device: device(),
      employeeName: 'Alex',
      employeeUserId: 7,
    );
    expect(
      pending.title(isManagerView: true),
      'Alex has requested for new device approval',
    );
    expect(pending.placeLabel(isManagerView: true), 'iPhone 16');
    expect(
      DeviceAlertItem(
        device: device(),
        employeeName: 'Alex',
        locationName: 'Head Office',
      ).placeLabel(isManagerView: false),
      'iPhone 16',
    );
    expect(
      DeviceAlertItem(
        device: device(),
        employeeName: 'Alex',
        locationName: 'Head Office',
      ).placeLabel(isManagerView: true),
      'Head Office',
    );
    expect(pending.key, '7-1');

    final approved = DeviceAlertItem(
      device: device(status: 'approved'),
      employeeName: 'Alex',
    );
    expect(
      approved.title(isManagerView: true),
      'Alex has requested for new device approval',
    );
  });
}
