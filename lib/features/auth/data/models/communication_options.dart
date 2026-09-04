/// Contact channels from `/auth/me` `communication_option`.
///
/// `email` → email icon.
/// `phone` → call, SMS, and WhatsApp.
/// Values can be combined (`email,phone`, a list, etc.).
class CommunicationOptions {
  const CommunicationOptions({
    required this.showCall,
    required this.showMessage,
    required this.showWhatsapp,
    required this.showEmail,
  });

  final bool showCall;
  final bool showMessage;
  final bool showWhatsapp;
  final bool showEmail;

  static const all = CommunicationOptions(
    showCall: true,
    showMessage: true,
    showWhatsapp: true,
    showEmail: true,
  );

  static const none = CommunicationOptions(
    showCall: false,
    showMessage: false,
    showWhatsapp: false,
    showEmail: false,
  );

  bool get hasAny => showCall || showMessage || showWhatsapp || showEmail;

  factory CommunicationOptions.parse(dynamic raw) {
    final tokens = _tokens(raw);
    if (tokens.isEmpty) return all;

    var showCall = false;
    var showMessage = false;
    var showWhatsapp = false;
    var showEmail = false;

    for (final token in tokens) {
      switch (token) {
        case 'all':
        case 'any':
          return all;
        case 'email':
        case 'mail':
          showEmail = true;
        case 'phone':
        case 'call':
        case 'mobile':
        case 'cell':
          showCall = true;
          showMessage = true;
          showWhatsapp = true;
        case 'sms':
        case 'msg':
        case 'message':
        case 'text':
          showMessage = true;
        case 'whatsapp':
        case 'wa':
          showWhatsapp = true;
      }
    }

    if (!showCall && !showMessage && !showWhatsapp && !showEmail) return all;
    return CommunicationOptions(
      showCall: showCall,
      showMessage: showMessage,
      showWhatsapp: showWhatsapp,
      showEmail: showEmail,
    );
  }

  static Set<String> _tokens(dynamic raw) {
    final out = <String>{};
    if (raw == null) return out;

    if (raw is List) {
      for (final item in raw) {
        out.addAll(_tokens(item));
      }
      return out;
    }

    var value = raw.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'null') return out;
    value = value.replaceAll(RegExp(r'[_/|+\-]+'), ',');
    value = value.replaceAll(' and ', ',');
    for (final part in value.split(',')) {
      final token = part.trim().replaceAll(RegExp(r'\s+'), '');
      if (token.isNotEmpty) out.add(token);
    }
    return out;
  }
}
