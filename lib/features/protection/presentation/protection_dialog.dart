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
    title: const Text('حماية الإعلانات'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تم حظر ${widget.blockedCount} طلب إعلان أو نافذة في هذه الصفحة.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('حظر الإعلانات والتتبع'),
            value: enabled,
            onChanged: (value) => setState(() => enabled = value),
          ),
          if (widget.host.isNotEmpty)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('السماح بالإعلانات لهذا الموقع'),
              subtitle: Text(widget.host),
              value: allowSite,
              onChanged: (value) => setState(() => allowSite = value),
            ),
          const Text(
            'يحظر نطاقات إعلانية معروفة والنوافذ الجديدة ويخفي علامات الإعلان الشائعة. قد لا يمنع جميع الإعلانات. إذا تعطلت وظيفة في الموقع، فعّل الاستثناء أعلاه.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: custom,
            minLines: 3,
            maxLines: 6,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'نطاقات إضافية — نطاق في كل سطر',
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
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: save, child: const Text('حفظ وإعادة تحميل')),
    ],
  );
}
