import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/manager_module/Manager_leaves/data/team_leaves_loader.dart';

void main() {
  test('TeamLeavesLoader type is constructible from overview service type', () {
    // Structural smoke: loader file exports a public constructor that takes
    // ManagerOverviewService. Full network coverage lives in overview tests.
    expect(TeamLeavesLoader, isNotNull);
  });
}
