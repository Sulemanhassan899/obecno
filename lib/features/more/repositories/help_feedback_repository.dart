import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';

import '../data/models/help_feedback_ticket_model.dart';

class HelpFeedbackRepository extends BaseRepository {
  HelpFeedbackRepository(super.apiClient);

  Future<ApiResponse<HelpFeedbackTicketResult>> submitFeedback(
    HelpFeedbackTicketModel model,
  ) {
    return postRequest<HelpFeedbackTicketResult>(
      EmployeeApiEndpoints.tickets,
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
                'Failed to submit your request.',
          );
        }

        final body = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        return HelpFeedbackTicketResult.fromJson(body);
      },
    );
  }
}
