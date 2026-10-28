import 'package:flutter/material.dart';
import 'core/storage/settings_store.dart';
import 'features/browser/presentation/browser_screen.dart';
import 'features/scripts/domain/script_repository.dart';

class ScriptBrowserApp extends StatelessWidget {
  const ScriptBrowserApp({
    super.key,
    required this.settingsStore,
    required this.repositories,
  });
  final SettingsStore settingsStore;
  final ScriptRepositoryFactory repositories;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff146c60),
      useMaterial3: true,
    ),
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: BrowserScreen(
      settingsStore: settingsStore,
      repositories: repositories,
    ),
  );
}
