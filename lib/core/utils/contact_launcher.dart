import 'package:obecno/features/more/data/domain/help_feedback_entity.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device mail / dialer / SMS / WhatsApp apps for an employee contact.
class ContactLauncher {
  ContactLauncher._();

  static Future<bool> email(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return false;
    return _launch(
      Uri(scheme: 'mailto', path: trimmed),
      preferred: LaunchMode.externalApplication,
    );
  }

  static Future<bool> call(String phone) async {
    final digits = _dialable(phone);
    if (digits == null) return false;
    return _launch(
      Uri(scheme: 'tel', path: digits),
      preferred: LaunchMode.externalApplication,
    );
  }

  static Future<bool> message(String phone) async {
    final digits = _dialable(phone);
    if (digits == null) return false;
    return _launch(
      Uri(scheme: 'sms', path: digits),
      preferred: LaunchMode.externalApplication,
    );
  }

  static Future<bool> whatsapp(String phone) async {
    final e164 = _whatsappDigits(phone);
    if (e164 == null) return false;

    final appUri = Uri.parse('whatsapp://send?phone=$e164');
    if (await _launch(appUri, preferred: LaunchMode.externalApplication)) {
      return true;
    }

    return _launch(
      Uri.https('wa.me', '/$e164'),
      preferred: LaunchMode.externalApplication,
    );
  }

  /// Digits suitable for `tel:` / `sms:` (keeps leading `+` when present).
  static String? _dialable(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final cleaned = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty || cleaned == '+') return null;
    return cleaned;
  }

  /// International digits without `+` for WhatsApp / `wa.me`.
  static String? _whatsappDigits(String raw) {
    final parts = HelpFeedbackPhone.split(raw);
    final local = parts.number.replaceAll(RegExp(r'\D'), '');
    if (local.isEmpty) return null;
    final country = parts.code.replaceAll(RegExp(r'\D'), '');
    return '$country$local';
  }

  static Future<bool> _launch(
    Uri uri, {
    required LaunchMode preferred,
  }) async {
    try {
      if (await launchUrl(uri, mode: preferred)) return true;
    } catch (_) {}
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}
