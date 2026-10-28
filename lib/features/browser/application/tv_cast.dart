import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:xml/xml.dart';
import 'media_source.dart';
import 'ram_media_buffer.dart';

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
  Uri? _original;
  bool receiverPageOpened = false;
  Uri get browserUrl => _base.resolve('/tv');
  String receiverState = 'waiting';
  double receiverTime = 0;
  int? lastUpstreamStatus;
  String? lastContentType;
  String? lastFailure;
  MediaRelay({
    required this.cookies,
    this.headers = const {},
    int bufferBytes = 128 * 1024 * 1024,
    this.maxSegmentBytes = 16 * 1024 * 1024,
    this.prefetchSeconds = 120,
    this.prefetchDelay = const Duration(milliseconds: 250),
  }) : buffer = RamMediaBuffer(capacity: bufferBytes);
  final RamMediaBuffer buffer;
  final int maxSegmentBytes;
  final double prefetchSeconds;
  final Duration prefetchDelay;
  final _pending = <Uri, Future<BufferedSegment?>>{};
  List<(Uri, double)> _plan = [];
  Uri? _planUrl;
  int _playIndex = 0, _nextIndex = 0, _generation = 0;
  bool _prefetching = false, _closed = false;
  DateTime? _pausedUntil;
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
    _original = media;
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

  String rewritePlaylist(String text, Uri original) {
    _configureBuffer(text, original);
    return text
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
  }

  void _configureBuffer(String text, Uri original) {
    // Cache immutable VOD segments. Byte-range playlists may reference one huge file.
    if (!text.contains('#EXTINF:') ||
        !text.contains('#EXT-X-ENDLIST') ||
        text.contains('#EXT-X-BYTERANGE'))
      return;
    final plan = <(Uri, double)>[];
    double duration = 0;
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:'))
        duration = double.tryParse(line.substring(8).split(',').first) ?? 6;
      else if (line.isNotEmpty && !line.startsWith('#'))
        plan.add((original.resolve(line), duration > 0 ? duration : 6));
    }
    if (plan.isEmpty || (_planUrl == original && _plan.isNotEmpty)) return;
    _generation++;
    buffer.clear();
    _planUrl = original;
    _plan = plan;
    _playIndex = 0;
    _nextIndex = 0;
    _kickPrefetch();
  }

  void _segmentRequested(Uri uri) {
    final index = _plan.indexWhere((entry) => entry.$1 == uri);
    if (index < 0) return;
    if ((index - _playIndex).abs() > 4) {
      _generation++;
      buffer.clear();
      _nextIndex = index + 1;
    }
    _playIndex = index;
    _nextIndex = max(_nextIndex, index + 1);
    final old = _plan.take(max(0, index - 2)).map((entry) => entry.$1).toSet();
    buffer.removeWhere(old.contains);
    _kickPrefetch();
  }

  void _pauseFor(HttpClientResponse response) {
    if (![429, 503].contains(response.statusCode)) return;
    final value = response.headers.value('retry-after') ?? '';
    final seconds = int.tryParse(value);
    DateTime? date;
    try {
      date = HttpDate.parse(value);
    } catch (_) {}
    final minimum = DateTime.now().add(const Duration(seconds: 30));
    final requested = seconds != null
        ? DateTime.now().add(Duration(seconds: seconds))
        : date ?? minimum;
    _pausedUntil = requested.isAfter(minimum) ? requested : minimum;
  }

  Future<(HttpClientResponse, Uri)> _openUpstream(
    Uri uri, {
    String method = 'GET',
    String? range,
  }) async {
    for (var redirect = 0; redirect < 6; redirect++) {
      final req = await _client.openUrl(method, uri);
      req.followRedirects = false;
      for (final entry in headers.entries) {
        if ([
          'user-agent',
          'referer',
          'origin',
        ].contains(entry.key.toLowerCase()))
          req.headers.set(entry.key, entry.value);
      }
      final cookie = await cookies(uri);
      if (cookie.isNotEmpty) req.headers.set('Cookie', cookie);
      if (range != null) req.headers.set('Range', range);
      final upstream = await req.close().timeout(const Duration(seconds: 25));
      if ([301, 302, 303, 307, 308].contains(upstream.statusCode)) {
        final target = upstream.headers.value('location');
        await upstream.drain<void>();
        if (target == null)
          throw const FormatException('Invalid media redirect');
        uri = uri.resolve(target);
        if (!['http', 'https'].contains(uri.scheme))
          throw const FormatException('Invalid redirect');
        continue;
      }
      _pauseFor(upstream);
      return (upstream, uri);
    }
    throw StateError('Too many media redirects');
  }

  void _kickPrefetch() {
    if (_closed ||
        _prefetching ||
        _plan.isEmpty ||
        (_pausedUntil?.isAfter(DateTime.now()) ?? false))
      return;
    _prefetching = true;
    unawaited(() async {
      final generation = _generation;
      try {
        while (!_closed &&
            generation == _generation &&
            _nextIndex < _plan.length) {
          if (_pausedUntil?.isAfter(DateTime.now()) ?? false) break;
          final ahead = _plan
              .skip(_playIndex)
              .take(max(0, _nextIndex - _playIndex))
              .fold<double>(0, (sum, entry) => sum + entry.$2);
          if (ahead >= prefetchSeconds ||
              buffer.freeBytes < min(maxSegmentBytes, buffer.capacity))
            break;
          final uri = _plan[_nextIndex++].$1;
          if (buffer.contains(uri)) continue;
          final future = _loadSegment(uri, generation);
          _pending[uri] = future;
          try {
            final data = await future;
            if (data == null) break;
            if (data != null && !_closed && generation == _generation)
              buffer.put(uri, data);
          } finally {
            _pending.remove(uri);
          }
          if (prefetchDelay > Duration.zero)
            await Future<void>.delayed(prefetchDelay);
        }
      } finally {
        _prefetching = false;
        if (!_closed && generation != _generation) _kickPrefetch();
      }
    }());
  }

  Future<BufferedSegment?> _loadSegment(Uri uri, int generation) async {
    try {
      final (response, _) = await _openUpstream(uri);
      if (response.statusCode != 200 ||
          response.contentLength > maxSegmentBytes) {
        await response.listen((_) {}).cancel();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      int size = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 25))) {
        if (_closed || generation != _generation) return null;
        size += chunk.length;
        if (size > maxSegmentBytes || size > buffer.capacity) return null;
        bytes.add(chunk);
      }
      return BufferedSegment(
        bytes.takeBytes(),
        response.headers.contentType?.mimeType ?? 'application/octet-stream',
      );
    } catch (_) {
      return null;
    }
  }

  void _serveBuffered(HttpRequest request, BufferedSegment data) {
    final response = request.response;
    final length = data.bytes.length;
    response.headers.set('Content-Type', data.contentType);
    response.headers.set('Accept-Ranges', 'bytes');
    var start = 0, end = length - 1;
    final range = request.headers.value('range');
    if (range != null) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
      if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$length');
        return;
      }
      if (match[1]!.isEmpty) {
        start = max(0, length - (int.tryParse(match[2]!) ?? 0));
      } else {
        start = int.tryParse(match[1]!) ?? length;
        if (match[2]!.isNotEmpty)
          end = min(end, int.tryParse(match[2]!) ?? end);
      }
      if (start >= length || start > end) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$length');
        return;
      }
      response.statusCode = 206;
      response.headers.set('Content-Range', 'bytes $start-$end/$length');
    }
    response.contentLength = max(0, end - start + 1);
    if (request.method != 'HEAD' && length > 0)
      response.add(Uint8List.sublistView(data.bytes, start, end + 1));
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      final parts = request.uri.pathSegments;
      if (request.connectionInfo?.remoteAddress.address == _peer &&
          request.method == 'GET' &&
          request.uri.path == '/tv') {
        receiverPageOpened = true;
        response.headers.contentType = ContentType.html;
        response.headers.set('Cache-Control', 'no-store');
        final preview = _original == null
            ? null
            : publicDrivePreview(_original!);
        if (preview != null) {
          response.write(
            '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Drive preview on TV</title><style>html,body{margin:0;width:100%;height:100%;background:black}iframe{border:0;width:100%;height:100%}</style></head><body><iframe src="${TvCast.xmlEscape('$preview')}" allow="autoplay; fullscreen" allowfullscreen title="Google Drive public preview"></iframe></body></html>''',
          );
          return;
        }
        response.write(
          '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Script Browser TV</title><style>html,body{margin:0;background:#080b0d;color:white;font:22px sans-serif;height:100%}video{width:100%;height:90vh;background:black}p{text-align:center;margin:8px}</style></head><body><video id="video" controls autoplay playsinline src="${TvCast.xmlEscape('$_media')}"></video><p id="status">Select Play to start the video.</p><script>
const v=document.getElementById('video'),s=document.getElementById('status');let last=0;
function report(state){fetch('/tv-status?state='+state+'&time='+v.currentTime).catch(()=>{});}
v.addEventListener('playing',()=>{s.textContent='Playing from your phone';report('playing');});
v.addEventListener('pause',()=>report('paused'));
v.addEventListener('error',()=>{s.textContent='This stream could not be played (error '+(v.error?v.error.code:'unknown')+').';report('error');});
v.addEventListener('timeupdate',()=>{if(v.currentTime-last>2){last=v.currentTime;report('playing');}});
v.play().catch(()=>{s.textContent='Press Play on the video to start.';});
setInterval(()=>{if(!v.paused&&!v.error)fetch('/tv-buffer').then(r=>r.json()).then(b=>{s.textContent='Playing · RAM buffer '+(b.used/1048576).toFixed(1)+' / '+(b.limit/1048576).toFixed(0)+' MB';}).catch(()=>{});},4000);
</script></body></html>''',
        );
        return;
      }
      if (request.connectionInfo?.remoteAddress.address == _peer &&
          request.method == 'GET' &&
          request.uri.path == '/tv-buffer') {
        response.headers.contentType = ContentType.json;
        response.headers.set('Cache-Control', 'no-store');
        response.write(
          jsonEncode({'used': buffer.usedBytes, 'limit': buffer.capacity}),
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
      final source = _urls[parts[1]]!;
      BufferedSegment? cached = buffer.get(source);
      if (cached == null && _pending.containsKey(source))
        cached = await _pending[source];
      if (request.method == 'GET') _segmentRequested(source);
      if (cached != null) {
        _serveBuffered(request, cached);
        return;
      }
      if (_plan.any((entry) => entry.$1 == source) &&
          (_pausedUntil?.isAfter(DateTime.now()) ?? false)) {
        response.statusCode = 429;
        response.headers.set(
          'Retry-After',
          max(1, _pausedUntil!.difference(DateTime.now()).inSeconds),
        );
        return;
      }
      final (upstream, uri) = await _openUpstream(
        source,
        method: request.method,
        range: request.headers.value('range'),
      );
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
    _closed = true;
    _generation++;
    buffer.clear();
    _plan.clear();
    _client.close(force: true);
    await _server?.close(force: true);
    _server = null;
    _urls.clear();
    _ids.clear();
  }
}
