import 'package:obecno/core/api/base_provider.dart';

import '../data/models/book_demo_ticket_model.dart';
import '../domain/entities/book_demo_entity.dart';
import '../services/book_demo_service.dart';

class BookDemoProvider extends BaseProvider {
  BookDemoProvider(this._service);

  final BookDemoService _service;

  BookDemoTicketResult? _submittedTicket;
  BookDemoTicketResult? get submittedTicket => _submittedTicket;

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

  void reset() {
    _submittedTicket = null;
  }
}
