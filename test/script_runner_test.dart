import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/scripts/application/script_runner.dart';
import 'support/fakes.dart';

void main() {
  test('Allows time for interactive scripts and episode collection', () {
    expect(const ScriptRunner().timeout, const Duration(minutes: 15));
  });
  test('Cancellation before polling is not reported as a timeout', () async {
    final runtime = FakeBrowserEngine();
    final result = await const ScriptRunner().run(
      runtime: runtime,
      source: 'return 42;',
      isCancelled: () => true,
      navigationChanged: () => false,
    );
    expect(result, isEmpty);
    expect(runtime.evaluations, 0);
    expect(runtime.commands.last, startsWith('delete window['));
  });
  test('Decodes plugin-native and Android quoted JSON results', () {
    const data = '{"ok":true,"value":{"answer":42}}';
    expect(ScriptRunner.decodeResult(data), contains('"answer": 42'));
    expect(
      ScriptRunner.decodeResult(jsonEncode(data)),
      contains('"answer": 42'),
    );
    expect(ScriptRunner.decodeResult(''), isNull);
  });
  test('Reports JavaScript errors', () {
    expect(
      ScriptRunner.decodeResult('{"ok":false,"error":"missing button"}'),
      contains('missing button'),
    );
  });
  test('Navigation change exits polling and cleans the result slot', () async {
    final runtime = FakeBrowserEngine();
    final output =
        await const ScriptRunner(pollInterval: Duration(milliseconds: 1)).run(
          runtime: runtime,
          source: 'return 42;',
          isCancelled: () => false,
          navigationChanged: () => true,
        );
    expect(output, contains('The page changed'));
    expect(runtime.evaluations, 0);
    expect(runtime.commands.last, startsWith('delete window['));
  });
  test('Times out scripts without a result and still cleans up', () async {
    final runtime = FakeBrowserEngine()..output = '';
    final output =
        await const ScriptRunner(
          timeout: Duration(milliseconds: 5),
          pollInterval: Duration(milliseconds: 1),
        ).run(
          runtime: runtime,
          source: 'await new Promise(() => {});',
          isCancelled: () => false,
          navigationChanged: () => false,
        );
    expect(output, contains('No result after'));
    expect(runtime.commands.last, startsWith('delete window['));
  });
}
