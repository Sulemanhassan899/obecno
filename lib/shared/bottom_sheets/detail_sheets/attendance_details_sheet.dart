
// attendance_details_sheet.dart
import 'package:flutter/material.dart';

import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/constants/text_styles.dart';

import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart'
    hide AttendanceFormat;
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart'
    show AttendanceFormat, KnownLocation;
import 'package:Obecno/shared/location/service/geofence_helper.dart';
import 'package:Obecno/shared/location/service/reverse_geocoding_service.dart';
import 'package:Obecno/main.dart';

import 'package:Obecno/core/generated/assets.dart';

import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/resolved_location_text.dart';
import 'package:Obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/attendance_sheet/attendance_edit_history_section.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:Obecno/features/employee_module/attendance/services/attendance_edit_request_store.dart';
import 'package:Obecno/features/employee_module/attendance/services/attendance_service.dart';

class AttendanceDetailsSheet {
  AttendanceDetailsSheet._();

  static Future<void> show({
    required BuildContext context,
    required DateTime day,
    required List<HistoryAttendanceEvent> events,
    required HistoryAttendanceSummary summary,
    required ApiClient apiClient,
    required String userEmail,
    VoidCallback? onEditAttendance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AttendanceDetailsSheetBody(
          pageContext: context,
          day: day,
          events: events,
          summary: summary,
          apiClient: apiClient,
          userEmail: userEmail,
          onEditAttendance: onEditAttendance,
        );
      },
    );
  }
}

class _AttendanceDetailsSheetBody extends StatefulWidget {
  final BuildContext pageContext;
  final DateTime day;
  final List<HistoryAttendanceEvent> events;
  final HistoryAttendanceSummary summary;
  final ApiClient apiClient;
  final String userEmail;
  final VoidCallback? onEditAttendance;

  const _AttendanceDetailsSheetBody({
    required this.pageContext,
    required this.day,
    required this.events,
    required this.summary,
    required this.apiClient,
    required this.userEmail,
    required this.onEditAttendance,
  });

  @override
  State<_AttendanceDetailsSheetBody> createState() =>
      _AttendanceDetailsSheetBodyState();
}

class _AttendanceDetailsSheetBodyState
    extends State<_AttendanceDetailsSheetBody> {
  late List<HistoryAttendanceEvent> _events;
  late HistoryAttendanceSummary _summary;
  bool _loadingDetails = true;
  int? _attendanceId;

  String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _events = widget.events;
    _summary = widget.summary;
    _loadDetailsFromApi();
  }

  @override
  void didUpdateWidget(covariant _AttendanceDetailsSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events || oldWidget.day != widget.day) {
      _events = widget.events;
      _summary = widget.summary;
      _loadDetailsFromApi();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isViewingToday {
    final now = DateTime.now();
    return _isSameDay(widget.day, now);
  }

  List<HistoryAttendanceEvent> _dayOnly(List<HistoryAttendanceEvent> events) {
    return events.where((e) => _isSameDay(e.time, widget.day)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<void> _loadDetailsFromApi() async {
    setState(() => _loadingDetails = true);

    try {
      final response = await AttendanceService(widget.apiClient)
          .getAttendanceDetails(date: _yyyyMMdd(widget.day));

      if (!mounted) return;

      if (response.success && response.data != null) {
        final data = response.data!;
        final apiEvents = _dayOnly(data.toHistoryEvents());
        if (apiEvents.isNotEmpty) {
          final withLocal = await _mergeLocalFallback(apiEvents);
          if (!mounted) return;
          setState(() {
            _events = withLocal;
            _summary = HistoryAttendanceEngine.compute(withLocal);
            _attendanceId = data.attendanceId;
            _loadingDetails = false;
          });
          return;
        }
        if (mounted) {
          setState(() => _attendanceId = data.attendanceId);
        }
      }
    } catch (_) {
      // Fall through to local/props events.
    }

    if (!mounted) return;
    final withLocal = await _mergeLocalFallback(_dayOnly(_events));
    if (!mounted) return;
    setState(() {
      _events = withLocal;
      _summary = HistoryAttendanceEngine.compute(withLocal);
      _loadingDetails = false;
    });
  }

  /// Prefer API `change_requests` / `changes`. If a card has none, attach
  /// any locally cached pending fix requests for that event type (optimistic).
  Future<List<HistoryAttendanceEvent>> _mergeLocalFallback(
    List<HistoryAttendanceEvent> events,
  ) async {
    final store = AttendanceEditRequestStore.instance;
    await store.ensureLoaded();

    final attachedTypes = <String>{};
    return events.map((event) {
      if (event.editRequests.isNotEmpty) return event;
      final typeName = event.type.name;
      if (!attachedTypes.add(typeName)) return event;
      final stored = store.forEvent(day: widget.day, eventType: typeName);
      if (stored.isEmpty) return event;
      return event.copyWith(editRequests: stored);
    }).toList(growable: false);
  }

  Color _colorFor(AttendanceHisotryEventType type) {
    switch (type) {
      case AttendanceHisotryEventType.checkIn:
        return kPrimaryColor;
      case AttendanceHisotryEventType.checkOut:
        return kredColor;
      case AttendanceHisotryEventType.breakStart:
      case AttendanceHisotryEventType.breakEnd:
        return kYellowColor;
    }
  }

  TimeOfDay _timeOfDay(DateTime dt) =>
      TimeOfDay(hour: dt.hour, minute: dt.minute);

  String? get _firstCheckInLocation {
    for (final e in HistoryAttendanceEngine.sortedOldestFirst(_events)) {
      if (e.type == AttendanceHisotryEventType.checkIn) return e.location;
    }
    return null;
  }

  String? get _lastCheckOutLocation {
    String? location;
    for (final e in HistoryAttendanceEngine.sortedOldestFirst(_events)) {
      if (e.type == AttendanceHisotryEventType.checkOut) location = e.location;
    }
    return location;
  }

  @override
  Widget build(BuildContext context) {
    // Chronological pass so edit-sheet IDs map to earliest in / latest out.
    HistoryAttendanceEvent? checkIn;
    HistoryAttendanceEvent? checkOut;
    HistoryAttendanceEvent? breakIn;
    HistoryAttendanceEvent? breakOut;

    for (final e in HistoryAttendanceEngine.sortedOldestFirst(_events)) {
      switch (e.type) {
        case AttendanceHisotryEventType.checkIn:
          checkIn ??= e;
          break;
        case AttendanceHisotryEventType.checkOut:
          checkOut = e;
          break;
        case AttendanceHisotryEventType.breakStart:
          breakOut ??= e;
          break;
        case AttendanceHisotryEventType.breakEnd:
          breakIn ??= e;
          break;
      }
    }

    // Full chronological timeline — never collapse to one-of-each-type.
    final timeline = HistoryAttendanceEngine.sortedOldestFirst(_events);
    final day = widget.day;
    final summary = _summary;
    final apiClient = widget.apiClient;
    final userEmail = widget.userEmail;
    final pageContext = widget.pageContext;
    final onEditAttendance = widget.onEditAttendance;

    // Live timer only for today while still checked in; past days must not
    // accumulate open-session time into the header (e.g. "76h").
    final workingDuration = _isViewingToday
        ? summary.liveWorkingDuration()
        : summary.totalWorkingDuration;

    final knownLocations = bindings.authProvider.locations
        .map((loc) => KnownLocation(name: loc.name, latLon: loc.latLon))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText.h5(
                      AttendanceFormat.fullDate(day),
                      weight: FontWeight.w600,
                    ),
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  color: kbackground2,
                  child: _loadingDetails
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryColor,
                          ),
                        )
                      : timeline.isEmpty
                      ? Center(child: AppText.p2("No attendance records"))
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AppText.p2(
                                              "Check-In",
                                              color: kPrimaryColor,
                                            ),
                                            const SizedBox(height: 6),
                                            AppText.h3(
                                              AttendanceFormat.time(
                                                summary.firstCheckIn,
                                              ),align: TextAlign.left,
                                              color: kPrimaryColor,
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
                                            AttendanceFormat.duration(
                                              workingDuration,
                                            ),
                                            weight: FontWeight.w600,
                                          ),
                                          const SizedBox(width: 6),
                                          _line(),
                                          _dot(),
                                        ],
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            AppText.p2(
                                              "Check-Out",
                                              color: kredColor,
                                            ),
                                            const SizedBox(height: 6),
                                            AppText.h3(
                                              AttendanceFormat.time(
                                                summary.lastCheckOut,
                                              ),align: TextAlign.right,
                                              color: kredColor,
                                              weight: FontWeight.w700,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: summary.firstCheckIn == null
                                            ? _location("--")
                                            : ResolvedLocationText(
                                                rawLocation:
                                                    _firstCheckInLocation,
                                                knownLocations: knownLocations,
                                                onlyKnownLocations: true,
                                                builder: (context, text) =>
                                                    _location(text),
                                              ),
                                      ),
                                      Expanded(
                                        child: summary.lastCheckOut == null
                                            ? _location("--", isRight: true)
                                            : ResolvedLocationText(
                                                rawLocation:
                                                    _lastCheckOutLocation,
                                                knownLocations: knownLocations,
                                                onlyKnownLocations: true,
                                                builder: (context, text) =>
                                                    _location(
                                                      text,
                                                      isRight: true,
                                                    ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            /// ================= TIMELINE HEADER =================
                            Row(
                              children: [
                                CommonImageView(
                                  imagePath: Assets.imagesClipboardClock,
                                  height: 24,
                                ),
                                const SizedBox(width: 8),
                                AppText.h5("Timeline", weight: FontWeight.w600),
                              ],
                            ),

                            const SizedBox(height: 14),

                            ...timeline.map(
                              (e) => _TimelineTile(
                                event: e,
                                color: _colorFor(e.type),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          AddAttendanceBottomSheet.show(
                            pageContext,
                            day: day,
                            apiClient: apiClient,
                            userEmail: userEmail,
                            attendanceId: _attendanceId,
                            initialCheckIn: checkIn != null
                                ? _timeOfDay(checkIn.time)
                                : null,
                            initialCheckOut: checkOut != null
                                ? _timeOfDay(checkOut.time)
                                : null,
                            initialBreakStart: breakOut != null
                                ? _timeOfDay(breakOut.time)
                                : null,
                            initialBreakEnd: breakIn != null
                                ? _timeOfDay(breakIn.time)
                                : null,
                            checkInDetailId: checkIn?.id,
                            checkOutDetailId: checkOut?.id,
                            breakStartDetailId: breakOut?.id,
                            breakEndDetailId: breakIn?.id,
                          );

                          onEditAttendance?.call();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kWhite,
                          border: Border.all(color: kBorderColor),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 4,
                                left: 6,
                              ),
                              child: CommonImageView(
                                imagePath: Assets.imagesPen,
                                height: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppText.caption(
                              "Edit Attendance",
                              weight: FontWeight.w500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
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

class _TimelineTile extends StatefulWidget {
  final HistoryAttendanceEvent event;
  final Color color;

  const _TimelineTile({required this.event, required this.color});

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile> {
  /// null while we haven't attempted resolution yet, "" while a reverse
  /// geocode lookup is in flight.
  String? _resolvedText;

  @override
  void initState() {
    super.initState();
    // Direct field assignment: initState runs before the first build, so
    // setState() here would be redundant (and is best avoided).
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _TimelineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.location != widget.event.location) {
      setState(_resolve);
    }
  }

  void _resolve() {
    final raw = widget.event.location?.trim();
    if (raw == null || raw.isEmpty) {
      _resolvedText = "--";
      return;
    }

    // Not a raw "lat,lon" pair -- the API already gave us a place name.
    if (!AttendanceFormat.isRawCoordinates(raw)) {
      _resolvedText = raw;
      return;
    }

    // 1) Fast path: does it fall within a known company location?
    final point = GeoPoint.tryParse(raw);
    if (point != null) {
      final knownLocations = bindings.authProvider.locations
          .map((loc) => KnownLocation(name: loc.name, latLon: loc.latLon))
          .toList();

      String? bestName;
      var bestDistance = double.infinity;
      for (final known in knownLocations) {
        final knownPoint = GeoPoint.tryParse(known.latLon);
        if (knownPoint == null) continue;
        final distance = GeofenceHelper.distanceMeters(point, knownPoint);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestName = known.name;
        }
      }

      if (bestName != null && bestDistance <= kDefaultGeofenceRadiusMeters) {
        _resolvedText = bestName;
        return;
      }

      // 2) Fall back to real reverse geocoding for an arbitrary location.
      _resolvedText = "";
      ReverseGeocodingServiceImpl.instance
          .resolve(lat: point.lat, lon: point.lon)
          .then((name) {
            if (!mounted) return;
            setState(
              () => _resolvedText = (name?.trim().isNotEmpty ?? false)
                  ? name!.trim()
                  : "--",
            );
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() => _resolvedText = "--");
          });
      return;
    }

    _resolvedText = "--";
  }

  @override
  Widget build(BuildContext context) {
    final displayLocation = _resolvedText == null || _resolvedText == ""
        ? "Resolving location..."
        : _resolvedText!;
    final isEdited = widget.event.isEdited;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText.h6(
                  AttendanceFormat.time(widget.event.time),
                  weight: FontWeight.w700,
                  align: TextAlign.left,
                ),
              ),
              if (isEdited)
                AppText.p2('Edited', color: kSubText, weight: FontWeight.w400),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              AppText.h5(
                widget.event.label,
                color: widget.color,
                weight: FontWeight.w700,
                align: TextAlign.left,
              ),
              if (isEdited) ...[
                const SizedBox(width: 10),
                CommonImageView(imagePath: Assets.imagesUserPen, height: 20),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
              const SizedBox(width: 6),
              Expanded(
                child: AppText.p2(
                  displayLocation,
                  color: kGreyColor,
                  weight: FontWeight.w500,
                  overflow: TextOverflow.ellipsis,
                  align: TextAlign.left,
                ),
              ),
            ],
          ),
          if (isEdited)
            AttendanceEditHistorySection(requests: widget.event.editRequests),
        ],
      ),
    );
  }
}