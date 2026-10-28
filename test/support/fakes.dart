import 'package:script_browser/core/storage/settings_store.dart';
import 'package:script_browser/features/browser/domain/browser_engine.dart';
import 'package:script_browser/features/scripts/domain/script.dart';
import 'package:script_browser/features/scripts/domain/script_repository.dart';

class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.settings = const AppSettings()]);
  AppSettings settings;
  String? savedLastUrl;
  List<String> recentSites = [];
  List<String> bookmarks = [];
  @override
  Future<void> saveRecentSites(List<String> urls) async {
    recentSites = List.of(urls);
  }

  @override
  Future<void> saveBookmarks(List<String> urls) async {
    bookmarks = List.of(urls);
  }

  @override
  Future<void> saveLastUrl(String url) async {
    savedLastUrl = url;
  }

  GitHubConfig? savedGitHub;
  ScriptDocument? savedScript;
  bool? savedProtection;
  @override
  Future<AppSettings> load() async => settings;
  @override
  Future<void> saveGitHub(GitHubConfig config) async {
    savedGitHub = config;
  }

  @override
  Future<void> saveScript(ScriptDocument document) async {
    savedScript = document;
  }

  @override
  Future<void> saveProtection({
    required bool enabled,
    required Set<String> allowedSites,
    required Set<String> customDomains,
  }) async {
    savedProtection = enabled;
  }
}

class FakeScriptRepository implements ScriptRepository {
  FakeScriptRepository({this.folder = 'scripts/example.com'});
  final String folder;
  Object? error;
  String code = 'return 42;';
  @override
  Future<List<ScriptFile>> list() async {
    if (error != null) throw error!;
    return [ScriptFile(name: 'remote.js', path: '$folder/remote.js')];
  }

  @override
  Future<String> source(String path) async {
    if (error != null) throw error!;
    return code;
  }
}

class FakeBrowserEngine implements BrowserEngine {
  @override
  String pageUrl = 'about:blank';
  Object output = '{"ok":true,"value":42}';
  int evaluations = 0;
  int reloads = 0;
  int protectionUpdates = 0;
  final List<String> commands = [];
  @override
  Future<void> runJavaScript(String source) async {
    commands.add(source);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String source) async {
    evaluations++;
    return output;
  }

  @override
  Future<void> loadRequest(Uri uri) async {
    pageUrl = uri.toString();
  }

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<void> goBack() async {}
  @override
  Future<void> updateProtection() async {
    protectionUpdates++;
  }
}
