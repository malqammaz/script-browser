import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/scripts/application/domain_script_catalog.dart';
import 'package:script_browser/features/scripts/application/site_scripts_controller.dart';
import 'package:script_browser/features/scripts/domain/script.dart';
import 'package:script_browser/features/scripts/domain/script_repository.dart';
import 'package:script_browser/features/scripts/domain/site_scripts.dart';
import 'support/fakes.dart';

class PendingRepository implements ScriptRepository {
  final pending = Completer<List<ScriptFile>>();
  @override
  Future<List<ScriptFile>> list() => pending.future;
  @override
  Future<String> source(String path) async => '';
}

void main() {
  test('Recognizes domain, www alias, ports and separate subdomains', () {
    expect(scriptDomain('https://WWW.Example.com:8443/watch'), 'example.com');
    expect(
      scriptDomain('https://video.example.com/watch'),
      'video.example.com',
    );
    expect(scriptDomain('about:blank'), '');
    expect(
      scriptsForDomain(
        const GitHubConfig(folder: '/scripts/'),
        'example.com',
      ).folder,
      'scripts/example.com',
    );
    expect(
      scriptsForDomain(const GitHubConfig(folder: ''), 'example.com').folder,
      'example.com',
    );
  });
  test('Fetches the domain folder and caches only the file list', () async {
    var requests = 0;
    GitHubConfig? used;
    final catalog = DomainScriptCatalog((config) {
      requests++;
      used = config;
      return FakeScriptRepository(folder: config.folder);
    });
    const config = GitHubConfig(repository: 'owner/repo');
    final files = await catalog.list(config, 'example.com');
    await catalog.list(config, 'example.com');
    expect(used?.folder, 'scripts/example.com');
    expect(files.single.path, 'scripts/example.com/remote.js');
    expect(requests, 1);
    await catalog.list(config, 'example.com', refresh: true);
    expect(requests, 2);
  });
  test(
    'Missing site directory gives an empty list, API failures remain visible',
    () async {
      final repo = FakeScriptRepository()
        ..error = const ScriptRepositoryException('missing', statusCode: 404);
      final catalog = DomainScriptCatalog((_) => repo);
      const config = GitHubConfig(repository: 'owner/repo');
      expect(await catalog.list(config, 'example.com'), isEmpty);
      repo.error = const ScriptRepositoryException(
        'rate limited',
        statusCode: 403,
      );
      await expectLater(
        catalog.list(config, 'example.com', refresh: true),
        throwsA(isA<ScriptRepositoryException>()),
      );
    },
  );
  test(
    'A late response from the previous site cannot replace current scripts',
    () async {
      final old = PendingRepository();
      final catalog = DomainScriptCatalog(
        (config) => config.folder.endsWith('old.com')
            ? old
            : FakeScriptRepository(folder: config.folder),
      );
      final controller = SiteScriptsController(catalog)
        ..configure(const GitHubConfig(repository: 'owner/repo'));
      controller.setPage('https://old.com/');
      final pending = controller.discover();
      controller.setPage('https://new.com/');
      await controller.discover();
      old.pending.complete([
        const ScriptFile(name: 'old.js', path: 'scripts/old.com/old.js'),
      ]);
      await pending;
      expect(controller.domain, 'new.com');
      expect(controller.files.single.path, 'scripts/new.com/remote.js');
      controller.dispose();
    },
  );
}
