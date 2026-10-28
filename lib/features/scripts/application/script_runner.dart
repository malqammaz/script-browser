import 'dart:convert';
import '../../browser/domain/browser_engine.dart';

/// Runs async scripts and polls a private page slot without exposing app bridges.
class ScriptRunner {
  const ScriptRunner({
    this.timeout = const Duration(seconds: 30),
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
        (async () => {
          try {
            const value = await (async () => {
              $source
            })();
            window[key] = JSON.stringify({ok:true, value: value === undefined ? 'تم التنفيذ بدون قيمة إرجاع' : value});
          } catch(e) { window[key] = JSON.stringify({ok:false,error:String(e)}); }
        })();
      })();''');
      final deadline = DateTime.now().add(timeout);
      while (!isCancelled() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
        if (isCancelled()) return '';
        if (navigationChanged()) {
          return 'تغيّرت الصفحة أثناء التنفيذ؛ قد يكون السكربت قد نفّذ التنقّل.';
        }
        final raw = await runtime.runJavaScriptReturningResult(
          'window[$key] || ""',
        );
        final response = decodeResult(raw);
        if (response != null) return response;
      }
      return 'انتهى انتظار النتيجة بعد 30 ثانية. قد يستمر السكربت؛ أعد تحميل الصفحة لإيقافه.';
    } catch (error) {
      return 'تعذر التنفيذ: $error';
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
        : 'خطأ: ${data['error']}';
  }
}
