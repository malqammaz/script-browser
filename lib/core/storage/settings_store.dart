import '../../features/scripts/domain/script.dart';

class AppSettings {
  const AppSettings({
    this.github = const GitHubConfig(),
    this.script = ScriptDocument.example,
    this.adBlockEnabled = true,
    this.allowedSites = const {},
    this.customDomains = const {},
  });
  final GitHubConfig github;
  final ScriptDocument script;
  final bool adBlockEnabled;
  final Set<String> allowedSites;
  final Set<String> customDomains;
}

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> saveGitHub(GitHubConfig config);
  Future<void> saveScript(ScriptDocument document);
  Future<void> saveProtection({
    required bool enabled,
    required Set<String> allowedSites,
    required Set<String> customDomains,
  });
}
