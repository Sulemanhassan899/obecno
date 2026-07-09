import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();

  static Future<bool> isEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted || status.isProvisional;
  }

  static Future<void> request() async {
    await Permission.notification.request();
  }
}
