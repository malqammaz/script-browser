import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:script_browser/core/storage/preferences_settings_store.dart';
import 'package:script_browser/features/scripts/domain/script.dart';

void main() {
  test('Uses the default repository only before user configuration', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = PreferencesSettingsStore(
      preferences,
      defaultGitHub: const GitHubConfig(repository: 'owner/default'),
    );
    expect((await store.load()).github.repository, 'owner/default');
    await store.saveGitHub(const GitHubConfig(repository: 'owner/custom'));
    expect((await store.load()).github.repository, 'owner/custom');
  });
  test(
    'Reads the original app preference keys without losing user settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'repo': 'owner/scripts',
        'branch': 'dev',
        'folder': 'js',
        'code': 'return 99;',
        'adBlockEnabled': false,
        'adBlockAllowedSites': ['example.com'],
      });
      final store = PreferencesSettingsStore(
        await SharedPreferences.getInstance(),
      );
      final settings = await store.load();
      expect(settings.github.repository, 'owner/scripts');
      expect(settings.github.branch, 'dev');
      expect(settings.script.source, 'return 99;');
      expect(settings.adBlockEnabled, isFalse);
      expect(settings.allowedSites, {'example.com'});
    },
  );
  test('Persists script name together with edited code', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesSettingsStore(
      await SharedPreferences.getInstance(),
    );
    await store.saveScript(
      const ScriptDocument(name: 'remote.js', source: 'return 1;'),
    );
    final settings = await store.load();
    expect(settings.script.name, 'remote.js');
    expect(settings.script.source, 'return 1;');
  });
}
