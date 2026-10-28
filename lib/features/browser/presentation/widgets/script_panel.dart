import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScriptPanel extends StatelessWidget {
  const ScriptPanel({
    super.key,
    required this.name,
    required this.result,
    required this.running,
    required this.onRun,
    required this.onCopied,
  });
  final String name;
  final String result;
  final bool running;
  final VoidCallback? onRun;
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
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              FilledButton.icon(
                onPressed: onRun,
                icon: Icon(running ? Icons.hourglass_top : Icons.play_arrow),
                label: Text(running ? 'Running' : 'Run'),
              ),
            ],
          ),
          ExpansionTile(
            title: Text(
              running ? 'Running script…' : 'Script output',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              result.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              if (running) const LinearProgressIndicator(),
              SizedBox(
                height: 160,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    result,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: result.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: result));
                        onCopied();
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copy output'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
