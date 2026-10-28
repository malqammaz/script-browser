import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/application/media_source.dart';

void main() {
  test(
    'Public MEGA files normalize to official embeds and retain their supplied key',
    () {
      final key = 'A' * 43;
      final file = Uri.parse('https://mega.nz/file/AbCd1234#$key');
      expect(
        publicMegaFile(
          Uri.parse('https://mega.nz/embed/AbCd1234#$key'),
        ).toString(),
        '$file',
      );
      expect(
        publicMegaFile(Uri.parse('https://mega.nz/file/AbCd1234')),
        isNull,
      );
      expect(
        publicMegaPreview(file).toString(),
        'https://mega.nz/embed/AbCd1234#$key',
      );
      expect(
        castableMedia('$file').toString(),
        'https://mega.nz/embed/AbCd1234#$key',
      );
      expect(
        publicMegaPreview(Uri.parse('https://mega.nz/folder/AbCd1234#$key')),
        isNull,
      );
      expect(
        publicMegaPreview(Uri.parse('https://mega.nz/file/AbCd1234')),
        isNull,
      );
      expect(
        publicMegaPreview(
          Uri.parse('https://mega.nz.evil.example/file/AbCd1234#$key'),
        ),
        isNull,
      );
      expect(
        publicMegaPreview(Uri.parse('http://mega.nz/file/AbCd1234#$key')),
        isNull,
      );
    },
  );
  test('Extensionless URLs require an actual video element', () {
    const url = 'https://cdn.example/opaque/token~abc?token=signed&expiry=123';
    expect(castableMedia(url), isNull);
    expect(castableMedia(url, fromVideoElement: true).toString(), url);
    expect(
      castableMedia('blob:https://example.com/123', fromVideoElement: true),
      isNull,
    );
    expect(
      castableMedia('javascript:alert(1)', fromVideoElement: true),
      isNull,
    );
  });
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
