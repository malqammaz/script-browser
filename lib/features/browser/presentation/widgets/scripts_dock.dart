import 'package:flutter/material.dart';

/// Keeps the complete scripts workspace mounted while giving space back to the page.
class ScriptsDock extends StatefulWidget {
  const ScriptsDock({super.key, required this.child, required this.running});
  final Widget child;
  final bool running;
  @override
  State<ScriptsDock> createState() => _ScriptsDockState();
}

class _ScriptsDockState extends State<ScriptsDock> {
  bool minimized = false;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.javascript, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.running ? 'Scripts · Running…' : 'Scripts',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: minimized ? 'Expand scripts' : 'Minimize scripts',
                isSelected: minimized,
                onPressed: () => setState(() => minimized = !minimized),
                icon: Icon(
                  minimized
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ),
            ],
          ),
        ),
        Offstage(offstage: minimized, child: widget.child),
      ],
    ),
  );
}
