import 'script.dart';

/// www is an alias; other subdomains have their own script folders.
String scriptDomain(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) return '';
  return uri.host
      .toLowerCase()
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceFirst(RegExp(r'^www\.'), '');
}

GitHubConfig scriptsForDomain(GitHubConfig root, String domain) {
  if (domain.isEmpty || domain.contains('/') || domain.contains('\\')) {
    throw const FormatException('افتح موقعًا أولًا لعرض سكربتاته');
  }
  final folder = root.folder.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  return GitHubConfig(
    repository: root.repository,
    branch: root.branch,
    folder: folder.isEmpty ? domain : '$folder/$domain',
  );
}
