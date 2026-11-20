import 'dart:convert';

const Set<String> _downloadExtensions = <String>{
  '7z',
  'apk',
  'avi',
  'bin',
  'bz2',
  'csv',
  'deb',
  'dmg',
  'doc',
  'docx',
  'epub',
  'exe',
  'flac',
  'gz',
  'img',
  'iso',
  'json',
  'm4a',
  'mkv',
  'mov',
  'mp3',
  'mp4',
  'msi',
  'odt',
  'pdf',
  'pkg',
  'ppt',
  'pptx',
  'rar',
  'rpm',
  'tar',
  'tbz2',
  'tgz',
  'txt',
  'wav',
  'webm',
  'xls',
  'xlsx',
  'xml',
  'xz',
  'yaml',
  'yml',
  'zip',
};

const Map<String, String> _mimeByExtension = <String, String>{
  '7z': 'application/x-7z-compressed',
  'apk': 'application/vnd.android.package-archive',
  'avi': 'video/x-msvideo',
  'bin': 'application/octet-stream',
  'bz2': 'application/x-bzip2',
  'csv': 'text/csv',
  'deb': 'application/vnd.debian.binary-package',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'epub': 'application/epub+zip',
  'exe': 'application/vnd.microsoft.portable-executable',
  'flac': 'audio/flac',
  'gz': 'application/gzip',
  'img': 'application/octet-stream',
  'iso': 'application/x-iso9660-image',
  'json': 'application/json',
  'm4a': 'audio/mp4',
  'mkv': 'video/x-matroska',
  'mov': 'video/quicktime',
  'mp3': 'audio/mpeg',
  'mp4': 'video/mp4',
  'msi': 'application/x-msi',
  'odt': 'application/vnd.oasis.opendocument.text',
  'pdf': 'application/pdf',
  'pkg': 'application/octet-stream',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'rar': 'application/vnd.rar',
  'rpm': 'application/x-rpm',
  'tar': 'application/x-tar',
  'txt': 'text/plain',
  'wav': 'audio/wav',
  'webm': 'video/webm',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'xml': 'application/xml',
  'xz': 'application/x-xz',
  'yaml': 'application/yaml',
  'yml': 'application/yaml',
  'zip': 'application/zip',
};

String? extensionOf(String value) {
  final String path = Uri.tryParse(value)?.path ?? value;
  final int slash = path.lastIndexOf('/');
  final String name = slash >= 0 ? path.substring(slash + 1) : path;
  final int dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) {
    return null;
  }
  return name.substring(dot + 1).toLowerCase();
}

String? mimeForFileName(String fileName) {
  final String? extension = extensionOf(fileName);
  return extension == null ? null : _mimeByExtension[extension];
}

bool looksLikeDownloadUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !<String>{'http', 'https'}.contains(uri.scheme)) {
    return false;
  }
  final String? extension = extensionOf(uri.path);
  if (extension != null && _downloadExtensions.contains(extension)) {
    return true;
  }
  final String lower = url.toLowerCase();
  return lower.contains('/download') ||
      lower.contains('download=') ||
      lower.contains('attachment');
}

bool shouldProbeForAttachment(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !<String>{'http', 'https'}.contains(uri.scheme)) {
    return false;
  }
  if (looksLikeDownloadUrl(url)) {
    return true;
  }
  final String? extension = extensionOf(uri.path);
  // Pages without a conventional HTML extension (or PHP/ASP handlers) may
  // still return Content-Disposition: attachment.
  return extension == null ||
      <String>{'php', 'asp', 'aspx', 'jsp', 'cgi', 'do', 'action'}
          .contains(extension);
}

bool isRiskyFileName(String fileName) {
  final String? extension = extensionOf(fileName);
  return extension != null &&
      <String>{'apk', 'exe', 'msi', 'bat', 'cmd', 'sh', 'ps1', 'bin', 'img'}
          .contains(extension);
}

String safeFileName(String candidate, {String fallback = 'download'}) {
  String name = candidate.trim();
  name = name.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  while (name.startsWith('.')) {
    name = name.substring(1).trim();
  }
  if (name.isEmpty) {
    name = fallback;
  }
  if (name.length > 120) {
    final int dot = name.lastIndexOf('.');
    final String extension = dot > 0 ? name.substring(dot) : '';
    final int keep = (120 - extension.length).clamp(1, 120);
    name = '${name.substring(0, keep)}$extension';
  }
  return name;
}

String fileNameFromDisposition(String? disposition) {
  if (disposition == null || disposition.trim().isEmpty) {
    return '';
  }
  final RegExp extended = RegExp(
    r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
    caseSensitive: false,
  );
  final RegExpMatch? extendedMatch = extended.firstMatch(disposition);
  if (extendedMatch != null) {
    String value = extendedMatch.group(1)!.trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length > 1) {
      value = value.substring(1, value.length - 1);
    }
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }
  final RegExp plain = RegExp(
    r'filename\s*=\s*"([^"]+)"|filename\s*=\s*([^;]+)',
    caseSensitive: false,
  );
  final RegExpMatch? match = plain.firstMatch(disposition);
  if (match == null) {
    return '';
  }
  String value = (match.group(1) ?? match.group(2) ?? '').trim();
  if (value.startsWith('"') && value.endsWith('"') && value.length > 1) {
    value = value.substring(1, value.length - 1);
  }
  try {
    return utf8.decode(latin1.encode(value));
  } on Object {
    return value;
  }
}

String fileNameFromUrl(String url, {String fallback = 'download'}) {
  final Uri? uri = Uri.tryParse(url);
  final String path = uri?.path ?? '';
  final int slash = path.lastIndexOf('/');
  final String raw = slash >= 0 ? path.substring(slash + 1) : path;
  String decoded = raw;
  try {
    decoded = Uri.decodeComponent(raw);
  } on ArgumentError {
    // Keep the raw name if the server sent malformed percent escapes.
  }
  return safeFileName(decoded, fallback: fallback);
}
