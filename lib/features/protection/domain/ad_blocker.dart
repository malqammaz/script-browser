/// Conservative host matching: URL paths and partial host names never match.
/// Locally maintained starter rules; no browsing history leaves the device.
class AdBlocker {
  bool enabled = true;
  final Set<String> allowedSites = {};
  final Set<String> customDomains = {};

  static const domains = {
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'googletagservices.com',
    'adservice.google.com',
    'google-analytics.com',
    'analytics.google.com',
    'ads.youtube.com',
    'adnxs.com',
    'adsrvr.org',
    'adform.net',
    'advertising.com',
    'amazon-adsystem.com',
    'criteo.com',
    'criteo.net',
    'taboola.com',
    'taboolasyndication.com',
    'outbrain.com',
    'outbrainimg.com',
    'revcontent.com',
    'mgid.com',
    'propellerads.com',
    'popads.net',
    'popcash.net',
    'popunder.net',
    'adsterra.com',
    'adsterra.org',
    'exoclick.com',
    'exosrv.com',
    'trafficjunky.net',
    'trafficjunky.com',
    'juicyads.com',
    'ad-maven.com',
    'hilltopads.net',
    'monetag.com',
    'onclicka.com',
    'onclickalgo.com',
    'onclkds.com',
    'onclckads.com',
    'a-ads.com',
    'bidvertiser.com',
    'clickadu.com',
    'clickaine.com',
    'adroll.com',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'openx.com',
    'casalemedia.com',
    'indexww.com',
    'smartadserver.com',
    'sharethrough.com',
    'yieldmo.com',
    'lijit.com',
    'sovrn.com',
    'bidswitch.net',
    'media.net',
    'adskeeper.com',
    'adskeeper.co.uk',
    'zedo.com',
    'moatads.com',
    'scorecardresearch.com',
    'quantserve.com',
    'hotjar.com',
    'hotjar.io',
    'clarity.ms',
    'ads-twitter.com',
    'ads.linkedin.com',
    'bat.bing.com',
  };

  bool activeFor(String? pageUrl) {
    final host = Uri.tryParse(pageUrl ?? '')?.host.toLowerCase() ?? '';
    return enabled && !allowedSites.contains(host);
  }

  static bool hostMatches(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  bool blocks(String url, String? pageUrl) {
    if (!activeFor(pageUrl)) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return false;
    final host = uri.host.toLowerCase();
    return domains.any((domain) => hostMatches(host, domain)) ||
        customDomains.any((domain) => hostMatches(host, domain));
  }

  static Set<String> parseCustomDomains(String text) {
    final result = <String>{};
    for (final input in text.split(RegExp(r'[\s,]+'))) {
      if (input.isEmpty) continue;
      final domain = input.toLowerCase().trim().replaceFirst(
        RegExp(r'^\*\.'),
        '',
      );
      if (!RegExp(
        r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$',
      ).hasMatch(domain)) {
        throw FormatException('أدخل اسم نطاق فقط مثل ads.example.com: $input');
      }
      result.add(domain);
    }
    return result;
  }

  // Precise advertising markers only: no generic overlays or player elements.
  static const cosmeticScript = r'''
(() => {
  if (window.__scriptBrowserAdStyle) return;
  window.__scriptBrowserAdStyle = true;
  const css = '.adsbygoogle,[data-ad-slot],[id^="google_ads_iframe_"],[id^="div-gpt-ad"],.ad-banner,.ad-container,.advertisement{display:none!important}';
  const apply = () => {
    if (!document.documentElement || document.getElementById('__sb_ad_style')) return;
    const style = document.createElement('style');
    style.id = '__sb_ad_style'; style.textContent = css;
    document.documentElement.appendChild(style);
  };
  apply();
  new MutationObserver(apply).observe(document, {childList:true,subtree:true});
})();
''';
}
