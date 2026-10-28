import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/storage/settings_store.dart';
import '../../protection/domain/ad_blocker.dart';
import '../../scripts/application/script_runner.dart';
import '../../scripts/application/domain_script_catalog.dart';
import '../../scripts/application/site_scripts_controller.dart';
import '../../scripts/domain/site_scripts.dart';
import '../../scripts/domain/script.dart';
import '../../scripts/domain/script_repository.dart';
import '../domain/browser_engine.dart';
import '../domain/address_resolver.dart';

/// Owns browser state and use cases. Widgets own only their UI controllers.
class BrowserSession extends ChangeNotifier {
  BrowserSession({
    required this.settingsStore,
    required this.repositories,
    this.runner = const ScriptRunner(),
    this.syncLibrary,
  });
  final SettingsStore settingsStore;
  final ScriptRepositoryFactory repositories;
  final ScriptRunner runner;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
  syncLibrary;
  final blocker = AdBlocker();
  late final siteScripts = SiteScriptsController(
    DomainScriptCatalog(repositories),
  )..addListener(_changed);
  late BrowserEngine engine;
  GitHubConfig github = const GitHubConfig();
  ScriptDocument script = ScriptDocument.example;
  String url = 'about:blank';
  String result = 'Script output will appear here';
  int progress = 100;
  int blockedCount = 0;
  int _navigation = 0;
  bool busy = false;
  bool running = false;
  bool _disposed = false;
  bool get canRun =>
      !running &&
      !busy &&
      progress == 100 &&
      (script.domain == null || script.domain == siteScripts.domain);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    final settings = await settingsStore.load();
    if (_disposed) return;
    github = settings.github;
    siteScripts.configure(github);
    siteScripts.setPage(url);
    script = settings.script;
    blocker.enabled = settings.adBlockEnabled;
    blocker.allowedSites.addAll(settings.allowedSites);
    blocker.customDomains.addAll(settings.customDomains);
    _changed();
    await engine.updateProtection();
    final saved = Uri.tryParse(settings.lastUrl);
    final destination =
        saved != null &&
            ['https', 'http'].contains(saved.scheme) &&
            saved.host.isNotEmpty
        ? saved
        : Uri.parse('https://www.google.com/');
    await engine.loadRequest(destination);
    await siteScripts.discover();
  }

  void pageStarted(String value) {
    if (_disposed) return;
    _navigation++;
    blockedCount = 0;
    url = value;
    siteScripts.setPage(value);
    _changed();
  }

  void pageFinished(String value) {
    if (_disposed) return;
    url = value;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty) {
      unawaited(settingsStore.saveLastUrl(value).catchError((Object _) {}));
    }
    siteScripts.setPage(value);
    progress = 100;
    _changed();
    unawaited(siteScripts.discover());
  }

  void progressChanged(int value) {
    progress = value;
    _changed();
  }

  void requestBlocked() {
    blockedCount++;
  }

  void pageFailed() {
    progress = 100;
    _changed();
  }

  static Uri parseAddress(String value) =>
      const AddressResolver().resolve(value);

  Future<void> open(String value) => engine.loadRequest(parseAddress(value));
  Future<void> reload() => engine.reload();
  Future<void> back() async {
    if (await engine.canGoBack()) await engine.goBack();
  }

  Future<List<ScriptFile>> listScripts(GitHubConfig config) async {
    busy = true;
    _changed();
    try {
      await settingsStore.saveGitHub(config);
      if (_disposed) return [];
      github = config;
      siteScripts.configure(config);
      await siteScripts.discover(refresh: true);
      if (siteScripts.error != null) {
        throw ScriptRepositoryException(siteScripts.error!);
      }
      return siteScripts.files;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> selectScript(ScriptFile file) async {
    final domain = siteScripts.domain;
    if (domain.isEmpty) {
      throw const FormatException('Open a website first to see its scripts');
    }
    final scoped = scriptsForDomain(github, domain);
    if (!file.path.startsWith('${scoped.folder}/')) {
      throw const FormatException(
        'This script does not belong to the current site',
      );
    }
    busy = true;
    _changed();
    try {
      final source = await repositories(scoped).source(file.path);
      if (_disposed) return;
      if (domain != siteScripts.domain) {
        throw StateError(
          'The site changed; choose a script for the current site',
        );
      }
      final selected = ScriptDocument(
        name: file.name,
        source: source,
        domain: domain,
      );
      await settingsStore.saveScript(selected);
      if (!_disposed) {
        script = selected;
        _changed();
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> saveScript(String source) async {
    final edited = ScriptDocument(
      name: script.name,
      source: source,
      domain: script.domain,
    );
    await settingsStore.saveScript(edited);
    if (!_disposed) {
      script = edited;
      _changed();
    }
  }

  Future<void> saveProtection({
    required bool enabled,
    required String host,
    required bool allowSite,
    required Set<String> customDomains,
  }) async {
    final allowedSites = {...blocker.allowedSites};
    if (host.isNotEmpty) {
      if (allowSite) {
        allowedSites.add(host);
      } else {
        allowedSites.remove(host);
      }
    }
    await settingsStore.saveProtection(
      enabled: enabled,
      allowedSites: allowedSites,
      customDomains: customDomains,
    );
    if (_disposed) return;
    blocker.enabled = enabled;
    blocker.allowedSites
      ..clear()
      ..addAll(allowedSites);
    blocker.customDomains
      ..clear()
      ..addAll(customDomains);
    _changed();
    await engine.updateProtection();
    await engine.reload();
  }

  Future<void> run() async {
    if (!canRun || _disposed) return;
    running = true;
    result = 'Running…';
    _changed();
    final initialNavigation = _navigation;
    final syncRequested =
        script.name == 'sync-anime-library.js' &&
        script.domain == 'yalanime.com' &&
        ['yalanime.com', 'www.yalanime.com'].contains(Uri.tryParse(url)?.host);
    try {
      final output = await runner.run(
        runtime: engine,
        source: script.source,
        isCancelled: () => _disposed,
        navigationChanged: () => _navigation != initialNavigation,
      );
      if (!_disposed) {
        result = output;
        if (syncRequested &&
            syncLibrary != null &&
            initialNavigation == _navigation) {
          try {
            final data = jsonDecode(output);
            if (data is Map<String, dynamic> &&
                data['action'] == 'syncAnimeLibrary') {
              result = 'Extraction complete; updating the GitHub library…';
              _changed();
              final status = await syncLibrary!(data);
              if (!_disposed) {
                result = const JsonEncoder.withIndent(
                  '  ',
                ).convert({...data, 'sync': status});
              }
            }
          } catch (error) {
            if (!_disposed) {
              result =
                  '$output\n\nCould not update the library: $error\nExtracted data is kept in the output; you can retry.';
            }
          }
        }
      }
    } finally {
      running = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    siteScripts.removeListener(_changed);
    siteScripts.dispose();
    super.dispose();
  }
}
