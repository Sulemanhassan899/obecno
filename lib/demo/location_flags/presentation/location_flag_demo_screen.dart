import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/location_flags/presentation/location_flag_demo_controller.dart';
import 'package:obecno/demo/location_flags/presentation/widgets/location_flag_checks_card.dart';
import 'package:obecno/demo/location_flags/presentation/widgets/location_flag_timeline_bar.dart';
import 'package:obecno/features/auth/providers/permission_provider.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';
import 'package:obecno/features/clock/location_flags/providers/location_flag_provider.dart';
import 'package:obecno/main.dart';

class LocationFlagDemoScreen extends StatefulWidget {
  const LocationFlagDemoScreen({super.key});

  static const routePath = '/demo/location-flags';

  @override
  State<LocationFlagDemoScreen> createState() => _LocationFlagDemoScreenState();
}

class _LocationFlagDemoScreenState extends State<LocationFlagDemoScreen>
    with TickerProviderStateMixin {
  late final LocationFlagDemoController _controller;
  LocationFlagProvider? _liveFlags;

  @override
  void initState() {
    super.initState();
    _controller = LocationFlagDemoController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final live = context.read<LocationFlagProvider>();
    final permissions = context.read<PermissionProvider>();
    _liveFlags = live;
    live.addListener(_onLiveFlags);
    await _controller.load(
      permissions: permissions,
      liveFlags: live,
      reminders: bindings.reminderSettingsProvider,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final live = context.read<LocationFlagProvider>();
    final permissions = context.read<PermissionProvider>();
    await _controller.load(
      permissions: permissions,
      liveFlags: live,
      reminders: bindings.reminderSettingsProvider,
    );
    if (bindings.locationFlagMonitor.isMonitoring) {
      await bindings.locationFlagMonitor.captureNow();
      await live.reloadForDay(DateTime.now());
      _controller.syncLive(live);
    }
    unawaited(bindings.locationFlagSyncService.syncPending());
  }

  void _onLiveFlags() {
    final live = _liveFlags;
    if (!mounted || live == null) return;
    _controller.syncLive(live);
  }

  @override
  void dispose() {
    _liveFlags?.removeListener(_onLiveFlags);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final verdict = _controller.verdict;
        final status = _statusView(verdict.status);
        return Scaffold(
          backgroundColor: kbackground1,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => unawaited(_refresh()),
                      icon: const Icon(Icons.refresh, size: 22),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.h3(
                        'Time attendance',
                        align: TextAlign.left,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 4),
                      AppText.p2(
                        'Today · ${AttendanceFormat.weekdayDate(_controller.policyWindow.start)}',
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                      AppText.p2(
                        'Attendance Location Monitoring',
                        color: kGreyColor,
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 16),
                      AppText.p2(
                        'Check In: ${LocationFlagEvaluator.formatClock(_controller.policyWindow.start)}',
                        align: TextAlign.left,
                      ),
                      AppText.p2(
                        'Check Out: ${LocationFlagEvaluator.formatClock(_controller.policyWindow.end)}',
                        align: TextAlign.left,
                      ),
                      const SizedBox(height: 20),
                      LocationFlagTimelineBar(
                        window: _controller.window,
                        segments: _controller.segments,
                        progress: _controller.progress,
                        intervals: _controller.outsideIntervals,
                        paintUnrecorded: _controller.sessionCheckedIn,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _StatusCard(
                  title: status.label,
                  color: status.color,
                  caption: 'Current status',
                ),
                const SizedBox(height: 16),
                LocationFlagChecksCard(
                  entries: _controller.allFlagEntries,
                  statusLabel: status.label,
                  statusColor: status.color,
                ),
                const SizedBox(height: AppSizes.headerTop),
              ],
            ),
          ),
        );
      },
    );
  }

  ({String label, Color color}) _statusView(LocationFlagUiStatus status) {
    switch (status) {
      case LocationFlagUiStatus.notCheckedIn:
        return (label: 'NOT CHECKED IN', color: kGreyColor);
      case LocationFlagUiStatus.inOffice:
        return (label: 'IN OFFICE', color: kPrimaryColor);
      case LocationFlagUiStatus.locationIssue:
        return (label: 'LOCATION ISSUE', color: kredColor);
      case LocationFlagUiStatus.locationUnavailable:
        return (label: 'LOCATION UNAVAILABLE', color: kOrangeColor);
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.color,
    required this.caption,
  });

  final String title;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.p2(caption, color: kGreyColor, align: TextAlign.left),
                const SizedBox(height: 4),
                AppText.p1(
                  title,
                  color: color,
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}
