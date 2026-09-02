import 'package:intl/intl.dart';
import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';

class DemoTimeFormat {
  DemoTimeFormat._();

  static final _time = DateFormat('hh:mm a');
  static final _date = DateFormat('yyyy-MM-dd');

  static String time(DateTime? value) {
    if (value == null) return '--';
    return _time.format(value);
  }

  static String date(DateTime? value) {
    if (value == null) return '--';
    return _date.format(value);
  }

  static String utc(DateTime? value) {
    if (value == null) return '--';
    final utc = value.isUtc ? value : value.toUtc();
    return utc.toIso8601String();
  }

  static String monotonic(Duration? value) {
    if (value == null) return '--';
    return value.inMilliseconds.toString();
  }

  static String yesNo(bool value) => value ? 'YES' : 'NO';

  static String network(bool online) => online ? 'ONLINE' : 'OFFLINE';

  static String clockDifference(Duration difference) {
    if (difference == Duration.zero) return '0 minutes';
    final sign = difference.isNegative ? '-' : '+';
    final abs = difference.abs();
    final hours = abs.inHours;
    final minutes = abs.inMinutes.remainder(60);
    if (hours != 0 && minutes != 0) {
      return '$sign$hours hours $minutes minutes';
    }
    if (hours != 0) {
      return hours == 1 ? '$sign$hours hour' : '$sign$hours hours';
    }
    return minutes == 1 ? '$sign$minutes minute' : '$sign$minutes minutes';
  }

  static String timezone(TimeAnchor? anchor) {
    if (anchor == null) return '--';
    final minutes = anchor.timezoneOffset.inMinutes;
    final sign = minutes >= 0 ? '+' : '-';
    final abs = minutes.abs();
    final hh = (abs ~/ 60).toString().padLeft(2, '0');
    final mm = (abs % 60).toString().padLeft(2, '0');
    return '${anchor.timezoneName} ($sign$hh:$mm)';
  }
}
