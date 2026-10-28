import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/application/ram_media_buffer.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    condition(),
    true,
    reason: 'Background buffering did not reach the expected state',
  );
}

void main() {
  test(
    'Default limit is 128 MiB; LRU eviction and oversize rejection preserve budget',
    () {
      expect(RamMediaBuffer().capacity, 128 * 1024 * 1024);
      final buffer = RamMediaBuffer(capacity: 8);
      BufferedSegment data(int size) =>
          BufferedSegment(Uint8List(size), 'video/mp2t');
      final a = Uri.parse('https://example.com/a'),
          b = Uri.parse('https://example.com/b'),
          c = Uri.parse('https://example.com/c');
      buffer.put(a, data(4));
      buffer.put(b, data(4));
      buffer.get(a);
      buffer.put(c, data(4));
      expect(buffer.contains(a), true);
      expect(buffer.contains(b), false);
      expect(buffer.usedBytes, 8);
      expect(buffer.put(b, data(9)), false);
      expect(buffer.usedBytes, 8);
      buffer.clear();
      expect(buffer.usedBytes, 0);
    },
  );
  test(
    'Prefetch stays bounded, serves cached ranges, and moves the window after seeking',
    () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final hits = <String, int>{};
      upstream.listen((req) async {
        hits.update(req.uri.path, (n) => n + 1, ifAbsent: () => 1);
        if (req.uri.path == '/list.m3u8') {
          req.response.headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          );
          req.response.write(
            '#EXTM3U\n${List.generate(8, (i) => '#EXTINF:10,\n$i.ts').join('\n')}\n#EXT-X-ENDLIST\n',
          );
        } else {
          final index = int.parse(
            req.uri.path.split('/').last.split('.').first,
          );
          req.response.headers.contentType = ContentType('video', 'mp2t');
          req.response.contentLength = 512;
          req.response.add(List.filled(512, index));
        }
        await req.response.close();
      });
      final relay = MediaRelay(
        cookies: (_) async => '',
        bufferBytes: 2048,
        maxSegmentBytes: 512,
        prefetchDelay: Duration.zero,
      );
      final client = HttpClient();
      try {
        final root = await relay.start(
          Uri.parse('http://127.0.0.1:${upstream.port}/list.m3u8'),
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        final playlist = await (await client.getUrl(root)).close();
        final text = await playlist
            .transform(const SystemEncoding().decoder)
            .join();
        final local = text
            .split('\n')
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .map(Uri.parse)
            .toList();
        await until(() => relay.buffer.usedBytes == 2048);
        expect(hits.keys.where((p) => p.endsWith('.ts')).length, 4);
        final request = await client.getUrl(local[1]);
        request.headers.set('Range', 'bytes=1-3');
        final response = await request.close();
        expect(response.statusCode, 206);
        expect(response.headers.value('Content-Range'), 'bytes 1-3/512');
        final bytes = await response.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        expect(bytes, [1, 1, 1]);
        expect(hits['/1.ts'], 1);
        final seek = await (await client.getUrl(local[6])).close();
        await seek.drain<void>();
        await until(
          () => relay.buffer.contains(
            Uri.parse('http://127.0.0.1:${upstream.port}/7.ts'),
          ),
        );
        expect(relay.buffer.usedBytes, lessThanOrEqualTo(2048));
        expect(hits['/6.ts'], 1);
      } finally {
        client.close(force: true);
        await relay.close();
        await upstream.close(force: true);
      }
      expect(relay.buffer.usedBytes, 0);
    },
  );
  test(
    'Rate limits pause prefetch and do not trigger an immediate retry',
    () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var segmentRequests = 0;
      upstream.listen((req) async {
        if (req.uri.path.endsWith('.m3u8')) {
          req.response.write(
            '#EXTM3U\n#EXTINF:10,\n0.ts\n#EXTINF:10,\n1.ts\n#EXT-X-ENDLIST\n',
          );
        } else {
          segmentRequests++;
          req.response.statusCode = 429;
          req.response.headers.set('Retry-After', '120');
        }
        await req.response.close();
      });
      final relay = MediaRelay(
        cookies: (_) async => '',
        bufferBytes: 2048,
        maxSegmentBytes: 512,
        prefetchDelay: Duration.zero,
      );
      final client = HttpClient();
      try {
        final root = await relay.start(
          Uri.parse('http://127.0.0.1:${upstream.port}/list.m3u8'),
          InternetAddress.loopbackIPv4,
          '127.0.0.1',
        );
        final response = await (await client.getUrl(root)).close();
        final text = await response
            .transform(const SystemEncoding().decoder)
            .join();
        final first = Uri.parse(
          text.split('\n').firstWhere((line) => line.startsWith('http:')),
        );
        await until(() => segmentRequests == 1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final blocked = await (await client.getUrl(first)).close();
        expect(blocked.statusCode, 429);
        expect(
          int.parse(blocked.headers.value('retry-after')!),
          greaterThan(60),
        );
        await blocked.drain<void>();
        expect(segmentRequests, 1);
      } finally {
        client.close(force: true);
        await relay.close();
        await upstream.close(force: true);
      }
    },
  );
}
