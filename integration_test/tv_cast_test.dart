import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Phone discovers LG and relays sample video to it', (
    tester,
  ) async {
    final devices = await TvCast.discover();
    final tv = devices.where((d) => d.name.contains('UR78006LL')).first;
    final cast = TvCast();
    try {
      await cast.cast(
        tv,
        Uri.parse('https://media.w3.org/2010/05/sintel/trailer.mp4'),
        cookies: (_) async => '',
      );
      final state = await TvCast.command(tv, 'GetTransportInfo');
      expect(state, contains('PLAYING'));
      await Future<void>.delayed(const Duration(seconds: 3));
      final position = await TvCast.command(tv, 'GetPositionInfo');
      expect(position, contains('<TrackURI>http://'));
      final time = RegExp(
        r'<RelTime>([^<]+)</RelTime>',
      ).firstMatch(position)?.group(1);
      expect(time, isNotNull);
      expect(time, isNot('00:00:00'));
    } finally {
      await cast.stop();
      await cast.close();
    }
  });
}
