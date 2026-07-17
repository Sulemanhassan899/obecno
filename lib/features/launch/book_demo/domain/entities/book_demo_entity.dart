/// Pure domain representation of a "Book a Demo" request.
///
/// No JSON/API concerns live here — that's the data layer's job
/// ([BookDemoTicketModel]). This is just the fields the form on
/// `book_demo.dart` collects, plus the single place that turns them
/// into the free-text message the ticket API expects in `content`.
///
/// Per spec: only `name` and `email` are meant to travel as their own
/// fields — `phone` and `industry` are folded into the `content`
/// message instead of being sent as separate top-level params.
class BookDemoEntity {
  const BookDemoEntity({
    required this.name,
    required this.email,
    required this.phoneCode,
    required this.phone,
    required this.industry,
  });

  final String name;
  final String email;
  final String phoneCode;
  final String phone;
  final String industry;

  /// Builds the free-text ticket body sent as `content` to
  /// `POST /api/employee/tickets`.
  String buildContentMessage() {
    final buffer = StringBuffer()
      ..writeln('New demo request submitted from the app.')
      ..writeln()
      ..writeln('Name: $name')
      ..writeln('Email: $email')
      ..writeln('Phone: $phoneCode $phone')
      ..writeln('Industry / Sector: $industry');
    return buffer.toString().trim();
  }

  @override
  String toString() =>
      'BookDemoEntity(name: $name, email: $email, phone: $phoneCode$phone, industry: $industry)';
}
