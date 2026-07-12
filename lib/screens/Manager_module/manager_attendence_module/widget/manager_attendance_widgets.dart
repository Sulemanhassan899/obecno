import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/manager_attendence_model.dart';
import 'package:Obecno/screens/Manager_module/manager_attendence_module/widget/filter_dropdown_chip.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/utils/demo_list.dart';

/// =======================================================
/// HEADER
/// =======================================================
class ManagerAttendanceHeader extends StatelessWidget {
  const ManagerAttendanceHeader({
    super.key,
    this.dateLabel = "Today - 12 Jan",
    this.onDateTap,
    this.onSearchTap,
  });

  final String dateLabel;
  final VoidCallback? onDateTap;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ButtonAnimations.press(
            onTap: onDateTap,
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: kGreyColor),
                const SizedBox(width: 10),
                AppText.h6(dateLabel, color: kBlack),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
          const Spacer(),
          ButtonAnimations.press(
            onTap: onSearchTap,
            child: Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                border: Border.all(color: kBorderColor),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerFilters extends StatefulWidget {
  const ManagerFilters({
    super.key,
    this.onStatusChanged,
    this.onLocationChanged,
  });

  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<String>? onLocationChanged;

  @override
  State<ManagerFilters> createState() => _ManagerFiltersState();
}

class _ManagerFiltersState extends State<ManagerFilters> {
  static const List<String> _statusOptions = [
    "Status",
    "Working",
    "On Break",
    "Late",
    "On Leave",
  ];

  static const List<String> _locationOptions = [
    "Locations",
    "Head Office",
    "Warehouse",
    "Remote",
  ];

  String _selectedStatus = _statusOptions.first;
  String _selectedLocation = _locationOptions.first;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilterDropdownChip(
            label: _selectedStatus,
            options: _statusOptions,
            onSelected: (value) {
              setState(() => _selectedStatus = value);
              widget.onStatusChanged?.call(value);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilterDropdownChip(
            label: _selectedLocation,
            options: _locationOptions,
            onSelected: (value) {
              setState(() => _selectedLocation = value);
              widget.onLocationChanged?.call(value);
            },
          ),
        ),
      ],
    );
  }
}

class ManagerAttendanceTile extends StatelessWidget {
  final ManagerAttendanceModel data;
  final VoidCallback? onTap;

  const ManagerAttendanceTile({super.key, required this.data, this.onTap});

  /// ---------------- HELPERS ----------------

  bool get _hasCheckIn => data.checkIn != null && data.checkIn!.isNotEmpty;

  bool get _hasCheckOut =>
      data.checkOut != null && data.checkOut!.isNotEmpty;

  bool get _hasRole =>
      data.role != null && data.role!.trim().isNotEmpty;

  bool get _hasTeam =>
      data.team != null && data.team!.trim().isNotEmpty;

  bool get _showEmptyState => !_hasCheckIn && !_hasCheckOut;

  String _statusText() {
    if (data.status.isEmpty) return "";

    switch (data.status.toLowerCase()) {
      case "working":
        return "Working";
      case "break":
        return "On Break";
      case "late":
        return "Late";
      case "leave":
        return "On Leave";
      default:
        return data.status;
    }
  }

  Color _statusBgColor() {
    switch (data.status.toLowerCase()) {
      case "working":
        return Colors.green.withOpacity(0.1);
      case "late":
        return Colors.red.withOpacity(0.1);
      case "break":
        return Colors.orange.withOpacity(0.1);
      case "leave":
        return Colors.blue.withOpacity(0.1);
      default:
        return kPrimaryColor2;
    }
  }

  Color _statusTextColor() {
    switch (data.status.toLowerCase()) {
      case "working":
        return Colors.green;
      case "late":
        return Colors.red;
      case "break":
        return Colors.orange;
      case "leave":
        return Colors.blue;
      default:
        return kPrimaryColor;
    }
  }

  Widget _connector() {
    return Row(
      children: [
        Icon(Icons.circle, size: 5, color: kGreyColor.withOpacity(0.3)),
        Container(width: 20, height: 2, color: kGreyColor.withOpacity(0.3)),
        Icon(Icons.circle, size: 5, color: kGreyColor.withOpacity(0.3)),
      ],
    );
  }

  Widget _statusBadge() {
    if (_statusText().isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBgColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText.caption(
        _statusText(),
        color: _statusTextColor(),
        weight: FontWeight.w400,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kGreyColor.withOpacity(0.2),
      ),
      child: const Text("-", style: TextStyle(fontSize: 12)),
    );
  }

  /// ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            /// LEFT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.p2(data.name),

                  const SizedBox(height: 6),

                  /// ROLE + TEAM (DECOUPLED)
                  if (_hasRole || _hasTeam)
                    Row(
                      children: [
                        /// ROLE
                        if (_hasRole)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AppText.caption(
                              data.role!,
                              color: kBlack,
                              weight: FontWeight.w600,
                            ),
                          ),

                        /// SPACING BETWEEN ROLE & TEAM
                        if (_hasRole && _hasTeam)
                          const SizedBox(width: 6),

                        /// TEAM (INDEPENDENT)
                        if (_hasTeam)
                          AppText.p2("[${data.team}]"),
                      ],
                    ),
                ],
              ),
            ),

            /// RIGHT SIDE
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (data.warning) ...[
                  CommonImageView(
                    imagePath: Assets.imagesTriangleExclamation,
                    height: 18,
                  ),
                  const SizedBox(width: 6),
                ],

                if (data.editIcon) ...[
                  CommonImageView(
                    imagePath: Assets.imagesPen,
                    height: 18,
                  ),
                  const SizedBox(width: 6),
                ],

                if (_showEmptyState) _emptyState(),

                if (_hasCheckIn && !_showEmptyState)
                  AppText.p2(data.checkIn!),

                if (_hasCheckIn) ...[
                  const SizedBox(width: 6),
                  _connector(),
                  const SizedBox(width: 6),
                ],

                if (_hasCheckOut)
                  AppText.p2(data.checkOut!)
                else if (_hasCheckIn)
                  _statusBadge(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}