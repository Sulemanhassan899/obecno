import '../domain/help_feedback_entity.dart';

class HelpFeedbackTicketModel {
  const HelpFeedbackTicketModel({required this.entity});

  final HelpFeedbackEntity entity;

  Map<String, dynamic> toJson() {
    return {
      'user_name': entity.name,
      'user_email': entity.email,
      'content': entity.buildContentMessage(),
    };
  }
}

class HelpFeedbackTicketResult {
  const HelpFeedbackTicketResult({
    required this.ticketId,
    required this.statusTitle,
    required this.createdAt,
  });

  final int ticketId;
  final String statusTitle;
  final String createdAt;

  factory HelpFeedbackTicketResult.fromJson(Map<String, dynamic> json) {
    final ticket = json['ticket'] is Map<String, dynamic>
        ? json['ticket'] as Map<String, dynamic>
        : json;

    return HelpFeedbackTicketResult(
      ticketId: int.tryParse(ticket['id']?.toString() ?? '') ?? 0,
      statusTitle: (ticket['status_title'] ?? ticket['status_label'] ?? '')
          .toString(),
      createdAt: (ticket['created_at'] ?? '').toString(),
    );
  }
}
