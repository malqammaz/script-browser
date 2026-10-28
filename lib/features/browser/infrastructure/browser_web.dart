import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../protection/domain/ad_blocker.dart';
import '../domain/browser_engine.dart';
import '../application/media_source.dart';
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
    this.onResource,
  });
  final AdBlocker blocker;
  final void Function(String) onStarted, onFinished, onError;
  final void Function(int) onProgress;
  final VoidCallback onBlocked;
  final void Function(Uri)? onResource;
  InAppWebViewController? controller;
  final mediaRequests = <String, Map<String, String>>{};
  void rememberMedia(String url, [Map<String, String> headers = const {}]) {
    final uri = castableMedia(url);
    if (uri == null) return;
    if (publicDrivePreview(Uri.parse(pageUrl)) != null &&
        isDrivePreviewMedia(uri))
      return;
    url = uri.toString();
    if (blocker.blocks(url, pageUrl)) return;
    if (mediaRequests.length < 60 &&
        (headers.isNotEmpty || !mediaRequests.containsKey(url)))
      mediaRequests[url] = Map.of(headers);
  }

  Future<void> detectMedia() async {
    final raw = await controller?.evaluateJavascript(
      source: '''JSON.stringify((()=>{
      const configured=[];
      try {
        if(typeof window.jwplayer==='function') {
          for(const item of window.jwplayer().getPlaylist() || []) {
            if(item.drm) continue;
            if(item.file) configured.push(item.file);
            for(const source of item.sources || []) if(!source.drm && source.file) configured.push(source.file);
          }
        }
      } catch (_) {}
      return [
      ...Array.from(document.querySelectorAll('video,video source')).map(v=>v.currentSrc||v.src),
      ...performance.getEntriesByType('resource').map(r=>r.name),
      ...configured
    ].filter(Boolean).map(url=>{try{return new URL(url,location.href).href;}catch(_){return '';}});
    })())''',
    );
    if (raw is String) {
      final list = jsonDecode(raw);
      if (list is List)
        for (final url in list) {
          if (url is String)
            rememberMedia(url, mediaRequests[url] ?? {'Referer': pageUrl});
        }
      if (mediaRequests.isNotEmpty) {
        final agent = await controller?.evaluateJavascript(
          source: 'navigator.userAgent',
        );
        if (agent is String)
          for (final headers in mediaRequests.values) {
            headers.putIfAbsent('User-Agent', () => agent);
          }
      }
    }
    final preview = publicDrivePreview(Uri.parse(pageUrl));
    if (preview != null) mediaRequests.putIfAbsent('$preview', () => {});
  }

  Future<String> mediaCookies(Uri url) async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri.uri(url),
    );
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

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
      mediaRequests.clear();
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
      onResource?.call(Uri.parse(request.url.toString()));
      rememberMedia(request.url.toString(), request.headers ?? const {});
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
