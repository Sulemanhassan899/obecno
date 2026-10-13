import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/theme/light_theme.dart';
import 'package:obecno/features/employee_module/leaves/data/mock/leaves_mock_store.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/holidays_calendar_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leave_history_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leave_types_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leaves_screen.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/apply_leave_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_detail_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_type_picker_sheet.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_leaves_card.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/attendance_day_overview_sheet.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';

/// Renders Leaves UI screens to PNGs under tmp/leaves_preview for visual review.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(390, 844);
  final outDir = Directory('tmp/leaves_preview');

  setUpAll(() async {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    // Touch mock store so seed data exists.
    LeavesMockStore.instance;
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget child, {
    bool sheet = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFFF7F9FA),
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: size,
                  padding: EdgeInsets.only(top: 47, bottom: 34),
                ),
                child: RepaintBoundary(
                  key: key,
                  child: sheet
                      ? ColoredBox(
                          color: Colors.black54,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Material(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SizedBox(
                                height: size.height * 0.82,
                                child: child,
                              ),
                            ),
                          ),
                        )
                      : child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${outDir.path}/$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  }

  testWidgets('01 leaves overview', (tester) async {
    await capture(tester, '01_leaves_overview', const LeavesScreen());
  });

  testWidgets('02 leave types', (tester) async {
    await capture(tester, '02_leave_types', const LeaveTypesScreen());
  });

  testWidgets('03 leave history', (tester) async {
    await capture(tester, '03_leave_history', const LeaveHistoryScreen());
  });

  testWidgets('04 holidays calendar', (tester) async {
    await capture(
      tester,
      '04_holidays_calendar',
      const HolidaysCalendarScreen(),
    );
  });

  testWidgets('05 clock leaves card', (tester) async {
    await capture(
      tester,
      '05_clock_leaves_card',
      const Scaffold(
        backgroundColor: Color(0xFFF7F9FA),
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClockLeavesCard(),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('06 apply leave sheet', (tester) async {
    await capture(
      tester,
      '06_apply_leave_sheet',
      const ApplyLeaveSheet(),
      sheet: true,
    );
  });

  testWidgets('07 leave type picker', (tester) async {
    await capture(
      tester,
      '07_leave_type_picker',
      const LeaveTypePickerSheet(
        selectedTypeId: 'casual',
        requestedDays: 2,
      ),
      sheet: true,
    );
  });

  testWidgets('08 leave detail pending', (tester) async {
    final pending = LeavesMockStore.instance.requests
        .firstWhere((r) => r.isPending);
    await capture(
      tester,
      '08_leave_detail_pending',
      LeaveDetailSheet(requestId: pending.id),
      sheet: true,
    );
  });

  testWidgets('09 attendance day overview', (tester) async {
    await capture(
      tester,
      '09_attendance_day_overview',
      AttendanceDayOverviewSheet(
        day: DateTime(2025, 10, 17),
        apiClient: ApiClient(
          networkChecker: _OnlineNetwork(),
          tokenService: TokenService(),
        ),
        userEmail: 'demo@obecno.app',
      ),
      sheet: true,
    );
  });
}

class _OnlineNetwork implements NetworkChecker {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}
