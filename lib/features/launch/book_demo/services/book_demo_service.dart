import 'package:Obecno/core/api/api_response.dart';

import '../data/models/book_demo_ticket_model.dart';
import '../domain/entities/book_demo_entity.dart';
import '../repositories/book_demo_repository.dart';

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
