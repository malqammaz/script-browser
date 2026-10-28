import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/scripts/application/anime_library_sync.dart';

void main() {
  Map<String, dynamic> incoming() => {
    'title': 'انمي Overgeared',
    'image': 'https://images.example/overgeared.jpg',
    'episodes': [
      {
        'number': 1,
        'title': 'مشاهدة',
        'links': [
          {'url': 'https://dood.to/e/a', 'label': 'Dood FHD', 'type': 'player'},
          {'url': 'https://dood.to/e/a', 'label': '', 'type': 'iframe'},
        ],
      },
    ],
  };
  test('Merges padded numbers, preserves data, repairs labels and titles', () {
    final library = <String, dynamic>{
      'anime': [
        {
          'title': 'انمي Overgeared',
          'episodes': [
            {
              'number': '01',
              'title': 'مشاهدة',
              'links': [
                {'url': 'https://old.example/video'},
              ],
            },
          ],
        },
        {'title': 'Other', 'episodes': []},
      ],
    };
    final result = AnimeLibrarySync.merge(library, incoming());
    expect(result['added'], 0);
    expect(library['anime'].length, 2);
    expect(
      library['anime'][0]['image'],
      'https://images.example/overgeared.jpg',
    );
    final ep = library['anime'][0]['episodes'][0];
    expect(ep['title'], 'الحلقة 1');
    expect(ep['links'].length, 2);
    expect(ep['links'][1]['label'], 'Dood FHD');
    expect(ep['links'][1]['quality'], 'FHD');
  });
  test('Rejects malicious URLs', () {
    final data = incoming();
    data['episodes'][0]['links'][0]['url'] = 'javascript:alert(1)';
    expect(
      () => AnimeLibrarySync.merge({'anime': []}, data),
      throwsFormatException,
    );
  });
  test('Preserves the cover when the next scrape has no image', () {
    final library = <String, dynamic>{'anime': []};
    AnimeLibrarySync.merge(library, incoming());
    final next = incoming()..remove('image');
    AnimeLibrarySync.merge(library, next);
    expect(
      library['anime'][0]['image'],
      'https://images.example/overgeared.jpg',
    );
  });
  test('Missing credential never sends a request', () async {
    final sync = AnimeLibrarySync(
      request: (_, _, _) async => throw StateError('Unexpected request'),
    );
    await expectLater(sync.sync(incoming(), ''), throwsStateError);
  });
  test(
    'Retries conflicts with latest SHA and keeps token out of output',
    () async {
      var reads = 0, writes = 0;
      final sync = AnimeLibrarySync(
        request: (method, token, body) async {
          expect(token, 'secret');
          if (method == 'GET') {
            reads++;
            return {
              'sha': 'sha-$reads',
              'encoding': 'base64',
              'content': base64Encode(utf8.encode('{"anime":[]}')),
            };
          }
          writes++;
          expect(body!['sha'], 'sha-$reads');
          expect(body['branch'], 'main');
          if (writes == 1) throw const LibraryConflict();
          final saved = jsonDecode(
            utf8.decode(base64Decode(body['content'] as String)),
          );
          expect(saved['anime'][0]['title'], 'Overgeared');
          return {
            'content': {'html_url': 'https://github.com/example/library.json'},
          };
        },
      );
      final result = await sync.sync(incoming(), 'secret');
      expect(reads, 2);
      expect(writes, 2);
      expect(result['success'], true);
      expect(jsonEncode(result), isNot(contains('secret')));
    },
  );
  test('Does not commit an unchanged library', () async {
    final library = <String, dynamic>{'anime': []};
    AnimeLibrarySync.merge(library, incoming());
    final sync = AnimeLibrarySync(
      request: (method, _, _) async {
        expect(method, 'GET');
        return {
          'sha': 'sha',
          'encoding': 'base64',
          'content': base64Encode(utf8.encode(jsonEncode(library))),
        };
      },
    );
    expect((await sync.sync(incoming(), 'secret'))['unchanged'], true);
  });
}
