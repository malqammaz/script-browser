import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/infrastructure/android_cast_keep_alive.dart';
import 'package:script_browser/features/browser/application/cast_keep_alive.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';

class FakeKeepAlive implements CastKeepAlive {
  int stops = 0;
  @override
  Future<void> start(String name) async {}
  @override
  Future<void> stop() async {
    stops++;
  }
}

class FailingRelay extends MediaRelay {
  FailingRelay() : super(cookies: (_) async => '');
  @override
  Future<void> close() async => throw StateError('close failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Platform adapter starts with TV name and stops background support',
    () async {
      const channel = MethodChannel('test/cast_background');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      final service = AndroidCastKeepAlive(channel: channel)..attach();
      try {
        await service.start('Living room TV');
        await service.stop();
        expect(calls.map((c) => c.method), ['start', 'stop']);
        expect(calls.first.arguments, {'deviceName': 'Living room TV'});
      } finally {
        service.detach();
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );
  test(
    'Closing a cast releases keep-alive even when relay cleanup fails',
    () async {
      final service = FakeKeepAlive();
      final cast = TvCast(keepAlive: service)..relay = FailingRelay();
      await expectLater(cast.close(), throwsStateError);
      expect(service.stops, 1);
      expect(cast.relay, isNull);
    },
  );
  test(
    'Stopping a receiver clears connection and releases keep-alive',
    () async {
      final service = FakeKeepAlive();
      final cast = TvCast(keepAlive: service)
        ..connected = CastTv('TV', Uri.parse('http://127.0.0.1/control'))
        ..browserReceiver = true;
      await cast.stop();
      expect(service.stops, 1);
      expect(cast.connected, isNull);
      expect(cast.browserReceiver, false);
    },
  );
}
