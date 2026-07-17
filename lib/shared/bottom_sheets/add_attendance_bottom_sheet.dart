// ignore_for_file: non_constant_identifier_names

import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/helpers/snackbar_helper.dart';
import 'package:Obecno/generated/assets.dart';

// 🔥 FIX — you were importing BOTH edit_response_sheet.dart AND
// response_bottom_sheet.dart. Both files define `class ReponseBottomSheet`
// and `enum TicketResponseStatus`, so Dart had two candidates for the same
// name (ambiguous import) and may have silently picked the stale one
// (response_bottom_sheet.dart, which doesn't have the `day` param) — that's
// very likely the real source of your "day isn't defined" errors.
// Only edit_response_sheet.dart is the one being maintained now.
import 'package:Obecno/shared/bottom_sheets/edit_response_sheet.dart';

import 'package:Obecno/shared/widgets/bottom_sheet.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddAttendanceBottomSheet {
  static void show(
    BuildContext context, {
    required DateTime day,
    required ApiClient apiClient,
    required String userEmail,
    TimeOfDay? initialCheckIn,
    TimeOfDay? initialCheckOut,
    TimeOfDay? initialBreakStart,
    TimeOfDay? initialBreakEnd,
  }) {
    // lets the "Save" button (rendered by CommonBottomSheet, outside this
    // widget's own build tree) reach into this content's state and
    // trigger the save/submit flow.
    final contentKey = GlobalKey<_AttendanceContentState>();

    CommonBottomSheet.show(
      context: context,
      height: MediaQuery.of(context).size.height * 0.8, // ✅ FIXED
      buttonText: "Save",
      buttonColor: kBlack,
      buttonFontColor: kWhite,

      onButtonTap: () => contentKey.currentState?.handleSave(),
      children: [
        _AttendanceContent(
          key: contentKey,
          day: day,
          apiClient: apiClient,
          userEmail: userEmail,
          initialCheckIn: initialCheckIn ?? const TimeOfDay(hour: 8, minute: 0),
          initialCheckOut:
              initialCheckOut ?? const TimeOfDay(hour: 12, minute: 0),
          initialBreakStart:
              initialBreakStart ?? const TimeOfDay(hour: 10, minute: 0),
          initialBreakEnd:
              initialBreakEnd ?? const TimeOfDay(hour: 10, minute: 30),
        ),
      ],
    );
  }
}

class _AttendanceContent extends StatefulWidget {
  final DateTime day;
  final ApiClient apiClient;
  final String userEmail;
  final TimeOfDay initialCheckIn;
  final TimeOfDay initialCheckOut;
  final TimeOfDay initialBreakStart;
  final TimeOfDay initialBreakEnd;

  const _AttendanceContent({
    super.key,
    required this.day,
    required this.apiClient,
    required this.userEmail,
    required this.initialCheckIn,
    required this.initialCheckOut,
    required this.initialBreakStart,
    required this.initialBreakEnd,
  });

  @override
  State<_AttendanceContent> createState() => _AttendanceContentState();
}

class _AttendanceContentState extends State<_AttendanceContent>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  final Map<String, GlobalKey> _itemKeys = {
    "checkin": GlobalKey(),
    "checkout": GlobalKey(),
    "breakstart": GlobalKey(),
    "breakend": GlobalKey(),
  };

  final Map<String, double> _pickerHeights = {};

  late TimeOfDay checkIn;
  late TimeOfDay checkOut;
  late TimeOfDay breakStart;
  late TimeOfDay breakEnd;

  String? editingField;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    checkIn = widget.initialCheckIn;
    checkOut = widget.initialCheckOut;
    breakStart = widget.initialBreakStart;
    breakEnd = widget.initialBreakEnd;
  }

  String formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$min $period";
  }

  // ✅ FIX: convert to DateTime
  DateTime _toDateTime(TimeOfDay t) {
    return DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      t.hour,
      t.minute,
    );
  }

  // ✅ FIX: dynamic working hours
  String _calculateWorkingHours() {
    final total = _toDateTime(checkOut).difference(_toDateTime(checkIn));
    final breakDur = _toDateTime(breakEnd).difference(_toDateTime(breakStart));

    final working = total - breakDur;

    final h = working.inHours;
    final m = working.inMinutes.remainder(60);

    return "${h}h ${m.toString().padLeft(2, '0')}m";
  }

  void openPicker(String fieldKey) async {
    setState(() {
      editingField = editingField == fieldKey ? null : fieldKey;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final contextKey = _itemKeys[fieldKey]?.currentContext;
    if (contextKey == null) return;

    final renderObject = contextKey.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox) return;

    final box = renderObject;
    final position = box.localToGlobal(Offset.zero);

    final screenHeight = MediaQuery.of(context).size.height;
    final itemCenter = position.dy + (box.size.height / 2);

    final offset = _scrollController.offset + (itemCenter - screenHeight / 2);

    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      offset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // 🔥 NO CHANGE BELOW (UI untouched)

  TimeOfDay _getValue(String fieldKey) {
    switch (fieldKey) {
      case "checkin":
        return checkIn;
      case "checkout":
        return checkOut;
      case "breakstart":
        return breakStart;
      case "breakend":
        return breakEnd;
      default:
        return checkIn;
    }
  }

  void _setValue(String fieldKey, TimeOfDay v) {
    setState(() {
      switch (fieldKey) {
        case "checkin":
          checkIn = v;
          break;
        case "checkout":
          checkOut = v;
          break;
        case "breakstart":
          breakStart = v;
          break;
        case "breakend":
          breakEnd = v;
          break;
      }
    });
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  Future<void> handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final now = DateTime.now(); // ✅ FIX

    final content = StringBuffer()
      ..writeln('Dear Team,')
      ..writeln()
      ..writeln(
        'I would like to request a correction in my attendance record for the date ${_dateLabel(widget.day)}.',
      )
      ..writeln()
      ..writeln('Requested at: $now')
      ..writeln()
      ..writeln(
        'Check-in: ${formatTime(widget.initialCheckIn)} → ${formatTime(checkIn)}',
      )
      ..writeln(
        'Check-out: ${formatTime(widget.initialCheckOut)} → ${formatTime(checkOut)}',
      )
      ..writeln(
        'Break start: ${formatTime(widget.initialBreakStart)} → ${formatTime(breakStart)}',
      )
      ..writeln(
        'Break end: ${formatTime(widget.initialBreakEnd)} → ${formatTime(breakEnd)}',
      )
      ..writeln()
      ..writeln(
        'Kindly review and update the record if appropriate. I would appreciate your support.',
      )
      ..writeln()
      ..writeln('Thank you.');

    try {
      final response = await widget.apiClient.post(
        ApiEndpoints.tickets,
        data: {
          'user_email': widget.userEmail,
          'subject': 'Attendance fix request - ${_dateLabel(widget.day)}',
          'content': content.toString(),
        },
      );

      if (!mounted) return;

      final success = response.statusCode == 200 || response.statusCode == 201;

      // ✅ UPDATED TO HANDLE BOTH CASES
      SnackbarHelper.showTopToast(
        context,
        message: success ? "Request Send" : "Request not send",
        backgroundColor: success ? kBlack : kredColor,
        textColor: kWhite,
      );

      String eventLabel = "Check-In";
      String newTime = formatTime(checkIn);
      String originalTime = formatTime(widget.initialCheckIn);

      switch (editingField) {
        case "checkout":
          eventLabel = "Check-Out";
          newTime = formatTime(checkOut);
          originalTime = formatTime(widget.initialCheckOut);
          break;
        case "breakstart":
          eventLabel = "Break Start";
          newTime = formatTime(breakStart);
          originalTime = formatTime(widget.initialBreakStart);
          break;
        case "breakend":
          eventLabel = "Break End";
          newTime = formatTime(breakEnd);
          originalTime = formatTime(widget.initialBreakEnd);
          break;
      }

      Navigator.of(context).pop();

      ReponseBottomSheet.show(
        context,
        status: success
            ? TicketResponseStatus.pending
            : TicketResponseStatus.rejected,
        time: formatTime(TimeOfDay.fromDateTime(now)),
        eventLabel: eventLabel,
        requestedAt: now,
        newTime: newTime,
        originalTime: originalTime,
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ReponseBottomSheet.show(
        context,
        status: TicketResponseStatus.rejected,
        requestedAt: now,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Widget timelineItem({
    required String title,
    required String value,
    required VoidCallback onTap,
    required String fieldKey,
    bool isLast = false,
    Color? valueColor,
  }) {
    final isActive = editingField == fieldKey;
    double safeHeight;
    if (!isActive) {
      safeHeight = 40;
    } else {
      final h = _pickerHeights[fieldKey];
      safeHeight = (h == null || !h.isFinite) ? 200 : h + 60;
    }
    return Container(
      key: _itemKeys[fieldKey],
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.circle, color: kDividerColor, size: 12),
                  if (!isLast)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 2,
                      height: safeHeight,
                      margin: const EdgeInsets.only(top: 2),
                      color: kDividerColor,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AppText.p2(
                            title,
                            color: kSubText,
                            weight: FontWeight.w400,
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.all(isActive ? 12 : 0),
                            decoration: BoxDecoration(
                              color: isActive ? kbackground : kTransperentColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AppText.p1(
                              value,
                              color: valueColor,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CommonImageView(
                            imagePath: Assets.imagesPen,
                            height: 16,
                          ),
                        ],
                      ),
                      inlinePicker(
                        fieldKey: fieldKey,
                        value: _getValue(fieldKey),
                        onChanged: (v) => _setValue(fieldKey, v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget inlinePicker({
    required String fieldKey,
    required TimeOfDay value,
    required Function(TimeOfDay) onChanged,
  }) {
    int selectedHour = value.hourOfPeriod;
    int selectedMinute = value.minute;
    int selectedPeriod = value.period == DayPeriod.am ? 0 : 1;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: editingField == fieldKey
          ? AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(fieldKey),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final h = constraints.maxHeight;
                        if (h.isFinite && h > 0) {
                          _pickerHeights[fieldKey] = h;
                        }
                      });
                      return SizedBox(
                        height: 200,
                        child: SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _wheel(13, selectedHour, (v) {
                                selectedHour = v;
                                final hour = selectedPeriod == 0
                                    ? selectedHour
                                    : (selectedHour + 12) % 24;
                                onChanged(
                                  TimeOfDay(hour: hour, minute: selectedMinute),
                                );
                              }),
                              _wheel(60, selectedMinute, (v) {
                                selectedMinute = v;
                                final hour = selectedPeriod == 0
                                    ? selectedHour
                                    : (selectedHour + 12) % 24;
                                onChanged(
                                  TimeOfDay(hour: hour, minute: selectedMinute),
                                );
                              }),
                              _wheel(2, selectedPeriod, (v) {
                                selectedPeriod = v;
                                final hour = selectedPeriod == 0
                                    ? selectedHour
                                    : (selectedHour + 12) % 24;
                                onChanged(
                                  TimeOfDay(hour: hour, minute: selectedMinute),
                                );
                              }, labels: ["AM", "PM"]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _wheel(
    int max,
    int initial,
    Function(int) onChanged, {
    List<String>? labels,
  }) {
    final bool isLooping = labels == null;
    final controller = FixedExtentScrollController(
      initialItem: isLooping ? (1000 * max + initial) : initial,
    );
    return SizedBox(
      width: 90,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            perspective: 0.0025,
            diameterRatio: 1.4,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              final realIndex = isLooping ? (val % max) : val;
              HapticFeedback.selectionClick();
              onChanged(realIndex);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: isLooping ? null : max,
              builder: (context, index) {
                final realIndex = isLooping ? (index % max) : index;
                final text = labels != null
                    ? labels[realIndex]
                    : realIndex.toString().padLeft(2, '0');
                return Center(child: AppText.p1(text, weight: FontWeight.w500));
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText.h5("Edit Attendance", weight: FontWeight.w600),
              ButtonAnimations.press(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText.h5(_dateLabel(widget.day), weight: FontWeight.w600),
                CommonImageView(
                  imagePath: Assets.imagesCalendarDay,
                  height: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              children: [
                timelineItem(
                  title: "Check-in",
                  value: formatTime(checkIn),
                  fieldKey: "checkin",
                  valueColor: Colors.green,
                  onTap: () => openPicker("checkin"),
                ),
                timelineItem(
                  title: "Check-out",
                  value: formatTime(checkOut),
                  fieldKey: "checkout",
                  isLast: true,
                  valueColor: Colors.red,
                  onTap: () => openPicker("checkout"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kbackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText.p2("Working hours", weight: FontWeight.w400),
                AppText.p2(
                  _calculateWorkingHours(), // ✅ FIX
                  weight: FontWeight.w400,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            spacing: 5,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 6),
                child: CommonImageView(
                  imagePath: Assets.imagesMugHotYellow,
                  height: 24,
                ),
              ),
              AppText.h5("Break"),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderColor),
            ),
            child: Column(
              children: [
                timelineItem(
                  title: "Break start",
                  value: formatTime(breakStart),
                  fieldKey: "breakstart",
                  valueColor: kYellowColor,
                  onTap: () => openPicker("breakstart"),
                ),
                timelineItem(
                  title: "Break end",
                  value: formatTime(breakEnd),
                  fieldKey: "breakend",
                  isLast: true,
                  valueColor: kBlack,
                  onTap: () => openPicker("breakend"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
