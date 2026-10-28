import 'package:flutter/material.dart';
import '../domain/script.dart';

class GitHubConfigDialog extends StatefulWidget {
  const GitHubConfigDialog({
    super.key,
    required this.initial,
    required this.domain,
  });
  final GitHubConfig initial;
  final String domain;
  @override
  State<GitHubConfigDialog> createState() => _GitHubConfigDialogState();
}

class _GitHubConfigDialogState extends State<GitHubConfigDialog> {
  late final repository = TextEditingController(
    text: widget.initial.repository,
  );
  late final branch = TextEditingController(text: widget.initial.branch);
  late final folder = TextEditingController(text: widget.initial.folder);
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    repository.dispose();
    branch.dispose();
    folder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('GitHub scripts'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use a public repository. The site domain is appended to the root folder, for example scripts/example.com/click.js.',
            ),
            if (widget.domain.isNotEmpty)
              Text('Current site: ${widget.domain}'),
            TextFormField(
              controller: repository,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'owner/repo'),
              validator: (value) =>
                  RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter owner/repo',
            ),
            TextFormField(
              controller: branch,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'Branch or commit SHA',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a branch'
                  : null,
            ),
            TextField(
              controller: folder,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'Scripts root folder (for example scripts)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            GitHubConfig(
              repository: repository.text.trim(),
              branch: branch.text.trim(),
              folder: folder.text.trim(),
            ),
          );
        },
        child: const Text('Load scripts'),
      ),
    ],
  );
}
