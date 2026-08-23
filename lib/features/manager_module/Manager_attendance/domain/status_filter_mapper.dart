import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_status_filter_model.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';

class StatusFilterMapper {
  StatusFilterMapper._();

  static List<StatusFilterOption> toOptions(List<ManagerStatusFilter> filters) {
    final mapped = filters
        .where((filter) => filter.key.toLowerCase() != StatusFilterOption.allId)
        .map(
          (filter) => StatusFilterOption(
            id: filter.key,
            label: filter.label.isEmpty ? filter.key : filter.label,
            icon: iconFor(filter.key),
          ),
        )
        .toList(growable: false);

    return [StatusFilterOption.all, ...mapped];
  }

  static String iconFor(String key) {
    switch (key.trim().toLowerCase()) {
      case 'all':
        return Assets.AllStatus;
      case 'present':
      case 'on_time':
      case 'checked_out':
        return Assets.PresentTodayHandIcon;
      case 'working':
      case 'active':
        return Assets.ActivePersonsIcon;
      case 'break':
      case 'on_break':
      case 'break_exceeded':
        return Assets.OnBreakIcon;
      case 'late':
      case 'late_checkin':
      case 'early_checkout':
      case 'early_checkin':
      case 'short_hours':
      case 'hours_over':
        return Assets.EarlyCheckOutInIcon;
      case 'absent':
        return Assets.AbsentIcon;
      default:
        return Assets.AllStatus;
    }
  }
}
