import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/application/media_source.dart';

void main() {
  test(
    'Only embeds public Drive preview pages, never download or external URLs',
    () {
      expect(
        publicDrivePreview(
          Uri.parse(
            'https://drive.google.com/file/d/test_ID-123/view?usp=sharing',
          ),
        ).toString(),
        'https://drive.google.com/file/d/test_ID-123/preview',
      );
      expect(
        publicDrivePreview(
          Uri.parse('https://drive.google.com/uc?export=download&id=test'),
        ),
        isNull,
      );
      expect(
        publicDrivePreview(
          Uri.parse('https://evil.example/file/d/test/preview'),
        ),
        isNull,
      );
    },
  );
  test('Accepts Drive preview media and drops only unsigned byte ranges', () {
    final uri = castableMedia(
      'https://r1.googlevideo.com/videoplayback?mime=video%2Fmp4&itag=18&range=0-100&sparams=id,expire',
    );
    expect(uri, isNotNull);
    expect(uri!.queryParameters.containsKey('range'), false);
    expect(
      castableMedia(
        'https://r1.googlevideo.com/videoplayback?mime=video%2Fmp4&range=0-100&sparams=range',
      )!.queryParameters['range'],
      '0-100',
    );
  });
  test(
    'Does not accept Drive original downloads, logins or audio-only tracks',
    () {
      for (final url in [
        'https://drive.usercontent.google.com/download?id=file&confirm=t',
        'https://drive.google.com/uc?id=file&export=download',
        'https://accounts.google.com/',
        'https://r1.googlevideo.com/videoplayback?mime=audio%2Fmp4&itag=140',
        'https://fakegooglevideo.com/videoplayback?mime=video%2Fmp4',
      ]) {
        expect(castableMedia(url), isNull);
      }
    },
  );
}
