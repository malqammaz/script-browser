import 'package:flutter/services.dart';
import '../application/cast_keep_alive.dart';

/// Android owns the foreground notification and CPU/network locks.
class AndroidCastKeepAlive implements CastKeepAlive {
  AndroidCastKeepAlive({MethodChannel? channel})
    : channel =
          channel ?? const MethodChannel('script_browser/cast_background');
  final MethodChannel channel;
  Future<void> Function()? onStopRequested;

  void attach() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'stopRequested') await onStopRequested?.call();
    });
  }

  void detach() => channel.setMethodCallHandler(null);

  @override
  Future<void> start(String deviceName) =>
      channel.invokeMethod<void>('start', {'deviceName': deviceName});
  @override
  Future<void> stop() => channel.invokeMethod<void>('stop');
}
