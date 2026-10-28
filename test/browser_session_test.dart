import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/core/storage/settings_store.dart';
import 'package:script_browser/features/browser/application/browser_session.dart';
import 'package:script_browser/features/scripts/application/script_runner.dart';
import 'package:script_browser/features/scripts/domain/script.dart';
import 'support/fakes.dart';

void main() {
  test(
    'Only the explicit sync script on Yalanime invokes the native uploader',
    () async {
      var uploads = 0;
      final engine = FakeBrowserEngine()
        ..output = jsonEncode({
          'ok': true,
          'value': {
            'action': 'syncAnimeLibrary',
            'title': 'Test',
            'episodes': [],
          },
        });
      final session = BrowserSession(
        settingsStore: MemorySettingsStore(),
        repositories: (_) => FakeScriptRepository(),
        runner: const ScriptRunner(pollInterval: Duration(milliseconds: 1)),
        syncLibrary: (data) async {
          uploads++;
          return {'success': true};
        },
      )..engine = engine;
      session.script = const ScriptDocument(
        name: 'extract-episodes.js',
        source: 'return {};',
        domain: 'yalanime.com',
      );
      session.pageFinished('https://yalanime.com/anime/');
      await session.run();
      expect(uploads, 0);
      session.script = const ScriptDocument(
        name: 'sync-anime-library.js',
        source: 'return {};',
        domain: 'yalanime.com',
      );
      await session.run();
      expect(uploads, 1);
      expect(session.result, contains('"success": true'));
      session.pageFinished('https://other.example/');
      await session.run();
      expect(uploads, 1);
      session.dispose();
    },
  );
  late MemorySettingsStore store;
  late FakeScriptRepository repository;
  late FakeBrowserEngine engine;
  late BrowserSession session;
  setUp(() {
    store = MemorySettingsStore();
    repository = FakeScriptRepository();
    engine = FakeBrowserEngine();
    session = BrowserSession(
      settingsStore: store,
      repositories: (_) => repository,
      runner: const ScriptRunner(pollInterval: Duration(milliseconds: 1)),
    )..engine = engine;
  });
  tearDown(() => session.dispose());

  test('Restores settings and applies protection', () async {
    store.settings = const AppSettings(
      github: GitHubConfig(repository: 'owner/repo'),
      script: ScriptDocument(name: 'saved.js', source: 'return 7;'),
      adBlockEnabled: false,
      allowedSites: {'example.com'},
    );
    await session.initialize();
    expect(session.github.repository, 'owner/repo');
    expect(session.script.name, 'saved.js');
    expect(session.blocker.enabled, isFalse);
    expect(session.blocker.allowedSites, contains('example.com'));
    expect(engine.protectionUpdates, 1);
  });
  test(
    'Fetches selected remote script and persists name and content',
    () async {
      final config = const GitHubConfig(repository: 'owner/repo');
      session.pageStarted('https://example.com/');
      final files = await session.listScripts(config);
      await session.selectScript(files.single);
      expect(session.script.source, 'return 42;');
      expect(store.savedGitHub?.repository, 'owner/repo');
      expect(store.savedScript?.name, 'remote.js');
      expect(session.busy, isFalse);
    },
  );
  test(
    'Network failures release busy state and preserve current script',
    () async {
      repository.error = Exception('offline');
      session.pageStarted('https://example.com/');
      await expectLater(
        session.listScripts(const GitHubConfig(repository: 'a/b')),
        throwsException,
      );
      expect(session.busy, isFalse);
      expect(session.script.source, ScriptDocument.example.source);
      expect(session.siteScripts.error, contains('offline'));
    },
  );
  test(
    'Run rejects duplicate executions and returns the script result',
    () async {
      final first = session.run();
      await session.run();
      await first;
      expect(engine.evaluations, 1);
      expect(session.result, '42');
      expect(session.running, isFalse);
      expect(engine.commands.last, startsWith('delete window['));
    },
  );
  test('Protection updates persist then reload the page', () async {
    await session.saveProtection(
      enabled: true,
      host: 'example.com',
      allowSite: true,
      customDomains: {'ads.test.com'},
    );
    expect(store.savedProtection, isTrue);
    expect(session.blocker.activeFor('https://example.com'), isFalse);
    expect(session.blocker.customDomains, contains('ads.test.com'));
    expect(engine.reloads, 1);
  });
  test('A selected site script cannot run on another domain', () async {
    session.pageStarted('https://example.com/');
    final files = await session.listScripts(
      const GitHubConfig(repository: 'owner/repo'),
    );
    await session.selectScript(files.single);
    expect(session.canRun, isTrue);
    session.pageStarted('https://other.com/');
    expect(session.canRun, isFalse);
    await session.run();
    expect(engine.evaluations, 0);
  });
  test('Rejects a file picked for the previous domain', () async {
    session.pageStarted('https://other.com/');
    await expectLater(
      session.selectScript(
        const ScriptFile(name: 'old.js', path: 'scripts/example.com/old.js'),
      ),
      throwsFormatException,
    );
  });
  test('Restores last website and ignores blank page callbacks', () async {
    store.settings = const AppSettings(
      lastUrl: 'https://example.com/watch#episode',
    );
    await session.initialize();
    expect(engine.pageUrl, 'https://example.com/watch#episode');
    session.pageFinished('https://example.com/next');
    expect(store.savedLastUrl, 'https://example.com/next');
    session.pageFinished('about:blank');
    expect(store.savedLastUrl, 'https://example.com/next');
  });
  test('Invalid saved state falls back to Google', () async {
    store.settings = const AppSettings(lastUrl: 'file:///bad');
    await session.initialize();
    expect(engine.pageUrl, 'https://www.google.com/');
  });
  test('Searches Google with safely encoded text', () {
    final uri = BrowserSession.parseAddress('انمي & cats #1');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], 'انمي & cats #1');
    expect(BrowserSession.parseAddress('cats').queryParameters['q'], 'cats');
    expect(
      BrowserSession.parseAddress('localhost:8765/watch').host,
      'localhost',
    );
    expect(BrowserSession.parseAddress('192.168.1.10:8878/tv').port, 8878);
  });
  test('Address parsing adds HTTPS and rejects unsupported schemes', () {
    expect(
      BrowserSession.parseAddress(' example.com/a ').toString(),
      'https://example.com/a',
    );
    expect(
      () => BrowserSession.parseAddress('file:///etc/passwd'),
      throwsFormatException,
    );
    expect(() => BrowserSession.parseAddress(''), throwsFormatException);
  });
}
