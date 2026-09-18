import 'package:obecno/features/more/data/models/device_model.dart';

class DeviceAlertItem {
  const DeviceAlertItem({
    required this.device,
    required this.employeeName,
    this.employeeUserId,
    this.email,
    this.locationName,
  });

  final DeviceModel device;
  final String employeeName;
  final int? employeeUserId;
  final String? email;
  final String? locationName;

  String get key {
    final id = device.id.isNotEmpty && device.id != '0'
        ? device.id
        : device.deviceId;
    return '${employeeUserId ?? 0}-$id';
  }

  String get _name {
    final value = employeeName.trim();
    return value.isEmpty ? 'Employee' : value;
  }

  String title({required bool isManagerView}) {
    if (isManagerView) {
      return '$_name has requested for new device approval';
    }
    return 'You have requested for new device approval';
  }

  String get requestType => title(isManagerView: true);

  String get locationLabel => (locationName ?? '').trim();

  String get emailLabel {
    final value = (email ?? '').trim();
    if (value.isEmpty) return '';
    return '$value';
  }

  String placeLabel({required bool isManagerView}) {
    if (!isManagerView) return device.displayName;
    if (locationLabel.isNotEmpty) return locationLabel;
    return device.displayName;
  }
}
