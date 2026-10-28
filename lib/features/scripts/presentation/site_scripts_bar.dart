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
    if (!scripts.configured) return 'اربط GitHub للتعرف على سكربتات المواقع';
    if (scripts.domain.isEmpty) return 'افتح موقعًا لعرض سكربتاته';
    if (scripts.loading) return 'جارٍ البحث عن سكربتات ${scripts.domain}…';
    if (scripts.error != null) return 'تعذر جلب السكربتات — اضغط تحديث';
    return '${scripts.domain} · ${scripts.files.length} سكربت متاح';
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
        tooltip: 'تحديث سكربتات الموقع',
        onPressed:
            scripts.loading || !scripts.configured || scripts.domain.isEmpty
            ? null
            : onRefresh,
        icon: const Icon(Icons.sync, size: 20),
      ),
    ],
  );
}
