import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/routes/app_routes.dart';
import 'package:obecno/features/employee_module/leaves/data/leaves_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_type_picker_sheet.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

class ApplyLeaveSheet extends StatefulWidget {
  const ApplyLeaveSheet({
    super.key,
    this.existing,
    this.initialDate,
    this.employeeUserId,
    this.employeeName,
  });

  final LeaveRequest? existing;
  final DateTime? initialDate;

  /// When set, manager assigns leave for this employee via
  /// `POST /manager/employees/{id}/leaves` (not employee self-apply).
  final int? employeeUserId;
  final String? employeeName;

  static Future<LeaveRequest?> show(
    BuildContext context, {
    LeaveRequest? existing,
    DateTime? initialDate,
    int? employeeUserId,
    String? employeeName,
  }) {
    return AppSheet.show<LeaveRequest>(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: AppSheetSize.constraintsOf(context),
          child: ApplyLeaveSheet(
            existing: existing,
            initialDate: initialDate,
            employeeUserId: employeeUserId,
            employeeName: employeeName,
          ),
        );
      },
    );
  }

  @override
  State<ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<ApplyLeaveSheet> {
  late DateTime _start;
  late DateTime _end;
  LeaveTypeInfo? _type;
  late final TextEditingController _noteController;
  String? _documentName;
  String? _editingField; // 'start' | 'end' | null
  bool _submitting = false;
  List<LeaveTypeInfo> _managerTypes = const [];
  bool _loadingManagerTypes = false;

  bool get _isEdit => widget.existing != null;

  bool get _isManagerAssign => widget.employeeUserId != null;

  LeavesStore get _store => bindings.leavesStore;

  int get _days {
    final start = DateTime(_start.year, _start.month, _start.day);
    final end = DateTime(_end.year, _end.month, _end.day);
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  bool get _insufficientBalance {
    final type = _type;
    if (type == null) return false;
    return type.available < _days;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final seed = widget.initialDate ?? DateTime.now();
    if (existing != null) {
      _start = existing.startDate;
      _end = existing.endDate;
      _type =
          _store.typeById(existing.typeId) ??
          _store.typeByNameHint(existing.typeName);
      _noteController = TextEditingController(text: existing.note);
      _documentName = existing.documentName;
    } else {
      _start = DateTime(seed.year, seed.month, seed.day);
      _end = _isManagerAssign
          ? _start
          : _start.add(const Duration(days: 2));
      _type =
          _store.typeByNameHint('casual') ??
          (_store.types.isNotEmpty ? _store.types.first : null);
      _noteController = TextEditingController(
        text: "I've been feeling unwell due to frequent business trips.",
      );
    }
    if (_isManagerAssign) {
      _loadManagerLeaveTypes();
    } else {
      _store.ensureLoaded().then((_) {
        if (!mounted) return;
        setState(() {
          _type ??=
              _store.typeByNameHint('casual') ??
              (_store.types.isNotEmpty ? _store.types.first : null);
        });
      });
    }
  }

  Future<void> _loadManagerLeaveTypes() async {
    final userId = widget.employeeUserId;
    if (userId == null) return;
    setState(() => _loadingManagerTypes = true);
    try {
      final response = await bindings.managerEmployeesService
          .loadEmployeeLeaveBalances(userId: userId);
      // Catalog has human labels when balances only return numeric type ids.
      await _store.ensureLoaded();
      if (!mounted) return;
      final types = _typesFromBalances(response.data ?? const []);
      setState(() {
        _managerTypes = types;
        _loadingManagerTypes = false;
        _type = _preferCasual(types);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingManagerTypes = false);
    }
  }

  List<LeaveTypeInfo> _typesFromBalances(
    List<ManagerEmployeeLeaveBalance> balances,
  ) {
    return balances.map((b) {
      final total = int.tryParse(b.entitled ?? '') ?? 0;
      final available = int.tryParse(b.remaining ?? '') ??
          (total - (int.tryParse(b.used ?? '') ?? 0));
      final id = (b.typeId ?? '').trim().isNotEmpty
          ? b.typeId!.trim()
          : b.type.trim();
      final rawName = b.type.trim();
      final catalog = _store.typeById(id);
      final name = (rawName.isNotEmpty && int.tryParse(rawName) == null)
          ? rawName
          : (catalog?.name ??
                (rawName.isEmpty ? 'Leave' : rawName));
      return LeaveTypeInfo(
        id: id.isEmpty ? b.type : id,
        name: name,
        available: available < 0 ? 0 : available,
        total: total > 0 ? total : (available > 0 ? available : 0),
      );
    }).toList(growable: false);
  }

  LeaveTypeInfo? _preferCasual(List<LeaveTypeInfo> types) {
    if (types.isEmpty) return null;
    for (final t in types) {
      final key = '${t.name} ${t.id}'.toLowerCase();
      if (key.contains('casual')) return t;
    }
    return types.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _clear() {
    final seed = widget.initialDate ?? DateTime.now();
    setState(() {
      _start = DateTime(seed.year, seed.month, seed.day);
      _end = _isManagerAssign
          ? _start
          : _start.add(const Duration(days: 2));
      if (_isManagerAssign) {
        _type = _preferCasual(_managerTypes);
      } else {
        _type =
            _store.typeByNameHint('casual') ??
            (_store.types.isNotEmpty ? _store.types.first : null);
      }
      _noteController.text =
          "I've been feeling unwell due to frequent business trips.";
      _documentName = null;
      _editingField = null;
    });
  }

  void _toggleField(String field) {
    setState(() {
      _editingField = _editingField == field ? null : field;
    });
  }

  Future<void> _pickType() async {
    final selected = await LeaveTypePickerSheet.show(
      context,
      selectedTypeId: _type?.id,
      requestedDays: _days <= 0 ? 1 : _days,
      types: _isManagerAssign ? _managerTypes : null,
    );
    if (selected == null || !mounted) return;
    setState(() => _type = selected);
  }

  Future<void> _submit() async {
    final type = _type;
    if (type == null) {
      ToastHelper.leaveApplyFailed(
        context,
        message: _loadingManagerTypes
            ? 'Loading leave types…'
            : 'Please select a leave type',
      );
      return;
    }
    if (_days <= 0 || _submitting) return;

    if (_isManagerAssign) {
      await _submitManagerAssign(type);
      return;
    }

    setState(() => _submitting = true);
    try {
      final LeaveRequest? result;
      if (_isEdit) {
        result = await _store.updateLeave(
          requestId: widget.existing!.id,
          typeId: type.id,
          startDate: _start,
          endDate: _end,
          note: _noteController.text,
          documentName: _documentName,
          clearDocument: _documentName == null,
        );
      } else {
        result = await _store.applyLeave(
          typeId: type.id,
          startDate: _start,
          endDate: _end,
          note: _noteController.text,
          documentName: _documentName,
        );
      }
      if (!mounted) return;
      if (result == null) {
        final message = _store.lastError ?? 'Could not submit leave request';
        ToastHelper.leaveApplyFailed(context, message: message);
        return;
      }

      final successMessage =
          _store.lastSuccessMessage ?? 'Leave request submitted';
      Navigator.pop(context, result);
      // Show toast on the root overlay so it survives the sheet closing
      // (same pattern as clock check-in toasts).
      final host = rootNavigatorKey.currentContext;
      if (host != null && host.mounted) {
        ToastHelper.leaveApplied(host, message: successMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.leaveApplyFailed(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitManagerAssign(LeaveTypeInfo type) async {
    final userId = widget.employeeUserId;
    if (userId == null) return;
    final leaveTypeId = int.tryParse(type.id);
    if (leaveTypeId == null) {
      ToastHelper.leaveApplyFailed(
        context,
        message: 'Please select a leave type allocated by your company.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final response = await bindings.managerEmployeesService.createEmployeeLeave(
        userId: userId,
        leaveTypeId: leaveTypeId,
        startDate: _start,
        endDate: _end,
        note: _noteController.text,
        typeName: type.name,
      );
      if (!mounted) return;
      if (!response.success || !response.isHttpOk) {
        final message =
            response.message ?? 'Could not assign leave for this employee';
        ToastHelper.leaveApplyFailed(context, message: message);
        return;
      }

      final created = response.data;
      final result = LeaveRequest(
        id: (created?.id ?? '').isEmpty
            ? 'mgr_${userId}_${_start.millisecondsSinceEpoch}'
            : created!.id,
        typeId: type.id,
        typeName: created?.type ?? type.name,
        startDate: _start,
        endDate: _end,
        status: LeaveRequestStatus.approved,
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
        timeline: const [],
      );
      final successMessage =
          response.message ?? 'Leave assigned successfully';
      Navigator.pop(context, result);
      final host = rootNavigatorKey.currentContext;
      if (host != null && host.mounted) {
        ToastHelper.leaveApplied(host, message: successMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.leaveApplyFailed(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final type = _type;
    final low = _insufficientBalance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(
            children: [
              AppText.h5(
                _isEdit ? 'Edit' : 'Apply for Leave',
                weight: FontWeight.w600,
              ),
              const Spacer(),
              ButtonAnimations.press(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 22),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
        Flexible(
          child: ColoredBox(
            color: kbackground1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dateCard(),
                  const SizedBox(height: 12),
                  _durationBanner(),
                  if (low) ...[const SizedBox(height: 12), _warningBanner()],
                  const SizedBox(height: 12),
                  _typeCard(type),
                  if (type?.requiresDocument == true) ...[
                    const SizedBox(height: 12),
                    _documentSection(),
                  ],
                  const SizedBox(height: 12),
                  _noteCard(),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: kBorderColor),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
          child: Row(
            children: [
              Expanded(
                child: MyButton(
                  height: 48,
                  size: MyButtonSize.normal,
                  buttonText: _isEdit ? 'Cancel' : 'Clear',
                  backgroundColor: kWhite,
                  fontColor: kBlack,
                  outlineColor: kBorderColor,
                  onTap: () async {
                    if (_isEdit) {
                      Navigator.pop(context);
                      return;
                    }
                    _clear();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MyButton(
                  height: 48,
                  size: MyButtonSize.normal,
                  buttonText: _submitting
                      ? 'Saving...'
                      : (_isEdit ? 'Save Change' : 'Submit'),
                  backgroundColor: kBlack,
                  fontColor: kWhite,
                  onTap: _submitting ? null : () async => _submit(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Same timeline row pattern as [AddAttendanceBottomSheet.timelineItem].
  Widget _dateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          _dateTimelineItem(
            title: 'Start Date',
            value: LeaveFormat.dayMonthYear(_start),
            fieldKey: 'start',
            isLast: false,
          ),
          _dateTimelineItem(
            title: 'End Date',
            value: LeaveFormat.dayMonthYear(_end),
            fieldKey: 'end',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _dateTimelineItem({
    required String title,
    required String value,
    required String fieldKey,
    required bool isLast,
  }) {
    final isActive = _editingField == fieldKey;
    final pickerHeight = isActive ? 200.0 : 0.0;

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleField(fieldKey),
          child: Row(
            children: [
              const SizedBox(
                width: 12,
                child: Icon(Icons.circle, color: kDividerColor, size: 12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AppText.p2(
                        title,
                        color: kSubText,
                        weight: FontWeight.w400,
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isActive ? 12 : 0,
                          vertical: isActive ? 8 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? kbackground : kTransperentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: AppText.p1(value, weight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      CommonImageView(imagePath: Assets.imagesPen, height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isLast)
              Container(
                width: 12,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 2,
                  height: isActive ? pickerHeight + 20 : 28,
                  color: kDividerColor,
                ),
              )
            else
              const SizedBox(width: 12),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isActive
                    ? _LeaveDateWheel(
                        key: ValueKey(fieldKey),
                        value: fieldKey == 'start' ? _start : _end,
                        onChanged: (value) {
                          setState(() {
                            if (fieldKey == 'start') {
                              _start = value;
                              if (_end.isBefore(_start)) _end = _start;
                            } else {
                              _end = value.isBefore(_start) ? _start : value;
                            }
                          });
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _durationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kbackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppText.p2('Leaves', weight: FontWeight.w500, color: kSubText),
          const Spacer(),
          AppText.p2(
            LeaveFormat.daysLabel(_days),
            weight: FontWeight.w500,
            color: kSubText,
          ),
        ],
      ),
    );
  }

  Widget _warningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: kYellowColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CommonImageView(imagePath: Assets.imagesYellowTriangle, height: 20),
          const SizedBox(width: 8),
          Expanded(
            child: AppText.p4(
              "You don't have enough leave balance for this leave type.",
              weight: FontWeight.w500,
              align: TextAlign.left,
              color: kGreyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeCard(LeaveTypeInfo? type) {
    return ButtonAnimations.press(
      onTap: _pickType,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText.p2(
              'Leave type',
              color: kGreyColor,
              weight: FontWeight.w400,
              align: TextAlign.left,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: AppText.p1(
                          type?.name ?? 'Select type',
                          weight: FontWeight.w500,
                          align: TextAlign.left,
                        ),
                      ),
                      if (type != null) ...[
                        const SizedBox(width: 8),
                        AppText.p2(
                          LeaveFormat.availableLabel(type.available),
                          color: type.available <= 1 ? kredColor : kBlue,
                          weight: FontWeight.w600,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: kGreyColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.p2('Document Required', weight: FontWeight.w600),
        const SizedBox(height: 10),
        ButtonAnimations.press(
          onTap: () {
            setState(() {
              _documentName = _documentName == null ? 'Filename etc.' : null;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: kGreyColor,
                ),
                const SizedBox(width: 10),
                AppText.p2(
                  _documentName ?? 'Select Document',
                  weight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _noteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p2(
            'Note',
            color: kGreyColor,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              fontFamily: AppFonts.Poppins,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: kBlack,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attendance-style month / day / year wheels for leave dates.
class _LeaveDateWheel extends StatefulWidget {
  const _LeaveDateWheel({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_LeaveDateWheel> createState() => _LeaveDateWheelState();
}

class _LeaveDateWheelState extends State<_LeaveDateWheel> {
  static const _months = [
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

  static const _itemExtent = 40.0;
  static const _wheelHeight = 200.0;
  static const _fontSize = 15.0;

  late int _month; // 1–12
  late int _day;
  late int _year;
  late int _minYear;
  late int _maxYear;

  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _yearCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minYear = now.year - 5;
    _maxYear = now.year + 5;
    _month = widget.value.month;
    _year = widget.value.year.clamp(_minYear, _maxYear);
    _day = widget.value.day.clamp(1, _daysInMonth(_year, _month));
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _minYear);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _emit() {
    final day = _day.clamp(1, _daysInMonth(_year, _month));
    if (day != _day) {
      _day = day;
      if (_dayCtrl.hasClients) {
        _dayCtrl.animateToItem(
          _day - 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    }
    widget.onChanged(DateTime(_year, _month, _day));
  }

  double _opacityFor(int index, int selected) {
    final distance = (index - selected).abs();
    return switch (distance) {
      0 => 1.0,
      1 => 0.55,
      2 => 0.28,
      3 => 0.14,
      _ => 0.08,
    };
  }

  Widget _column({
    required FixedExtentScrollController controller,
    required int childCount,
    required int selectedIndex,
    required String Function(int index) labelAt,
    required ValueChanged<int> onSelected,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _itemExtent,
      perspective: 0.0025,
      diameterRatio: 1.4,
      // Bouncy parent keeps flings smooth; FixedExtent snaps to a row.
      physics: const FixedExtentScrollPhysics(
        parent: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      ),
      onSelectedItemChanged: (index) {
        HapticFeedback.selectionClick();
        onSelected(index);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: childCount,
        builder: (context, index) {
          return Center(
            child: Opacity(
              opacity: _opacityFor(index, selectedIndex),
              child: Text(
                labelAt(index),
                style: const TextStyle(
                  fontFamily: AppFonts.Poppins,
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w500,
                  color: kBlack,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _daysInMonth(_year, _month);

    return SizedBox(
      height: _wheelHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            right: 4,
            child: Container(
              height: _itemExtent,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.28, 0.72, 1.0],
              ).createShader(bounds);
            },
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _column(
                    controller: _monthCtrl,
                    childCount: 12,
                    selectedIndex: _month - 1,
                    labelAt: (i) => _months[i],
                    onSelected: (i) {
                      setState(() => _month = i + 1);
                      _emit();
                    },
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _column(
                    controller: _dayCtrl,
                    childCount: dayCount,
                    selectedIndex: _day - 1,
                    labelAt: (i) => '${i + 1}',
                    onSelected: (i) {
                      setState(() => _day = i + 1);
                      _emit();
                    },
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _column(
                    controller: _yearCtrl,
                    childCount: _maxYear - _minYear + 1,
                    selectedIndex: _year - _minYear,
                    labelAt: (i) => '${_minYear + i}',
                    onSelected: (i) {
                      setState(() => _year = _minYear + i);
                      _emit();
                    },
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
