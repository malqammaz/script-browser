import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:script_browser/ad_blocker.dart';
import 'package:script_browser/browser_web.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android blocks ad requests and popups, keeps scripts and site exceptions working',
    (tester) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '''<!doctype html><html><body><div class="ad-banner">Ad</div><button id="normal" onclick="this.textContent='clicked'">Normal</button><a id="popup" href="https://ads.example.test/" target="_blank">Popup</a><script>const a=document.createElement('script');a.src='https://ads.example.test/ad.js';a.onerror=()=>window.adFailed=true;document.head.appendChild(a);</script></body></html>''',
        );
        request.response.close();
      });
      final blocker = AdBlocker()..customDomains.add('ads.example.test');
      var blocked = 0;
      var loaded = Completer<void>();
      final web = BrowserWeb(
        blocker: blocker,
        onStarted: (_) {},
        onFinished: (_) {
          if (!loaded.isCompleted) loaded.complete();
        },
        onProgress: (_) {},
        onError: (_) {},
        onBlocked: () => blocked++,
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: web.view())));
      await tester.runAsync(() async {
        while (web.controller == null) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await loaded.future.timeout(const Duration(seconds: 20));
        loaded = Completer<void>();
        final url = Uri.parse('http://127.0.0.1:${server.port}/');
        await web.loadRequest(url);
        await loaded.future.timeout(const Duration(seconds: 20));
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(blocked, greaterThan(0));
        expect(
          await web.runJavaScriptReturningResult(
            "getComputedStyle(document.querySelector('.ad-banner')).display",
          ),
          'none',
        );
        await web.runJavaScript("document.querySelector('#normal').click()");
        expect(
          await web.runJavaScriptReturningResult(
            "document.querySelector('#normal').textContent",
          ),
          'clicked',
        );
        await web.runJavaScript("document.querySelector('#popup').click()");
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(web.pageUrl, url.toString());

        blocker.allowedSites.add('127.0.0.1');
        loaded = Completer<void>();
        await web.updateProtection();
        await web.reload();
        await loaded.future.timeout(const Duration(seconds: 20));
        expect(
          await web.runJavaScriptReturningResult(
            "getComputedStyle(document.querySelector('.ad-banner')).display",
          ),
          'block',
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await server.close(force: true);
    },
  );
}
