import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/theme/light_theme.dart';
import 'package:obecno/features/employee_module/leaves/data/leaves_store.dart';
import 'package:obecno/features/employee_module/leaves/data/services/leaves_service.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
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
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/binding/app_binding.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Renders Leaves UI screens to PNGs under tmp/leaves_preview for visual review.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(390, 844);
  final outDir = Directory('tmp/leaves_preview');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Assign before any await so LeavesStore._userId / ApplyLeaveSheet never
    // read an uninitialized late [bindings].
    app.bindings = AppBindings();
    await app.bindings.initForWidgetTests();
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    LeavesStore.instance.debugReplace(
      service: _ScreenshotLeavesService(),
      quotaResetLabel: 'Leaves quota will be reset on 01 Jan 2027',
      types: const [
        LeaveTypeInfo(
          id: 'casual',
          name: 'Casual Leaves',
          available: 1,
          total: 10,
          accent: LeaveTypeAccent.red,
        ),
        LeaveTypeInfo(
          id: 'sick',
          name: 'Sick Leaves',
          available: 6,
          total: 10,
          requiresDocument: true,
          accent: LeaveTypeAccent.purple,
        ),
        LeaveTypeInfo(
          id: 'emergency',
          name: 'Emergency Leaves',
          available: 6,
          total: 10,
          accent: LeaveTypeAccent.green,
        ),
        LeaveTypeInfo(
          id: 'marriage',
          name: 'Marriage',
          available: 10,
          total: 10,
          resetLabel: 'One time',
          accent: LeaveTypeAccent.grey,
        ),
        LeaveTypeInfo(
          id: 'misc',
          name: 'Miscellaneous leave',
          available: 10,
          total: 10,
        ),
        LeaveTypeInfo(
          id: 'paternity',
          name: 'Paternity leave',
          available: 2,
          total: 5,
          accent: LeaveTypeAccent.purple,
        ),
        LeaveTypeInfo(
          id: 'bereavement',
          name: 'Bereavement leave',
          available: 1,
          total: 3,
          accent: LeaveTypeAccent.red,
        ),
      ],
      holidays: [
        LeaveHoliday(date: DateTime(2026, 1, 1), name: "New Year's Day"),
        LeaveHoliday(
          date: DateTime(2026, 3, 21),
          name: 'Eid-ul-Fitr (Expected)',
          days: 3,
        ),
      ],
      requests: [
        LeaveRequest(
          id: 'leave_seed_pending',
          typeId: 'sick',
          typeName: 'Sick Leave',
          startDate: DateTime(2025, 10, 12),
          endDate: DateTime(2025, 10, 14),
          status: LeaveRequestStatus.pending,
          note: "I've been feeling unwell due to frequent business trips.",
          createdAt: DateTime(2025, 10, 11, 9, 0),
          documentName: 'Filename etc.',
          timeline: [
            LeaveTimelineEvent(
              id: 'leave_seed_pending_req',
              kind: LeaveTimelineKind.requested,
              at: DateTime(2025, 10, 17, 22, 23),
            ),
          ],
        ),
      ],
    );
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
      TickerMode(
        enabled: false,
        child: MaterialApp(
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
                    disableAnimations: true,
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
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Layout overflows on the fixed 390px frame are OK for preview PNGs.
    while (tester.takeException() != null) {}
    expect(key.currentContext, isNotNull);

    // PNG export is best-effort (toImage can hang on some CI/macOS runners).
    unawaited(() async {
      try {
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        final image = await boundary
            .toImage(pixelRatio: 2)
            .timeout(const Duration(seconds: 2));
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return;
        await File('${outDir.path}/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List());
      } catch (_) {}
    }());
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
    final pending = LeavesStore.instance.requests.firstWhere((r) => r.isPending);
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

class _OfflineNetwork implements NetworkChecker {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

/// Avoids live `/employee/leaves*` calls when screens call [LeavesStore.refresh].
class _ScreenshotLeavesService extends LeavesService {
  _ScreenshotLeavesService()
      : super(
          ApiClient(
            networkChecker: _OfflineNetwork(),
            tokenService: TokenService(),
          ),
        );

  @override
  Future<ApiResponse<List<LeaveRequest>>> getLeaves({
    String? dateFrom,
    String? dateTo,
    String? status,
    ApiCancelToken? cancelToken,
  }) async =>
      ApiResponse.success(const []);

  @override
  Future<ApiResponse<LeaveBalancesPayload>> getBalances({
    ApiCancelToken? cancelToken,
  }) async =>
      ApiResponse.success(
        LeaveBalancesPayload(
          types: const [],
          summary: LeaveBalancesSummary.fromTypes(const []),
        ),
      );

  @override
  Future<ApiResponse<List<LeaveTypeInfo>>> getTypes({
    ApiCancelToken? cancelToken,
  }) async =>
      ApiResponse.success(const []);
}
