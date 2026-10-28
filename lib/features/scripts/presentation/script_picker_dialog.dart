import 'package:flutter/material.dart';
import '../domain/script.dart';

class ScriptPickerDialog extends StatelessWidget {
  const ScriptPickerDialog({
    super.key,
    required this.files,
    required this.domain,
  });
  final List<ScriptFile> files;
  final String domain;
  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: Text(
      domain.isEmpty
          ? 'افتح موقعًا أولًا لعرض سكربتاته'
          : files.isEmpty
          ? 'لا توجد سكربتات لـ $domain'
          : 'سكربتات $domain',
    ),
    children: files
        .map(
          (file) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, file),
            child: Text(file.name),
          ),
        )
        .toList(),
  );
}
