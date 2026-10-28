import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'ad_blocker.dart';

/// Keeps the script editor independent of the Android WebView implementation.
class BrowserWeb {
  BrowserWeb({
    required this.blocker,
    required this.onStarted,
    required this.onFinished,
    required this.onProgress,
    required this.onError,
    required this.onBlocked,
  });
  final AdBlocker blocker;
  final void Function(String) onStarted, onFinished, onError;
  final void Function(int) onProgress;
  final VoidCallback onBlocked;
  InAppWebViewController? controller;
  String pageUrl = 'about:blank';

  InAppWebViewSettings get settings => InAppWebViewSettings(
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    useShouldInterceptRequest: true,
    supportMultipleWindows: blocker.activeFor(pageUrl),
    javaScriptCanOpenWindowsAutomatically: !blocker.activeFor(pageUrl),
    mediaPlaybackRequiresUserGesture: true,
  );

  Future<void> loadRequest(Uri uri) async {
    pageUrl = uri.toString();
    await updateProtection();
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
  }

  Future<void> reload() async => controller?.reload();
  Future<bool> canGoBack() async => await controller?.canGoBack() ?? false;
  Future<void> goBack() async => controller?.goBack();
  Future<void> runJavaScript(String source) async {
    if (controller == null) throw StateError('المتصفح غير جاهز');
    await controller!.evaluateJavascript(source: source);
  }

  Future<Object> runJavaScriptReturningResult(String source) async {
    if (controller == null) throw StateError('المتصفح غير جاهز');
    return await controller!.evaluateJavascript(source: source) ?? '';
  }

  UserScript get styleScript => UserScript(
    groupName: 'ad-protection',
    source:
        'if (${blocker.enabled} && !${jsonEncode(blocker.allowedSites.toList())}.includes(location.hostname.toLowerCase())) { ${AdBlocker.cosmeticScript} }',
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  Future<void> updateProtection() async {
    await controller?.setSettings(settings: settings);
    await controller?.removeUserScriptsByGroupName(groupName: 'ad-protection');
    if (blocker.activeFor(pageUrl)) {
      await controller?.addUserScript(userScript: styleScript);
    }
  }

  Widget view() => InAppWebView(
    initialSettings: settings,
    initialUserScripts: UnmodifiableListView(
      blocker.activeFor(pageUrl) ? [styleScript] : <UserScript>[],
    ),
    initialData: InAppWebViewInitialData(
      data:
          '''<!doctype html><html lang="ar" dir="rtl"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font:20px sans-serif;background:#f3f8f6;padding:32px;color:#163d34}button{background:#146c60;color:white;border:0;padding:20px;border-radius:12px;font-size:20px}</style><h1>متصفح السكربتات</h1><p>افتح موقعًا من شريط العنوان، أو جرّب تشغيل السكربت على هذا الزر.</p><button onclick="this.textContent='تم الضغط بنجاح ✓'">زر تجريبي</button></html>''',
    ),
    onWebViewCreated: (value) async {
      controller = value;
      await updateProtection();
    },
    onLoadStart: (c, url) async {
      pageUrl = url?.toString() ?? 'about:blank';
      onStarted(pageUrl);
      await updateProtection();
    },
    onLoadStop: (c, url) async {
      pageUrl = url?.toString() ?? pageUrl;
      if (blocker.activeFor(pageUrl)) {
        await c.evaluateJavascript(source: AdBlocker.cosmeticScript);
      }
      onFinished(pageUrl);
    },
    onProgressChanged: (c, value) => onProgress(value),
    onReceivedError: (c, request, error) {
      if (request.isForMainFrame == true) onError(error.description);
    },
    shouldOverrideUrlLoading: (c, action) async {
      final url = action.request.url;
      if (url == null || !['http', 'https', 'about'].contains(url.scheme)) {
        return NavigationActionPolicy.CANCEL;
      }
      if (blocker.blocks(url.toString(), pageUrl)) {
        onBlocked();
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.ALLOW;
    },
    shouldInterceptRequest: (c, request) async {
      if (!blocker.blocks(request.url.toString(), pageUrl)) return null;
      onBlocked();
      return WebResourceResponse(
        contentType: 'text/plain',
        contentEncoding: 'utf-8',
        statusCode: 403,
        reasonPhrase: 'Blocked by Script Browser',
        data: Uint8List(0),
      );
    },
    onCreateWindow: (c, action) async {
      // Never create a hidden WebView or send popup links to external apps.
      if (blocker.activeFor(pageUrl)) onBlocked();
      return false;
    },
  );
}
