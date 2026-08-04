class PrivacyModel {
  const PrivacyModel({required this.content, this.updatedAt});

  final String content;
  final String? updatedAt;

  factory PrivacyModel.fromApiJson(Map<String, dynamic> json) {
    final rawHtml =
        (json['content'] ??
                json['body'] ??
                json['description'] ??
                json['policy'] ??
                json['text'] ??
                json['html'] ??
                '')
            .toString();

    final updatedAt =
        (json['updated_at'] ??
                json['updatedAt'] ??
                json['last_updated'] ??
                json['modified_at'])
            ?.toString();

    return PrivacyModel(
      content: _htmlToPlainText(rawHtml),
      updatedAt: updatedAt,
    );
  }

  factory PrivacyModel.fromCache({required String content, String? updatedAt}) {
    return PrivacyModel(content: content, updatedAt: updatedAt);
  }

  bool isSameAs(PrivacyModel other) {
    if (updatedAt != null && other.updatedAt != null) {
      return updatedAt == other.updatedAt;
    }
    return content == other.content;
  }
}

String _htmlToPlainText(String html) {
  if (html.trim().isEmpty) return '';

  var text = html;

  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  text = text.replaceAll(
    RegExp(r'</(p|div|li|h[1-6]|tr|blockquote)\s*>', caseSensitive: false),
    '\n\n',
  );

  text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ');

  text = text.replaceAll(RegExp(r'<[^>]*>'), '');

  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&rsquo;': '\u2019',
    '&lsquo;': '\u2018',
    '&rdquo;': '\u201d',
    '&ldquo;': '\u201c',
    '&mdash;': '\u2014',
    '&ndash;': '\u2013',
  };
  entities.forEach((entity, replacement) {
    text = text.replaceAll(entity, replacement);
  });

  final lines = text.split('\n');
  final normalized = <String>[];
  var blankRun = 0;
  for (final raw in lines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      blankRun++;
      if (blankRun > 1) continue;
    } else {
      blankRun = 0;
    }
    normalized.add(trimmed);
  }

  return normalized.join('\n').trim();
}
