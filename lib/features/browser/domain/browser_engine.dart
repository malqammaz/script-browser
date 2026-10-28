abstract interface class JavaScriptRuntime {
  Future<void> runJavaScript(String source);
  Future<Object> runJavaScriptReturningResult(String source);
}

/// Application logic depends on this contract, never on a WebView plugin.
abstract interface class BrowserEngine implements JavaScriptRuntime {
  String get pageUrl;
  Future<void> loadRequest(Uri uri);
  Future<void> reload();
  Future<bool> canGoBack();
  Future<void> goBack();
  Future<void> updateProtection();
}
