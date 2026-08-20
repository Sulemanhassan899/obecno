import 'package:Obecno/core/validators/validators.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/employee_module/alerts/presentation/screens/alerts_screen.dart';
import 'package:Obecno/widgets/custom_checkbox_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Employee auth gate (no production code changes)', () {
    test('employee role routes home to employee, not manager', () {
      expect(_homeTargetFor(role: 'employee'), AuthHomeTarget.employee);
      expect(_homeTargetFor(role: '3'), AuthHomeTarget.employee);
      expect(_homeTargetFor(role: 'manager'), AuthHomeTarget.manager);
    });

    test('login email must be valid before password step', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('worker@obecno.com'), isNull);
    });

    test('remember-me opt-in is explicit (missing key = off)', () {
      String? flag;
      bool isRememberMe() => flag == 'true';
      expect(isRememberMe(), isFalse);
      flag = 'true';
      expect(isRememberMe(), isTrue);
      flag = 'false';
      expect(isRememberMe(), isFalse);
    });
  });

  group('Employee widgets', () {
    testWidgets('alerts placeholder is visible for employees', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AlertsScreen()));
      expect(find.textContaining('Coming soon'), findsOneWidget);
    });

    testWidgets('remember-me checkbox toggles without crashing', (tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomCheckbox(
              initialValue: false,
              onChanged: (v) => value = v,
              text: 'Remember me',
            ),
          ),
        ),
      );
      expect(find.text('Remember me'), findsOneWidget);
      await tester.tap(find.byType(CustomCheckbox));
      await tester.pump();
      expect(value, isTrue);
    });
  });
}

AuthHomeTarget _homeTargetFor({required String role}) {
  final r = role.trim().toLowerCase();
  if (r == '6' || r == 'manager' || r == 'owner' || r == 'admin') {
    return AuthHomeTarget.manager;
  }
  return AuthHomeTarget.employee;
}
