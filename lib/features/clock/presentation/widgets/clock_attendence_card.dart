// clock_attendence_card.dart
import 'dart:async';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/shared/bottom_sheets/clock_sheets/clock_attendance_details_sheet.dart';
import 'package:obecno/widgets/resolved_location_text.dart';
import 'package:obecno/main.dart';

import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

class AttendanceCard extends StatefulWidget {
  final DateTime day;
  final List<AttendanceEvent> events;
  final ApiClient apiClient;
  final String userEmail;
  final VoidCallback? onEditAttendance;
  final ValueChanged<List<AttendanceEvent>>? onTodayEventsLoaded;

  const AttendanceCard({
    super.key,
    required this.day,
    required this.events,
    required this.apiClient,
    required this.userEmail,
    this.onEditAttendance,
    this.onTodayEventsLoaded,
  });

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  late AttendanceSummary _summary;

  @override
  void initState() {
    super.initState();
    _recompute();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AttendanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recompute();
    _startTimer();
  }

  void _recompute() {
    _summary = AttendanceEngine.compute(widget.events);
    _elapsed = _summary.liveWorkingDuration();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _summary = AttendanceEngine.compute(widget.events);
        _elapsed = _summary.liveWorkingDuration();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String formatTime(DateTime? time) => AttendanceFormat.time(time);

  String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return "${hours}h ${mm}m";
  }

  String? get _firstCheckInLocation {
    for (final e in AttendanceEngine.sortedOldestFirst(widget.events)) {
      if (e.type == AttendanceEventType.checkIn) return e.location;
    }
    return null;
  }

  String? get _lastCheckOutLocation {
    String? location;
    for (final e in AttendanceEngine.sortedOldestFirst(widget.events)) {
      if (e.type == AttendanceEventType.checkOut) location = e.location;
    }
    return location;
  }

  void _openDetails() {
    ClockAttendanceDetailsSheet.show(
      context: context,
      day: widget.day,
      events: widget.events,
      summary: _summary,
      apiClient: widget.apiClient,
      userEmail: widget.userEmail,
      onEditAttendance: widget.onEditAttendance,
      onTodayEventsLoaded: widget.onTodayEventsLoaded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstCheckIn = _summary.firstCheckIn;
    final lastCheckOut = _summary.lastCheckOut;
    final knownLocations = bindings.authProvider.locations
        .map((loc) => KnownLocation(name: loc.name, latLon: loc.latLon))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// FIRST CHECK-IN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.p2("Check-In", color: kPrimaryColor),
                      const SizedBox(height: 4),
                      AppText.h4(
                        formatTime(firstCheckIn),
                        color: kPrimaryColor,
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
                            child: firstCheckIn == null
                                ? AppText.p2(
                                    "--",
                                    color: kGreyColor,
                                    overflow: TextOverflow.fade,
                                    weight: FontWeight.w500,
                                    align: TextAlign.left,
                                  )
                                : ResolvedLocationText(
                                    rawLocation: _firstCheckInLocation,
                                    knownLocations: knownLocations,
                                    onlyKnownLocations: true,
                                    builder: (context, text) => AppText.p2(
                                      text,
                                      color: kGreyColor,
                                      overflow: TextOverflow
                                          .ellipsis, // 🔥 better UX than fade
                                      maxLines: 1, // 🔥 REQUIRED
                                      weight: FontWeight.w500,
                                      align: TextAlign.left,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                /// TOTAL WORKING DURATION
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    Container(
                      width: 15,
                      height: 2,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    const SizedBox(width: 6),
                    AppText.p2(
                      firstCheckIn == null ? "--" : formatDuration(_elapsed),
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 15,
                      height: 2,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                  ],
                ),

                /// LAST CHECK-OUT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText.p2("Check-Out", color: kredColor),
                      const SizedBox(height: 4),
                      AppText.h4(formatTime(lastCheckOut), color: kredColor,         align: TextAlign.right,),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: lastCheckOut == null
                                ? AppText.p2(
                                    "--",
                                    color: kGreyColor,
                                    overflow: TextOverflow.fade,
                                    weight: FontWeight.w500,
                                    align: TextAlign.right,
                                  )
                                : ResolvedLocationText(
                                    rawLocation: _lastCheckOutLocation,
                                    knownLocations: knownLocations,
                                    onlyKnownLocations: true,
                                    builder: (context, text) => AppText.p2(
                                      text,
                                      color: kGreyColor,
                                      overflow: TextOverflow
                                          .ellipsis, // 🔥 better UX than fade
                                      maxLines: 1, // 🔥 REQUIRED
                                      weight: FontWeight.w500,
                                      align: TextAlign.left,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          CommonImageView(
                            imagePath: Assets.imagesLocationDot,
                            height: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: kBorderColor),

          InkWell(
            onTap: _openDetails,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CommonImageView(imagePath: Assets.imagesPen, height: 12),
                      const SizedBox(width: 6),
                      AppText.p2("Fix time"),
                    ],
                  ),
                  Row(
                    children: [
                      AppText.p2("View details"),
                      const SizedBox(width: 6),
                      CommonImageView(
                        imagePath: Assets.imagesArrowNextBlack,
                        height: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
