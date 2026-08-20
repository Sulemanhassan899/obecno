import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/employee_module/alerts/presentation/screens/alerts_screen.dart';

void main() {
  testWidgets('Alerts screen shows coming soon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AlertsScreen()));
    expect(find.textContaining('Coming soon'), findsOneWidget);
  });
}
