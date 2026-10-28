import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/github.dart';

void main() {
  test('GitHub URL keeps branch and script path intact', () {
    final uri = GitHub(
      'owner/repo',
      'feature/scripts',
      'scripts',
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
      () => GitHub('https://github.com/owner/repo', 'main', '').uri(''),
      throwsFormatException,
    );
  });
}
