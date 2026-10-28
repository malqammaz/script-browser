/// Accept video URLs, including Drive preview playback; never Drive downloads.
Uri? castableMedia(String value, {bool fromVideoElement = false}) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  final mega = publicMegaPreview(uri);
  if (mega != null) return mega;
  if (fromVideoElement) return uri;
  if (RegExp(r'\.(mp4|m3u8)$', caseSensitive: false).hasMatch(uri.path)) {
    return uri;
  }
  final host = uri.host.toLowerCase();
  final google =
      host == 'drive.google.com' ||
      host.endsWith('.drive.google.com') ||
      host.endsWith('.googlevideo.com') ||
      host.endsWith('.googleusercontent.com');
  if (!google || !uri.path.endsWith('/videoplayback')) return null;
  final query = Map<String, String>.from(uri.queryParameters);
  final mime = query['mime'] ?? '';
  if (mime.startsWith('audio/') ||
      ['139', '140', '141', '249', '250', '251'].contains(query['itag'])) {
    return null;
  }
  final signed = (query['sparams'] ?? '').split(',');
  if (!signed.contains('range')) query.remove('range');
  return uri.replace(queryParameters: query);
}

Uri? publicDrivePreview(Uri uri) {
  if (uri.scheme != 'https' || uri.host != 'drive.google.com') return null;
  final match = RegExp(
    r'^/file/d/([A-Za-z0-9_-]+)/(?:view|preview)/?$',
  ).firstMatch(uri.path);
  if (match == null) return null;
  return Uri.https(
    'drive.google.com',
    '/file/d/${match[1]}/preview',
    uri.queryParameters['resourcekey'] == null
        ? null
        : {'resourcekey': uri.queryParameters['resourcekey']!},
  );
}

bool isDrivePreviewMedia(Uri uri) =>
    uri.path.endsWith('/videoplayback') && castableMedia('$uri') != null;

/// Only public MEGA file links containing their supplied key; never folders or accounts.
Uri? publicMegaPreview(Uri uri) {
  if (uri.scheme != 'https' ||
      !['mega.nz', 'www.mega.nz'].contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final path = RegExp(
    r'^/(?:file|embed)/([A-Za-z0-9_-]{8})/?$',
  ).firstMatch(uri.path);
  if (path == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(uri.fragment)) {
    return null;
  }
  return Uri.https(
    'mega.nz',
    '/embed/${path[1]}',
  ).replace(fragment: uri.fragment);
}

Uri? publicEmbeddedPreview(Uri uri) =>
    publicDrivePreview(uri) ?? publicMegaPreview(uri);
