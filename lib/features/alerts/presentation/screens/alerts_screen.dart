import 'dart:async';

import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/alerts/data/models/device_alert_item.dart';
import 'package:obecno/features/alerts/presentation/widgets/device_alert_card.dart';
import 'package:obecno/features/alerts/presentation/widgets/leave_alert_card.dart';
import 'package:obecno/features/alerts/providers/alerts_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/presentation/widgets/join_employee_alert_card.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/presentation/screens/linked_devices.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_detail_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/manager_leave_detail_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/select_default_location_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _AlertFilter { all, checkIn, checkOut, leaves, device, reminder }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => AlertsScreenState();
}

class AlertsScreenState extends State<AlertsScreen>
    with TickerProviderStateMixin {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _AlertFilter _filter = _AlertFilter.all;
  List<ReminderLog> _reminders = const [];
  bool _remindersLoading = false;
  int _reminderLoad = 0;
  Set<String> _knownReminderKeys = {};
  Set<_AlertFilter> _pulseFilters = {};
  Timer? _pulseTimer;
  final Map<String, GlobalKey> _leaveCardKeys = {};

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// List-only entrance — filter changes replay this without touching date/chips.
  late final AnimationController _listEntranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final List<CurvedAnimation> _chromeAnimations = [];
  final List<CurvedAnimation> _listAnimations = [];

  static const _shortMonths = [
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

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final alerts = context.read<AlertsProvider>();
      alerts.refresh();
      unawaited(alerts.syncLeaveAlerts());
      unawaited(context.read<JoinInviteProvider>().ensureLoaded());
      unawaited(_loadReminders());
      // Refresh Alerts as soon as a reminder is written (notification fired).
      bindings.reminderSettingsProvider.addListener(_onRemindersChanged);
    });
    _entranceController.forward();
    _listEntranceController.forward();
  }

  List<ManagerTeamLeaveItem> _visibleLeaves(AlertsProvider provider) {
    if (_filter == _AlertFilter.checkIn ||
        _filter == _AlertFilter.checkOut ||
        _filter == _AlertFilter.device ||
        _filter == _AlertFilter.reminder) {
      return const [];
    }
    return provider.leaveAlerts;
  }

  String? _photoForLeave(ManagerTeamLeaveItem item) {
    final direct = item.employeePhoto?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final members = context.read<ManagerEmployeesProvider>().members;
    final userId = item.userId;
    if (userId != null) {
      for (final member in members) {
        if (member.userId == userId) {
          final photo = member.photo?.trim();
          if (photo != null && photo.isNotEmpty) return photo;
        }
      }
    }
    final name = (item.employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final member in members) {
      if (member.name.trim().toLowerCase() == name) {
        final photo = member.photo?.trim();
        if (photo != null && photo.isNotEmpty) return photo;
      }
    }
    return null;
  }

  GlobalKey _keyForLeave(String alertKey) =>
      _leaveCardKeys.putIfAbsent(alertKey, GlobalKey.new);

  void _scrollToLeave(String? leaveKey) {
    if (leaveKey == null || leaveKey.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _leaveCardKeys[leaveKey]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        context.read<AlertsProvider>().clearLeaveFocus();
      });
    });
  }

  void playEntranceAnimation() {
    if (!mounted) return;
    _entranceController
      ..reset()
      ..forward();
    _listEntranceController
      ..reset()
      ..forward();
  }

  void playListEntranceAnimation() {
    if (!mounted) return;
    _listEntranceController
      ..reset()
      ..forward();
  }

  /// Used when Clock / notifications open Alerts on a specific chip
  /// (`leaves`, `device`, `reminder`, `check_in`, `check_out`, `all`).
  void applyFilter(String? filter, {String? leaveKey}) {
    if (!mounted) return;
    final normalized = (filter ?? '').trim().toLowerCase().replaceAll('-', '_');
    final next = switch (normalized) {
      'leave' || 'leaves' => _AlertFilter.leaves,
      'device' || 'devices' => _AlertFilter.device,
      'reminder' || 'reminders' => _AlertFilter.reminder,
      'check_in' || 'checkin' => _AlertFilter.checkIn,
      'check_out' || 'checkout' => _AlertFilter.checkOut,
      'all' || '' => _AlertFilter.all,
      _ => _AlertFilter.all,
    };
    final alerts = context.read<AlertsProvider>();
    setState(() => _filter = next);
    if (leaveKey != null && leaveKey.trim().isNotEmpty) {
      alerts.focusLeave(leaveKey.trim());
    }
    if (next == _AlertFilter.leaves || leaveKey != null) {
      unawaited(
        alerts.syncLeaveAlerts().then((_) {
          if (!mounted) return;
          _scrollToLeave(leaveKey ?? alerts.focusLeaveKey);
        }),
      );
    }
    if (next == _AlertFilter.all || next == _AlertFilter.reminder) {
      unawaited(_loadReminders());
    }
    playListEntranceAnimation();
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    bindings.reminderSettingsProvider.removeListener(_onRemindersChanged);
    for (final animation in _chromeAnimations) {
      animation.dispose();
    }
    for (final animation in _listAnimations) {
      animation.dispose();
    }
    _entranceController.dispose();
    _listEntranceController.dispose();
    super.dispose();
  }

  CurvedAnimation _curveFor(
    AnimationController parent,
    int index,
    int total,
  ) {
    final safeTotal = total <= 1 ? 1 : total;
    final start = (index / safeTotal) * 0.6;
    final end = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: parent,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOutCubic),
    );
  }

  Widget _staggeredChrome(int index, Widget child) {
    const total = 2;
    if (_chromeAnimations.length != total) {
      for (final animation in _chromeAnimations) {
        animation.dispose();
      }
      _chromeAnimations
        ..clear()
        ..addAll(
          List.generate(
            total,
            (i) => _curveFor(_entranceController, i, total),
          ),
        );
    }
    final animation = _chromeAnimations[index];
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

  Widget _staggeredList(int index, int total, Widget child) {
    if (_listAnimations.length != total) {
      for (final animation in _listAnimations) {
        animation.dispose();
      }
      _listAnimations
        ..clear()
        ..addAll(
          List.generate(
            total,
            (i) => _curveFor(_listEntranceController, i, total),
          ),
        );
    }
    final animation = _listAnimations[index];
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

  void _onRemindersChanged() {
    if (!mounted) return;
    // Always reload so we can pulse the matching chip even on other filters.
    unawaited(_loadReminders());
  }

  /// One Alerts card per reminder type + clock minute (not raw millis).
  /// Native "fired now" and Flutter's planned fireAt often differ by seconds
  /// but show the same "9:45 pm" label — collapse those into one row.
  String _reminderKey(ReminderLog log) {
    final local = log.firedAt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${log.type.storageKey}|$y-$m-$d|$h:$min';
  }

  Set<_AlertFilter> _chipsForReminder(ReminderType type) {
    switch (type) {
      case ReminderType.checkIn:
      case ReminderType.checkInMissed:
      case ReminderType.enterLocation:
        return {_AlertFilter.reminder, _AlertFilter.checkIn, _AlertFilter.all};
      case ReminderType.checkOut:
      case ReminderType.checkOutMissed:
      case ReminderType.leaveLocation:
        return {_AlertFilter.reminder, _AlertFilter.checkOut, _AlertFilter.all};
      default:
        return {_AlertFilter.reminder, _AlertFilter.all};
    }
  }

  List<DeviceAlertItem> _visibleItems(List<DeviceAlertItem> items) {
    if (_filter == _AlertFilter.checkIn ||
        _filter == _AlertFilter.checkOut ||
        _filter == _AlertFilter.leaves ||
        _filter == _AlertFilter.reminder) {
      return const [];
    }
    final now = DateTime.now();
    final viewingCurrentMonth =
        _month.year == now.year && _month.month == now.month;
    return items.where((item) {
      // Pending / one-shot approved cards must stay visible even when the
      // device request timestamp falls outside the selected month.
      if (item.device.isPending) return true;
      if (viewingCurrentMonth &&
          (item.device.isApproved ||
              item.device.isRejected ||
              item.device.isBlocked)) {
        return true;
      }
      final stamp = item.device.cardTimestamp.toLocal();
      return stamp.year == _month.year && stamp.month == _month.month;
    }).toList();
  }

  List<JoinInviteRecord> _visibleJoins(List<JoinInviteRecord> items) {
    if (_filter == _AlertFilter.checkIn ||
        _filter == _AlertFilter.checkOut ||
        _filter == _AlertFilter.leaves ||
        _filter == _AlertFilter.device ||
        _filter == _AlertFilter.reminder) {
      return const [];
    }
    return items.where((item) {
      final stamp = (item.joinedAt ?? item.createdAt).toLocal();
      return stamp.year == _month.year && stamp.month == _month.month;
    }).toList();
  }

  DateTime _stampForJoin(JoinInviteRecord invite) =>
      invite.joinedAt ?? invite.createdAt;

  Future<void> _approveJoin(JoinInviteRecord invite) async {
    final join = context.read<JoinInviteProvider>();
    final updated = await join.reviewJoin(id: invite.id, approve: true);
    if (!mounted || updated == null) return;
    final selected = await SelectDefaultLocationSheet.show(
      context,
      selectedId: updated.locationId,
    );
    if (selected == null || !mounted) return;
    await join.assignLocation(
      id: updated.id,
      locationId: selected.id,
      locationName: selected.name,
    );
  }

  Future<void> _rejectJoin(JoinInviteRecord invite) async {
    await context.read<JoinInviteProvider>().reviewJoin(
      id: invite.id,
      approve: false,
    );
  }

  String _groupLabel(DateTime stamp) {
    final local = stamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final label = '${local.day} ${_shortMonths[local.month - 1]}';
    if (day == today) return '$label - Today';
    if (day == today.subtract(const Duration(days: 1))) {
      return '$label - Yesterday';
    }
    return label;
  }

  void _openMonthPicker() {
    MonthYearPickerSheet.show(
      context,
      initialDate: _month,
      onSelected: (date) {
        setState(() {
          _month = DateTime(date.year, date.month);
        });
        if (_filter == _AlertFilter.all || _filter == _AlertFilter.reminder) {
          unawaited(_loadReminders());
        }
      },
    );
  }

  Future<void> _loadReminders() async {
    final token = ++_reminderLoad;
    final month = _month;
    final userId = bindings.authProvider.user?.id ?? '';
    if (mounted) setState(() => _remindersLoading = true);
    if (userId.isEmpty) {
      if (!mounted || token != _reminderLoad) return;
      setState(() {
        _reminders = const [];
        _remindersLoading = false;
      });
      return;
    }

    List<ReminderLog> archived = const [];
    try {
      await bindings.reminderSettingsProvider.importFiredNotifications();
      archived = await bindings.reminderDao.loadShownNotifications(
        userId: userId,
        month: month,
      );
    } catch (_) {}

    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final batches = await Future.wait([
      for (var day = 1; day <= days; day++)
        Future.wait([
          bindings.reminderDao.loadLogs(
            userId: userId,
            date: DateTime(month.year, month.month, day),
          ),
          bindings.reminderDao.loadDeliveredLogs(
            userId: userId,
            date: DateTime(month.year, month.month, day),
          ),
        ]),
    ]);
    if (!mounted || token != _reminderLoad) return;

    // One row per type + clock minute. Same reminder from native import +
    // Flutter engine must not appear twice with identical "9:45 pm" labels.
    final merged = <String, ReminderLog>{};
    void take(ReminderLog log) {
      final key = _reminderKey(log);
      final current = merged[key];
      if (current == null || _preferReminder(log, current)) {
        merged[key] = log;
      }
    }

    for (final log in archived) {
      take(log);
    }
    for (final batch in batches) {
      for (final log in [...batch[0], ...batch[1]]) {
        take(log);
      }
    }
    final logs = merged.values.toList()
      ..sort((a, b) => b.firedAt.compareTo(a.firedAt));
    final nextKeys = {for (final log in logs) _reminderKey(log)};
    final isFirstLoad = _knownReminderKeys.isEmpty;
    final newLogs = [
      for (final log in logs)
        if (!_knownReminderKeys.contains(_reminderKey(log))) log,
    ];
    _knownReminderKeys = nextKeys;

    final pulse = <_AlertFilter>{};
    if (!isFirstLoad) {
      for (final log in newLogs) {
        pulse.addAll(_chipsForReminder(log.type));
      }
    }

    setState(() {
      _reminders = logs;
      _remindersLoading = false;
      if (pulse.isNotEmpty) {
        _pulseFilters = pulse;
      }
    });
    if (pulse.isNotEmpty) {
      _pulseTimer?.cancel();
      _pulseTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _pulseFilters = {});
      });
    }
  }

  bool _preferReminder(ReminderLog next, ReminderLog current) {
    final nextHasCopy =
        next.title.trim().isNotEmpty && next.message.trim().isNotEmpty;
    final currentHasCopy =
        current.title.trim().isNotEmpty && current.message.trim().isNotEmpty;
    if (nextHasCopy != currentHasCopy) return nextHasCopy;
    final nextDelivered = next.deliveredAt;
    final currentDelivered = current.deliveredAt;
    if (nextDelivered != null && currentDelivered == null) return true;
    if (nextDelivered == null && currentDelivered != null) return false;
    return false;
  }

  void _openSettings() {
    if (context.read<AlertsProvider>().isManagerView) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkedDevices()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertsProvider>();
    final joinProvider = context.watch<JoinInviteProvider>();
    final showingReminders = _filter == _AlertFilter.reminder;
    final includeReminders =
        _filter == _AlertFilter.all || _filter == _AlertFilter.reminder;
    final items = _visibleItems(provider.items);
    final joins = provider.isManagerView
        ? _visibleJoins(joinProvider.managerAlerts())
        : const <JoinInviteRecord>[];
    final isManager =
        provider.isManagerView ||
        bindings.authProvider.homeTarget == AuthHomeTarget.manager;
    final leaves = _visibleLeaves(provider);
    final reminders = includeReminders ? _reminders : const <ReminderLog>[];
    final focusLeaveKey = provider.focusLeaveKey;
    final totalCount =
        items.length + joins.length + reminders.length + leaves.length;
    final isInitialLoad =
        totalCount == 0 &&
        ((includeReminders && _remindersLoading) ||
            (!showingReminders &&
                provider.isLoading &&
                provider.items.isEmpty &&
                joins.isEmpty &&
                leaves.isEmpty));

    // Build a merged timeline of joins, devices, leaves, and reminders.
    // Newest stamp first across all alert types (date-wise).
    final timeline = <({DateTime stamp, Object item})>[
      for (final join in joins)
        (stamp: _stampForJoin(join), item: join as Object),
      for (final item in items)
        (stamp: item.device.cardTimestamp, item: item as Object),
      for (final leave in leaves)
        (stamp: leave.alertSortTime, item: leave as Object),
      for (final log in reminders) (stamp: log.firedAt, item: log as Object),
    ]..sort((a, b) {
      // Focused leave from notification tap rises to the top.
      if (focusLeaveKey != null) {
        final aFocus = a.item is ManagerTeamLeaveItem &&
            (a.item as ManagerTeamLeaveItem).alertKey == focusLeaveKey;
        final bFocus = b.item is ManagerTeamLeaveItem &&
            (b.item as ManagerTeamLeaveItem).alertKey == focusLeaveKey;
        if (aFocus != bFocus) return aFocus ? -1 : 1;
      }
      return b.stamp.compareTo(a.stamp);
    });

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: ShimmerRefreshIndicator(
          instagramStyle: true,
          triggerFraction: 0.40,
          showOrb: false,
          onRefresh: () async {
            playEntranceAnimation();
            await Future.wait([
              provider.refresh(),
              joinProvider.ensureLoaded(),
              provider.syncLeaveAlerts(),
              if (_filter == _AlertFilter.all ||
                  _filter == _AlertFilter.reminder)
                _loadReminders(),
            ]);
          },
          child: Builder(
            builder: (context) {
              final listCount =
                  isInitialLoad ||
                      (!showingReminders &&
                          reminders.isEmpty &&
                          provider.errorMessage != null &&
                          provider.items.isEmpty &&
                          joins.isEmpty) ||
                      totalCount == 0
                  ? 1
                  : timeline.length;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 5)),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        _staggeredChrome(
                          0,
                          _AlertsHeader(
                            monthLabel:
                                '${_monthNames[_month.month - 1]} ${_month.year}',
                            onMonthTap: _openMonthPicker,
                            onSettingsTap: _openSettings,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _staggeredChrome(
                          1,
                          _AlertFilterRow(
                            selected: _filter,
                            pulsed: _pulseFilters,
                            onSelected: (filter) {
                              setState(() => _filter = filter);
                              if (filter == _AlertFilter.all ||
                                  filter == _AlertFilter.reminder) {
                                unawaited(_loadReminders());
                              }
                              playListEntranceAnimation();
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  if (isInitialLoad)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _staggeredList(
                        0,
                        listCount,
                        const Center(child: ShimmerProgress()),
                      ),
                    )
                  else if (!showingReminders &&
                      reminders.isEmpty &&
                      provider.errorMessage != null &&
                      provider.items.isEmpty &&
                      joins.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _staggeredList(
                        0,
                        listCount,
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText.h6(
                                provider.errorMessage ??
                                    'Failed to load alerts.',
                                align: TextAlign.center,
                                color: kGreyColor,
                              ),
                              const SizedBox(height: 16),
                              MyButton(
                                size: MyButtonSize.normal,
                                width: 140,
                                buttonText: 'Retry',
                                onTap: () => provider.refresh(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (totalCount == 0)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _staggeredList(
                        0,
                        listCount,
                        Center(
                          child: AppText.h6(
                            'No alerts',
                            align: TextAlign.center,
                            color: kGreyColor,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final entry = timeline[index];
                        final stamp = entry.stamp;
                        final showHeader =
                            index == 0 ||
                            _groupLabel(timeline[index - 1].stamp) !=
                                _groupLabel(stamp);
                        final item = entry.item;
                        return _staggeredList(
                          index,
                          listCount,
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader) ...[
                                  AppText.h5(
                                    _groupLabel(stamp),
                                    align: TextAlign.left,
                                    weight: FontWeight.w600,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (item is JoinInviteRecord)
                                  JoinEmployeeAlertCard(
                                    invite: item,
                                    onApprove: () => _approveJoin(item),
                                    onReject: () => _rejectJoin(item),
                                  )
                                else if (item is ReminderLog)
                                  _ReminderAlertCard(log: item)
                                else if (item is ManagerTeamLeaveItem)
                                  KeyedSubtree(
                                    key: _keyForLeave(item.alertKey),
                                    child: LeaveAlertCard(
                                      item: item,
                                      busy:
                                          provider.actingLeaveKey ==
                                          item.alertKey,
                                      highlighted:
                                          focusLeaveKey == item.alertKey,
                                      isEmployeeView: !isManager,
                                      onOpen: () async {
                                        if (!isManager) {
                                          await bindings.leavesStore
                                              .ensureLoaded();
                                          if (!context.mounted) return;
                                          await LeaveDetailSheet.show(
                                            context,
                                            requestId: item.leaveRequestId,
                                            fallbackNote: item.note,
                                          );
                                          return;
                                        }
                                        final result =
                                            await ManagerLeaveDetailSheet.show(
                                              context: context,
                                              leave:
                                                  ManagerLeaveView.fromTeamItem(
                                                    item,
                                                  ),
                                              employeeName: item.employeeName,
                                              employeePhoto: _photoForLeave(
                                                item,
                                              ),
                                            );
                                        if (result == 'approve' ||
                                            result == 'reject') {
                                          await provider.archiveLeaveReview(
                                            item,
                                            result as String,
                                          );
                                        } else if (result == true) {
                                          await provider.syncLeaveAlerts();
                                        }
                                      },
                                      onApprove: isManager &&
                                              item.isPendingInInbox
                                          ? () => provider.reviewLeaveAlert(
                                              item,
                                              'approve',
                                              context,
                                            )
                                          : null,
                                      onReject: isManager &&
                                              item.isPendingInInbox
                                          ? () => provider.reviewLeaveAlert(
                                              item,
                                              'reject',
                                              context,
                                            )
                                          : null,
                                    ),
                                  )
                                else if (item is DeviceAlertItem)
                                  DeviceAlertCard(
                                    item: item,
                                    isManagerView: provider.isManagerView,
                                    busy: provider.actingKey == item.key,
                                    onDelete: provider.isManagerView
                                        ? null
                                        : () => provider.deleteRequest(
                                            item,
                                            context,
                                          ),
                                    onApprove: provider.isManagerView
                                        ? () => provider.review(
                                            item,
                                            'approve',
                                            context,
                                          )
                                        : null,
                                    onReject: provider.isManagerView
                                        ? () => provider.review(
                                            item,
                                            'reject',
                                            context,
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: timeline.length),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader({
    required this.monthLabel,
    required this.onMonthTap,
    required this.onSettingsTap,
  });

  final String monthLabel;
  final VoidCallback onMonthTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ButtonAnimations.press(
                onTap: onMonthTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommonImageView(
                      imagePath: Assets.imagesCalender,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    AppText.p3(
                      monthLabel,
                      weight: FontWeight.w400,
                      color: kSubText,
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      CupertinoIcons.chevron_down,
                      size: 18,
                      color: kBlack,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertFilterRow extends StatelessWidget {
  const _AlertFilterRow({
    required this.selected,
    required this.onSelected,
    this.pulsed = const {},
  });

  final _AlertFilter selected;
  final ValueChanged<_AlertFilter> onSelected;
  final Set<_AlertFilter> pulsed;

  @override
  Widget build(BuildContext context) {
    const chips = [
      (_AlertFilter.all, 'All'),
      (_AlertFilter.reminder, 'Reminder'),
      (_AlertFilter.leaves, 'Leaves'),
      (_AlertFilter.device, 'Device'),
      (_AlertFilter.checkIn, 'Check-In'),
      (_AlertFilter.checkOut, 'Check-Out'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _AlertChip(
              label: chips[i].$2,
              selected: selected == chips[i].$1,
              showDot: pulsed.contains(chips[i].$1),
              onTap: () => onSelected(chips[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? kPrimaryColor2 : kWhite,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? kPrimaryColor2 : kBorderColor,
              ),
            ),
            child: AppText.p2(label, color: kBlack, weight: FontWeight.w500),
          ),
          if (showDot)
            Positioned(
              top: 0,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: kWhite, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReminderAlertCard extends StatelessWidget {
  const _ReminderAlertCard({required this.log});

  final ReminderLog log;

  @override
  Widget build(BuildContext context) {
    final title = log.title.trim().isEmpty ? log.timelineLabel : log.title;
    final detail = log.message.trim().isEmpty ? log.timelineLabel : log.message;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CommonImageView(
              imagePath: Assets.imagesReminderClock,
              height: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.h6(
                  title,
                  align: TextAlign.left,
                  weight: FontWeight.w600,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppText.p2(
                        detail,
                        align: TextAlign.left,
                        color: kGreyColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppText.p2(
                      _formatAlertTime(log.firedAt),
                      color: kGreyColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAlertTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final min = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'pm' : 'am';
  return '$hour:$min $period';
}
