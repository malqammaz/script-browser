import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/scripts/data/github_script_repository.dart';
import 'package:script_browser/features/scripts/domain/script.dart';

void main() {
  test('GitHub URL keeps branch and script path intact', () {
    final uri = GitHubScriptRepository(
      const GitHubConfig(repository: 'owner/repo', branch: 'feature/scripts'),
    ).uri('scripts/click button.js');
    expect(uri.host, 'api.github.com');
    expect(
      Uri.decodeComponent(uri.path),
      '/repos/owner/repo/contents/scripts/click button.js',
    );
    expect(uri.queryParameters['ref'], 'feature/scripts');
  });
  test('Invalid repository input is rejected', () {
    expect(
      () => GitHubScriptRepository(
        const GitHubConfig(repository: 'https://github.com/owner/repo'),
      ).uri(''),
      throwsFormatException,
    );
  });
}
