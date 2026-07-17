import 'package:Obecno/core/api/api_response.dart';

import '../data/models/book_demo_ticket_model.dart';
import '../domain/entities/book_demo_entity.dart';
import '../repositories/book_demo_repository.dart';

/// Thin orchestration layer between [BookDemoProvider] (UI state) and
/// [BookDemoRepository] (network I/O) -- mirrors the role [AuthService]
/// plays for the auth module. No local persistence is needed here (a
/// demo request isn't a session), so this mostly keeps the provider
/// from having to build request models itself.
class BookDemoService {
  BookDemoService(this._repository);

  final BookDemoRepository _repository;

  Future<ApiResponse<BookDemoTicketResult>> submitDemoRequest(
    BookDemoEntity entity,
  ) {
    final model = BookDemoTicketModel(entity: entity);
    return _repository.submitDemoRequest(model);
  }
}
