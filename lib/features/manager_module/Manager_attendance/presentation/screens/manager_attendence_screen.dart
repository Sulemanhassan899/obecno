import 'dart:async';

import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/manager_leave_detail_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key});

  @override
  State<ManagerAttendanceScreen> createState() =>
      ManagerAttendanceScreenState();
}

class ManagerAttendanceScreenState extends State<ManagerAttendanceScreen>
    with TickerProviderStateMixin {
  bool _isSearching = false;
  String _searchQuery = "";

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final List<CurvedAnimation> _entranceAnimations = [];

  @override
  void initState() {
    super.initState();
    ManagerAttendanceRecentSearch.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ManagerAttendanceProvider>();
      // Always refresh so the list matches the full employee directory
      // (portal), not a stale/partial overview seed.
      unawaited(provider.load());
      context.read<ManagerLocationsProvider>().load();
    });
    _entranceController.forward();
  }

  void playEntranceAnimation() {
    if (!mounted) return;
    _entranceController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    for (final animation in _entranceAnimations) {
      animation.dispose();
    }
    _entranceController.dispose();
    super.dispose();
  }

  CurvedAnimation _curveFor(int index, int total) {
    final safeTotal = total <= 1 ? 1 : total;
    final start = (index / safeTotal) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
    );
  }

  Widget _staggered(int index, int total, Widget child) {
    if (_entranceAnimations.length != total) {
      for (final animation in _entranceAnimations) {
        animation.dispose();
      }
      _entranceAnimations
        ..clear()
        ..addAll(List.generate(total, (i) => _curveFor(i, total)));
    }
    final animation = _entranceAnimations[index];
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 18),
            child: child,
          ),
        );
      },
    );
  }

  List<ManagerAttendanceModel> get _searchResults {
    return context.read<ManagerAttendanceProvider>().searchResults(
      _searchQuery,
    );
  }

  void _openDetails(ManagerAttendanceModel employee, DateTime day) {
    final provider = context.read<ManagerAttendanceProvider>();
    final status = employee.status.toLowerCase().trim();
    final raw = employee.userId == null
        ? null
        : provider.items
              .where((e) => e.userId == employee.userId)
              .firstOrNull;
    final isOnLeave =
        status == 'leave' ||
        status == 'on leave' ||
        status == 'onleave' ||
        status.contains('leave') ||
        (raw?.isOnLeave ?? false);
    if (isOnLeave) {
      unawaited(
        ManagerLeaveDetailSheet.showForDay(
          context: context,
          day: day,
          userId: employee.userId,
          employeeName: employee.name,
          employeeRole: employee.role,
          employeePhoto: employee.photo,
        ),
      );
      return;
    }

    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: day,
      ),
      loadDetails: employee.userId == null
          ? null
          : () {
              final current =
                  provider.tiles
                      .where((e) => e.userId == employee.userId)
                      .firstOrNull ??
                  employee;
              return provider.loadEmployeeDay(
                employee: current,
                day: provider.selectedDate,
              );
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ManagerAttendanceProvider>();
    final tiles = provider.tiles;
    final isInitialLoad = provider.isLoading && provider.items.isEmpty;

    final isNonWorkingDay = provider.isNonWorkingDay;
    final nonWorkingLabels = provider.nonWorkingDayLabels;

    late final int total;
    if (_isSearching) {
      // 0 header, 1 search body
      total = 2;
    } else if (isInitialLoad ||
        (provider.hasError && provider.items.isEmpty) ||
        tiles.isEmpty) {
      // 0 header, 1 filters, 2 placeholder
      total = 3;
    } else if (isNonWorkingDay) {
      // 0 header, 1 filters, 2 holiday/weekend banner, then tiles
      total = 3 + tiles.length;
    } else {
      // 0 header, 1 filters, then tiles
      total = 2 + tiles.length;
    }

    return Scaffold(
      backgroundColor: kbackground1,
      body: ShimmerRefreshIndicator(
        instagramStyle: true,
        triggerFraction: 0.40,
        showOrb: false,
        onRefresh: provider.refresh,
        child: Padding(
          padding: AppSizes.page(
            context,
            const EdgeInsets.fromLTRB(10, 30, 20, 0),
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 5)),
              SliverToBoxAdapter(
                child: _staggered(
                  0,
                  total,
                  ManagerAttendanceHeader(
                    selectedDate: provider.selectedDate,
                    onDateSelected: provider.setDate,
                    onSearchModeChanged: (searching) {
                      setState(() {
                        _isSearching = searching;
                        if (!searching) _searchQuery = "";
                      });
                    },
                    onSearchQueryChanged: (query) {
                      setState(() => _searchQuery = query);
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (_isSearching)
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: _staggered(
                    1,
                    total,
                    ManagerAttendanceSearchView(
                      query: _searchQuery,
                      results: _searchResults,
                      recent: ManagerAttendanceRecentSearch.items,
                      onPersonTap: (person) {
                        ManagerAttendanceRecentSearch.add(person);
                        _openDetails(person, provider.selectedDate);
                      },
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _staggered(
                    1,
                    total,
                    ManagerFilters(
                      initialStatus: provider.statusFilterId,
                      initialLocationId: provider.locationId,
                      onStatusChanged: provider.setStatus,
                      onLocationChanged: (id) {
                        final name = id == LocationFilterOption.allId
                            ? null
                            : context
                                  .read<ManagerLocationsProvider>()
                                  .byId(id)
                                  ?.name;
                        provider.setLocation(id: id, name: name);
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                if (isInitialLoad)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _staggered(
                      2,
                      total,
                      const Center(child: ShimmerProgress()),
                    ),
                  )
                else if (provider.hasError && provider.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _staggered(
                      2,
                      total,
                      _AttendanceMessage(
                        message:
                            provider.errorMessage ??
                            'Failed to load attendance.',
                        actionLabel: 'Retry',
                        onAction: provider.load,
                      ),
                    ),
                  )
                else if (tiles.isEmpty && isNonWorkingDay)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _staggered(
                      2,
                      total,
                      _HolidayEmptyState(labels: nonWorkingLabels),
                    ),
                  )
                else if (tiles.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _staggered(
                      2,
                      total,
                      const _AttendanceMessage(message: 'No attendance'),
                    ),
                  )
                else ...[
                  if (isNonWorkingDay)
                    SliverToBoxAdapter(
                      child: _staggered(
                        2,
                        total,
                        _HolidayBanner(labels: nonWorkingLabels),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 32),
                    sliver: SliverList.separated(
                      itemCount: tiles.length,
                      separatorBuilder: (_, __) => Divider(
                        height: MediaQuery.textScalerOf(context).scale(24),
                        color: kDividerColor,
                      ),
                      itemBuilder: (context, index) {
                        final item = tiles[index];
                        return _staggered(
                          (isNonWorkingDay ? 3 : 2) + index,
                          total,
                          ManagerAttendanceTile(
                            data: item,
                            onTap: () =>
                                _openDetails(item, provider.selectedDate),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceMessage extends StatelessWidget {
  const _AttendanceMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText.p1(message, color: kSubText, align: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HolidayEmptyState extends StatelessWidget {
  const _HolidayEmptyState({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CommonImageView(
              imagePath: Assets.imagesCalendarStar,
              height: 112,
            ),
            const SizedBox(height: 20),
            _NonWorkingDayLabels(labels: labels),
          ],
        ),
      ),
    );
  }
}

class _HolidayBanner extends StatelessWidget {
  const _HolidayBanner({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          CommonImageView(
            imagePath: Assets.imagesCalendarStar,
            height: 88,
          ),
          const SizedBox(height: 16),
          _NonWorkingDayLabels(labels: labels),
        ],
      ),
    );
  }
}

/// Weekend dates stack in a column; holiday is a single line.
class _NonWorkingDayLabels extends StatelessWidget {
  const _NonWorkingDayLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          AppText.h4(
            labels[i],
            color: kSubText,
            weight: FontWeight.w500,
            align: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
