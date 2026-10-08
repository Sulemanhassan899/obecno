import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_attendence_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('shows Late badge for open late check-in', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ManagerAttendanceTile(
          data: ManagerAttendanceModel(
            name: 'Employee1',
            checkIn: '10:50 AM',
            status: 'late',
          ),
        ),
      ),
    );

    expect(find.text('Late'), findsOneWidget);
    expect(find.text('10:50 AM'), findsOneWidget);
    expect(find.text('Working'), findsNothing);
  });

  testWidgets('shows Late badge even when checkout is present', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ManagerAttendanceTile(
          data: ManagerAttendanceModel(
            name: 'Employee1',
            checkIn: '10:50 AM',
            checkOut: '06:00 PM',
            status: 'late',
          ),
        ),
      ),
    );

    // Current behavior under test — Late must remain visible.
    expect(find.text('Late'), findsOneWidget);
  });

  testWidgets('recognizes late_check_in status key as Late', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ManagerAttendanceTile(
          data: ManagerAttendanceModel(
            name: 'Employee1',
            checkIn: '10:50 AM',
            status: 'late_check_in',
          ),
        ),
      ),
    );

    expect(find.text('Late'), findsOneWidget);
  });
}
