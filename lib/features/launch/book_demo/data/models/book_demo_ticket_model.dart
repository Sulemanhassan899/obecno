import '../../domain/entities/book_demo_entity.dart';

class BookDemoTicketModel {
  const BookDemoTicketModel({
    required this.entity,
    this.categoryId,
    this.productId,
  });

  final BookDemoEntity entity;

  final int? categoryId;

  final int? productId;

  Map<String, dynamic> toJson() {
    return {
      'user_name': entity.name,
      'user_email': entity.email,
      'content': entity.buildContentMessage(),
      if (categoryId != null) 'category_id': categoryId,
      if (productId != null) 'product_id': productId,
    };
  }
}

class BookDemoTicketResult {
  const BookDemoTicketResult({
    required this.ticketId,
    required this.statusTitle,
    required this.createdAt,
  });

  final int ticketId;
  final String statusTitle;
  final String createdAt;

  factory BookDemoTicketResult.fromJson(Map<String, dynamic> json) {
    final ticket = json['ticket'] is Map<String, dynamic>
        ? json['ticket'] as Map<String, dynamic>
        : json;

    return BookDemoTicketResult(
      ticketId: int.tryParse(ticket['id']?.toString() ?? '') ?? 0,
      statusTitle: (ticket['status_title'] ?? ticket['status_label'] ?? '')
          .toString(),
      createdAt: (ticket['created_at'] ?? '').toString(),
    );
  }

  @override
  String toString() =>
      'BookDemoTicketResult(ticketId: $ticketId, statusTitle: $statusTitle, createdAt: $createdAt)';
}
