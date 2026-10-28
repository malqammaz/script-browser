import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:xml/xml.dart';

class CastTv {
  const CastTv(this.name, this.control);
  final String name;
  final Uri control;
}

class TvCast {
  static const service = 'urn:schemas-upnp-org:service:AVTransport:1';
  MediaRelay? relay;
  CastTv? connected;
  bool browserReceiver = false;
  Uri? get receiverUrl => relay?.browserUrl;

  static String xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static Future<List<CastTv>> discover() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final locations = <String>{};
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        final text = utf8.decode(datagram!.data, allowMalformed: true);
        final location = RegExp(
          r'^location:\s*(.+)$',
          caseSensitive: false,
          multiLine: true,
        ).firstMatch(text)?.group(1)?.trim();
        if (location != null) locations.add(location);
      }
    });
    try {
      final bytes = utf8.encode(
        'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\nST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n',
      );
      socket.send(bytes, InternetAddress('239.255.255.250'), 1900);
      await Future<void>.delayed(const Duration(seconds: 1));
      socket.send(bytes, InternetAddress('239.255.255.250'), 1900);
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      await subscription.cancel();
      socket.close();
    }
    final devices = <CastTv>[];
    await Future.wait(
      locations.map((location) async {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 3);
        try {
          final uri = Uri.parse(location);
          if (!['http', 'https'].contains(uri.scheme)) return;
          final response = await (await client.getUrl(
            uri,
          )).close().timeout(const Duration(seconds: 4));
          if (response.statusCode != 200) return;
          final doc = XmlDocument.parse(
            await utf8.decoder
                .bind(response)
                .join()
                .timeout(const Duration(seconds: 4)),
          );
          final base = doc
              .findAllElements('URLBase')
              .firstOrNull
              ?.innerText
              .trim();
          final root = base == null || base.isEmpty ? uri : uri.resolve(base);
          for (final item in doc.findAllElements('service')) {
            if (item.getElement('serviceType')?.innerText != service) continue;
            final path = item.getElement('controlURL')?.innerText;
            if (path == null) continue;
            final control = root.resolve(path);
            if (control.host != uri.host) continue;
            if (!devices.any((d) => d.control == control))
              devices.add(
                CastTv(
                  doc.findAllElements('friendlyName').firstOrNull?.innerText ??
                      uri.host,
                  control,
                ),
              );
          }
        } catch (_) {
          /* An unrelated device must not fail discovery. */
        } finally {
          client.close(force: true);
        }
      }),
    );
    return devices;
  }

  static Future<String> command(
    CastTv tv,
    String action, [
    Map<String, String> args = const {},
  ]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(tv.control);
      request.headers.set('Content-Type', 'text/xml; charset=utf-8');
      request.headers.set('SOAPAction', '"$service#$action"');
      final fields = {'InstanceID': '0', ...args};
      request.write(
        '<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:$action xmlns:u="$service">${fields.entries.map((e) => '<${e.key}>${xmlEscape(e.value)}</${e.key}>').join()}</u:$action></s:Body></s:Envelope>',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        final code =
            RegExp(
              r'<errorCode>([^<]+)</errorCode>',
            ).firstMatch(text)?.group(1) ??
            '${response.statusCode}';
        throw StateError(
          'التلفزيون رفض الطلب ($action، $code). جرّب رابط فيديو آخر.',
        );
      }
      return text;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> cast(
    CastTv tv,
    Uri media, {
    required Future<String> Function(Uri) cookies,
    Map<String, String> headers = const {},
    bool useBrowserReceiver = false,
  }) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final peer = (await InternetAddress.lookup(
      tv.control.host,
      type: InternetAddressType.IPv4,
    )).first;
    final addresses = interfaces.expand((i) => i.addresses).toList();
    if (addresses.isEmpty)
      throw StateError('اتصل بنفس شبكة Wi-Fi الخاصة بالتلفزيون.');
    final prefix = peer.address.split('.').take(3).join('.');
    final local =
        addresses.where((a) => a.address.startsWith('$prefix.')).firstOrNull ??
        addresses.first;
    await relay?.close();
    final next = MediaRelay(cookies: cookies, headers: headers);
    relay = next;
    try {
      final url = await next.start(
        media,
        local,
        peer.address,
        port: useBrowserReceiver ? 8878 : 0,
      );
      browserReceiver = useBrowserReceiver;
      if (useBrowserReceiver) {
        connected = tv;
        return;
      }
      final type = media.path.toLowerCase().endsWith('.m3u8')
          ? 'application/vnd.apple.mpegurl'
          : 'video/mp4';
      final metadata =
          '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="video" parentID="0" restricted="1"><dc:title>Script Browser</dc:title><upnp:class>object.item.videoItem</upnp:class><res protocolInfo="http-get:*:$type:*">${xmlEscape('$url')}</res></item></DIDL-Lite>';
      await command(tv, 'SetAVTransportURI', {
        'CurrentURI': '$url',
        'CurrentURIMetaData': metadata,
      });
      await command(tv, 'Play', {'Speed': '1'});
      connected = tv;
    } catch (_) {
      try {
        await command(tv, 'Stop');
      } catch (_) {}
      connected = null;
      await next.close();
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      if (connected != null && !browserReceiver)
        await command(connected!, 'Stop');
    } finally {
      connected = null;
      browserReceiver = false;
      await relay?.close();
      relay = null;
    }
  }

  Future<void> close() async {
    await relay?.close();
    relay = null;
  }
}

/// Streams bytes in memory; URLs are registered explicitly, never an open proxy.
class MediaRelay {
  Uri? _media;
  Uri get browserUrl => _base.resolve('/tv');
  String receiverState = 'waiting';
  double receiverTime = 0;
  int? lastUpstreamStatus;
  String? lastContentType;
  String? lastFailure;
  MediaRelay({required this.cookies, this.headers = const {}});
  final Future<String> Function(Uri) cookies;
  final Map<String, String> headers;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final _urls = <String, Uri>{};
  final _ids = <Uri, String>{};
  HttpServer? _server;
  late String _peer;
  late Uri _base;
  late String _secret;
  Future<Uri> start(
    Uri media,
    InternetAddress address,
    String peer, {
    int port = 0,
  }) async {
    _peer = peer;
    _secret = List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _server = await HttpServer.bind(address, port);
    _base = Uri(scheme: 'http', host: address.address, port: _server!.port);
    _server!.listen((request) => unawaited(_serve(request)));
    _media = register(media);
    return _media!;
  }

  Uri register(Uri uri) {
    if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty)
      throw const FormatException('رابط فيديو غير صالح.');
    final id = _ids.putIfAbsent(
      uri,
      () =>
          '${_ids.length}.${uri.path.toLowerCase().endsWith('.m3u8') ? 'm3u8' : 'bin'}',
    );
    _urls[id] = uri;
    return _base.resolve('/$_secret/$id');
  }

  String rewritePlaylist(String text, Uri original) => text
      .split('\n')
      .map((line) {
        if (line.trim().isEmpty) return line;
        if (line.trimLeft().startsWith('#'))
          return line.replaceAllMapped(
            RegExp(r'URI="([^"]+)"'),
            (m) => 'URI="${register(original.resolve(m[1]!))}"',
          );
        return '${register(original.resolve(line.trim()))}';
      })
      .join('\n');

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      final parts = request.uri.pathSegments;
      if (request.connectionInfo?.remoteAddress.address == _peer &&
          request.method == 'GET' &&
          request.uri.path == '/tv') {
        response.headers.contentType = ContentType.html;
        response.headers.set('Cache-Control', 'no-store');
        response.write(
          '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Script Browser TV</title><style>html,body{margin:0;background:#080b0d;color:white;font:22px sans-serif;height:100%}video{width:100%;height:90vh;background:black}p{text-align:center;margin:8px}</style></head><body><video id="video" controls autoplay playsinline src="${TvCast.xmlEscape('$_media')}"></video><p id="status">Select Play to start the video.</p><script>
const v=document.getElementById('video'),s=document.getElementById('status');let last=0;
function report(state){fetch('/tv-status?state='+state+'&time='+v.currentTime).catch(()=>{});}
v.addEventListener('playing',()=>{s.textContent='Playing from your phone';report('playing');});
v.addEventListener('pause',()=>report('paused'));
v.addEventListener('error',()=>{s.textContent='This stream could not be played (error '+(v.error?v.error.code:'unknown')+').';report('error');});
v.addEventListener('timeupdate',()=>{if(v.currentTime-last>2){last=v.currentTime;report('playing');}});
v.play().catch(()=>{s.textContent='Press Play on the video to start.';});
</script></body></html>''',
        );
        return;
      }
      if (request.connectionInfo?.remoteAddress.address == _peer &&
          request.method == 'GET' &&
          request.uri.path == '/tv-status') {
        final state = request.uri.queryParameters['state'];
        if (['playing', 'paused', 'error'].contains(state))
          receiverState = state!;
        receiverTime =
            double.tryParse(request.uri.queryParameters['time'] ?? '') ?? 0;
        response.statusCode = 204;
        return;
      }
      if (request.connectionInfo?.remoteAddress.address != _peer ||
          parts.length != 2 ||
          parts[0] != _secret ||
          !_urls.containsKey(parts[1])) {
        response.statusCode = 403;
        return;
      }
      if (!['GET', 'HEAD'].contains(request.method)) {
        response.statusCode = 405;
        return;
      }
      var uri = _urls[parts[1]]!;
      HttpClientResponse? upstream;
      for (var redirect = 0; redirect < 6; redirect++) {
        final req = await _client.openUrl(request.method, uri);
        req.followRedirects = false;
        for (final entry in headers.entries)
          if ([
            'user-agent',
            'referer',
            'origin',
          ].contains(entry.key.toLowerCase()))
            req.headers.set(entry.key, entry.value);
        final cookie = await cookies(uri);
        if (cookie.isNotEmpty) req.headers.set('Cookie', cookie);
        final range = request.headers.value('range');
        if (range != null) req.headers.set('Range', range);
        upstream = await req.close().timeout(const Duration(seconds: 25));
        if ([301, 302, 303, 307, 308].contains(upstream.statusCode)) {
          final target = upstream.headers.value('location');
          await upstream.drain<void>();
          if (target == null)
            throw const FormatException('Invalid media redirect');
          uri = uri.resolve(target);
          if (!['http', 'https'].contains(uri.scheme))
            throw const FormatException('Invalid redirect');
          upstream = null;
          continue;
        }
        break;
      }
      if (upstream == null) throw StateError('Too many media redirects');
      response.statusCode = upstream.statusCode;
      lastUpstreamStatus = upstream.statusCode;
      final type = upstream.headers.contentType?.mimeType ?? '';
      lastContentType = type;
      final playlist =
          type.contains('mpegurl') || uri.path.toLowerCase().endsWith('.m3u8');
      if (playlist && request.method != 'HEAD' && upstream.statusCode == 200) {
        final text = await utf8.decoder
            .bind(upstream)
            .join()
            .timeout(const Duration(seconds: 20));
        response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        response.write(rewritePlaylist(text, uri));
      } else {
        for (final name in ['content-type', 'content-range', 'accept-ranges']) {
          final value = upstream.headers.value(name);
          if (value != null) response.headers.set(name, value);
        }
        if (upstream.contentLength >= 0)
          response.contentLength = upstream.contentLength;
        if (request.method == 'HEAD') {
          await upstream.drain<void>();
        } else {
          await response.addStream(
            upstream.timeout(const Duration(seconds: 30)),
          );
        }
      }
    } catch (error) {
      lastFailure = error.runtimeType.toString();
      try {
        response.statusCode = 502;
      } catch (_) {}
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    _client.close(force: true);
    await _server?.close(force: true);
    _server = null;
    _urls.clear();
    _ids.clear();
  }
}
