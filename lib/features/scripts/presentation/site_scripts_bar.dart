import 'package:flutter/material.dart';
import '../application/site_scripts_controller.dart';

class SiteScriptsBar extends StatelessWidget {
  const SiteScriptsBar({
    super.key,
    required this.scripts,
    required this.onChoose,
    required this.onRefresh,
  });
  final SiteScriptsController scripts;
  final VoidCallback? onChoose;
  final VoidCallback onRefresh;
  String get label {
    if (!scripts.configured) return 'Connect GitHub to find site scripts';
    if (scripts.domain.isEmpty) return 'Open a website to see its scripts';
    if (scripts.loading) return 'Finding scripts for ${scripts.domain}…';
    if (scripts.error != null) return 'Could not load scripts — tap refresh';
    return '${scripts.domain} · ${scripts.files.length} scripts available';
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextButton.icon(
          onPressed: onChoose,
          icon: const Icon(Icons.javascript),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
      IconButton(
        tooltip: 'Refresh site scripts',
        onPressed:
            scripts.loading || !scripts.configured || scripts.domain.isEmpty
            ? null
            : onRefresh,
        icon: const Icon(Icons.sync, size: 20),
      ),
    ],
  );
}
