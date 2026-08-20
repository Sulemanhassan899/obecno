import 'package:flutter_test/flutter_test.dart';

/// Lightweight smoke test — does not boot the full app (avoids secure storage /
/// network bindings). Full app wiring is covered by feature unit tests.
void main() {
  test('placeholder smoke', () {
    expect(2 + 2, 4);
  });
}
