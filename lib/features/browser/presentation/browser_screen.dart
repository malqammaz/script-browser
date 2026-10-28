import 'package:flutter/material.dart';
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
import 'widgets/address_bar.dart';
import 'widgets/script_panel.dart';

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

  @override
  void initState() {
    super.initState();
    session = BrowserSession(
      settingsStore: widget.settingsStore,
      repositories: widget.repositories,
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

  @override
  void dispose() {
    session.removeListener(onSessionChanged);
    session.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('متصفح السكربتات'),
      actions: [
        IconButton(
          tooltip: 'حماية الإعلانات',
          onPressed: () => handle(editProtection),
          icon: Icon(
            session.blocker.activeFor(session.url)
                ? Icons.shield
                : Icons.shield_outlined,
          ),
        ),
        IconButton(
          tooltip: 'GitHub',
          onPressed: session.busy || session.running
              ? null
              : () => handle(chooseScript),
          icon: const Icon(Icons.cloud_download_outlined),
        ),
        IconButton(
          tooltip: 'تعديل السكربت',
          onPressed: session.running ? null : () => handle(editScript),
          icon: const Icon(Icons.code),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          AddressBar(
            controller: address,
            onOpen: () => handle(() => session.open(address.text)),
            onReload: () => handle(session.reload),
          ),
          if (session.progress < 100 || session.busy)
            LinearProgressIndicator(
              value: session.busy ? null : session.progress / 100,
            ),
          Expanded(child: web.view()),
          SiteScriptsBar(
            scripts: session.siteScripts,
            onChoose:
                session.busy || session.running || session.siteScripts.loading
                ? null
                : () => handle(availableScripts),
            onRefresh: () =>
                handle(() => session.siteScripts.discover(refresh: true)),
          ),
          ScriptPanel(
            name: session.script.name,
            result: session.result,
            running: session.running,
            onRun: session.canRun ? () => handle(session.run) : null,
            onBack: () => handle(session.back),
            onCopied: () => notice('تم نسخ النتيجة'),
          ),
        ],
      ),
    ),
  );
}
