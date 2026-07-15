// ignore_for_file: non_constant_identifier_names

import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/bottom_sheet.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class AddAttendanceBottomSheet {
  static void show(BuildContext context) {
    CommonBottomSheet.show(
      context: context,
      height: MediaQuery.of(context).size.height * 0.8, // ✅ FIXED
      buttonText: "Save",
      buttonColor: kBlack,
      buttonFontColor: kWhite,
      children: [const _AttendanceContent()],
    );
  }
}

class _AttendanceContent extends StatefulWidget {
  const _AttendanceContent();

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
    "duration": GlobalKey(),
  };

  final Map<String, double> _pickerHeights = {};

  TimeOfDay checkIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay checkOut = const TimeOfDay(hour: 12, minute: 0);

  /// 🔥 NEW (minimal state added)
  TimeOfDay breakStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay duration = const TimeOfDay(hour: 0, minute: 30);

  String? editingField;

  String formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 13 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$min $period";
  }

  void openPicker1(String fieldKey) async {
    setState(() {
      editingField = editingField == fieldKey ? null : fieldKey;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    final contextKey = _itemKeys[fieldKey]?.currentContext;
    if (contextKey == null) return;

    final box = contextKey.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    final screenHeight = MediaQuery.of(context).size.height;
    final itemCenter = position.dy + (box.size.height / 2);

    final offset = _scrollController.offset + (itemCenter - screenHeight / 2);

    _scrollController.animateTo(
      offset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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

  Widget _wheel(
    int max,
    int initial,
    Function(int) onChanged, {
    List<String>? labels,
  }) {
    final bool isLooping = labels == null; // 🔥 AM/PM has labels → no loop

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
              childCount: isLooping ? null : max, // 🔥 AM/PM finite
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

  /// 🔥 FIX: correct value binding per field
  TimeOfDay _getValue(String fieldKey) {
    switch (fieldKey) {
      case "checkin":
        return checkIn;
      case "checkout":
        return checkOut;
      case "breakstart":
        return breakStart;
      case "duration":
        return duration;
      default:
        return checkIn;
    }
  }

  /// 🔥 FIX: correct setter
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
        case "duration":
          duration = v;
          break;
      }
    });
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

                      /// 🔥 FIXED (dynamic binding)
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
                AppText.h5("17 October 2025", weight: FontWeight.w600),
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
                AppText.p2("8h 00m ", weight: FontWeight.w400),
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
                  title: "Break",
                  value: formatTime(breakStart),
                  fieldKey: "breakstart",
                  valueColor: kYellowColor,
                  onTap: () => openPicker("breakstart"),
                ),
                timelineItem(
                  title: "Duration",
                  value: formatTime(duration),
                  fieldKey: "duration",
                  isLast: true,
                  valueColor: kBlack,
                  onTap: () => openPicker("duration"), // 🔥 FIX
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kWhite,
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    spacing: 6,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 6),
                        child: CommonImageView(
                          imagePath: Assets.imagesMugHot,
                          height: 16,
                        ),
                      ),
                      AppText.caption("Add break", weight: FontWeight.w500),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
