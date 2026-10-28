import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScriptPanel extends StatelessWidget {
  const ScriptPanel({
    super.key,
    required this.name,
    required this.result,
    required this.running,
    required this.onRun,
    required this.onBack,
    required this.onCopied,
  });
  final String name;
  final String result;
  final bool running;
  final VoidCallback? onRun;
  final VoidCallback onBack;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'رجوع',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
              ),
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              FilledButton.icon(
                onPressed: onRun,
                icon: Icon(running ? Icons.hourglass_top : Icons.play_arrow),
                label: const Text('تشغيل'),
              ),
            ],
          ),
          SizedBox(
            height: 90,
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.centerRight,
                child: SelectableText(result),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result));
                onCopied();
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ النتيجة'),
            ),
          ),
        ],
      ),
    ),
  );
}
