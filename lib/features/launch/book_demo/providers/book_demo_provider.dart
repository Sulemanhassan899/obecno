import 'package:Obecno/core/api/base_provider.dart';

import '../data/models/book_demo_ticket_model.dart';
import '../domain/entities/book_demo_entity.dart';
import '../services/book_demo_service.dart';

/// UI-facing state for `book_demo.dart` / `request_demo.dart`.
///
/// Exposes [isLoading]/[hasError]/[errorMessage] via [BaseProvider], and
/// [submittedTicket] once a request has gone through, so
/// `request_demo.dart` can show a ticket id/reference if wanted.
class BookDemoProvider extends BaseProvider {
  BookDemoProvider(this._service);

  final BookDemoService _service;

  BookDemoTicketResult? _submittedTicket;
  BookDemoTicketResult? get submittedTicket => _submittedTicket;

  /// Submits the "Book a Demo" form. `phone`/`industry` are folded into
  /// the ticket's `content` message inside [BookDemoEntity] -- only
  /// `name`/`email` travel as their own fields.
  Future<bool> submitDemoRequest({
    required String name,
    required String email,
    required String phoneCode,
    required String phone,
    required String industry,
  }) {
    final entity = BookDemoEntity(
      name: name,
      email: email,
      phoneCode: phoneCode,
      phone: phone,
      industry: industry,
    );

    return safeCall<BookDemoTicketResult>(
      operationKey: 'book_demo_submit',
      request: (_) => _service.submitDemoRequest(entity),
      onSuccess: (data) => _submittedTicket = data,
    );
  }

  /// Clears state so the form can be reused for a fresh submission.
  void reset() {
    _submittedTicket = null;
  }
}
