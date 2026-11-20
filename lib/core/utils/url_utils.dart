/// URL helpers shared by the add-service form, scan results and WebView.
///
/// LANDeck only accepts web URLs. A missing scheme is filled with
/// [defaultScheme] (HTTP by default), while an explicit scheme is preserved.
String? normalizeHttpUrl(String raw, {String defaultScheme = 'http'}) {
  String value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  if (value.contains(RegExp(r'\s'))) {
    return null;
  }
  if (value.startsWith('//')) {
    value = '$defaultScheme:$value';
  } else if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value)) {
    value = '$defaultScheme://$value';
  }

  final Uri? uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  final String scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
    return null;
  }
  if (uri.userInfo.isNotEmpty) {
    return null;
  }

  final String host = uri.host.toLowerCase();
  final bool defaultPort =
      (scheme == 'http' && uri.port == 80) ||
      (scheme == 'https' && uri.port == 443);
  final Uri normalized = uri.replace(
    scheme: scheme,
    host: host,
    port: defaultPort || !uri.hasPort ? null : uri.port,
  );
  return normalized.toString();
}

/// Stable key used to detect duplicate services.
///
/// Default ports and a trailing slash are ignored; query strings are kept.
String canonicalHttpUrl(String url) {
  final String? normalized = normalizeHttpUrl(url);
  if (normalized == null) {
    return url.trim().toLowerCase();
  }
  final Uri uri = Uri.parse(normalized);
  final String path = uri.path == '/' ? '' : uri.path;
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
    query: uri.hasQuery ? uri.query : null,
    fragment: uri.hasFragment ? uri.fragment : null,
  ).toString();
}

/// Best-effort URL for a host/port pair discovered on the LAN.
String buildScanUrl(String host, int port, {bool https = false}) {
  final String scheme = https ? 'https' : 'http';
  final bool defaultPort = (https && port == 443) || (!https && port == 80);
  return defaultPort ? '$scheme://$host' : '$scheme://$host:$port';
}

/// Human-readable title fallback for a candidate.
String candidateTitle(String host, int port) {
  return port == 80 || port == 443 ? host : '$host:$port';
}

/// Validates a device address (IPv4, hostname or domain).
///
/// Devices keep the host only; protocol/port/path belong to services. A device
/// address must not contain a scheme or path so URLs can be generated safely.
String? normalizeDeviceAddress(String raw) {
  final String value = raw.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) {
    return null;
  }
  if (value.contains('://') ||
      value.contains('/') ||
      value.contains('?') ||
      value.contains('#')) {
    return null;
  }
  // Reject host:port. IPv6 literals contain multiple colons and are allowed.
  if (RegExp(r'^[^:]+:\d+$').hasMatch(value)) {
    return null;
  }
  final Uri? parsed = Uri.tryParse('http://$value');
  if (parsed == null || parsed.host.isEmpty) {
    return null;
  }
  return value;
}

/// Composes the URL of a device-linked service.
///
/// [port] is omitted for the protocol default; [path] may include a query and
/// fragment. [customUrl] always wins when present.
String buildServiceUrl({
  String? customUrl,
  required String address,
  String protocol = 'http',
  int? port,
  String? path,
}) {
  final String? custom = customUrl?.trim();
  if (custom != null && custom.isNotEmpty) {
    return normalizeHttpUrl(custom) ?? custom;
  }
  final String scheme = protocol.toLowerCase() == 'https' ? 'https' : 'http';
  final bool defaultPort =
      (scheme == 'http' && port == 80) || (scheme == 'https' && port == 443);
  final int? effectivePort =
      port == null || port < 1 || port > 65535 || defaultPort ? null : port;

  String rawPath = path?.trim() ?? '';
  String? query;
  String? fragment;
  final int hash = rawPath.indexOf('#');
  if (hash >= 0) {
    fragment = rawPath.substring(hash + 1);
    rawPath = rawPath.substring(0, hash);
  }
  final int question = rawPath.indexOf('?');
  if (question >= 0) {
    query = rawPath.substring(question + 1);
    rawPath = rawPath.substring(0, question);
  }
  if (rawPath.isNotEmpty && !rawPath.startsWith('/')) {
    rawPath = '/$rawPath';
  }
  if (rawPath == '/') {
    rawPath = '';
  }
  return Uri(
    scheme: scheme,
    host: address.trim(),
    port: effectivePort,
    path: rawPath,
    query: query?.isEmpty == true ? null : query,
    fragment: fragment?.isEmpty == true ? null : fragment,
  ).toString();
}
