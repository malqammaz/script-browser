import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:script_browser/app.dart';
import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Loads a selected remote script, edits it, runs it, and opens protection',
    (tester) async {
      final store = MemorySettingsStore();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<!doctype html><html><body><h1>Script test</h1></body></html>',
        );
        request.response.close();
      });
      await tester.pumpWidget(
        ScriptBrowserApp(
          settingsStore: store,
          repositories: (config) => FakeScriptRepository(folder: config.folder),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'http://127.0.0.1:${server.port}/',
      );
      await tester.tap(find.byTooltip('فتح'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('GitHub'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'owner/repo');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('تحميل القائمة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('remote.js'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ وإغلاق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تشغيل'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
      expect(store.savedGitHub?.repository, 'owner/repo');
      expect(store.savedScript?.name, 'remote.js');
      await tester.tap(find.byTooltip('حماية الإعلانات'));
      await tester.pumpAndSettle();
      expect(find.text('حظر الإعلانات والتتبع'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
    },
  );
}
