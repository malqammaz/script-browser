import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart';
import 'media_relay.dart';
export 'media_relay.dart';

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
            if (!devices.any((d) => d.control == control)) {
              devices.add(
                CastTv(
                  doc.findAllElements('friendlyName').firstOrNull?.innerText ??
                      uri.host,
                  control,
                ),
              );
            }
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
          'The TV rejected the request ($action, $code). Try another video link.',
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
    if (addresses.isEmpty) {
      throw StateError('Connect to the same Wi-Fi as your TV.');
    }
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
      if (connected != null && !browserReceiver) {
        await command(connected!, 'Stop');
      }
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
