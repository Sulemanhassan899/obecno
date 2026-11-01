import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_request_card.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet.dart';
import 'package:obecno/shared/bottom_sheets/app_sheet_size.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/apply_leave_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/manager_leave_detail_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/my_button.dart';

class ManagerEmployeeLeavesSheet {
  ManagerEmployeeLeavesSheet._();

  static Future<void> show({
    required BuildContext context,
    required int userId,
    required String employeeName,
    String? employeeRole,
    String? employeePhoto,
  }) {
    return AppSheet.show<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManagerEmployeeLeavesSheetBody(
        userId: userId,
        employeeName: employeeName,
        employeeRole: employeeRole,
        employeePhoto: employeePhoto,
      ),
    );
  }
}

class _ManagerEmployeeLeavesSheetBody extends StatefulWidget {
  const _ManagerEmployeeLeavesSheetBody({
    required this.userId,
    required this.employeeName,
    this.employeeRole,
    this.employeePhoto,
  });

  final int userId;
  final String employeeName;
  final String? employeeRole;
  final String? employeePhoto;

  @override
  State<_ManagerEmployeeLeavesSheetBody> createState() =>
      _ManagerEmployeeLeavesSheetBodyState();
}

class _ManagerEmployeeLeavesSheetBodyState
    extends State<_ManagerEmployeeLeavesSheetBody> {
  bool _loading = true;
  String? _error;
  List<LeaveTypeInfo> _types = const [];
  List<LeaveRequest> _requests = const [];
  List<ManagerEmployeeLeaveRequest> _rawLeaves = const [];

  LeaveBalancesSummary get _balances => LeaveBalancesSummary.fromTypes(_types);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = bindings.managerEmployeesService;
      final balancesRes = await service.loadEmployeeLeaveBalances(
        userId: widget.userId,
      );
      final leavesRes = await service.loadEmployeeLeaves(userId: widget.userId);
      if (!mounted) return;

      final balances = (balancesRes.success && balancesRes.data != null)
          ? balancesRes.data!
          : const <ManagerEmployeeLeaveBalance>[];
      final leaves = (leavesRes.success && leavesRes.data != null)
          ? leavesRes.data!
          : const <ManagerEmployeeLeaveRequest>[];

      final types = _typesFromBalances(balances);
      final requests = leaves
          .map(
            (leave) => ManagerLeaveView.fromEmployeeLeave(
              leave,
              userId: widget.userId,
              employeeName: widget.employeeName,
            ).toLeaveRequest(),
          )
          .toList(growable: false);

      setState(() {
        _types = types;
        _rawLeaves = leaves;
        _requests = requests;
        _loading = false;
        if (!balancesRes.success && !leavesRes.success) {
          _error = 'Could not load leaves';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load leaves';
      });
    }
  }

  List<LeaveTypeInfo> _typesFromBalances(
    List<ManagerEmployeeLeaveBalance> balances,
  ) {
    return balances.map((b) {
      final total = _asInt(b.entitled);
      final used = _asInt(b.used);
      var available = _asInt(b.remaining);
      if (available <= 0 && total > 0) {
        available = (total - used).clamp(0, total);
      }
      final id = (b.typeId ?? '').trim().isNotEmpty
          ? b.typeId!.trim()
          : b.type.trim();
      final rawName = b.type.trim();
      final name = (rawName.isNotEmpty && int.tryParse(rawName) == null)
          ? rawName
          : (rawName.isEmpty ? 'Leave' : rawName);
      return LeaveTypeInfo(
        id: id.isEmpty ? b.type : id,
        name: name,
        available: available < 0 ? 0 : available,
        total: total > 0 ? total : (available > 0 ? available : used),
      );
    }).toList(growable: false);
  }

  int _asInt(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.trim().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned)?.round() ?? int.tryParse(cleaned) ?? 0;
  }

  Future<void> _openAssign() async {
    await ApplyLeaveSheet.show(
      context,
      employeeUserId: widget.userId,
      employeeName: widget.employeeName,
    );
    await _load();
  }

  Future<void> _openDetail(int index) async {
    if (index < 0 || index >= _rawLeaves.length) return;
    await ManagerLeaveDetailSheet.show(
      context: context,
      leave: ManagerLeaveView.fromEmployeeLeave(
        _rawLeaves[index],
        userId: widget.userId,
        employeeName: widget.employeeName,
      ),
      employeeName: widget.employeeName,
      employeeRole: widget.employeeRole,
      employeePhoto: widget.employeePhoto,
    );
    await _load();
  }

  Future<void> _openLeaveTypes() {
    return AppSheet.show<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManagerEmployeeLeaveTypesSheetBody(types: _types),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balances = _balances;

    return ConstrainedBox(
      constraints: AppSheetSize.constraintsOf(context),
      child: Container(
        decoration: const BoxDecoration(
          color: kbackground1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    BackCircleButton(onTap: () => Navigator.pop(context)),
                    Expanded(
                      child: AppText.h5('Leaves', weight: FontWeight.w700),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(
                child: ShimmerRefreshIndicator(
                  instagramStyle: true,
                  triggerFraction: 0.40,
                  showOrb: false,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (_loading && _types.isEmpty && _requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: ShimmerProgress()),
                        )
                      else if (_error != null &&
                          _types.isEmpty &&
                          _requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: AppText.p2(_error!, color: kGreyColor),
                          ),
                        )
                      else ...[
                        _summaryCard(balances),
                        const SizedBox(height: 20),
                        AppText.p1(
                          'Leave Requests',
                          weight: FontWeight.w600,
                          align: TextAlign.left,
                        ),
                        const SizedBox(height: 12),
                        if (_requests.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: AppText.p2(
                                'No leave requests',
                                color: kGreyColor,
                              ),
                            ),
                          )
                        else
                          for (var i = 0; i < _requests.length; i++) ...[
                            LeaveRequestCard(
                              request: _requests[i],
                              onTap: () => _openDetail(i),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 16),
                child: Material(
                  elevation: 10,
                  color: kTransperentColor,
                  borderRadius: BorderRadius.circular(50),
                  shadowColor: kBlack.withOpacity(0.9),
                  child: MyButton(
                    width: double.infinity,
                    buttonText: 'Assign Leave',
                    backgroundColor: kBlack,
                    fontColor: kWhite,
                    onTap: _openAssign,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(LeaveBalancesSummary balances) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 18),
            child: Row(
              children: [
                _statCell(
                  value: '${balances.allAvailable}',
                  total: '${balances.allTotal}',
                  label: 'All Leaves',
                  valueColor: kPrimaryColor,
                ),
                Container(width: 1, height: 48, color: kBorderColor),
                _statCell(
                  value: '${balances.casualAvailable}',
                  total: '${balances.casualTotal}',
                  label: 'Casual Leaves',
                  valueColor: kPurple,
                ),
                Container(width: 1, height: 48, color: kBorderColor),
                _statCell(
                  value: '${balances.sickAvailable}',
                  total: '${balances.sickTotal}',
                  label: 'Sick Leaves',
                  valueColor: kPurple,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, thickness: 1, color: kBorderColor),
          ),
          ButtonAnimations.press(
            onTap: _openLeaveTypes,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppText.p1(
                      'Leave types',
                      weight: FontWeight.w500,
                      align: TextAlign.left,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: kGreyColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required String value,
    required String total,
    required String label,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    height: 1.2,
                  ),
                ),
                TextSpan(
                  text: ' / $total',
                  style: const TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 22,
                    color: kBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppText.caption(label, color: kGreyColor, weight: FontWeight.w500),
        ],
      ),
    );
  }
}

class _ManagerEmployeeLeaveTypesSheetBody extends StatelessWidget {
  const _ManagerEmployeeLeaveTypesSheetBody({required this.types});

  final List<LeaveTypeInfo> types;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: AppSheetSize.constraintsOf(context),
      child: Container(
        decoration: const BoxDecoration(
          color: kbackground1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    BackCircleButton(onTap: () => Navigator.pop(context)),
                    Expanded(
                      child: AppText.h5(
                        'Leave types',
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (types.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: AppText.p2(
                            'No leave types',
                            color: kGreyColor,
                          ),
                        ),
                      )
                    else
                      for (final type in types) ...[
                        _LeaveTypeCard(type: type),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveTypeCard extends StatelessWidget {
  const _LeaveTypeCard({required this.type});

  final LeaveTypeInfo type;

  static Color colorForProgress(double progress) {
    if (progress <= 0) return kGreyColor;
    if (progress <= 0.33) return kPrimaryColor;
    if (progress < 0.7) return kPurple;
    return kredColor;
  }

  String _usedLabel(int used) =>
      used == 0 ? '0' : used.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final used = type.used;
    final progress = type.progress.clamp(0.0, 1.0);
    final accent = colorForProgress(progress);
    final totalLabel = type.total.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText.p1(
                  type.name,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _usedLabel(used),
                      style: TextStyle(
                        fontFamily: AppFonts.Poppins,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    TextSpan(
                      text: ' / $totalLabel',
                      style: const TextStyle(
                        fontFamily: AppFonts.Poppins,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: kBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: kGreyContainerGreyColor.withValues(alpha: 0.7),
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          AppText.caption(
            type.resetLabel,
            color: kGreyColor,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
