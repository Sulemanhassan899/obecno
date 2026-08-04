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
