/// Platform-independent lifecycle contract for an active cast session.
abstract interface class CastKeepAlive {
  Future<void> start(String deviceName);
  Future<void> stop();
}

class NoCastKeepAlive implements CastKeepAlive {
  const NoCastKeepAlive();
  @override
  Future<void> start(String deviceName) async {}
  @override
  Future<void> stop() async {}
}
