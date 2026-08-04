import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/core/api/base_repository.dart';

import '../data/models/book_demo_ticket_model.dart';

class BookDemoRepository extends BaseRepository {
  BookDemoRepository(super.apiClient);

  Future<ApiResponse<BookDemoTicketResult>> submitDemoRequest(
    BookDemoTicketModel model,
  ) {
    return postRequest<BookDemoTicketResult>(
      ApiEndpoints.tickets,
      data: model.toJson(),
      parser: (json) {
        final decoded = json is Map<String, dynamic> ? json : null;
        if (decoded == null) {
          throw const ApiError(
            type: ApiErrorType.parsing,
            message: 'Unexpected response from server. Please try again.',
          );
        }

        final success = decoded['success'] == true;
        if (!success) {
          throw ApiError(
            type: ApiErrorType.server,
            message:
                (decoded['message'] as String?) ??
                'Failed to submit your demo request.',
          );
        }

        final body = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        return BookDemoTicketResult.fromJson(body);
      },
    );
  }
}
