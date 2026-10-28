import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';

void main() {
  test(
    'MEGA receiver redirects to the normal file page without fetching encrypted bytes',
    () async {
      final key = 'A' * 43;
      final relay = MediaRelay(
        cookies: (_) async => throw StateError('No native MEGA cookie request'),
      );
      final client = HttpClient();
      try {
        final url = await relay.start(
          Uri.parse('https://mega.nz/embed/AbCd1234#$key'),
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        final request = await client.getUrl(url.replace(path: '/tv'));
        request.followRedirects = false;
        final response = await request.close();
        expect(response.statusCode, HttpStatus.found);
        expect(
          response.headers.value('location'),
          'https://mega.nz/file/AbCd1234#$key',
        );
        expect(response.headers.value('cache-control'), 'no-store');
        final body = await utf8.decoder.bind(response).join();
        expect(body, isNot(contains('<iframe')));
        expect(relay.lastUpstreamStatus, isNull);
      } finally {
        client.close(force: true);
        await relay.close();
      }
    },
  );
  test(
    'Declared HLS rewrites txt master and variant manifests without altering upstream URLs',
    () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = upstream.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        switch (request.uri.path) {
          case '/master.txt':
            request.response.write(
              '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000\nvariant.txt\n',
            );
          case '/variant.txt':
            request.response.write(
              '#EXTM3U\n#EXTINF:5,\npart.bin\n#EXT-X-ENDLIST\n',
            );
          case '/part.bin':
            request.response.add([1, 2, 3]);
          default:
            request.response.statusCode = 404;
        }
        await request.response.close();
      });
      final relay = MediaRelay(cookies: (_) async => '', sourceIsHls: true);
      final client = HttpClient();
      try {
        final url = await relay.start(
          Uri.parse('http://127.0.0.1:${upstream.port}/master.txt'),
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        expect(url.path, endsWith('.m3u8'));
        final master = await (await client.getUrl(url)).close();
        expect(
          master.headers.contentType?.mimeType,
          'application/vnd.apple.mpegurl',
        );
        final manifest = await utf8.decoder.bind(master).join();
        final child = Uri.parse(
          manifest.split('\n').firstWhere((line) => line.startsWith('http')),
        );
        expect(child.path, endsWith('.m3u8'));
        final variant = await (await client.getUrl(child)).close();
        expect(
          variant.headers.contentType?.mimeType,
          'application/vnd.apple.mpegurl',
        );
        final body = await utf8.decoder.bind(variant).join();
        expect(body, contains('#EXTINF:5,'));
        expect(body, isNot(contains('part.bin')));
        expect(relay.lastFailure, isNull);
      } finally {
        client.close(force: true);
        await relay.close();
        await subscription.cancel();
        await upstream.close(force: true);
      }
    },
  );
  test(
    'Drive receiver embeds preview without fetching any original bytes or cookies',
    () async {
      final relay = MediaRelay(
        cookies: (_) async =>
            throw StateError('Must not read cookies for preview embedding'),
      );
      final client = HttpClient();
      try {
        final uri = await relay.start(
          Uri.parse('https://drive.google.com/file/d/public-test/view'),
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        final response = await (await client.getUrl(
          uri.replace(path: '/tv'),
        )).close();
        final html = await utf8.decoder.bind(response).join();
        expect(html, contains('<iframe'));
        expect(
          html,
          contains('https://drive.google.com/file/d/public-test/preview'),
        );
        expect(html, isNot(contains('export=download')));
        expect(html, isNot(contains('confirm=')));
        expect(relay.lastUpstreamStatus, isNull);
      } finally {
        client.close(force: true);
        await relay.close();
      }
    },
  );
  test(
    'Relay forwards range requests and scoped cookies without storing video',
    () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = upstream.listen((req) async {
        expect(req.headers.value('range'), 'bytes=1-3');
        expect(req.headers.value('cookie'), 'session=allowed');
        req.response.statusCode = 206;
        req.response.headers.set('Content-Range', 'bytes 1-3/5');
        req.response.headers.contentType = ContentType('video', 'mp4');
        req.response.contentLength = 3;
        req.response.add([2, 3, 4]);
        await req.response.close();
      });
      final original = Uri.parse('http://127.0.0.1:${upstream.port}/movie.mp4');
      final relay = MediaRelay(
        loadPlayerScript: () =>
            File('assets/vendor/hls-1.7.3.min.js').readAsString(),
        cookies: (uri) async {
          expect(uri.host, '127.0.0.1');
          return 'session=allowed';
        },
      );
      final client = HttpClient();
      try {
        final url = await relay.start(
          original,
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        final req = await client.getUrl(url);
        req.headers.set('Range', 'bytes=1-3');
        final res = await req.close();
        expect(res.statusCode, 206);
        expect(res.headers.value('content-range'), 'bytes 1-3/5');
        final bytes = await res.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        expect(bytes, [2, 3, 4]);
        final denied = await (await client.getUrl(
          url.replace(path: '/wrong/0.bin'),
        )).close();
        expect(denied.statusCode, 403);
        await denied.drain<void>();
        final page = await (await client.getUrl(
          url.replace(path: '/tv'),
        )).close();
        expect(page.statusCode, 200);
        final html = await utf8.decoder.bind(page).join();
        expect(html, contains('<video'));
        expect(html, contains('/tv-status'));
        final status = await (await client.getUrl(
          url.replace(
            path: '/tv-status',
            queryParameters: {
              'state': 'playing',
              'time': '4.5',
              'engine': 'hlsjs',
              'ahead': '12.5',
              'ready': '4',
            },
          ),
        )).close();
        expect(status.statusCode, 204);
        await status.drain<void>();
        expect(relay.receiverState, 'playing');
        expect(relay.receiverTime, 4.5);
        expect(relay.receiverEngine, 'hlsjs');
        expect(relay.receiverBufferedSeconds, 12.5);
        expect(relay.receiverReadyState, 4);
        final player = await (await client.getUrl(
          url.replace(path: '/tv-hls.js'),
        )).close();
        expect(player.statusCode, 200);
        expect(player.headers.contentType?.mimeType, 'application/javascript');
        final playerJs = await utf8.decoder.bind(player).join();
        expect(playerJs.length, greaterThan(100000));
      } finally {
        client.close(force: true);
        await relay.close();
        await subscription.cancel();
        await upstream.close(force: true);
      }
    },
  );
  test(
    'HLS relay rewrites segments, variants and keys to registered URLs',
    () async {
      final relay = MediaRelay(cookies: (_) async => '');
      try {
        final root = await relay.start(
          Uri.parse('https://media.example/master.m3u8'),
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        final playlist = relay.rewritePlaylist(
          '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXT-X-MAP:URI="init.mp4"\nvariant.m3u8\nsegment.ts\n',
          Uri.parse('https://media.example/path/list.m3u8'),
        );
        expect(playlist, contains('#EXTM3U'));
        expect(playlist, contains('URI="http://127.0.0.1:${root.port}/'));
        expect(playlist, contains('.m3u8'));
        expect(playlist, isNot(contains('segment.ts')));
        expect(playlist, isNot(contains('https://media.example')));
      } finally {
        await relay.close();
      }
    },
  );
  test('SOAP escapes metadata and reports rejected playback', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      expect(body, contains('&amp;'));
      expect(body, contains('&lt;'));
      req.response.statusCode = 500;
      await req.response.close();
    });
    try {
      await expectLater(
        TvCast.command(
          CastTv('Test', Uri.parse('http://127.0.0.1:${server.port}/control')),
          'SetAVTransportURI',
          {
            'CurrentURI': 'https://a.example/?a=1&b=2',
            'CurrentURIMetaData': '<test>',
          },
        ),
        throwsStateError,
      );
    } finally {
      await server.close(force: true);
    }
  });
}
