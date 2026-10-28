import 'package:flutter/material.dart';
import '../domain/ad_blocker.dart';

class ProtectionSelection {
  const ProtectionSelection({
    required this.enabled,
    required this.allowSite,
    required this.customDomains,
  });
  final bool enabled;
  final bool allowSite;
  final Set<String> customDomains;
}

class ProtectionDialog extends StatefulWidget {
  const ProtectionDialog({
    super.key,
    required this.blocker,
    required this.host,
    required this.blockedCount,
  });
  final AdBlocker blocker;
  final String host;
  final int blockedCount;
  @override
  State<ProtectionDialog> createState() => _ProtectionDialogState();
}

class _ProtectionDialogState extends State<ProtectionDialog> {
  late bool enabled = widget.blocker.enabled;
  late bool allowSite = widget.blocker.allowedSites.contains(widget.host);
  late final custom = TextEditingController(
    text: widget.blocker.customDomains.join('\n'),
  );
  String? error;
  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  void save() {
    try {
      final domains = AdBlocker.parseCustomDomains(custom.text);
      Navigator.pop(
        context,
        ProtectionSelection(
          enabled: enabled,
          allowSite: allowSite,
          customDomains: domains,
        ),
      );
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ad protection'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Blocked ${widget.blockedCount} ad requests or popups on this page.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Block ads and trackers'),
            value: enabled,
            onChanged: (value) => setState(() => enabled = value),
          ),
          if (widget.host.isNotEmpty)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow ads on this site'),
              subtitle: Text(widget.host),
              value: allowSite,
              onChanged: (value) => setState(() => allowSite = value),
            ),
          const Text(
            'Blocks known ad domains and popups and hides common ad elements. Some ads may remain. If a site feature breaks, allow ads for this site above.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: custom,
            minLines: 3,
            maxLines: 6,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'Additional domains — one per line',
              hintText: 'ads.example.com',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save and reload')),
    ],
  );
}
