import 'package:flutter/material.dart';
import 'package:script_browser/features/browser/presentation/widgets/address_bar.dart';
import 'package:script_browser/features/browser/presentation/widgets/scripts_dock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:script_browser/features/browser/presentation/cast_dialog.dart';
import 'package:script_browser/features/browser/presentation/widgets/script_panel.dart';
import 'package:script_browser/features/browser/application/tv_cast.dart';
import 'package:script_browser/features/browser/infrastructure/browser_web.dart';
import 'package:script_browser/features/protection/domain/ad_blocker.dart';

void main() {
  testWidgets('Address controls fit a compact phone and remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0, reloaded = 0, wentBack = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddressBar(
            controller: controller,
            onOpen: () => opened++,
            onReload: () => reloaded++,
            onBack: () => wentBack++,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(0));
    await tester.tap(find.byTooltip('Go'));
    await tester.tap(find.byTooltip('Reload'));
    await tester.tap(find.byTooltip('Back'));
    expect(opened, 1);
    expect(reloaded, 1);
    expect(wentBack, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Corner arrow minimizes the entire scripts area without losing output',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScriptsDock(
              running: false,
              child: ScriptPanel(
                name: 'test.js',
                result: 'kept output',
                running: false,
                onRun: () {},
                onCopied: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Script output'));
      await tester.pumpAndSettle();
      expect(find.text('Copy output'), findsOneWidget);
      await tester.tap(find.byTooltip('Minimize scripts'));
      await tester.pumpAndSettle();
      expect(find.text('Run'), findsNothing);
      expect(find.text('Copy output'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      await tester.tap(find.byTooltip('Expand scripts'));
      await tester.pumpAndSettle();
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Copy output'), findsOneWidget);
      expect(find.text('kept output'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
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
    expect(find.text('Copy output'), findsNothing);
    await tester.tap(find.text('Script output'));
    await tester.pumpAndSettle();
    expect(find.text('Copy output'), findsOneWidget);
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
            Directionality(textDirection: TextDirection.ltr, child: child!),
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
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('HLS · Adaptive stream'), findsOneWidget);
    expect(find.text('https://example.com/video.m3u8'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Start casting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
