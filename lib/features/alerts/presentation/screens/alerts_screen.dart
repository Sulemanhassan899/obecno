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
import 'package:obecno/features/alerts/providers/alerts_provider.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:obecno/features/join/data/models/join_invite_models.dart';
import 'package:obecno/features/join/presentation/widgets/join_employee_alert_card.dart';
import 'package:obecno/features/join/providers/join_invite_provider.dart';
import 'package:obecno/features/more/presentation/screens/linked_devices.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/select_default_location_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _AlertFilter { all, checkIn, checkOut, leaves, device }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  _AlertFilter _filter = _AlertFilter.all;

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
      context.read<AlertsProvider>().refresh();
      unawaited(context.read<JoinInviteProvider>().ensureLoaded());
    });
  }

  List<DeviceAlertItem> _visibleItems(List<DeviceAlertItem> items) {
    if (_filter == _AlertFilter.checkIn ||
        _filter == _AlertFilter.checkOut ||
        _filter == _AlertFilter.leaves) {
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
        _filter == _AlertFilter.device) {
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
      },
    );
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
    final items = _visibleItems(provider.items);
    final joins = provider.isManagerView
        ? _visibleJoins(joinProvider.managerAlerts())
        : const <JoinInviteRecord>[];
    final isInitialLoad = provider.isLoading &&
        provider.items.isEmpty &&
        joins.isEmpty;
    final totalCount = items.length + joins.length;

    // Build a merged timeline of joins + devices for manager view.
    final timeline = <({DateTime stamp, Object item})>[
      for (final join in joins)
        (stamp: _stampForJoin(join), item: join as Object),
      for (final item in items)
        (stamp: item.device.cardTimestamp, item: item as Object),
    ]..sort((a, b) => b.stamp.compareTo(a.stamp));

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: ShimmerRefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              provider.refresh(),
              joinProvider.ensureLoaded(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 5)),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    _AlertsHeader(
                      monthLabel:
                          '${_monthNames[_month.month - 1]} ${_month.year}',
                      onMonthTap: _openMonthPicker,
                      onSettingsTap: _openSettings,
                    ),
                    const SizedBox(height: 16),
                    _AlertFilterRow(
                      selected: _filter,
                      onSelected: (filter) {
                        setState(() => _filter = filter);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              if (isInitialLoad)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: ShimmerProgress()),
                )
              else if (provider.errorMessage != null &&
                  provider.items.isEmpty &&
                  joins.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText.h6(
                          provider.errorMessage ?? 'Failed to load alerts.',
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
                )
              else if (totalCount == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppText.h6(
                      'No alerts',
                      align: TextAlign.center,
                      color: kGreyColor,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = timeline[index];
                    final stamp = entry.stamp;
                    final showHeader = index == 0 ||
                        _groupLabel(timeline[index - 1].stamp) !=
                            _groupLabel(stamp);
                    final item = entry.item;
                    return Padding(
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
                          else if (item is DeviceAlertItem)
                            DeviceAlertCard(
                              item: item,
                              isManagerView: provider.isManagerView,
                              busy: provider.actingKey == item.key,
                              onDelete: provider.isManagerView
                                  ? null
                                  : () => provider.deleteRequest(item, context),
                              onApprove: provider.isManagerView
                                  ? () => provider.review(
                                        item,
                                        'approve',
                                        context,
                                      )
                                  : null,
                              onReject: provider.isManagerView
                                  ? () =>
                                      provider.review(item, 'reject', context)
                                  : null,
                            ),
                        ],
                      ),
                    );
                  }, childCount: timeline.length),
                ),
            ],
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
  const _AlertFilterRow({required this.selected, required this.onSelected});

  final _AlertFilter selected;
  final ValueChanged<_AlertFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const chips = [
      (_AlertFilter.all, 'All'),
      (_AlertFilter.checkIn, 'Check-In'),
      (_AlertFilter.checkOut, 'Check-Out'),
      (_AlertFilter.leaves, 'Leaves'),
      (_AlertFilter.device, 'Device'),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimaryColor2 : kWhite,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? kPrimaryColor2 : kBorderColor),
        ),
        child: AppText.p2(label, color: kBlack, weight: FontWeight.w500),
      ),
    );
  }
}
