import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'app_config.dart';
import 'core/storage/preferences_settings_store.dart';
import 'features/scripts/data/github_script_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ScriptBrowserApp(
      settingsStore: PreferencesSettingsStore(
        preferences,
        defaultGitHub: defaultScriptRepository,
      ),
      repositories: GitHubScriptRepository.new,
    ),
  );
}
