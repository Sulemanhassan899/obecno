import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';
import 'package:obecno/demo/location_flags/presentation/location_flag_monitor_host.dart';
import 'package:obecno/demo/location_flags/presentation/widgets/flag_timeline.dart'
    show colorForKind, kBreak, kFuture, kInside, kMissing, kOutside;
import 'package:obecno/shared/bottom_sheets/edit_sheets/date_picker.dart';

class LocationFlagDemoScreen extends StatefulWidget {
  const LocationFlagDemoScreen({super.key});

  @override
  State<LocationFlagDemoScreen> createState() => _LocationFlagDemoScreenState();
}

class _LocationFlagDemoScreenState extends State<LocationFlagDemoScreen>
    with SingleTickerProviderStateMixin {
  final _controller = LocationFlagMonitorHost.controller;
  late final TabController _tabs;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _controller.addListener(_onChange);
    if (_controller.ready) {
      _onChange();
    } else {
      _controller.init();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(LocationFlagMonitorHost.refreshFromBackend(context));
      // If alerts are already enabled, prove the tray path as soon as the
      // demo opens — users were reporting "no notification" while waiting
      // for a 5-minute GPS slot.
      if (_controller.smartSettings.premisesNotifications) {
        unawaited(_controller.sendTestLocationFlagNotification());
      }
    });
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _openDatePicker() {
    DateMonthYearPickerSheet.show(
      context,
      initialDate: _controller.selectedDay,
      onSelected: (picked) {
        unawaited(_controller.selectDate(picked));
      },
    );
  }

  String _dateHeadline(DateTime day) {
    final short = '${day.day} ${_monthShort(day)}';
    if (_controller.isViewingToday) {
      return 'Today - $short';
    }
    return '${_weekday(day)}, $short ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = _controller.selectedDay;
    final policy = _controller.policy;
    // Flag window = backend check-in/out ± 1 hour grace.
    final start = policy.onDay(day, policy.visualStartMinutes);
    final end = policy.onDay(day, policy.visualEndMinutes);
    final latest = _latestWorking();
    final status = _controller.isViewingToday
        ? currentStatusLabel(phase: _controller.monitor.phase, latest: latest)
        : (latest == null
            ? 'NO FLAGS'
            : currentStatusLabel(
                phase: latest.phase,
                latest: latest,
              ));
    final inside =
        latest?.kind == SlotKind.inside || latest?.value == FlagValue.inside;
    final viewNow = _controller.isViewingToday ? DateTime.now() : end;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        elevation: 0,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.white,
                        elevation: 0,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refreshing ? null : _onRefresh,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  color: Color(0xFF111827),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppText.p1(
                    'Time attendance',
                    align: TextAlign.left,
                    weight: FontWeight.w700,
                    color: kBlack300,
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openDatePicker,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: Color(0xFF111827),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: AppText.p4(
                                _dateHeadline(day),
                                align: TextAlign.left,
                                color: const Color(0xFF111827),
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: Color(0xFF111827),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppText.p4(
                    'Assigned ${_shortTime(policy.onDay(day, policy.checkInMinutes))} – ${_shortTime(policy.onDay(day, policy.checkOutMinutes))}',
                    align: TextAlign.left,
                    color: kGreyColor,
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabs,
                    labelColor: kBlack300,
                    unselectedLabelColor: kGreyColor,
                    indicatorColor: kBlack300,
                    labelStyle: const TextStyle(
                      fontFamily: AppFonts.Poppins,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Smart Attendance'),
                      Tab(text: 'Location flags'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      _SmartAlertsCard(
                        settings: _controller.smartSettings,
                        onPremises: _controller.setPremisesNotifications,
                        onSmart: _controller.setSmartAttendance,
                        onTestNotification: () {
                          unawaited(
                            _controller.sendTestLocationFlagNotification(),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _StatusCard(status: status, inside: inside),
                      const SizedBox(height: 10),
                      _AutoPunchCard(punches: _controller.autoPunches),
                      const SizedBox(height: 10),
                      _AlertCard(
                        title: 'Premises & smart alerts',
                        alerts: _controller.alerts
                            .where(
                              (a) =>
                                  a.type == AlertType.premisesCheckIn ||
                                  a.type == AlertType.premisesCheckOut ||
                                  a.type == AlertType.autoCheckIn ||
                                  a.type == AlertType.autoCheckOut,
                            )
                            .toList(),
                        autoPunches: _controller.autoPunches,
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      _AttendanceBar(
                        records: _controller.records,
                        start: start,
                        end: end,
                        now: viewNow,
                        refreshToken: _controller.refreshToken,
                      ),
                      const SizedBox(height: 12),
                      _StatusCard(status: status, inside: inside),
                      const SizedBox(height: 10),
                      _StatusIntervalsCard(
                        intervals: _controller.savedIntervals,
                      ),
                      const SizedBox(height: 10),
                      _MissingOutsideCard(
                        snapshots: _controller.savedIssueHours,
                      ),
                      const SizedBox(height: 10),
                      _AlertCard(alerts: _controller.alerts),
                      const SizedBox(height: 10),
                      _ChecksCard(
                        records: _controller.records,
                        now: viewNow,
                        checkIn: start,
                        checkOut: end,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await LocationFlagMonitorHost.refreshFromBackend(context);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  LocationFlagRecord? _latestWorking() {
    final rows = _controller.records.where((r) => r.value != null).toList();
    if (rows.isEmpty) return null;
    return rows.last;
  }
}

class _AttendanceBar extends StatefulWidget {
  const _AttendanceBar({
    required this.records,
    required this.start,
    required this.end,
    required this.now,
    required this.refreshToken,
  });

  final List<LocationFlagRecord> records;
  final DateTime start;
  final DateTime end;
  final DateTime now;
  final int refreshToken;

  @override
  State<_AttendanceBar> createState() => _AttendanceBarState();
}

class _AttendanceBarState extends State<_AttendanceBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _AttendanceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.records.length != widget.records.length ||
        oldWidget.start != widget.start ||
        oldWidget.end != widget.end) {
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start;
    final end = widget.end;
    final now = widget.now;
    final records = widget.records;
    final span = end.difference(start).inMinutes;
    if (span <= 0) return const SizedBox.shrink();
    final slots = resolvedSlots(
      records,
      checkIn: start,
      checkOut: end,
      now: now,
    );

    return Column(
      children: [
        SizedBox(
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _shortTime(start),
                style: const TextStyle(
                  fontFamily: AppFonts.Poppins,
                  color: kGreyColor,
                  fontSize: 11,
                  height: 1.0,
                ),
              ),
              Text(
                _shortTime(end),
                style: const TextStyle(
                  fontFamily: AppFonts.Poppins,
                  color: kGreyColor,
                  fontSize: 11,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 10,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_anim.value);
                    return Stack(
                      children: [
                        Container(color: kFuture),
                        for (final slot in slots)
                          if (!slot.scheduledAt.isBefore(start) &&
                              slot.scheduledAt.isBefore(end))
                            Positioned(
                              left: slot.scheduledAt
                                      .difference(start)
                                      .inMinutes /
                                  span *
                                  constraints.maxWidth,
                              width: (5 / span * constraints.maxWidth)
                                  .clamp(2.0, constraints.maxWidth)
                                  .toDouble(),
                              top: 0,
                              bottom: 0,
                              child: Opacity(
                                opacity: t,
                                child: Transform.scale(
                                  alignment: Alignment.centerLeft,
                                  scaleX: t.clamp(0.05, 1.0),
                                  child: ColoredBox(
                                    color: colorForKind(slot.kind),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.inside});
  final String status;
  final bool inside;

  @override
  Widget build(BuildContext context) {
    final outside = status == 'LOCATION ISSUE';
    final color = inside
        ? kInside
        : (outside ? kOutside : const Color(0xFF6B7280));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p4(
                  'Current status',
                  align: TextAlign.left,
                  color: kGreyColor,
                ),
                const SizedBox(height: 2),
                AppText.p2(
                  _statusPhrase(status),
                  align: TextAlign.left,
                  color: color,
                  weight: FontWeight.w600,
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_outlined, color: color),
          ),
        ],
      ),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard({
    required this.records,
    required this.now,
    required this.checkIn,
    required this.checkOut,
  });

  final List<LocationFlagRecord> records;
  final DateTime now;
  final DateTime checkIn;
  final DateTime checkOut;

  @override
  Widget build(BuildContext context) {
    final last = now.isBefore(checkOut)
        ? now
        : checkOut.subtract(const Duration(minutes: 1));
    final hours = <DateTime>[];
    if (!last.isBefore(checkIn)) {
      var cursor = DateTime(
        checkIn.year,
        checkIn.month,
        checkIn.day,
        checkIn.hour,
      );
      final endHour = DateTime(last.year, last.month, last.day, last.hour);
      while (!cursor.isAfter(endHour)) {
        hours.add(cursor);
        cursor = cursor.add(const Duration(hours: 1));
      }
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p1(
            'Locations Flags Checks',
            align: TextAlign.left,
            weight: FontWeight.w700,
            color: kBlack300,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          if (hours.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppText.p4(
                'No location flags in this window yet.',
                align: TextAlign.left,
                color: kGreyColor,
              ),
            )
          else
            for (final hour in hours.reversed)
              _HourBlock(hour: hour, records: records, now: now),
        ],
      ),
    );
  }
}

class _HourBlock extends StatelessWidget {
  const _HourBlock({
    required this.hour,
    required this.records,
    required this.now,
  });
  final DateTime hour;
  final List<LocationFlagRecord> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hourEnd = hour.add(const Duration(hours: 1));
    final slots = slotsInHour(hour)
        .where((slot) => !slot.isAfter(hourEnd) && !slot.isAfter(now))
        .toList();
    final bySlot = {
      for (final row in records)
        slotStart(row.scheduledAt).millisecondsSinceEpoch: row,
    };
    // Include upcoming slots still inside this hour so the list stays complete.
    final upcoming = slotsInHour(hour)
        .where((slot) => slot.isAfter(now) && slot.isBefore(hourEnd))
        .toList();
    final visible = [...slots, ...upcoming]
      ..sort((a, b) => b.compareTo(a));

    // Hour summary ignores empty/upcoming placeholders so "No checks" only
    // appears when nothing was actually captured.
    final recordedKinds = <SlotKind>[
      for (final slot in visible)
        if (_slotKind(slot, bySlot[slot.millisecondsSinceEpoch], now)
            case final kind?)
          kind,
    ];
    final phrase = _hourPhrase(recordedKinds);
    final color = _hourColor(recordedKinds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Row(
              children: [
                AppText.p4(
                  '${_clockLabel(hour)} – ${_clockLabel(hourEnd)}',
                  align: TextAlign.left,
                  color: kGreyColor,
                ),
                const Spacer(),
                AppText.p4(
                  phrase,
                  align: TextAlign.right,
                  color: color,
                  weight: FontWeight.w600,
                ),
              ],
            ),
          ),
          for (final slot in visible)
            _FlagRow(
              slot: slot,
              kind: _slotKind(
                    slot,
                    bySlot[slot.millisecondsSinceEpoch],
                    now,
                  ) ??
                  SlotKind.notReached,
              unchecked:
                  !slot.isAfter(now) &&
                  bySlot[slot.millisecondsSinceEpoch] == null,
            ),
          const Divider(height: 22),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                AppText.p4(
                  'Flag status :',
                  align: TextAlign.left,
                  color: kGreyColor,
                ),
                const Spacer(),
                AppText.p4(
                  recordedKinds.isEmpty ? '—' : phrase,
                  align: TextAlign.right,
                  color: color,
                  weight: FontWeight.w600,
                ),
              ],
            ),
          ),
          const Divider(height: 10),
        ],
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({
    required this.slot,
    required this.kind,
    this.unchecked = false,
  });
  final DateTime slot;
  final SlotKind kind;
  final bool unchecked;

  @override
  Widget build(BuildContext context) {
    final color = unchecked ? kGreyColor : colorForKind(kind);
    final label = unchecked ? 'No check' : _pill(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Container(width: 2, height: 28, color: const Color(0xFFE5E7EB)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _flagTime(slot),
                  style: const TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2430),
                  ),
                ),
                const Text(
                  'Flag time check',
                  style: TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 13,
                    color: Color(0xFF9AA3AF),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.Poppins,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIntervalsCard extends StatelessWidget {
  const _StatusIntervalsCard({required this.intervals});
  final List<StatusInterval> intervals;

  @override
  Widget build(BuildContext context) {
    final rows = intervals
        .where(
          (i) =>
              i.kind == SlotKind.inside ||
              i.kind == SlotKind.outside ||
              i.kind == SlotKind.missing,
        )
        .toList()
        .reversed
        .toList();
    return _Panel(
      title: 'Status intervals',
      child: rows.isEmpty
          ? AppText.p4(
              'No location intervals yet.',
              align: TextAlign.left,
              color: kGreyColor,
            )
          : Column(
              children: [
                for (final interval in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorForKind(interval.kind),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppText.p4(
                            '${_shortTime(interval.started)} - ${_shortTime(interval.ended)}',
                            align: TextAlign.left,
                            color: kBlack200,
                          ),
                        ),
                        AppText.p4(
                          interval.label,
                          align: TextAlign.right,
                          color: colorForKind(interval.kind),
                          weight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MissingOutsideCard extends StatelessWidget {
  const _MissingOutsideCard({required this.snapshots});
  final List<MissingOutsideHour> snapshots;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _Panel(
      title: 'Missing & outside flags',
      child: snapshots.isEmpty
          ? AppText.p4(
              'No missing or outside flags yet.',
              align: TextAlign.left,
              color: kGreyColor,
            )
          : Column(
              children: [
                for (final snapshot in snapshots)
                  _MissingOutsideRow(snapshot: snapshot, now: now),
              ],
            ),
    );
  }
}

class _MissingOutsideRow extends StatelessWidget {
  const _MissingOutsideRow({required this.snapshot, required this.now});

  final MissingOutsideHour snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final inProgress = now.isBefore(snapshot.hourEnd);
    final label = inProgress ? 'in progress' : snapshot.summaryLabel;
    final color =
        inProgress ? kGreyColor : colorForKind(snapshot.summaryKind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: AppText.p4(
              '${_shortTime(snapshot.hourStart)} - ${_shortTime(snapshot.hourEnd)}',
              align: TextAlign.left,
              color: kBlack200,
            ),
          ),
          AppText.p4(
            label,
            align: TextAlign.right,
            color: color,
            weight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

class _SmartAlertsCard extends StatelessWidget {
  const _SmartAlertsCard({
    required this.settings,
    required this.onPremises,
    required this.onSmart,
    required this.onTestNotification,
  });

  final SmartAttendanceSettings settings;
  final ValueChanged<bool> onPremises;
  final ValueChanged<bool> onSmart;
  final VoidCallback onTestNotification;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Smart & alerts',
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: AppText.p4(
              'Attendance notifications',
              align: TextAlign.left,
              color: kBlack300,
              weight: FontWeight.w600,
            ),
            subtitle: AppText.p4(
              'Premises + location-flag alerts every 5 min',
              align: TextAlign.left,
              color: kGreyColor,
            ),
            value: settings.premisesNotifications,
            activeThumbColor: kWhite,
            onChanged: onPremises,
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: AppText.p4(
              'Smart Attendance',
              align: TextAlign.left,
              color: kBlack300,
              weight: FontWeight.w600,
            ),
            subtitle: AppText.p4(
              'Auto punch on enter / leave assigned offices',
              align: TextAlign.left,
              color: kGreyColor,
            ),
            value: settings.smartAttendance,
            activeThumbColor: kWhite,
            onChanged: onSmart,
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: AppText.p4(
              'Send test location-flag notification',
              align: TextAlign.left,
              color: kBlack300,
              weight: FontWeight.w600,
            ),
            subtitle: AppText.p4(
              'Tap to post a banner to the notification shade now',
              align: TextAlign.left,
              color: kGreyColor,
            ),
            trailing: const Icon(Icons.notifications_active_outlined),
            onTap: onTestNotification,
          ),
        ],
      ),
    );
  }
}

class _AutoPunchCard extends StatefulWidget {
  const _AutoPunchCard({required this.punches});
  final List<AutoPunchRecord> punches;

  @override
  State<_AutoPunchCard> createState() => _AutoPunchCardState();
}

class _AutoPunchCardState extends State<_AutoPunchCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final punches = widget.punches;
    final rows = punches.reversed.take(12).toList();
    final now = DateTime.now();
    return _Panel(
      title: 'Auto punch times',
      child: rows.isEmpty
          ? AppText.p4(
              'No auto check-in / check-out yet.',
              align: TextAlign.left,
              color: kGreyColor,
            )
          : Column(
              children: [
                for (final punch in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText.p4(
                            _autoPunchLabel(punch, punches, now),
                            align: TextAlign.left,
                            color: kBlack200,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

String _autoPunchLabel(
  AutoPunchRecord punch,
  List<AutoPunchRecord> all,
  DateTime now,
) {
  final office = punch.officeName ?? 'assigned office';
  final time = _shortTime(punch.timestamp);
  final queued = punch.applied ? '' : '\n(queued)';
  if (punch.kind == AutoPunchKind.checkIn) {
    final duration = _autoCheckInDuration(punch, all, now);
    final durationLine = duration == null ? '' : '\nDuration: $duration';
    return 'Smart attendance\nauto checked in at $time at ($office)$queued$durationLine';
  }
  final duration = _autoSessionDuration(punch, all);
  final durationLine = duration == null ? '' : '\nDuration: $duration';
  return 'Smart attendance\nauto checked out at $time from ($office)$queued$durationLine';
}

/// Elapsed time since this auto check-in (until matching check-out, or now).
String? _autoCheckInDuration(
  AutoPunchRecord checkIn,
  List<AutoPunchRecord> all,
  DateTime now,
) {
  DateTime? checkOutAt;
  for (final punch in all) {
    if (punch.kind != AutoPunchKind.checkOut) continue;
    if (!punch.timestamp.isAfter(checkIn.timestamp)) continue;
    if (checkOutAt == null || punch.timestamp.isBefore(checkOutAt)) {
      checkOutAt = punch.timestamp;
    }
  }
  final end = checkOutAt ?? now;
  if (end.isBefore(checkIn.timestamp)) return null;
  return _formatDuration(end.difference(checkIn.timestamp));
}

/// Session length for an auto check-out (from the latest check-in before it).
String? _autoSessionDuration(
  AutoPunchRecord checkOut,
  List<AutoPunchRecord> all,
) {
  DateTime? checkInAt;
  for (final punch in all) {
    if (punch.kind != AutoPunchKind.checkIn) continue;
    if (!punch.timestamp.isBefore(checkOut.timestamp)) continue;
    if (checkInAt == null || punch.timestamp.isAfter(checkInAt)) {
      checkInAt = punch.timestamp;
    }
  }
  if (checkInAt == null) return null;
  return _formatDuration(checkOut.timestamp.difference(checkInAt));
}

String _formatDuration(Duration value) {
  final totalMinutes = value.inMinutes;
  if (totalMinutes < 1) return '${value.inSeconds}s';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '$minutes min';
  if (minutes == 0) return '$hours hr';
  return '$hours hr $minutes min';
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alerts,
    this.title = 'Notification history',
    this.autoPunches = const [],
  });
  final List<FlagAlert> alerts;
  final String title;
  final List<AutoPunchRecord> autoPunches;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _Panel(
      title: title,
      child: alerts.isEmpty
          ? AppText.p4(
              'No alerts yet.',
              align: TextAlign.left,
              color: kGreyColor,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final alert in alerts.reversed.take(40))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppText.p4(
                      _alertDisplayMessage(alert, autoPunches, now),
                      align: TextAlign.left,
                      color: kBlack200,
                    ),
                  ),
              ],
            ),
    );
  }
}

String _alertDisplayMessage(
  FlagAlert alert,
  List<AutoPunchRecord> punches,
  DateTime now,
) {
  if (alert.type != AlertType.autoCheckIn &&
      alert.type != AlertType.autoCheckOut) {
    return alert.message;
  }
  AutoPunchRecord? match;
  for (final punch in punches.reversed) {
    final isCheckIn = punch.kind == AutoPunchKind.checkIn;
    if (alert.type == AlertType.autoCheckIn && !isCheckIn) continue;
    if (alert.type == AlertType.autoCheckOut && isCheckIn) continue;
    final delta = punch.timestamp.difference(alert.timestamp).abs();
    if (delta <= const Duration(minutes: 2)) {
      match = punch;
      break;
    }
  }
  if (match == null) return alert.message;
  final duration = match.kind == AutoPunchKind.checkIn
      ? _autoCheckInDuration(match, punches, now)
      : _autoSessionDuration(match, punches);
  if (duration == null) return alert.message;
  if (alert.message.contains('Duration:')) return alert.message;
  return '${alert.message}\nDuration: $duration';
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p2(
            title,
            align: TextAlign.left,
            weight: FontWeight.w700,
            color: kBlack300,
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

SlotKind? _slotKind(DateTime slot, LocationFlagRecord? record, DateTime now) {
  if (slot.isAfter(now)) return SlotKind.notReached;
  // No stored flag = unchecked gap, not missing. Missing is only written when
  // a live GPS capture fails (location unavailable).
  if (record == null) return null;
  return record.kind;
}

String _hourPhrase(List<SlotKind> kinds) {
  if (kinds.isEmpty) return 'No checks';
  // Hour cycle still running (some 5-min slots are upcoming).
  if (kinds.contains(SlotKind.notReached)) return 'in progress';
  if (kinds.contains(SlotKind.outside)) return 'Out of office location';
  if (kinds.contains(SlotKind.missing) && kinds.contains(SlotKind.inside)) {
    return 'Location partially unavailable';
  }
  if (kinds.contains(SlotKind.missing)) return 'Missing';
  if (kinds.contains(SlotKind.inside)) return 'Inside office premises';
  if (kinds.contains(SlotKind.onBreak)) return 'On break';
  return 'Upcoming';
}

Color _hourColor(List<SlotKind> kinds) {
  if (kinds.isEmpty) return kGreyColor;
  if (kinds.contains(SlotKind.notReached)) return kGreyColor;
  if (kinds.contains(SlotKind.outside)) return kOutside;
  if (kinds.contains(SlotKind.missing)) return kMissing;
  if (kinds.contains(SlotKind.inside)) return kInside;
  if (kinds.contains(SlotKind.onBreak)) return kBreak;
  return kGreyColor;
}

String _statusPhrase(String status) {
  switch (status) {
    case 'IN OFFICE':
      return 'In office location';
    case 'LOCATION ISSUE':
      return 'Out of office location';
    case 'NOT CHECKED IN':
      return 'Not checked in';
    case 'ON BREAK':
      return 'On break';
    case 'CHECKED OUT':
      return 'Checked out';
    default:
      return 'Location unavailable';
  }
}

String _flagStatusPhrase(String label) {
  if (label == 'LOCATION ISSUE') return 'Out of office location';
  if (label == 'IN OFFICE') return 'Inside office premises';
  if (label == 'NOT REACHED') return 'Upcoming';
  return 'Location unavailable';
}

String _pill(SlotKind kind) {
  switch (kind) {
    case SlotKind.inside:
      return 'Inside office premises';
    case SlotKind.outside:
      return 'outside office premises';
    case SlotKind.missing:
      return 'Missing';
    case SlotKind.onBreak:
      return 'Break';
    case SlotKind.notReached:
      return 'Upcoming';
  }
}

String _shortTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour >= 12 ? 'pm' : 'am';
  if (local.minute == 0) return '$hour $suffix';
  return '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
}

String _flagTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour >= 12 ? 'pm' : 'am';
  if (local.minute == 0) return '$hour $suffix';
  return '$hour : ${local.minute.toString().padLeft(2, '0')} $suffix';
}

String _clockLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _weekday(DateTime time) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[time.weekday - 1];
}

String _monthShort(DateTime time) {
  const names = [
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
  return names[time.month - 1];
}
