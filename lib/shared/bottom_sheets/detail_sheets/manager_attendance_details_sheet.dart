import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/demo/manager_attendence_model.dart';
import 'package:Obecno/shared/bottom_sheets/attendance_sheet/manager_edit_attendance_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/manager_employee_attendance_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/employee_sheet/manager_employee_profile_sheet.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

/// Timeline event types for manager attendance details.
enum ManagerAttendanceEventType {
  checkIn,
  checkOut,
  breakStart,
  breakEnd,
  reminder,
}

class ManagerAttendanceTimelineEvent {
  const ManagerAttendanceTimelineEvent({
    required this.type,
    required this.timeLabel,
    this.location,
    this.reminderText,
  });

  final ManagerAttendanceEventType type;
  final String timeLabel;
  final String? location;
  final String? reminderText;

  String get label {
    switch (type) {
      case ManagerAttendanceEventType.checkIn:
        return "Check-In";
      case ManagerAttendanceEventType.checkOut:
        return "Check-Out";
      case ManagerAttendanceEventType.breakStart:
        return "Break Start";
      case ManagerAttendanceEventType.breakEnd:
        return "Break End";
      case ManagerAttendanceEventType.reminder:
        return reminderText ?? "Please Check-In";
    }
  }

  Color get color {
    switch (type) {
      case ManagerAttendanceEventType.checkIn:
        return kPrimaryColor;
      case ManagerAttendanceEventType.checkOut:
        return kredColor;
      case ManagerAttendanceEventType.breakStart:
      case ManagerAttendanceEventType.breakEnd:
        return kYellowColor;
      case ManagerAttendanceEventType.reminder:
        return kGreyColor;
    }
  }
}

class ManagerAttendanceDetailsData {
  const ManagerAttendanceDetailsData({
    required this.day,
    required this.name,
    this.role,
    this.photo,
    this.checkIn,
    this.checkOut,
    this.checkInLocation,
    this.checkOutLocation,
    this.durationLabel = "0h 00m",
    this.timeline = const [],
  });

  final DateTime day;
  final String name;
  final String? role;
  final String? photo;
  final String? checkIn;
  final String? checkOut;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String durationLabel;
  final List<ManagerAttendanceTimelineEvent> timeline;

  bool get hasAttendance =>
      (checkIn != null && checkIn!.trim().isNotEmpty) ||
      (checkOut != null && checkOut!.trim().isNotEmpty) ||
      timeline.isNotEmpty;

  static String formatFullDate(DateTime d) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  /// Builds demo details from a list tile + selected day.
  factory ManagerAttendanceDetailsData.fromEmployee({
    required ManagerAttendanceModel employee,
    required DateTime day,
  }) {
    final hasTimes =
        (employee.checkIn?.trim().isNotEmpty ?? false) ||
        (employee.checkOut?.trim().isNotEmpty ?? false);

    if (!hasTimes || employee.status.toLowerCase() == "leave") {
      return ManagerAttendanceDetailsData(
        day: day,
        name: employee.name,
        role: employee.role ?? "Employee",
        photo: employee.photo,
        durationLabel: "0h 00m",
      );
    }

    final checkIn = employee.checkIn;
    final checkOut = employee.checkOut;
    const location = "Head Office";

    final timeline = <ManagerAttendanceTimelineEvent>[
      if (checkOut != null && checkOut.trim().isNotEmpty)
        ManagerAttendanceTimelineEvent(
          type: ManagerAttendanceEventType.checkOut,
          timeLabel: checkOut,
          location: location,
        ),
      const ManagerAttendanceTimelineEvent(
        type: ManagerAttendanceEventType.breakEnd,
        timeLabel: "02:00 PM",
        location: location,
      ),
      const ManagerAttendanceTimelineEvent(
        type: ManagerAttendanceEventType.breakStart,
        timeLabel: "01:00 PM",
        location: location,
      ),
      if (checkIn != null && checkIn.trim().isNotEmpty)
        ManagerAttendanceTimelineEvent(
          type: ManagerAttendanceEventType.checkIn,
          timeLabel: checkIn,
          location: location,
        ),
      const ManagerAttendanceTimelineEvent(
        type: ManagerAttendanceEventType.reminder,
        timeLabel: "09:00 PM",
        reminderText: "Please Check-In",
      ),
    ];

    return ManagerAttendanceDetailsData(
      day: day,
      name: employee.name,
      role: employee.role ?? "Employee",
      photo: employee.photo,
      checkIn: checkIn,
      checkOut: checkOut,
      checkInLocation: location,
      checkOutLocation: checkOut != null ? location : null,
      durationLabel: checkOut != null ? "7h 57m" : "0h 00m",
      timeline: timeline,
    );
  }
}

class ManagerAttendanceDetailsSheet {
  ManagerAttendanceDetailsSheet._();

  static Future<void> show({
    required BuildContext context,
    required ManagerAttendanceDetailsData data,
    VoidCallback? onProfileTap,
    VoidCallback? onAttendanceTap,
    VoidCallback? onAddAttendance,
    VoidCallback? onEditAttendance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ManagerAttendanceDetailsSheetBody(
        data: data,
        onProfileTap: onProfileTap ??
            () {
              ManagerEmployeeProfileSheet.show(
                context: sheetContext,
                data: data,
              );
            },
        onAttendanceTap: onAttendanceTap ??
            () {
              ManagerEmployeeAttendanceSheet.show(
                context: sheetContext,
                employeeName: data.name,
              );
            },
        onAddAttendance: onAddAttendance ??
            () {
              Navigator.pop(sheetContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                ManagerEditAttendanceSheet.show(
                  context: context,
                  data: data,
                  isAdd: true,
                );
              });
            },
        onEditAttendance: onEditAttendance ??
            () {
              Navigator.pop(sheetContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                ManagerEditAttendanceSheet.show(
                  context: context,
                  data: data,
                  isAdd: false,
                );
              });
            },
      ),
    );
  }
}

class _ManagerAttendanceDetailsSheetBody extends StatelessWidget {
  const _ManagerAttendanceDetailsSheetBody({
    required this.data,
    this.onProfileTap,
    this.onAttendanceTap,
    this.onAddAttendance,
    this.onEditAttendance,
  });

  final ManagerAttendanceDetailsData data;
  final VoidCallback? onProfileTap;
  final VoidCallback? onAttendanceTap;
  final VoidCallback? onAddAttendance;
  final VoidCallback? onEditAttendance;

  @override
  Widget build(BuildContext context) {
    final hasAttendance = data.hasAttendance;

    return DraggableScrollableSheet(
      initialChildSize: hasAttendance ? 0.88 : 0.62,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              /// Header — date + close
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText.h5(
                        ManagerAttendanceDetailsData.formatFullDate(data.day),
                        weight: FontWeight.w600,
                        align: TextAlign.left,
                      ),
                    ),
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kDividerColor),

              /// Profile card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    ClipOval(
                      child: CommonImageView(
                        imagePath: data.photo ?? Assets.imagesUserimage,
                        height: 48,
                        width: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText.p2(
                            data.name,
                            color: kBlack,
                            weight: FontWeight.w600,
                            align: TextAlign.left,
                          ),
                          if (data.role != null &&
                              data.role!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            AppText.caption(
                              data.role!,
                              color: kGreyColor,
                              weight: FontWeight.w400,
                              align: TextAlign.left,
                            ),
                          ],
                        ],
                      ),
                    ),
                    ButtonAnimations.press(
                      onTap: () => onProfileTap?.call(),
                      child: CommonImageView(
                        imagePath: Assets.PersonIconSheet,
                        height: 45,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ButtonAnimations.press(
                      onTap: () => onAttendanceTap?.call(),
                      child: CommonImageView(
                        imagePath: Assets.AttendanceIconSheet,
                        height: 45,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kDividerColor),

              /// Body
              Expanded(
                child: Container(
                  color: kbackground2,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    children: [
                      _SummaryCard(data: data),
                      if (hasAttendance && data.timeline.isNotEmpty) ...[
                      const SizedBox(height: 32),
                        Row(
                          children: [
                            CommonImageView(
                              imagePath: Assets.imagesClipboardClock,
                              height: 22,
                            ),
                            const SizedBox(width: 8),
                            AppText.h5("Timeline", weight: FontWeight.w600),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...data.timeline.map(
                          (e) => _ManagerTimelineTile(event: e),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              /// Footer action
              Container(
                width: double.infinity,
                color: kWhite,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: hasAttendance
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: MyButton(
                            size: MyButtonSize.normal,
                            width: 200,
                            buttonText: 'Edit Attendance',
                            backgroundColor: kWhite,
                            fontColor: kBlack,
                            outlineColor: kBorderColor,
                            hasicon: true,
                            leftWidget: CommonImageView(
                              imagePath: Assets.imagesPen,
                              height: 16,
                            ),
                            onTap: () async => onEditAttendance?.call(),
                          ),
                        )
                      : MyButton(
                          buttonText: "Add Attendance",
                          backgroundColor: kPrimaryColor,
                          onTap: () async => onAddAttendance?.call(),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final ManagerAttendanceDetailsData data;

  String get _checkIn =>
      (data.checkIn?.trim().isNotEmpty ?? false) ? data.checkIn! : "--";

  String get _checkOut =>
      (data.checkOut?.trim().isNotEmpty ?? false) ? data.checkOut! : "--";

  bool get _hasCheckIn => _checkIn != "--";
  bool get _hasCheckOut => _checkOut != "--";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.p2("Check-In", color: kPrimaryColor),
                    const SizedBox(height: 6),
                    AppText.h3(
                      _checkIn,
                      align: TextAlign.left,
                      color: _hasCheckIn ? kPrimaryColor : kBlack,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _dot(),
                  _line(),
                  const SizedBox(width: 6),
                  AppText.p2(
                    data.durationLabel,
                    weight: FontWeight.w600,
                    color: kGreyColor,
                  ),
                  const SizedBox(width: 6),
                  _line(),
                  _dot(),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText.p2(
                      "Check-Out",
                      color: _hasCheckOut ? kredColor : kGreyColor,
                    ),
                    const SizedBox(height: 6),
                    AppText.h3(
                      _checkOut,
                      align: TextAlign.right,
                      color: _hasCheckOut ? kredColor : kBlack,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _location(
                  data.checkInLocation?.trim().isNotEmpty == true
                      ? data.checkInLocation!
                      : "--",
                ),
              ),
              Expanded(
                child: _location(
                  data.checkOutLocation?.trim().isNotEmpty == true
                      ? data.checkOutLocation!
                      : "--",
                  isRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() =>
      Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3));

  Widget _line() =>
      Container(width: 18, height: 2, color: kGreyColor.withOpacity(0.3));

  Widget _location(String text, {bool isRight = false}) {
    return Row(
      children: [
        if (!isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
        if (!isRight) const SizedBox(width: 6),
        Expanded(
          child: AppText.caption(
            text,
            color: kGreyColor,
            weight: FontWeight.w500,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            align: isRight ? TextAlign.right : TextAlign.left,
          ),
        ),
        if (isRight) const SizedBox(width: 6),
        if (isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
      ],
    );
  }
}

class _ManagerTimelineTile extends StatelessWidget {
  const _ManagerTimelineTile({required this.event});

  final ManagerAttendanceTimelineEvent event;

  bool get _isReminder => event.type == ManagerAttendanceEventType.reminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: _isReminder
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CommonImageView(imagePath: Assets.imagesBell, height: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.p2(
                        event.timeLabel,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                      AppText.p4(
                        event.label,
                        align: TextAlign.left,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h6(event.timeLabel, weight: FontWeight.w700),
                const SizedBox(height: 6),
                AppText.h5(
                  event.label,
                  color: event.color,
                  weight: FontWeight.w700,
                  align: TextAlign.left,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CommonImageView(
                      imagePath: Assets.imagesLocationDot,
                      height: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AppText.p2(
                        event.location?.trim().isNotEmpty == true
                            ? event.location!
                            : "--",
                        color: kGreyColor,
                        weight: FontWeight.w500,
                        overflow: TextOverflow.ellipsis,
                        align: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
