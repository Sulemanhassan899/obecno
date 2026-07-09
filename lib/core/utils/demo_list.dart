import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/attendence_model.dart';
import 'package:Obecno/screens/bottom_sheets/location_detail_sheet.dart';
import 'package:Obecno/screens/bottom_sheets/company_detail_sheet.dart';

class ClockScreenDemoData {
  ClockScreenDemoData._();

  static List<LocationModel> get locations => [
    LocationModel(
      name: "Head Office",
      address: "100 Stour St, Birmingham B3 1DG, UK",
      image: Assets.imagesLocation1,
    ),
    LocationModel(
      name: "North Office",
      address: "Bailey St, Stafford ST17 4BG, UK",
      image: Assets.imagesLocation1,
    ),
    LocationModel(
      name: "South Office",
      address: "14 - 20 Elizabeth St, London SW1W 9RB, UK",
      image: "assets/map2.png",
    ),
    LocationModel(name: "Service Works", address: "No Location", image: ""),
  ];

  static List<CompanyModel> get companys => [
    CompanyModel(
      name: "Company 1",
      address: "100 Stour St, Birmingham B3 1DG, UK",
      image: Assets.imagesLocation1,
    ),
    CompanyModel(
      name: "Company 2",
      address: "Bailey St, Stafford ST17 4BG, UK",
      image: Assets.imagesLocation1,
    ),
    CompanyModel(
      name: "Company 3",
      address: "14 - 20 Elizabeth St, London SW1W 9RB, UK",
      image: "assets/map2.png",
    ),
    CompanyModel(name: "Service Works", address: "No Location", image: ""),
  ];
}

class MonthlyAttendanceDemoData {
  MonthlyAttendanceDemoData._();

  static MonthSummary summaryFor(DateTime month) {
    return const MonthSummary(
      workingDays: 18,
      totalDays: 22,
      absentOrLeaves: 4,
      lateCheckIns: 6,
      lateCheckOuts: 2,
    );
  }

  static List<AttendanceDayRecord> recordsFor(DateTime month) {
    return [
      /// 🔹 WEEK 1 (13 → 17)
      AttendanceDayRecord(
        day: 13,
        weekday: "Mon",
        date: DateTime(month.year, month.month, 13),
        checkIn: "08:48 AM",
        checkOut: "05:01 PM",
      ),
      AttendanceDayRecord(
        day: 14,
        weekday: "Tue",
        date: DateTime(month.year, month.month, 14),
        checkIn: "09:03 AM",
        checkOut: "05:23 PM",
        status: AttendanceDayStatus.manuallyEdited,
      ),
      AttendanceDayRecord(
        day: 15,
        weekday: "Wed",
        date: DateTime(month.year, month.month, 15),
        checkIn: "08:52 AM",
        checkOut: "05:12 PM",
      ),
      AttendanceDayRecord(
        day: 16,
        weekday: "Thu", // ✅ fixed
        date: DateTime(month.year, month.month, 16),
        checkIn: "09:01 AM",
        checkOut: "05:02 PM",
      ),
      AttendanceDayRecord(
        day: 17,
        weekday: "Fri",
        date: DateTime(month.year, month.month, 17),
        checkIn: "09:40 AM",
        checkOut: null,
        status: AttendanceDayStatus.missingCheckOut,
      ),

      /// 🔹 WEEK 2 (20 → 24)
      AttendanceDayRecord(
        day: 20,
        weekday: "Mon",
        date: DateTime(month.year, month.month, 20),
        checkIn: null,
        checkOut: null,
        status: AttendanceDayStatus.absent,
      ),
      AttendanceDayRecord(
        day: 21,
        weekday: "Tue",
        date: DateTime(month.year, month.month, 21),
        checkIn: "08:50 AM",
        checkOut: "05:00 PM",
      ),
      AttendanceDayRecord(
        day: 22,
        weekday: "Wed",
        date: DateTime(month.year, month.month, 22),
        checkIn: "09:20 AM",
        checkOut: "05:15 PM",
        status: AttendanceDayStatus.lateCheckIn,
      ),
      AttendanceDayRecord(
        day: 23,
        weekday: "Thu",
        date: DateTime(month.year, month.month, 23),
        checkIn: "08:59 AM",
        checkOut: "05:05 PM",
      ),
      AttendanceDayRecord(
        day: 24,
        weekday: "Fri",
        date: DateTime(month.year, month.month, 24),
        checkIn: "09:10 AM",
        checkOut: "05:30 PM",
      ),

      /// 🔹 WEEK 3 (27 → 31)
      AttendanceDayRecord(
        day: 27,
        weekday: "Mon",
        date: DateTime(month.year, month.month, 27),
        checkIn: "08:50 AM",
        checkOut: "05:10 PM",
      ),
      AttendanceDayRecord(
        day: 28,
        weekday: "Tue",
        date: DateTime(month.year, month.month, 28),
        checkIn: "08:45 AM",
        checkOut: "05:00 PM",
      ),
      AttendanceDayRecord(
        day: 29,
        weekday: "Wed",
        date: DateTime(month.year, month.month, 29),
        checkIn: "09:25 AM",
        checkOut: "05:40 PM",
        status: AttendanceDayStatus.lateCheckIn,
      ),
      AttendanceDayRecord(
        day: 30,
        weekday: "Thu",
        date: DateTime(month.year, month.month, 30),
        checkIn: "08:55 AM",
        checkOut: "05:02 PM",
      ),
      AttendanceDayRecord(
        day: 31,
        weekday: "Fri",
        date: DateTime(month.year, month.month, 31),
        checkIn: "09:05 AM",
        checkOut: "05:18 PM",
      ),
    ];
  }
}
