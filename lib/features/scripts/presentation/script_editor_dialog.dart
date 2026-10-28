import 'package:flutter/material.dart';
import '../domain/script.dart';

class ScriptEditorDialog extends StatefulWidget {
  const ScriptEditorDialog({super.key, required this.document});
  final ScriptDocument document;
  @override
  State<ScriptEditorDialog> createState() => _ScriptEditorDialogState();
}

class _ScriptEditorDialogState extends State<ScriptEditorDialog> {
  late final editor = TextEditingController(text: widget.document.source);
  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.document.name),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Scripts can read and interact with this page. Only run code you trust. Use return for a result; await is supported.',
          ),
          const SizedBox(height: 12),
          Flexible(
            child: TextField(
              controller: editor,
              textDirection: TextDirection.ltr,
              maxLines: 18,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(border: OutlineInputBorder()),
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
      FilledButton(
        onPressed: () => Navigator.pop(context, editor.text),
        child: const Text('Save and close'),
      ),
    ],
  );
}
