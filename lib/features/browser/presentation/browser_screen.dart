import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../application/tv_cast.dart';
import 'cast_dialog.dart';
import '../../scripts/application/anime_library_sync.dart';
import '../../../core/storage/settings_store.dart';
import '../../protection/presentation/protection_dialog.dart';
import '../../scripts/domain/script.dart';
import '../../scripts/domain/script_repository.dart';
import '../../scripts/presentation/github_config_dialog.dart';
import '../../scripts/presentation/script_editor_dialog.dart';
import '../../scripts/presentation/script_picker_dialog.dart';
import '../../scripts/presentation/site_scripts_bar.dart';
import '../application/browser_session.dart';
import '../infrastructure/browser_web.dart';
import '../infrastructure/android_cast_keep_alive.dart';
import 'widgets/address_bar.dart';
import 'widgets/cast_status_bar.dart';
import 'widgets/script_panel.dart';
import 'widgets/scripts_dock.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.settingsStore,
    required this.repositories,
  });
  final SettingsStore settingsStore;
  final ScriptRepositoryFactory repositories;
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final address = TextEditingController();
  late final BrowserSession session;
  late final BrowserWeb web;
  String _lastUrl = '';
  static const tokenKey = 'anime_library_github_token';
  final secureStorage = const FlutterSecureStorage();
  final librarySync = AnimeLibrarySync();
  final castBackground = AndroidCastKeepAlive();
  late final tvCast = TvCast(keepAlive: castBackground);

  @override
  void initState() {
    super.initState();
    castBackground.onStopRequested = () async {
      await tvCast.stop();
      if (mounted) setState(() {});
    };
    castBackground.attach();
    session = BrowserSession(
      settingsStore: widget.settingsStore,
      repositories: widget.repositories,
      syncLibrary: (data) async {
        final token = await secureStorage.read(key: tokenKey) ?? '';
        return librarySync.sync(data, token);
      },
    );
    web = BrowserWeb(
      blocker: session.blocker,
      onStarted: session.pageStarted,
      onFinished: session.pageFinished,
      onProgress: session.progressChanged,
      onBlocked: session.requestBlocked,
      onError: (message) {
        session.pageFailed();
        notice(message);
      },
    );
    session.engine = web;
    session.addListener(onSessionChanged);
    handle(session.initialize);
  }

  void onSessionChanged() {
    if (!mounted) return;
    if (_lastUrl != session.url) {
      _lastUrl = session.url;
      address.text = session.url;
    }
    setState(() {});
  }

  void notice(Object message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$message')));
    }
  }

  Future<void> handle(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      notice(error);
    }
  }

  Future<void> chooseScript() async {
    final config = await showDialog<GitHubConfig>(
      context: context,
      builder: (_) => GitHubConfigDialog(
        initial: session.github,
        domain: session.siteScripts.domain,
      ),
    );
    if (config == null || !mounted) return;
    final files = await session.listScripts(config);
    if (!mounted) return;
    await pickFromFiles(files);
  }

  Future<void> availableScripts() async {
    if (!session.siteScripts.configured) {
      await chooseScript();
      return;
    }
    await pickFromFiles(session.siteScripts.files);
  }

  Future<void> pickFromFiles(List<ScriptFile> files) async {
    final chosen = await showDialog<ScriptFile>(
      context: context,
      builder: (_) =>
          ScriptPickerDialog(files: files, domain: session.siteScripts.domain),
    );
    if (chosen == null || !mounted) return;
    await session.selectScript(chosen);
    if (mounted) await editScript();
  }

  Future<void> editScript() async {
    final source = await showDialog<String>(
      context: context,
      builder: (_) => ScriptEditorDialog(document: session.script),
    );
    if (source != null && mounted) await session.saveScript(source);
  }

  Future<void> editProtection() async {
    final host = Uri.tryParse(session.url)?.host ?? '';
    final selection = await showDialog<ProtectionSelection>(
      context: context,
      builder: (_) => ProtectionDialog(
        blocker: session.blocker,
        host: host,
        blockedCount: session.blockedCount,
      ),
    );
    if (selection == null || !mounted) return;
    await session.saveProtection(
      enabled: selection.enabled,
      host: host,
      allowSite: selection.allowSite,
      customDomains: selection.customDomains,
    );
  }

  Future<void> configureLibrarySync() async {
    final configured = await secureStorage.containsKey(key: tokenKey);
    if (!mounted) return;
    final controller = TextEditingController();
    try {
      final selection = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Anime library sync'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'malqammaz/anime-library → library.json\nAfter setup, run sync-anime-library.js on an anime page to extract, merge, and upload automatically.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'GitHub fine-grained token',
                    helperText: configured
                        ? 'Token saved; leave blank to keep it'
                        : 'Contents: Read and write for this repository only',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The token is stored securely in the app and is not sent to the anime page.',
                ),
              ],
            ),
          ),
          actions: [
            if (configured)
              TextButton(
                onPressed: () => Navigator.pop(context, 'disable'),
                child: const Text('Disable sync and delete token'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save and enable'),
            ),
          ],
        ),
      );
      if (selection == 'disable') {
        await secureStorage.delete(key: tokenKey);
        notice('Sync disabled and token deleted from the app');
      } else if (selection == 'save') {
        final token = controller.text.trim();
        if (token.isEmpty && !configured) {
          throw const FormatException('Enter a GitHub token to enable sync.');
        }
        if (token.isNotEmpty) {
          await AnimeLibrarySync.githubRequest('GET', token, null);
          await secureStorage.write(key: tokenKey, value: token);
        }
        notice('Sync is ready; run sync-anime-library.js on the anime page');
      }
    } finally {
      controller.clear();
      controller.dispose();
    }
  }

  @override
  void dispose() {
    castBackground.detach();
    tvCast.close();
    session.removeListener(onSessionChanged);
    session.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Script Browser'),
      actions: [
        IconButton(
          tooltip: 'Cast to TV',
          onPressed: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => CastDialog(web: web, cast: tvCast),
            );
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.cast),
        ),
        IconButton(
          tooltip: 'Ad protection',
          onPressed: () => handle(editProtection),
          icon: Icon(
            session.blocker.activeFor(session.url)
                ? Icons.shield
                : Icons.shield_outlined,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Settings and tools',
          onSelected: (value) => handle(() async {
            switch (value) {
              case 'sync':
                await configureLibrarySync();
              case 'github':
                await chooseScript();
              case 'edit':
                await editScript();
            }
          }),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'sync',
              enabled: !session.running,
              child: const Text('Anime library sync'),
            ),
            PopupMenuItem(
              value: 'github',
              enabled: !session.running && !session.busy,
              child: const Text('GitHub script settings'),
            ),
            PopupMenuItem(
              value: 'edit',
              enabled: !session.running,
              child: const Text('Edit script'),
            ),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          AddressBar(
            controller: address,
            onOpen: () {
              FocusScope.of(context).unfocus();
              handle(() => session.open(address.text));
            },
            onReload: () => handle(session.reload),
            onBack: () => handle(session.back),
          ),
          if (session.progress < 100 || session.busy)
            LinearProgressIndicator(
              value: session.busy ? null : session.progress / 100,
            ),
          Expanded(child: web.view()),
          if (tvCast.connected != null)
            CastStatusBar(
              cast: tvCast,
              onOpen: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => CastDialog(web: web, cast: tvCast),
                );
                if (mounted) setState(() {});
              },
              onStop: () => handle(() async {
                await tvCast.stop();
                if (mounted) setState(() {});
              }),
            ),
          Offstage(
            offstage: MediaQuery.viewInsetsOf(context).bottom > 0,
            child: ScriptsDock(
              running: session.running,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SiteScriptsBar(
                    scripts: session.siteScripts,
                    onChoose:
                        session.busy ||
                            session.running ||
                            session.siteScripts.loading
                        ? null
                        : () => handle(availableScripts),
                    onRefresh: () => handle(
                      () => session.siteScripts.discover(refresh: true),
                    ),
                  ),
                  ScriptPanel(
                    name: session.script.name,
                    result: session.result,
                    running: session.running,
                    onRun: session.canRun ? () => handle(session.run) : null,
                    onCopied: () => notice('Output copied'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
