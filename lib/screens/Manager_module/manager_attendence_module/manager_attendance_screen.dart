import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/utils/demo_list.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/manager_attendence_model.dart';
import 'package:Obecno/screens/Manager_module/manager_attendence_module/widget/manager_attendance_widgets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  /// ✅ LOCAL STATE LIST (FIX)
  List<ManagerAttendanceModel> _filteredList = List.from(
    dummyManagerAttendance,
  );

  String selectedStatus = "Status";
  String selectedLocation = "Locations";

  /// ✅ FILTER LOGIC (VERY IMPORTANT)
  void _applyFilters() {
    List<ManagerAttendanceModel> tempList = List.from(dummyManagerAttendance);

    /// STATUS FILTER
    if (selectedStatus != "Status") {
      tempList = tempList.where((item) {
        return item.status.toLowerCase() == selectedStatus.toLowerCase();
      }).toList();
    }

    /// LOCATION FILTER (if you have location field later)
    if (selectedLocation != "Locations") {
      tempList = tempList.where((item) {
        return (item.team ?? "").toLowerCase() ==
            selectedLocation.toLowerCase();
      }).toList();
    }

    /// 🔥 THIS TRIGGERS UI UPDATE
    setState(() {
      _filteredList = tempList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground.withOpacity(0.2),
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          children: [
            /// HEADER
            const ManagerAttendanceHeader(),

            const SizedBox(height: 12),

            /// ✅ CONNECT FILTERS TO STATE
            ManagerFilters(
              onStatusChanged: (value) {
                selectedStatus = value;
                _applyFilters(); // 🔥 important
              },
              onLocationChanged: (value) {
                selectedLocation = value;
                _applyFilters(); // 🔥 important
              },
            ),

            const SizedBox(height: 12),

            /// LIST
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,

                /// ✅ USE FILTERED LIST (FIX)
                itemCount: _filteredList.length,

                separatorBuilder: (_, __) =>
                    const Divider(height: 24, color: kDividerColor),

                itemBuilder: (context, index) {
                  final item = _filteredList[index];

                  return ManagerAttendanceTile(data: item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
