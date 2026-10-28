import 'dart:convert';
import '../../browser/domain/browser_engine.dart';

/// Runs async scripts and polls a private page slot without exposing app bridges.
class ScriptRunner {
  const ScriptRunner({
    this.timeout = const Duration(minutes: 15),
    this.pollInterval = const Duration(milliseconds: 250),
  });
  final Duration timeout;
  final Duration pollInterval;

  Future<String> run({
    required JavaScriptRuntime runtime,
    required String source,
    required bool Function() isCancelled,
    required bool Function() navigationChanged,
  }) async {
    final key = jsonEncode(
      '__scriptBrowser_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await runtime.runJavaScript('''(() => {
        const key = $key;
        window[key] = null;
        const complete = value => {
          if (Object.prototype.hasOwnProperty.call(window, key)) {
            window[key] = JSON.stringify(value);
          }
        };
        (async () => {
          try {
            const value = await (async () => {
              $source
            })();
            complete({ok:true, value: value === undefined ? 'Completed without a return value' : value});
          } catch(e) { complete({ok:false,error:String(e)}); }
        })();
      })();''');
      final deadline = DateTime.now().add(timeout);
      while (!isCancelled() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
        if (isCancelled()) return '';
        if (navigationChanged()) {
          return 'The page changed while running; the script may have navigated.';
        }
        final raw = await runtime.runJavaScriptReturningResult(
          'window[$key] || ""',
        );
        final response = decodeResult(raw);
        if (response != null) return response;
      }
      if (isCancelled()) return '';
      return 'No result after ${timeout.inSeconds} seconds. The script may still be running; reload the page to stop it.';
    } catch (error) {
      return 'Could not run script: $error';
    } finally {
      try {
        await runtime.runJavaScript('delete window[$key]');
      } catch (_) {
        /* Page may already be gone. */
      }
    }
  }

  static String? decodeResult(Object raw) {
    dynamic value = raw;
    if (value is String && value.startsWith('"')) value = jsonDecode(value);
    if (value is! String || value.isEmpty) return null;
    final data = jsonDecode(value) as Map<String, dynamic>;
    return data['ok'] == true
        ? const JsonEncoder.withIndent('  ').convert(data['value'])
        : 'Error: ${data['error']}';
  }
}
