import '../../domain/entities/book_demo_entity.dart';

/// Data-layer shape for a submitted demo request: wraps [BookDemoEntity]
/// with the exact JSON `POST /api/employee/tickets` expects.
///
/// A "Book a Demo" submission is, on the backend, just a guest ticket —
/// see the sample ticket response's `"submitter": {"type": "guest", ...}`.
/// No new endpoint is introduced; this reuses [ApiEndpoints.tickets]
/// (`/api/employee/tickets`), the same one the employee support-ticket
/// module already talks to.
class BookDemoTicketModel {
  const BookDemoTicketModel({
    required this.entity,
    this.categoryId,
    this.productId,
  });

  final BookDemoEntity entity;

  /// The sample ticket used category 3 ("Bugs / Technical") — a demo
  /// request should land in whichever category the backend uses for
  /// sales/demo leads. Pass the real id in once it's known; omitted
  /// from the JSON body when null so the backend can apply its own
  /// default instead of us guessing wrong.
  final int? categoryId;

  /// Same idea as [categoryId] — the sample ticket's `product_id: 2`
  /// is Obecno itself; leave null unless demo requests should be
  /// filed against a specific product.
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

/// Minimal parse of the ticket the backend hands back — mirrors the
/// `data.ticket` envelope in the sample response. Only what the UI
/// needs to confirm the submission.
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
      statusTitle:
          (ticket['status_title'] ?? ticket['status_label'] ?? '').toString(),
      createdAt: (ticket['created_at'] ?? '').toString(),
    );
  }

  @override
  String toString() =>
      'BookDemoTicketResult(ticketId: $ticketId, statusTitle: $statusTitle, createdAt: $createdAt)';
}
