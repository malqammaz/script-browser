import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:script_browser/core/storage/preferences_settings_store.dart';
import 'package:script_browser/features/browser/application/browser_session.dart';
import 'package:script_browser/features/browser/presentation/saved_sites_dialog.dart';
import 'support/fakes.dart';

void main() {
  Future<BrowserSession> createSession() async {
    final store = PreferencesSettingsStore(
      await SharedPreferences.getInstance(),
    );
    final session = BrowserSession(
      settingsStore: store,
      repositories: (_) => FakeScriptRepository(),
    )..engine = FakeBrowserEngine();
    await session.initialize();
    return session;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Visits are deduplicated, bounded, and persisted; clear keeps bookmarks',
    () async {
      final session = await createSession();
      for (var i = 0; i < 105; i++) {
        session.pageFinished('https://example.com/$i');
      }
      session.pageFinished('https://example.com/50');
      session.pageFinished('about:blank');
      session.pageFinished('javascript:alert(1)');
      // Bookmark writes share the queue, so this also waits for every visit write.
      await session.toggleBookmark('https://example.com/50');
      expect(session.recentSites.length, 100);
      expect(session.recentSites.first, 'https://example.com/50');
      expect(session.recentSites.where((url) => url.endsWith('/50')).length, 1);
      final restored = await createSession();
      expect(restored.recentSites, session.recentSites);
      expect(restored.bookmarks, ['https://example.com/50']);
      await restored.clearRecentSites();
      final cleared = await createSession();
      expect(cleared.recentSites, isEmpty);
      expect(cleared.bookmarks, ['https://example.com/50']);
      session.dispose();
      restored.dispose();
      cleared.dispose();
    },
  );

  test(
    'Concurrent bookmark toggles do not lose updates and reject unsafe URLs',
    () async {
      final session = await createSession();
      await Future.wait([
        session.toggleBookmark('https://one.example/episode#1'),
        session.toggleBookmark('https://two.example/'),
        session.toggleBookmark('file:///private/file'),
        session.toggleBookmark('https://user:pass@example.com/'),
      ]);
      expect(session.bookmarks, [
        'https://two.example/',
        'https://one.example/episode#1',
      ]);
      await session.toggleBookmark('https://two.example/');
      expect(session.bookmarks, ['https://one.example/episode#1']);
      session.pageFinished('https://one.example/episode#1');
      await session.removeRecent('https://one.example/episode#1');
      expect(session.recentSites, isEmpty);
      expect(session.bookmarks, hasLength(1));
      session.dispose();
    },
  );

  testWidgets('Saved sites can be searched, bookmarked and reopened', (
    tester,
  ) async {
    final session = await createSession();
    session.pageFinished('https://example.com/episode-2');
    await session.toggleBookmark('https://other.example/');
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showDialog<String>(
                  context: context,
                  builder: (_) => SavedSitesDialog(session: session),
                );
              },
              child: const Text('Open sites'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sites'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'episode-2');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark site'));
    await tester.pumpAndSettle();
    expect(session.isBookmarked('https://example.com/episode-2'), isTrue);
    await tester.tap(find.text('https://example.com/episode-2'));
    await tester.pumpAndSettle();
    expect(selected, 'https://example.com/episode-2');
    expect(tester.takeException(), isNull);
    session.dispose();
  });
}
