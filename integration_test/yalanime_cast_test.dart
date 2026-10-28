import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:script_browser/features/browser/infrastructure/browser_web.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';
import 'package:script_browser/features/protection/domain/ad_blocker.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Detects a Yalanime episode stream and casts it to LG', (
    tester,
  ) async {
    var completed = '';
    final web = BrowserWeb(
      blocker: AdBlocker(),
      onStarted: (_) {},
      onFinished: (url) {
        completed = url;
      },
      onProgress: (_) {},
      onError: (message) {
        debugPrint('WebView: $message');
      },
      onBlocked: () {},
    );
    final cast = TvCast();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: web.view())));
    await tester.pump(const Duration(seconds: 2));
    Future<void> load(String url) async {
      completed = '';
      await web.loadRequest(Uri.parse(url));
      for (var i = 0; i < 35 && completed.isEmpty; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(completed, isNotEmpty, reason: 'Web page failed to load');
    }

    try {
      await load(
        'https://yalanime.com/انمي-overgeared-2026-مترجم-كامل-الحلقة-1/watch/',
      );
      final raw = await web.controller!.evaluateJavascript(
        source:
            'JSON.stringify(Array.from(document.querySelectorAll("[data-server]")).map(e=>e.getAttribute("data-server")))',
      );
      final servers = (jsonDecode(raw as String) as List).cast<String>();
      expect(
        servers,
        isNotEmpty,
        reason: 'No episode servers found on Yalanime',
      );
      final ordered = servers
          .where((s) => s.contains('vidara'))
          .followedBy(servers.where((s) => s.contains('uqload')))
          .followedBy(servers.where((s) => s.contains('morencius')))
          .toList();
      String? selected;
      for (final server in ordered) {
        try {
          await load(server);
        } catch (_) {
          debugPrint('Player ${Uri.parse(server).host} did not load');
          continue;
        }
        await tester.pump(const Duration(seconds: 5));
        await web.detectMedia();
        if (web.mediaRequests.isEmpty) {
          final rect = await web.controller!.evaluateJavascript(
            source:
                '''JSON.stringify((()=>{const e=document.querySelector('.vjs-big-play-button,.jw-icon-display,button[aria-label="Play"],video');if(!e)return null;const r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})())''',
          );
          final point = jsonDecode(rect as String);
          if (point is Map) {
            await tester.tapAt(
              Offset(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              ),
            );
          }
          for (var i = 0; i < 12 && web.mediaRequests.isEmpty; i++) {
            await tester.pump(const Duration(seconds: 1));
            await web.detectMedia();
          }
        }
        debugPrint(
          'Player ${Uri.parse(server).host}: ${web.mediaRequests.length} detected streams',
        );
        if (web.mediaRequests.isNotEmpty) {
          selected = web.mediaRequests.keys.last;
          break;
        }
      }
      expect(
        selected,
        isNotNull,
        reason: 'No MP4/HLS stream detected in the episode players',
      );
      final devices = await TvCast.discover();
      final tv = devices.where((d) => d.name.contains('UR78006LL')).first;
      debugPrint(
        'Selected stream type: ${Uri.parse(selected!).path.endsWith('.m3u8') ? 'HLS' : 'MP4'}',
      );
      try {
        await cast.cast(
          tv,
          Uri.parse(selected!),
          cookies: web.mediaCookies,
          useBrowserReceiver: true,
          headers: web.mediaRequests[selected] ?? const {},
        );
      } catch (_) {
        debugPrint(
          'Relay diagnostics: status=${cast.relay?.lastUpstreamStatus}, type=${cast.relay?.lastContentType}, error=${cast.relay?.lastFailure}',
        );
        rethrow;
      }
      debugPrint('LG_BROWSER_READY ${cast.receiverUrl}');
      for (
        var i = 0;
        i < 180 &&
            cast.relay!.receiverTime < 3 &&
            cast.relay!.receiverState != 'error';
        i++
      )
        await tester.pump(const Duration(seconds: 1));
      debugPrint(
        'Receiver state=${cast.relay!.receiverState}, time=${cast.relay!.receiverTime}, upstream=${cast.relay!.lastUpstreamStatus}, type=${cast.relay!.lastContentType}',
      );
      expect(cast.relay!.receiverState, 'playing');
      expect(cast.relay!.receiverTime, greaterThanOrEqualTo(3));
    } finally {
      await cast.stop();
      await cast.close();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
