import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiCancelToken starts active and cancels once', () async {
    final token = ApiCancelToken();
    expect(token.isCancelled, isFalse);
    token.cancel('bye');
    expect(token.isCancelled, isTrue);
    expect(token.reason, 'bye');
    await expectLater(token.whenCancelled, completes);
  });
}
