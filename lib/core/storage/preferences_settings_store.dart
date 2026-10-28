import 'package:shared_preferences/shared_preferences.dart';
import '../../features/scripts/domain/script.dart';
import 'settings_store.dart';

/// Retains the original preference keys so installed users keep their settings.
class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore(
    this.preferences, {
    this.defaultGitHub = const GitHubConfig(),
  });
  final SharedPreferences preferences;
  final GitHubConfig defaultGitHub;

  @override
  Future<AppSettings> load() async => AppSettings(
    lastUrl: preferences.getString('lastUrl') ?? 'https://www.google.com/',
    github: GitHubConfig(
      repository: preferences.getString('repo') ?? defaultGitHub.repository,
      branch: preferences.getString('branch') ?? defaultGitHub.branch,
      folder: preferences.getString('folder') ?? defaultGitHub.folder,
    ),
    script: ScriptDocument(
      name: preferences.getString('scriptName') ?? ScriptDocument.example.name,
      source: preferences.getString('code') ?? ScriptDocument.example.source,
      domain: preferences.getString('scriptDomain'),
    ),
    adBlockEnabled: preferences.getBool('adBlockEnabled') ?? true,
    allowedSites: (preferences.getStringList('adBlockAllowedSites') ?? [])
        .toSet(),
    customDomains: (preferences.getStringList('adBlockCustomDomains') ?? [])
        .toSet(),
  );

  @override
  Future<void> saveLastUrl(String url) async {
    await preferences.setString('lastUrl', url);
  }

  @override
  Future<void> saveGitHub(GitHubConfig config) async {
    await preferences.setString('repo', config.repository);
    await preferences.setString('branch', config.branch);
    await preferences.setString('folder', config.folder);
  }

  @override
  Future<void> saveScript(ScriptDocument document) async {
    await preferences.setString('scriptName', document.name);
    await preferences.setString('code', document.source);
    if (document.domain == null) {
      await preferences.remove('scriptDomain');
    } else {
      await preferences.setString('scriptDomain', document.domain!);
    }
  }

  @override
  Future<void> saveProtection({
    required bool enabled,
    required Set<String> allowedSites,
    required Set<String> customDomains,
  }) async {
    await preferences.setBool('adBlockEnabled', enabled);
    await preferences.setStringList(
      'adBlockAllowedSites',
      allowedSites.toList(),
    );
    await preferences.setStringList(
      'adBlockCustomDomains',
      customDomains.toList(),
    );
  }
}
