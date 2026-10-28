import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:script_browser/features/browser/application/media_relay.dart';
import 'package:script_browser/features/browser/infrastructure/android_cast_keep_alive.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Foreground relay remains reachable while phone is locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Background casting connection test')),
        ),
      ),
    );
    await tester.runAsync(() async {
      final background = AndroidCastKeepAlive();
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var hits = 0;
      final subscription = upstream.listen((request) async {
        hits++;
        request.response.statusCode = 206;
        request.response.headers.set('Content-Range', 'bytes 1-3/4');
        request.response.contentLength = 3;
        request.response.add([2, 3, 4]);
        await request.response.close();
      });
      final relay = MediaRelay(cookies: (_) async => '');
      try {
        await background.start('Screen-off connection test');
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        );
        final local = interfaces
            .expand((i) => i.addresses)
            .firstWhere((a) => a.address.startsWith('192.168.'));
        const peer = String.fromEnvironment(
          'TEST_PEER',
          defaultValue: '192.168.1.15',
        );
        final url = await relay.start(
          Uri.parse('http://127.0.0.1:${upstream.port}/sample.mp4'),
          local,
          peer,
        );
        // The host reads this temporary URL, locks the device, and verifies Range responses over Wi-Fi.
        debugPrint('BACKGROUND_RELAY_URL=$url');
        await Future<void>.delayed(const Duration(seconds: 50));
        expect(
          hits,
          greaterThanOrEqualTo(5),
          reason: 'Host must verify relay requests while screen is off',
        );
        debugPrint('BACKGROUND_RELAY_HITS=$hits');
      } finally {
        await relay.close();
        await background.stop();
        await subscription.cancel();
        await upstream.close(force: true);
      }
    });
  });
}
