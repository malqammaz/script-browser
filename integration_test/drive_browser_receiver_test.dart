import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Serves the public Drive player to LG without fetching the original',
    (tester) async {
      final cast = TvCast();
      try {
        final tv = (await TvCast.discover())
            .where((d) => d.name.contains('UR78006LL'))
            .first;
        await cast.cast(
          tv,
          Uri.parse(
            'https://drive.google.com/file/d/1sK7cH4NKuWxdjtLHxexMHH9IyzAPuqT1/preview',
          ),
          cookies: (_) async => '',
          useBrowserReceiver: true,
        );
        debugPrint('DRIVE_BROWSER_READY ${cast.receiverUrl}');
        for (var i = 0; i < 180 && !cast.relay!.receiverPageOpened; i++)
          await tester.pump(const Duration(seconds: 1));
        expect(cast.relay!.receiverPageOpened, true);
        await tester.pump(const Duration(seconds: 45));
        debugPrint(
          'Drive player page opened on LG. Playback requires user visual confirmation.',
        );
      } finally {
        await cast.stop();
        await cast.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
