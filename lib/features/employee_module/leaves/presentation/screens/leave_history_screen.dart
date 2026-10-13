import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/leaves/data/mock/leaves_mock_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_detail_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_history_date_picker_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_status_filter_sheet.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_request_card.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final LeavesMockStore _store = LeavesMockStore.instance;

  /// null = no date filter (show full list). Label still shows today by default.
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  LeaveRequestStatus? _statusFilter; // null = All types

  static final _monthYear = DateFormat('MMM yy');
  static final _dayMonth = DateFormat('d MMM');

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _hasDateFilter => _rangeStart != null;

  @override
  void initState() {
    super.initState();
    _store.addListener(_refresh);
  }

  @override
  void dispose() {
    _store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String get _durationLabel {
    if (!_hasDateFilter) {
      return _dayMonth.format(_today);
    }
    final start = _rangeStart!;
    final end = _rangeEnd ?? start;
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return _dayMonth.format(start);
    }
    return '${_monthYear.format(start)} - ${_monthYear.format(end)}';
  }

  String get _showLabel => switch (_statusFilter) {
        LeaveRequestStatus.approved => 'Accepted',
        LeaveRequestStatus.pending => 'Pending',
        LeaveRequestStatus.rejected => 'Rejected',
        null => 'All types',
      };

  List<LeaveRequest> get _filtered {
    return [
      for (final request in _store.requests)
        if ((_statusFilter == null || request.status == _statusFilter) &&
            (!_hasDateFilter ||
                _overlaps(
                  request,
                  _rangeStart!,
                  _rangeEnd ?? _rangeStart!,
                )))
          request,
    ];
  }

  bool _overlaps(LeaveRequest request, DateTime start, DateTime end) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);
    final from = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final to = DateTime(
      request.endDate.year,
      request.endDate.month,
      request.endDate.day,
    );
    return !from.isAfter(rangeEnd) && !to.isBefore(rangeStart);
  }

  Future<void> _openDurationPicker() async {
    final result = await LeaveHistoryDatePickerSheet.show(
      context,
      initialStart: _hasDateFilter ? _rangeStart : null,
      initialEnd: _hasDateFilter ? (_rangeEnd ?? _rangeStart) : null,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.isCleared) {
        _rangeStart = null;
        _rangeEnd = null;
      } else {
        _rangeStart = result.start;
        _rangeEnd = result.end;
      }
    });
  }

  Future<void> _openStatusFilter() async {
    final result = await LeaveStatusFilterSheet.show(
      context,
      selected: _statusFilter,
    );
    if (result == null || !mounted) return;
    setState(() => _statusFilter = result.status);
  }

  @override
  Widget build(BuildContext context) {
    final requests = _filtered;

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: Column(
          children: [
            const BackButtonBg(
              title: 'Leave History',
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            const SizedBox(height: 12),
            _filtersCard(),
            const SizedBox(height: 14),
            Expanded(
              child: requests.isEmpty
                  ? Center(
                      child: AppText.p2(
                        'No leave history',
                        color: kGreyColor,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return LeaveRequestCard(
                          request: request,
                          onTap: () => LeaveDetailSheet.show(
                            context,
                            requestId: request.id,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _filterHalf(
                label: 'Duration',
                value: _durationLabel,
                trailing: CommonImageView(
                  imagePath: Assets.imagesCalendarDay,
                  height: 18,
                ),
                onTap: _openDurationPicker,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Container(width: 1, color: kBorderColor),
            ),
            Expanded(
              child: _filterHalf(
                label: 'Show',
                value: _showLabel,
                trailing: const Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: kGreyColor,
                ),
                onTap: _openStatusFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterHalf({
    required String label,
    required String value,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText.caption(
              label,
              color: kGreyColor,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: AppText.p2(
                    value,
                    weight: FontWeight.w600,
                    align: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Center(child: trailing),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
