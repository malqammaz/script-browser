import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/ad_blocker.dart';

void main() {
  late AdBlocker blocker;
  setUp(() => blocker = AdBlocker());
  test('Blocks advertising hosts and subdomains', () {
    expect(
      blocker.blocks('https://doubleclick.net/ad.js', 'https://example.com'),
      isTrue,
    );
    expect(
      blocker.blocks(
        'https://pagead2.googlesyndication.com/a',
        'https://example.com',
      ),
      isTrue,
    );
  });
  test('Does not match partial hosts or words in paths', () {
    for (final url in [
      'https://notdoubleclick.net/',
      'https://doubleclick.net.example.com/',
      'https://example.com/ads/doubleclick.net',
      'https://github.com/',
    ]) {
      expect(blocker.blocks(url, 'https://example.com'), isFalse, reason: url);
    }
  });
  test('Global switch disables network blocking', () {
    blocker.enabled = false;
    expect(
      blocker.blocks('https://doubleclick.net/', 'https://example.com'),
      isFalse,
    );
  });
  test('Site exception is exact and scoped to the page', () {
    blocker.allowedSites.add('example.com');
    expect(
      blocker.blocks('https://doubleclick.net/', 'https://example.com/watch'),
      isFalse,
    );
    expect(
      blocker.blocks('https://doubleclick.net/', 'https://other.example.com'),
      isTrue,
    );
  });
  test('Custom domains support subdomains and normalization', () {
    blocker.customDomains.addAll(
      AdBlocker.parseCustomDomains('ADS.Example.com\n*.tracker.example.org'),
    );
    expect(
      blocker.blocks('https://sub.ads.example.com/a', 'https://site.test'),
      isTrue,
    );
    expect(
      blocker.blocks('https://tracker.example.org/a', 'https://site.test'),
      isTrue,
    );
    expect(
      blocker.blocks('https://example.com/', 'https://site.test'),
      isFalse,
    );
  });
  test('Rejects URLs and invalid custom domains', () {
    for (final input in [
      'https://example.com/ad',
      'example.com/path',
      'bad_domain.com',
    ]) {
      expect(() => AdBlocker.parseCustomDomains(input), throwsFormatException);
    }
  });
}
