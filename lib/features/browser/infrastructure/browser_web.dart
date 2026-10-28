import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../protection/domain/ad_blocker.dart';
import '../domain/browser_engine.dart';
import 'home_page.dart';

/// Keeps the script editor independent of the Android WebView implementation.
class BrowserWeb implements BrowserEngine {
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
  @override
  String pageUrl = 'about:blank';

  InAppWebViewSettings get settings => InAppWebViewSettings(
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    useShouldInterceptRequest: true,
    supportMultipleWindows: blocker.activeFor(pageUrl),
    javaScriptCanOpenWindowsAutomatically: !blocker.activeFor(pageUrl),
    mediaPlaybackRequiresUserGesture: true,
  );

  @override
  Future<void> loadRequest(Uri uri) async {
    pageUrl = uri.toString();
    await updateProtection();
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
  }

  @override
  Future<void> reload() async => controller?.reload();
  @override
  Future<bool> canGoBack() async => await controller?.canGoBack() ?? false;
  @override
  Future<void> goBack() async => controller?.goBack();
  @override
  Future<void> runJavaScript(String source) async {
    if (controller == null) throw StateError('المتصفح غير جاهز');
    await controller!.evaluateJavascript(source: source);
  }

  @override
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

  @override
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
    initialData: InAppWebViewInitialData(data: homePageHtml),
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
