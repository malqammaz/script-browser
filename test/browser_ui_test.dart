import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/presentation/cast_dialog.dart';
import 'package:script_browser/features/browser/presentation/widgets/script_panel.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';
import 'package:script_browser/features/browser/infrastructure/browser_web.dart';
import 'package:script_browser/features/protection/domain/ad_blocker.dart';

void main() {
  testWidgets('Script output stays collapsed until requested', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptPanel(
            name: 'sync.js',
            result: 'result content',
            running: false,
            onRun: () {},
            onCopied: () {},
          ),
        ),
      ),
    );
    expect(find.text('نسخ النتيجة'), findsNothing);
    await tester.tap(find.text('نتيجة السكربت'));
    await tester.pumpAndSettle();
    expect(find.text('نسخ النتيجة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Casting steps fit a small phone and preserve video selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final web = BrowserWeb(
      blocker: AdBlocker(),
      onStarted: (_) {},
      onFinished: (_) {},
      onProgress: (_) {},
      onError: (_) {},
      onBlocked: () {},
    );
    web.rememberMedia('https://example.com/video.m3u8');
    final cast = TvCast();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CastDialog(
                  web: web,
                  cast: cast,
                  discover: () async => [
                    CastTv('LG test', Uri.parse('http://192.168.1.16/control')),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('LG test'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('HLS · بث متكيف'), findsOneWidget);
    expect(find.text('https://example.com/video.m3u8'), findsNothing);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('بدء البث'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
