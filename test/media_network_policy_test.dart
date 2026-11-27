import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/application/media_network_policy.dart';

void main() {
  test('cast destinations distinguish public, private and loopback addresses', () {
    for (final host in ['8.8.8.8', '2606:4700:4700::1111']) {
      expect(MediaNetworkPolicy.isPublic(InternetAddress(host)), isTrue);
    }
    for (final host in ['127.0.0.1', '10.0.0.1', '169.254.1.1', '::1', 'fd00::1']) {
      expect(MediaNetworkPolicy.isPublic(InternetAddress(host)), isFalse);
    }
  });

  test('text limit counts bytes across chunks before decoding', () async {
    Stream<List<int>> chunks() => Stream.fromIterable([
      [0xc3],
      [0xa9],
    ]);
    expect(await MediaNetworkPolicy.readText(chunks(), 2), 'é');
    await expectLater(MediaNetworkPolicy.readText(chunks(), 1), throwsFormatException);
  });
}
