import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';

void main() {
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
