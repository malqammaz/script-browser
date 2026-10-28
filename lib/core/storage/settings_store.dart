import '../../features/scripts/domain/script.dart';

class AppSettings {
  const AppSettings({
    this.github = const GitHubConfig(),
    this.script = ScriptDocument.example,
    this.adBlockEnabled = true,
    this.lastUrl = 'https://www.google.com/',
    this.allowedSites = const {},
    this.customDomains = const {},
    this.recentSites = const [],
    this.bookmarks = const [],
  });
  final GitHubConfig github;
  final String lastUrl;
  final ScriptDocument script;
  final bool adBlockEnabled;
  final Set<String> allowedSites;
  final Set<String> customDomains;
  final List<String> recentSites;
  final List<String> bookmarks;
}

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> saveLastUrl(String url);
  Future<void> saveRecentSites(List<String> urls);
  Future<void> saveBookmarks(List<String> urls);
  Future<void> saveGitHub(GitHubConfig config);
  Future<void> saveScript(ScriptDocument document);
  Future<void> saveProtection({
    required bool enabled,
    required Set<String> allowedSites,
    required Set<String> customDomains,
  });
}
