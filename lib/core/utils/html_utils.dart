/// Extracts a readable `<title>` from the first bytes of an HTML document.
String? extractHtmlTitle(String html) {
  final RegExpMatch? match = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  if (match == null) {
    return null;
  }
  String title = match.group(1) ?? '';
  title = title
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isEmpty || title.length > 120) {
    return title.isEmpty ? null : title.substring(0, 120);
  }
  return decodeBasicHtmlEntities(title);
}

String decodeBasicHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}
