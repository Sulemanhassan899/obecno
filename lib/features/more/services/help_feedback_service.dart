import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';

import '../data/models/help_feedback_ticket_model.dart';
import '../data/domain/help_feedback_entity.dart';
import '../repositories/help_feedback_repository.dart';

class HelpFeedbackService {
  HelpFeedbackService(this._repository);

  final HelpFeedbackRepository _repository;

  static const _red = '\x1B[31m';
  static const _reset = '\x1B[0m';

  Future<ApiResponse<HelpFeedbackTicketResult>> submitFeedback(
    HelpFeedbackEntity entity,
  ) {
    final model = HelpFeedbackTicketModel(entity: entity);
    _logSubmitPayload(model.toJson());
    return _repository.submitFeedback(model);
  }

  void _logSubmitPayload(Map<String, dynamic> payload) {
    if (!kDebugMode) return;

    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    print('$_red========== HELP & FEEDBACK SUBMIT ==========');
    print('Endpoint: ${EmployeeApiEndpoints.tickets}');
    print('Payload sent:');
    print(pretty);
    print('==========================================$_reset');
  }
}
